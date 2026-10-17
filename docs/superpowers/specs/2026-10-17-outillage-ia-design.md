# Outillage de développement par IA : l'atelier rejouable

Version 0.2 · 2026-10-17 · backlog L1-26 (nouveau) · carnet « Installation », phase 2 · statut : conception

## 1. Objet

L'atelier qui construit DuneI (Claude Code, ses réglages, rtk, les plugins, la mémoire de Claude) n'existe
que sur `caladan`, monté à la main entre le 12 et le 16 octobre 2026. La réinstallation de `caladan`
décidée pour L1-25 l'effacerait. Cette feature le rend **rejouable** : la phase 2 de l'installation le
remonte à l'identique sur toute machine DuneI, et Nicolas n'a plus qu'à se reconnecter.

**Intention : reproduire, pas améliorer.** L'atelier actuel convient à Nicolas ; il n'a pas encore de vision
sur ce qui serait à améliorer. Toute amélioration va dans une ligne de backlog séparée (§ 9).

Relevé du 2026-10-17 sur `caladan` :

| Élément | Emplacement | État |
| --- | --- | --- |
| Claude Code 2.1.302 | `~/.local/bin/claude` → `~/.local/share/claude/versions/` | Installateur officiel, se met à jour seul (D56) ; déjà dans la procédure |
| Réglages globaux | `~/.claude/settings.json` | Permissions refusées (`~/.claude/.credentials.json`, `~/.ssh/**`, `~/.gnupg/**`, `**/.env*`, `git push --force*`, `git push -f*`), `defaultMode: auto`, `skipDangerousModePermissionPrompt`, thème sombre, effort `high` pour Opus 5.5, `enabledPlugins` (context7, superpowers), hook `PreToolUse` `rtk hook claude` |
| Instructions globales | `~/.claude/CLAUDE.md` (`@RTK.md`), `~/.claude/RTK.md` | Posées par rtk |
| Instructions du dossier personnel | `~/CLAUDE.md` | Bloc `rtk-instructions v2`, doublon de `RTK.md` |
| rtk 1.0.1 | `~/.local/bin/rtk` | Binaire de la publication officielle, édition par défaut, archive `rtk-x86_64-unknown-linux-musl.tar.gz` : somme du binaire identique octet pour octet (vérifié). Aucun paquet ne le possède |
| Réglages de rtk | `~/.config/rtk/config.toml` | Réglages réels (télémétrie désactivée, suivi sur 90 jours, limites) |
| Filtres de rtk | `~/.config/rtk/filters.toml`, `~/.rtk/filters.toml` | Modèles d'exemple seulement, aucun filtre écrit |
| Plugins | `~/.claude/plugins/` | context7 et superpowers 7.0.0, marché `claude-plugins-official` |
| Mémoire | `~/.claude/projects/-home-junei-DuneI/memory/` | 5 fichiers ; seul projet doté d'une mémoire |
| Identité git | `~/.gitconfig` | Nom, adresse, assistant d'identification `gh auth git-credential` |
| Secrets et état | `~/.claude/.credentials.json`, `history.jsonl`, `sessions/`, `projects/*/` (hors mémoire), caches, télémétrie | Ne quittent jamais la machine |

Rien de tout cela n'est dans le dépôt ; `~/DuneI/CLAUDE.md` seul est versionné.

**Critères de réussite**

1. Sur une installation neuve, la phase 2 (`make paquets`, installateur de Claude Code, `gh auth login`,
   `make install`) suivie de la seule connexion de Claude Code donne un atelier identique : mêmes
   permissions refusées, sorties condensées par rtk, context7 et superpowers actifs, mémoire relue (la
   première session connaît la règle « jamais `firefox --headless` pour juger une police »).
2. `make install` refuse une archive rtk dont la somme `sha256` diffère de celle épinglée, sans rien poser.
3. Sur `caladan`, le premier passage reprend l'existant sans rien perdre ni rien changer à son
   comportement.
4. Un changement de l'atelier non envoyé sur GitHub (mémoire ou réglage) est signalé par le bilan de
   `make install` et par `dunei-maj`.
5. Aucun secret n'entre dans un dépôt : ni `.credentials.json`, ni jeton, ni historique.
6. Répété dans la machine virtuelle de recette (`setup/vm.sh`) avant la réinstallation de `caladan`.

## 2. Décisions prises pendant la conception

Arbitrées avec Nicolas le 2026-10-17, à consigner au journal (D61 et suivantes).

