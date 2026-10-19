# Contrôle de la génération : plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal :** refuser tout `generated/` qui diffère d'une génération fraîche, au commit par un crochet git
et à la fusion par un contrôle GitHub obligatoire sur `main`, et interdire à Claude Code les fusions qui
passeraient outre.

**Architecture :** une cible `make generes` porte la comparaison (diff contre l'index, fichiers non
suivis) ; `make check` et le crochet `.githooks/pre-commit` l'appellent. `deploy.py` gagne une
destination `crochets` qui pose `core.hooksPath`. Un workflow GitHub lance `make check` dans un conteneur
Arch, sous un compte non root ; un *ruleset* versionné l'exige sur `main`. Les refus de Claude Code
vivent dans le dépôt de l'atelier.

**Tech Stack :** GNU make, sh POSIX, Python 3 (`unittest`, `subprocess`, `shutil`, `json`), git,
GitHub Actions (`archlinux:latest`, `actions/checkout`), API REST des rulesets par `gh api`, réglages
de Claude Code.

**Spec :** `docs/superpowers/specs/2026-10-19-controle-generation-design.md` (version 0.2).

## Global Constraints

- Le crochet ne lance pas les tests ; le contrôle GitHub lance `make check` complet.
- `make check` ne refuse pas un fichier généré correct déjà indexé ; il refuse un fichier **non suivi**
  sous `generated/` (`git ls-files --others --exclude-standard generated/`).
- Valeur de `core.hooksPath` : `.githooks` (relative), posée en `--local`.
- Nom de la tâche du workflow et du contrôle exigé : `controle`.
- `actions/checkout` épinglé : `3d3c42e5aac5ba805825da76410c181273ba90b1` (v7.0.1).
- Ruleset : cible `~DEFAULT_BRANCH`, `enforcement: active`, une règle `required_status_checks`
  (`controle`, `integration_id` 15368 de GitHub Actions, `strict_required_status_checks_policy: false`),
  contournement `RepositoryRole` 5 (administrateur) en `bypass_mode: pull_request`.
- Refus de Claude Code : `Bash(gh pr merge*--admin*)` et `Bash(gh api*merge*)`. Un motif trop large vaut
  mieux qu'un motif troué.
- Claude ne passe jamais `--admin` ; `--no-verify` lui est permis.
- Les tests ne modifient jamais la configuration git du vrai dépôt ni le vrai `~`.
- Chaque fonction porte un commentaire : titre et rôle, entrées, sorties, erreurs, dépendances (format des
  docstrings de `deploy.py`). Code minimal. Tout texte en français correct, accents compris.
- Chaque commit se termine par `Co-Authored-By: <modèle qui l'a écrit> <noreply@anthropic.com>`.
- `make check` passe à la fin de chaque tâche.

## Review Focus

- Commit partiel avec une source modifiée non indexée : refus, et le message nomme ce cas (test en
  tâche 1).
- Lancement des tests sur `caladan` après `make install` : `test_deploy` ne doit ni poser ni lire la
  vraie `core.hooksPath` du dépôt (environnement injecté, tâche 2).
- Conteneur du contrôle en root : `deploy.py` refuse root, donc `make check` doit tourner sous un compte
  ordinaire, dans un clone git réel (git installé avant `actions/checkout`, tâche 3).
- Un fichier nouveau dans `generated/`, jamais ajouté : refusé par `make generes` comme par le crochet
  (tâche 1).
- Motif de refus mal formé qui laisserait passer `gh pr merge 12 --merge --admin` : éprouvé sur un numéro
  de PR inexistant, jamais sur une vraie PR (tâche 6).

---

### Task 1 : `make generes` et le crochet `pre-commit`

