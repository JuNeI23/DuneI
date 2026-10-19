# Contrôle de la génération : la chaîne branchée et verrouillée

Version 0.4 · 2026-10-19 · backlog L1-21 · carnet « La chaîne de génération — L1-21 » · statut : implémentée, recette passée

## 1. Objet

Point fait le 2026-10-19 sur L1-21. La génération est **déjà dans la chaîne de construction** :
`make tokens`, `make motion` et `make energie` produisent `generated/`, et `make install` régénère toujours
avant de déployer, si bien qu'aucune valeur ne peut atteindre la session sans passer par les générateurs.
`make check` passe sur `main` : 492 tests, `generated/` identique à une génération fraîche.

Ce qui manque, c'est le verrou. Le carnet affirme qu'« un contrôle refuse la validation si un fichier généré
a été modifié à la main », mais rien ne l'impose : ni crochet git, ni contrôle sur GitHub. `make check` ne
tourne que si quelqu'un pense à le lancer, et il ne voit pas un fichier de `generated/` jamais ajouté à git
(`git diff` ignore les fichiers non suivis).

**Le risque que Nicolas veut fermer** : Claude ou un sous-agent qui retouche `generated/` à la main, ou
oublie de régénérer après un changement de source, et dont l'erreur traverse commit, push et fusion sans
alerte, jusqu'à se voir à l'écran sous la forme d'une valeur légèrement fausse.

**Choix de Nicolas (option D)** : deux étages.

1. Un **crochet git** avant chaque commit, local, qui refuse en 0,3 s.
2. Un **contrôle GitHub** sur chaque PR, `make check` complet, rendu obligatoire par une règle (*ruleset*)
   sur `main` : la fusion est refusée tant qu'il est rouge.

**Contournement (choix de Nicolas, option 2)** : le rôle administrateur peut passer outre, par
`gh pr merge --admin`, **réservé à Nicolas**. Claude ne passe jamais `--admin`, quelle que soit la
situation : un contrôle rouge se corrige, ou se signale à Nicolas. Comme Claude travaille avec le compte
GitHub de Nicolas, administrateur du dépôt, GitHub ne peut pas distinguer leurs fusions : la règle est
écrite dans `CLAUDE.md` **et** rendue mécanique par des refus dans les réglages de Claude Code (§ 3.6),
demandés par Nicolas après la relecture.

**Le crochet, lui, reste contournable par Claude** (`git commit --no-verify`), sur décision de Nicolas : le
second étage est le verrou, le premier une alerte précoce.

## 2. Critères de réussite

1. Un commit qui contient un fichier de `generated/` différent de ce que produisent les sources est refusé
   par le crochet, avec un message qui dit quoi faire. Il en va de même pour un changement de source
   commité sans sa régénération, et pour un fichier généré nouveau resté hors de git.
2. Le crochet est actif sur `caladan` après `make install`, et dans les arbres secondaires des sous-agents
   sans autre geste.
3. Une PR dont le contrôle GitHub est rouge ne peut pas être fusionnée par `gh pr merge <n> --merge`.
4. Le contrôle GitHub exécute `make check` complet, tests compris, dans un conteneur Arch.
5. Un push direct sur `main` est refusé ; l'étiquette `lot1` reste possible.
6. `make check` refuse aussi un fichier de `generated/` non suivi.
7. Claude Code refuse de lancer une fusion qui passerait outre la règle : `gh pr merge` avec `--admin`, et
   toute fusion par `gh api`.

## 3. Conception

### 3.1 `make check` voit aussi les fichiers non suivis

`git diff --exit-code generated/` est complété par un refus de tout fichier **non suivi** sous
`generated/` (`git ls-files --others --exclude-standard generated/`), pour qu'un fichier nouveau resté hors
de git soit vu. Un fichier généré correct et déjà indexé n'est pas refusé : la suite régénérer,
`git add`, `make check`, commit reste valable (choix de Claude après la relecture). Le diff reste affiché
quand il y en a un : c'est lui qui dit ce qui diffère.

### 3.2 Le crochet `pre-commit`