- **Réinstallation de `caladan` au lieu du chiffrement sur place (L1-25, renverse en partie D53).** Rien
  sur `caladan` n'est irremplaçable : les fichiers de Nicolas vivent sur une autre machine, ses mots de
  passe dans Bitwarden ; les documents de `~/Documents` et `~/Downloads` sont copiés par lui sur Google
  Drive avant l'effacement. La raison de D53 (ne pas risquer la machine avant que la procédure soit
  prouvée) est tombée avec la recette en machine virtuelle (D59). Réinstaller fait de `caladan` la recette
  grandeur nature de la procédure, chiffrement compris ; le chemin sur place n'aurait produit qu'une
  procédure à usage unique.
- **Ordre.** L1-26 d'abord, puis les écarts de la procédure relevés le 2026-10-17 (services non activés,
  `PATH`), rangés dans L1-25, puis L1-25 : répétition complète en machine virtuelle, puis réinstallation.
- **L1-26 est une feature du lot 1** : l'atelier est l'outil de base du développement de DuneI.
- **Deux dépôts.** Le dépôt public `JuNeI23/DuneI` porte la façon de poser l'atelier et l'épinglage de
  rtk ; un dépôt **privé** `JuNeI23/dunei-atelier` porte les réglages de Claude Code, les instructions, la
  mémoire et l'identité git. Raison : ce qui est poussé sur un dépôt public y reste dans l'historique ; la
  mémoire grandira. Le forfait gratuit de GitHub couvre les dépôts privés.
- **Envoi des changements par Claude.** Quand Claude écrit en mémoire ou modifie un réglage de l'atelier, il
  valide et envoie le changement sur `dunei-atelier` dans la foulée, visiblement, comme pour DuneI. Le
  bilan signale ce qui serait resté sur la machine ; il n'envoie jamais rien lui-même.
- **rtk épinglé par DuneI (option B du repérage).** Version et sommes `sha256` écrites dans le dépôt ; la
  pose télécharge l'archive de la publication GitHub et refuse toute somme différente. Édition par défaut,
  celle en usage. Pas de mise à jour automatique : Claude monte la version par un commit. `rtk init -g`
  n'est jamais lancé, le hook vit dans le `settings.json` versionné.