**Files:**
- Modify: `Makefile` (cible `generes`, `check` en dépend, commentaire d'en-tête)
- Create: `.githooks/pre-commit` (exécutable)
- Modify: `tests/test_shellcheck.py` (ajoute `.githooks/*` à `SCRIPTS`)
- Test: `tests/test_crochet.py`

**Interfaces:**
- Produces : `make generes` (code 0 si `generated/` égale l'index et n'a aucun fichier non suivi) ;
  `.githooks/pre-commit`, que la tâche 2 active.

- [ ] **Step 1 : écrire `tests/test_crochet.py`.** Fixture : `shutil.copytree(ROOT, tmp, ignore=...)`
  sans `.git`, `.superpowers`, `docs`, `proto`, `tests` ; `git init`, premier commit avec
  `-c user.name=t -c user.email=t@t` et `--no-verify`, puis `git config core.hooksPath .githooks`.
  Environnement : `GIT_CONFIG_GLOBAL=/dev/null`, `GIT_CONFIG_SYSTEM=/dev/null`. Tests, tous par
  `git commit` réel dans la copie :
  - `test_commit_propre_accepte` : ajout d'un fichier hors `generated/`, commit → code 0.
  - `test_generated_retouche_refuse` : une ligne ajoutée à `generated/tokens.css`, indexée → code ≠ 0,
    `"generated/"` dans stderr.
  - `test_source_sans_regeneration_refuse` : une valeur de `tokens.toml` changée et indexée sans
    régénérer → code ≠ 0 ; puis `git add generated/` et nouveau commit → code 0.
  - `test_fichier_non_suivi_refuse` : `generated/nouveau.txt` créé, non indexé, commit d'un autre
    fichier → code ≠ 0.
  - `test_commit_partiel_message` : `tokens.toml` modifié **non indexé**, commit d'un autre fichier →
    code ≠ 0 et `"non indexée"` dans stderr.
  - `test_make_generes` : dans la copie propre, `make -s generes` → 0 ; après `generated/nouveau.txt` → ≠ 0.
- [ ] **Step 2 :** `python3 -m unittest tests.test_crochet -v` → échec (crochet et cible absents).
- [ ] **Step 3 : `Makefile`.** Cible `generes: tokens motion energie` qui lance
  `git diff --exit-code generated/`, puis refuse toute sortie de
  `git ls-files --others --exclude-standard generated/` en l'affichant avec
  « fichiers de generated/ hors de git : git add generated/ » sur stderr. `check: generes test`
  remplace l'ancienne recette. Ajouter `generes` à `.PHONY` et à l'en-tête
  (« make generes  refuse si generated/ diffère d'une génération fraîche ou contient un fichier hors de git »).
- [ ] **Step 4 : `.githooks/pre-commit`**, sh POSIX, `chmod 755`. Lance `make -s generes` ; en cas
  d'échec, écrit sur stderr exactement :

  ```
  commit refusé : generated/ diffère de ce que produisent les sources (L1-21).
  generated/ ne s'édite pas à la main ; il vient d'être régénéré : relire le diff, git add generated/,
  puis recommencer le commit.
  Commit partiel : une source modifiée mais non indexée fausse la comparaison ; l'indexer ou la mettre de côté.
  ```

  et sort en 1. En-tête commenté : rôle, entrée (aucune, lancé par git à la racine de l'arbre), sortie,
  dépendances (`make`, `git`).
- [ ] **Step 5 : `tests/test_shellcheck.py`** : `SCRIPTS` inclut `(ROOT / ".githooks").glob("*")`.
- [ ] **Step 6 :** `python3 -m unittest tests.test_crochet tests.test_shellcheck -v` → OK ; `make check` → OK.
- [ ] **Step 7 : commit** (`Makefile`, `.githooks/pre-commit`, `tests/test_crochet.py`,
  `tests/test_shellcheck.py`), message « Crochet pre-commit et make generes (L1-21) ».

### Task 2 : destination `crochets` de `deploy.py`

**Files:**
- Modify: `deploy.py` (constante `CROCHETS`, `plan_crochets`, `DESTINATIONS`, `describe`, `apply`,
  en-tête du `Makefile` pour `make install`)
- Modify: `tests/test_deploy.py` (environnement de `run()` et de `setUp`)
- Test: `tests/test_deploy.py` (nouvelle classe `CrochetsTest`)

**Interfaces:**
- Consumes : `.githooks/` (tâche 1).
- Produces : `plan_crochets(repo: Path, home: Path) -> tuple[list[tuple], list[str]]` ; action
  `("crochets", repo)`.

- [ ] **Step 1 : isoler le vrai dépôt.** Dans `run()` et dans le `mock.patch.dict` de `DeployTest.setUp`,
  ajouter `GIT_CONFIG_COUNT=1`, `GIT_CONFIG_KEY_0=core.hooksPath`, `GIT_CONFIG_VALUE_0=.githooks` :
  la valeur effective est déjà la bonne, aucune action n'écrit dans `.git/config`.
- [ ] **Step 2 : `CrochetsTest`**, sur un `git init` temporaire, `GIT_CONFIG_GLOBAL` et
  `GIT_CONFIG_SYSTEM` à `/dev/null` :
  - `test_absent_pose` : `plan_crochets` → `([("crochets", repo)], [])` ; après `apply`,
    `git -C repo config --local core.hooksPath` vaut `.githooks`.
  - `test_deja_pose_rien` : valeur `.githooks` → `([], [])`.
  - `test_valeur_etrangere_refusee` : valeur `/ailleurs` → `([], [msg])`, `msg` contient `/ailleurs` et
    `core.hooksPath`.
  - `test_describe` : `describe(("crochets", repo))` contient `.githooks`.
- [ ] **Step 3 :** `python3 -m unittest tests.test_deploy -v` → échec sur `CrochetsTest`.
- [ ] **Step 4 : implémenter.** `CROCHETS = ".githooks"` avec commentaire de ligne ;
  `plan_crochets` lit la valeur effective par `git -C repo config --get core.hooksPath` (code 1 = absente) ;
  absente → action ; égale → rien ; autre → erreur « core.hooksPath vaut X : les crochets de DuneI
  (.githooks) ne seraient pas lancés ; git config --local core.hooksPath .githooks, puis relancer ».
  `DESTINATIONS` : `"crochets"` juste après `"bin"`. `describe` : « activer les crochets du dépôt
  ({0}/.githooks) ». `apply` : `git -C repo config --local core.hooksPath .githooks`, `check=True`.
  L'en-tête du `Makefile` cite « pose core.hooksPath (crochets du dépôt) » dans `make install`.
- [ ] **Step 5 :** `make check` → OK ; `git -C ~/DuneI config --local --get core.hooksPath` → toujours
  absent (le test n'a rien écrit).
- [ ] **Step 6 : commit** « make install active les crochets du dépôt (L1-21) ».

### Task 3 : workflow `controle` et ruleset versionné

**Files:**
- Create: `.github/workflows/controle.yml`
- Create: `setup/github/regle-main.json`
- Test: `tests/test_controle.py`

**Interfaces:**
- Produces : contrôle nommé `controle` ; fichier de ruleset appliqué en tâche 6.

- [ ] **Step 1 : `tests/test_controle.py`**, sans dépendance YAML (lecture texte et `json`) :
  - `test_tache_controle` : le workflow contient la ligne `  controle:` sous `jobs:` et `pull_request`.
  - `test_actions_epinglees` : chaque `uses:` porte une empreinte de 40 caractères hexadécimaux.
  - `test_ruleset` : JSON chargé ; `rules` = une seule règle `required_status_checks` dont l'unique
    `context` est `controle`, `strict_required_status_checks_policy` faux ; `bypass_actors` =
    `[{"actor_id": 5, "actor_type": "RepositoryRole", "bypass_mode": "pull_request"}]` ;
    `conditions.ref_name.include` = `["~DEFAULT_BRANCH"]`.
- [ ] **Step 2 :** le test échoue (fichiers absents).
- [ ] **Step 3 : `controle.yml`.** `on: pull_request` (branches `main`) et `workflow_dispatch` ; tâche
  `controle`, `runs-on: ubuntu-latest`, `container: archlinux:latest`. Étapes, dans cet ordre :
  `pacman -Syu --noconfirm --needed git make python python-numpy python-pillow luajit shellcheck` (git
  avant `checkout`, pour un vrai clone) ; `actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1  # v7.0.1` ;
  création d'un compte `controle`, `chown -R` de l'espace de travail, puis
  `runuser -u controle -- env HOME=/home/controle make -C "$GITHUB_WORKSPACE" check`. Commentaire
  d'en-tête : rôle, pourquoi un compte non root (`deploy.py` refuse root).
- [ ] **Step 4 : `regle-main.json`**, nom « main : contrôle de la génération requis », selon les
  valeurs des contraintes globales (`target: branch`, `exclude: []`, `do_not_enforce_on_create: false`).
- [ ] **Step 5 :** `make check` → OK.
- [ ] **Step 6 : commit** « Contrôle GitHub et règle de main versionnés (L1-21) ».

### Task 4 : refus de Claude Code dans l'atelier

**Files:**
- Modify: `~/dunei-atelier/claude/settings.json` (`permissions.deny`)

- [ ] **Step 1 :** ajouter `"Bash(gh pr merge*--admin*)"` et `"Bash(gh api*merge*)"` après
  `"Bash(git push -f*)"`. JSON valide (`python3 -m json.tool`).
- [ ] **Step 2 :** dans `~/dunei-atelier` : commit « Refus des fusions hors règle (DuneI L1-21, D77) »
  avec `Co-Authored-By`, push direct sur `main` (D64).
- [ ] **Step 3 :** relever si la session en cours applique déjà les refus ; sinon le noter pour la
  tâche 6, qui se fait dans une session neuve.

### Task 5 : documentation

**Files:**
- Modify: carnet, section « La chaîne de génération — L1-21 » (cible `generes`, crochet et son message,
  `core.hooksPath` posé par `make install`, contrôle `controle`, ruleset et ses deux commandes `gh api`
  de création et de mise à jour, contournement réservé à Nicolas, refus de Claude Code), historique.
- Modify: `README.md` (bloc de la chaîne : `generes`, `check`, `install`).
- Modify: `CLAUDE.md`, Repères : « Jamais `--admin` ni fusion par `gh api` : un contrôle rouge se
  corrige ou se signale (D77). `--no-verify` est permis. »
- Modify: backlog, L1-21 « fait (D77) » avec résumé ; historique.
- Modify: `docs/journal-decisions.md`, D77 : deux étages, contournement administrateur réservé à Nicolas
  et refus mécaniques, `--no-verify` permis, `make check` limité aux non suivis, et ce qui a été écarté
  (`pre-commit.com`, crochets locaux seuls, contournement nul).
- Modify: notes de direction, paragraphe « Contrôle de la génération — 19 octobre 2026 » ; prochaine
  étape : recette de sortie du lot 1 et étiquette `lot1` ; historique.
- Modify: bible, annexe des fichiers si elle liste les outils de la chaîne.
- Modify: spec, statut « implémentée ».

- [ ] **Step 1 :** rédiger, versions et historiques compris.
- [ ] **Step 2 :** `make check` → OK ; commit « Documentation du contrôle de la génération (L1-21, D77) ».

### Task 6 : recette, PR, fusion

- [ ] **Step 1 :** `make install` sur `caladan` ; `git config --local --get core.hooksPath` → `.githooks`.
- [ ] **Step 2 :** sur la branche, ligne ajoutée à `generated/tokens.css`, `git add`, `git commit` →
  refus avec le message de la tâche 1 ; `git checkout -- generated/` et `git restore --staged`.
  Montrer le refus à Nicolas.
- [ ] **Step 3 :** push, `gh pr create` ; le contrôle `controle` passe au vert (corriger et repousser
  sinon). Relever sa durée.
- [ ] **Step 4 :** appliquer la règle :
  `gh api -X POST repos/JuNeI23/DuneI/rulesets --input setup/github/regle-main.json` ; relire par
  `gh api repos/JuNeI23/DuneI/rulesets/<id>`.
- [ ] **Step 5 :** PR jetable `essai/controle-rouge` partie de la branche de feature, un fichier généré
  retouché, commit `--no-verify` : contrôle rouge ; `gh pr merge <n> --merge` refuse. Fermer la PR,
  supprimer la branche locale et distante.
- [ ] **Step 6 :** dans une session Claude Code neuve si la tâche 4 l'exige :
  `gh pr merge 999999 --merge --admin` et `gh api repos/JuNeI23/DuneI/pulls/999999/merge` → refusés
  par Claude Code avant tout envoi. Jamais sur une vraie PR.
- [ ] **Step 7 :** branche locale jetable partie d'`origin/main`, `git commit --allow-empty`, puis
  `git push origin HEAD:main` → refusé par GitHub (au pire, un commit vide sur `main`). Supprimer la
  branche jetable.
- [ ] **Step 8 :** consigner les résultats (carnet, journal D77, spec), commit, push.
- [ ] **Step 9 :** relecture finale de la branche ; validation de Nicolas à l'écran ;
  `gh pr merge <n> --merge` (passe : contrôle vert), puis procédure après fusion du carnet.

## Historique des versions

| Version | Date | Changement |
| --- | --- | --- |
| 0.1 | 2026-10-19 | Version initiale |