- Fichier versionné `.githooks/pre-commit`, script POSIX `sh`, exécutable, analysé par `shellcheck` comme
  les autres scripts (`tests/test_shellcheck.py` l'ajoute à sa liste).
- Il régénère (`make -s tokens motion energie`) puis compare `generated/` de l'arbre de travail à l'index :
  `git diff --exit-code generated/` et aucun fichier non suivi sous `generated/`. Toute différence refuse le
  commit, avec le diff et la consigne : « `generated/` ne s'édite pas ; régénérer, `git add generated/`,
  recommencer ».
- Il ne lance pas les tests (14 s) : c'est le rôle du contrôle GitHub.
- Il ne fait rien d'autre et ne modifie aucune source ; il réécrit `generated/` comme le fait déjà
  `make check`.
- **Limite acceptée** : comme il génère depuis les sources de l'arbre de travail, un changement de source
  non indexé lors d'un commit partiel fait refuser à tort. Le message le signale ; il suffit d'indexer la
  source ou de la mettre de côté.

### 3.3 Activation par `make install`

Une destination de plus dans `deploy.py` : si `git config --local core.hooksPath` vaut déjà `.githooks`,
rien ; s'il est absent, l'action « activer les crochets du dépôt » le pose ; s'il vaut autre chose, erreur
qui refuse tout, comme pour un fichier étranger. Le chemin relatif `.githooks` est résolu depuis la racine
de l'arbre de travail (documentation de git, `core.hooksPath`) : les arbres secondaires, qui partagent la
configuration du dépôt et contiennent `.githooks/` dès que leur branche part d'un `main` qui l'a, sont
couverts sans geste.

### 3.4 Le contrôle GitHub

- Workflow `.github/workflows/controle.yml`, déclenché par `pull_request` vers `main` et par
  `workflow_dispatch`. Une seule tâche, nommée `controle` : c'est le nom que la règle exige.
- Exécutée sur `ubuntu-latest` dans le conteneur `archlinux:latest` : la même distribution que les machines
  DuneI, les paquets du dépôt officiel.
- Installe le strict nécessaire au contrôle (`git`, `make`, `python`, `python-numpy`, `python-pillow`,
  `lua`, `shellcheck`) puis lance `make check`. Les tests qui demandent la session (`hyprctl`) ou les
  polices (`fc-match`) se sautent d'eux-mêmes, comme aujourd'hui sans l'outil.
- Actions épinglées par empreinte de commit, version en commentaire (recommandation de GitHub).

### 3.5 La règle sur `main`

- Un *ruleset* de branche, versionné en JSON dans `setup/github/regle-main.json`, appliqué par
  `gh api` selon une commande écrite au carnet. Il vit sur GitHub, pas sur la machine : une réinstallation
  ne le perd pas, et le fichier permet de le recréer ou de le relire.
- Cible : la branche par défaut. Mise en application : active.
- Règle unique : contrôles requis avant fusion, contrôle `controle`, sans exiger une branche à jour de
  `main` (un seul développeur, branches courtes).
- Contournement : le rôle administrateur du dépôt, en mode « par PR seulement » : `gh pr merge --admin`
  passe, un push direct sur `main` reste refusé à tous.
- L'étiquette `lot1` n'est pas visée : la règle ne cible que les branches.

### 3.6 Les refus dans les réglages de Claude Code

- Dans `~/dunei-atelier/claude/settings.json`, liste `permissions.deny`, à côté des refus de
  `git push --force` : `gh pr merge` portant `--admin`, et toute fusion de PR par `gh api` (route REST
  `…/pulls/<n>/merge` et mutation GraphQL `mergePullRequest`). La syntaxe exacte des motifs suit la
  documentation à jour de Claude Code ; un motif trop large, qui bloquerait une lecture par `gh api`, est
  préférable à un motif troué.
- Ces refus arrêtent le réflexe d'un agent bloqué ; ils ne prétendent pas résister à un détour délibéré.
- Le dépôt de l'atelier reçoit ce changement par un envoi direct sur son `main`, avec la ligne
  `Co-Authored-By` (D64).

## 4. Recette

1. `make test` et `make check` passent ; un test couvre la destination de `deploy.py` (absent, déjà posé,
   valeur étrangère) et le crochet (refus d'un fichier généré retouché, d'un fichier non suivi, d'une
   source sans régénération ; acceptation d'un commit propre), dans un dépôt temporaire.
2. Sur `caladan`, après `make install` : `git config core.hooksPath` vaut `.githooks` ; un commit qui
   retouche `generated/tokens.css` à la main est refusé.
3. La PR de cette feature fait tourner le contrôle, vert.
4. Après fusion, la règle est appliquée, puis éprouvée par une PR jetable dont un fichier généré est
   retouché (commit passé avec `--no-verify`) : contrôle rouge, `gh pr merge` refuse, et Claude Code
   refuse `gh pr merge --admin` sur cette même PR. La PR est fermée et sa
   branche supprimée. Ce n'est pas une opération factice sur `caladan` : rien ne touche la machine.
5. Un `git push origin main` direct est refusé (vérifié avec un commit vide sur une copie locale de `main`,
   jamais fusionné).

## 5. Hors périmètre

- Les valeurs recopiées en dur dans `config/` au lieu d'être lues dans les jetons : autre problème, plus
  difficile à vérifier par programme.
- Interdire la réécriture d'historique ou la suppression de `main` par la règle : `settings.json` refuse
  déjà `git push --force` à Claude ; non demandé.
- Le dépôt `dunei-atelier`, qui reçoit des envois directs sur `main` (D64) : non touché.

## 6. Documentation

Carnet (section L1-21 : crochet, contrôle, règle, commande `gh api`, refus de Claude Code), `README.md`,
`CLAUDE.md` (Repères : jamais `--admin`), atelier (`claude/settings.json`), backlog (L1-21 fait), journal (D77), notes de direction (prochaine étape : recette de
sortie du lot 1 et étiquette `lot1`), bible (annexe des fichiers, si elle liste les outils de la chaîne).

## Historique des versions

| Version | Date | Changement |
| --- | --- | --- |
| 0.1 | 2026-10-19 | Version initiale : options D et contournement 2 retenus par Nicolas |
| 0.2 | 2026-10-19 | Après relecture : refus mécaniques de `--admin` et des fusions par `gh api` (Nicolas), `--no-verify` permis à Claude (Nicolas), `make check` ne refuse que les fichiers non suivis (Claude) |
| 0.3 | 2026-10-19 | Implémentée |
| 0.4 | 2026-10-19 | Recette passée ; `lua` au lieu de `luajit` dans le contrôle |