Repérage de la source de rtk (2026-10-17) : rtk n'est dans aucun dépôt officiel d'Arch et D56 exclut
l'AUR. Les publications ne sont ni signées ni attestées (`gh attestation verify` répond 404) ; seule existe
une liste `checksums.txt` hébergée avec les archives. Écartés : le script officiel `install.sh` (version
variable, vérification contre une liste de même origine), la compilation par `cargo` (chaîne Rust lourde,
pour un code qu'on ne relit pas). Deux éditions existent : par défaut, avec un moteur sous BUSL-1.1, et
`oss`, sous Apache-2.0, sans ce moteur.

## 3. Ce qui va où

| Contenu | Dépôt | Posé à |
| --- | --- | --- |
| Épinglage de rtk : version, édition, cible, somme de l'archive, somme du binaire | DuneI, `atelier.toml` | — |
| Adresse et emplacement du clone de `dunei-atelier` | DuneI, `atelier.toml` | — |
| Pose de rtk et de l'atelier | DuneI, `deploy.py` (destinations `rtk` et `atelier`) | — |
| `autoMemoryDirectory` du projet DuneI | DuneI, `.claude/settings.json` | Lu par Claude Code dans `~/DuneI` |
| Réglages globaux de Claude Code | atelier, `claude/settings.json` | `~/.claude/settings.json` |
| Instructions globales | atelier, `claude/CLAUDE.md`, `claude/RTK.md` | `~/.claude/` |
| Instructions du dossier personnel | atelier, `maison/CLAUDE.md` | `~/CLAUDE.md` |
| Réglages de rtk | atelier, `rtk/config.toml` | `~/.config/rtk/config.toml` |
| Mémoire de Claude pour DuneI | atelier, `memoire/` | Désigné par `autoMemoryDirectory` |
| Identité git | atelier, `git/gitconfig` | Inclus par `~/.gitconfig` (§ 4) |
| Secrets, historique, sessions, caches, plugins téléchargés | aucun | — |

Les fichiers de l'atelier sont posés par **liens symboliques**, comme `config/` l'est déjà : un réglage
modifié par Claude Code lui-même apparaît dans `git status` de `dunei-atelier` au lieu de se perdre.

La mémoire est rattachée au **seul projet DuneI** par le réglage de projet, et non par le réglage global :
un `autoMemoryDirectory` global mêlerait les mémoires de tous les projets. La documentation de Claude Code
précise que ce réglage, placé dans `.claude/settings.json` d'un projet, n'est lu qu'après acceptation de la
confiance accordée au dossier ; il prend un chemin absolu ou commençant par `~/`.

## 4. Comportement de `make install`

Deux destinations s'ajoutent à `DESTINATIONS`, avec la règle commune de `deploy.py` : tout inspecter,
une seule erreur refuse tout, ne jamais écraser un fichier que DuneI n'a pas posé.

**`rtk`**
- Si `~/.local/bin/rtk` (`$XDG_BIN_HOME`) a la somme du binaire épinglé : rien à faire.
- S'il manque, ou s'il a une autre somme : l'archive de la version épinglée est téléchargée **pendant
  l'inspection**, dans `~/.cache/dunei/` (`$XDG_CACHE_HOME`), puis vérifiée ; `--dry-run` télécharge donc
  aussi. Une somme différente est une erreur d'inspection : **rien n'est posé, aucune destination**, et le
  message donne la somme attendue et la somme lue. Une alerte sur la chaîne d'approvisionnement doit
  arrêter net, pas passer dans un bilan. *(Choix de Claude.)*
- Hors ligne avec rtk manquant : même erreur, le téléchargement ayant échoué. Le cas ne se présente qu'à
  une installation neuve, toujours en réseau. *(Choix de Claude.)*
- À l'application : extraction, vérification de la somme du binaire, pose atomique. Un binaire présent
  d'une autre version est remplacé : `~/.local/bin/rtk` appartient à DuneI. Le remplacement est annoncé.
- Les tests simulent le téléchargement par une fonction injectée ; ils n'ont jamais besoin du réseau.

**`atelier`**
- Si `gh` n'est pas connecté, ou si le clone échoue (compte sans accès, réseau en panne) : la destination
  est sautée avec un message qui donne la cause et la commande à lancer ; le reste de `make install`
  continue. L'atelier n'est pas nécessaire au bureau. *(Choix de Claude.)*
- Si le clone manque : `gh repo clone` à l'emplacement d'`atelier.toml`.
- Pour chaque lien :
  - la destination est déjà le bon lien : rien ;
  - elle manque : créer le lien ;
  - c'est un fichier identique au fichier de l'atelier : le remplacer par le lien ;
  - c'est un fichier différent et **le clone existait avant ce passage** : c'est un lien que Claude Code a
    remplacé par un fichier en réécrivant ses réglages. Le fichier est repris dans le clone, puis le lien
    est remis. La différence apparaît dans `git status` du clone et dans le bilan ; git permet de la
    défaire. Jamais d'erreur : un `/config` ne doit pas bloquer Hyprland. *(Choix de Claude.)*
  - c'est un fichier différent et **le clone vient d'être créé** (installation neuve) : c'est un fichier
    par défaut posé par un outil. L'atelier l'emporte ; le fichier est conservé à côté sous le nom
    `<nom>.avant-dunei`, et le bilan le signale. *(Choix de Claude.)*
- `~/.gitconfig` n'est **pas** un lien. `gh auth login` y écrit ses assistants d'identification avant
  `make install` (réponse « oui » à « Authenticate Git with your GitHub credentials? ») ; `make install`
  y ajoute seulement `[include] path = <clone>/git/gitconfig` s'il manque (`git config --global`).
  L'atelier porte l'identité, `gh` ses assistants, chacun son fichier. *(Choix de Claude.)*
- Plugins, **avant** les liens : pour chaque clé de `enabledPlugins` du `settings.json` de l'atelier
  absente de `claude plugin list`, `claude plugin install <clé>`. La liste des plugins n'a qu'une source.
  Les versions ne sont pas épinglées : le critère est « actifs », et le marché officiel les tient à jour.
  *(Choix de Claude.)*
- Bilan : changements non validés ou non envoyés dans le clone (`git status --porcelain`, commits en
  avance sur `origin`), lien repris, fichier `.avant-dunei` laissé, tout est signalé ; rien n'est envoyé.

**Envoi par Claude.** La règle est écrite dans `claude/CLAUDE.md` de l'atelier, donc globale : toute
session, dans n'importe quel dossier, qui modifie un fichier de l'atelier (mémoire ou réglage) valide et
envoie aussitôt sur `main` de `dunei-atelier`, sans branche ni PR (dépôt privé, aucune relecture à
attendre), avec la signature `Co-Authored-By` du modèle. C'est le seul ajout fait à l'atelier par cette
feature, voulu par Nicolas (« tu gères cela »). *(Choix de Claude pour l'emplacement et le flux.)*

**`dunei-maj`** ajoute le même signalement à sa fin.

## 5. Premier passage sur `caladan`

1. Créer `dunei-atelier` (`gh repo create JuNeI23/dunei-atelier --private`) et y verser les fichiers
   actuels tels quels ; premier envoi.
2. Copier la mémoire actuelle dans `memoire/` du clone.
3. `make install` : rtk est reconnu à sa somme, les fichiers identiques deviennent des liens.
4. Vérifier, dans une nouvelle session de Claude Code dans `~/DuneI`, que la mémoire est lue depuis le
   clone et que rtk condense toujours les sorties ; seulement ensuite retirer l'ancien dossier de mémoire.

## 6. Procédure (carnet, phase 2)

    git clone https://github.com/JuNeI23/DuneI ~/DuneI && cd ~/DuneI
    make paquets
    curl -fsSL https://claude.ai/install.sh | bash
    gh auth login                    # nouveau : HTTPS, et « oui » à l'identification de git
    make install                     # pose aussi rtk et l'atelier
    claude                           # connexion au compte, puis confiance accordée à ~/DuneI

Tant que L1-25 n'écrit pas le `PATH`, `~/.local/bin` s'y ajoute à la main, comme le carnet le dit déjà : le
hook `rtk hook claude` en dépend. La recette de L1-26 en machine virtuelle fait ce geste. Pas de chemin
absolu dans `settings.json` : ce serait modifier l'atelier. *(Choix de Claude.)*

## 7. Risques à vérifier pendant la construction

- **Claude Code peut remplacer un lien par un fichier** s'il réécrit `settings.json` par renommage :
  `~/.claude/settings.json.bak` sur `caladan` montre qu'il réécrit ce fichier. La reprise du § 4 couvre le
  cas ; la machine virtuelle dira s'il est rare ou systématique. S'il est systématique, la conception
  revient à Nicolas avant d'aller plus loin : un lien qui casse à chaque écriture n'est plus un lien.
- **Installation des plugins sans menu.** Vérifier que `claude plugin install` fonctionne sur une
  installation neuve où le marché `claude-plugins-official` n'a jamais été chargé.
- **Les fichiers `filters.toml` de rtk** ne sont pas repris : ce sont des modèles. Vérifier en machine
  virtuelle que rtk fonctionne sans eux.
- Toute la documentation de Claude Code et de rtk est relue par context7 au moment d'écrire (règle des
  outils).

## 8. Hors champ

- L'amélioration de l'atelier (§ 9).
- Les connexions : compte Claude, `gh`, connecteurs claude.ai.
- Un autre assistant, un modèle local, l'IA dans l'interface de DuneI.
- Les écarts de la procédure hors atelier (services non activés, `PATH`) : L1-25.

## 9. Suites pour le backlog

- **L1-26** : cette feature.
- **Améliorer l'atelier** (lot à choisir) : ligne ouverte sans contenu, à remplir au fil des irritants.
  Premier constat : le doublon `~/CLAUDE.md` / `RTK.md`.
- **L1-25** reçoit : réinstallation au lieu du chiffrement sur place ; activation par la procédure des
  services `ufw` (avec `ufw enable`), `power-profiles-daemon`, `bluetooth`, `cups`, `fstrim.timer` ;
  écriture du `PATH` au lieu de son simple signalement.

## 10. Laissé au constructeur

- Le nom des clés d'`atelier.toml` et l'emplacement du clone (proposition : `~/dunei-atelier`).
- L'organisation des fonctions dans `deploy.py`, en suivant celle des destinations existantes.
- L'exclusion de `.claude/` dans `.gitignore`, à resserrer pour laisser passer `.claude/settings.json`
  seul.

## Historique des versions

| Version | Date | Changement |
| --- | --- | --- |
| 0.2 | 2026-10-17 | Relecture du constructeur : téléchargement de rtk à l'inspection, reprise d'un lien remplacé, fichier par défaut d'une installation neuve, `~/.gitconfig` par inclusion, plugins avant les liens, règle d'envoi dans l'atelier, `PATH` manuel jusqu'à L1-25 |
| 0.1 | 2026-10-17 | Version initiale |
