# Outillage IA : plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal :** rendre l'atelier de développement (rtk, réglages et instructions de Claude Code, plugins, mémoire,
identité git) rejouable par `make install`, à partir du dépôt public et d'un dépôt privé `dunei-atelier`.

**Architecture :** un nouveau module `atelier.py` porte deux destinations, `rtk` et `atelier`, au format
de `deploy.py` (`plan_x(repo, home) -> (actions, erreurs)`), plus l'exécution de ses propres actions et
un relevé d'état. `deploy.py` les inscrit dans `DESTINATIONS` et délègue à `atelier.appliquer` les
actions qu'il ne connaît pas. `atelier.toml` déclare l'épinglage de rtk et la carte des liens.

**Tech Stack :** Python 3 (bibliothèque standard : `tomllib`, `hashlib`, `tarfile`, `urllib.request`,
`subprocess`), `unittest`, `git`, `gh`, `claude` (CLI), bash pour `dunei-maj`.

**Spec :** `docs/superpowers/specs/2026-10-17-outillage-ia-design.md` (version 0.2).

## Global Constraints

- rtk épinglé : version `1.0.1`, archive `rtk-x86_64-unknown-linux-musl.tar.gz`, somme de l'archive
  `5b919c3bccb799b67a61866d0e617410a4fcdf173e2614440e59de2fa2003436`, somme du binaire
  `2e7508fe33f5fa336df8784158fafffa9bca09d060de22f7b4c6246ede96c4c4`, adresse
  `https://github.com/rtk-ai/rtk/releases/download/v1.0.1/rtk-x86_64-unknown-linux-musl.tar.gz`.
- Dépôt privé : `JuNeI23/dunei-atelier`, clone à `~/dunei-atelier`.
- Aucun secret dans aucun dépôt : ni `.credentials.json`, ni jeton, ni `history.jsonl`, ni `sessions/`.
- `rtk init` n'est jamais lancé.
- Chaque fonction porte un commentaire : titre et rôle, entrées, sorties, erreurs, dépendances (format des
  docstrings de `deploy.py`). Code minimal. Tout texte en français correct, accents compris.
- Les tests n'utilisent jamais le réseau, ni le vrai `~`, ni les vrais `gh` et `claude` : `HOME`,
  `XDG_*` temporaires, faux exécutables dans le `PATH`, URL `file://`.
- Chaque commit se termine par `Co-Authored-By: <modèle qui l'a écrit> <noreply@anthropic.com>`.
- `make check` passe à la fin de chaque tâche.

## Review Focus

- Machine neuve sans `~/.claude/` ni `~/.config/rtk/` : les dossiers parents sont créés avant les liens.
- Lien étranger (lien symbolique vers un autre chemin que le clone) à la place d'un lien de l'atelier :
  erreur qui nomme le lien, jamais de remplacement silencieux.
- Archive en cache corrompue ou d'une autre version : supprimée et retéléchargée une fois ; une seconde
  somme fausse est une erreur.
- `~/.gitconfig` absent (réponse « non » à `gh auth login`) : créé avec la seule inclusion.
- `claude` absent du `PATH` au moment de `make install` : signalement, pas d'erreur, le reste est posé.

---

### Task 1 : `atelier.toml`, sa lecture et le réglage de mémoire du projet

**Files :**
- Create : `atelier.toml`, `atelier.py`, `.claude/settings.json`, `tests/test_atelier.py`
- Modify : `.gitignore`

**Interfaces :**
- Produces : `lire_atelier(repo: Path) -> tuple[dict, list[str]]` ; constantes `ATELIER = "atelier.toml"`.
  Le dictionnaire rendu a les clés `rtk` (`version`, `archive`, `url`, `sha256_archive`, `sha256_binaire`)
  et `atelier` (`depot`, `clone: Path` déjà développé par `expanduser`, `gitconfig: str`,
  `liens: dict[str, Path]`, chemin relatif au clone → destination développée). La variable
  d'environnement `DUNEI_ATELIER_TOML`, réservée aux tests, remplace le chemin du fichier.

- [ ] **Step 1 : écrire `atelier.toml`**

```toml
# Atelier de développement — rtk épinglé et carte des liens de dunei-atelier (spec 2026-10-17).
[rtk]
version = "1.0.1"
archive = "rtk-x86_64-unknown-linux-musl.tar.gz"
url = "https://github.com/rtk-ai/rtk/releases/download/v1.0.1/rtk-x86_64-unknown-linux-musl.tar.gz"
sha256_archive = "5b919c3bccb799b67a61866d0e617410a4fcdf173e2614440e59de2fa2003436"
sha256_binaire = "2e7508fe33f5fa336df8784158fafffa9bca09d060de22f7b4c6246ede96c4c4"

[atelier]
depot = "JuNeI23/dunei-atelier"
clone = "~/dunei-atelier"
gitconfig = "git/gitconfig"           # inclus par ~/.gitconfig, jamais lié

[atelier.liens]                       # chemin dans le clone → destination
"claude/settings.json" = "~/.claude/settings.json"
"claude/CLAUDE.md" = "~/.claude/CLAUDE.md"
"claude/RTK.md" = "~/.claude/RTK.md"
"maison/CLAUDE.md" = "~/CLAUDE.md"
"rtk/config.toml" = "~/.config/rtk/config.toml"
```

- [ ] **Step 2 : écrire `.claude/settings.json`** : `{"autoMemoryDirectory": "~/dunei-atelier/memoire"}` ;
  dans `.gitignore`, remplacer `.claude/` par `.claude/*` puis `!.claude/settings.json`.

- [ ] **Step 3 : tests qui échouent** dans `tests/test_atelier.py`, classe `LectureTest` :
  - `test_lit_le_depot` : `lire_atelier(ROOT)` rend `rtk.version == "1.0.1"`, `atelier.clone ==
    Path.home() / "dunei-atelier"`, 5 liens, aucune erreur.
  - `test_memoire_du_projet_dans_le_clone` : `json.loads(ROOT/.claude/settings.json)["autoMemoryDirectory"]`
    développé égale `clone / "memoire"`.
  - `test_cle_manquante` : un `atelier.toml` temporaire sans `sha256_binaire` → message qui nomme la clé.
  - `test_somme_mal_formee` : une somme qui n'a pas 64 caractères hexadécimaux → message.
  - `test_aucun_secret_dans_les_liens` : aucune destination ne se termine par `.credentials.json`.
  - `test_git_ignore_le_reste_de_claude` : `git check-ignore -q .claude/settings.local.json` réussit,
    `git check-ignore -q .claude/settings.json` échoue.

- [ ] **Step 4 :** `python3 -m unittest tests.test_atelier -v` → échec (module absent).
- [ ] **Step 5 : implémenter `lire_atelier`** dans `atelier.py` (docstring de module sur le modèle de
  `deploy.py`, qui décrit les deux destinations). Toutes les erreurs deviennent des messages, aucune
  exception.
- [ ] **Step 6 :** les tests passent ; `make check` passe.
- [ ] **Step 7 : commit** « Atelier : atelier.toml, lecture et mémoire du projet (L1-26) ».

### Task 2 : destination `rtk`

**Files :**
- Modify : `atelier.py`, `deploy.py` (`DESTINATIONS`, `describe`, `apply`, `NOTES`), `tests/test_deploy.py`
  (fonction `run`)
- Test : `tests/test_atelier.py`

**Interfaces :**
- Consumes : `lire_atelier` (tâche 1) ; `deploy.bin_home(env)`.
- Produces :
  - `cache_home(env: Mapping[str, str]) -> Path` : `$XDG_CACHE_HOME/dunei`, sinon `~/.cache/dunei`.
  - `telecharger(url: str, dest: Path) -> None` : `urllib.request.urlretrieve`, seul point réseau.
  - `sha256(path: Path) -> str`.
  - `plan_rtk(repo: Path, home: Path) -> tuple[list[tuple], list[str]]`. Actions :
    `("rtk-pose", archive: Path, binaire_attendu: str, dest: Path)`, et la note
    `("rtk-remplace", dest: Path, version: str)` quand un binaire d'une autre somme est présent.
  - `appliquer(action: tuple) -> bool` : exécute une action de `atelier.py`, rend `False` si le type ne
    lui appartient pas. Pour `rtk-pose` : extraire le membre `rtk` de l'archive dans un fichier temporaire
    du dossier cible, vérifier sa somme (sinon `OSError`), `chmod 755`, `os.replace`.
  - `describe` de `deploy.py` reçoit les phrases de `rtk-pose` et `rtk-remplace`.

- [ ] **Step 1 : tests qui échouent**, classe `RtkTest` (archive factice construite par le test avec
  `tarfile`, contenant `rtk`, `LICENSE` ; `atelier.toml` temporaire pointé par `DUNEI_ATELIER_TOML`, avec une
  URL `file://` et les sommes de l'archive factice ; `XDG_BIN_HOME` et `XDG_CACHE_HOME` temporaires) :
  - `test_binaire_conforme_rien_a_faire` : binaire en place avec la bonne somme → `([], [])`, aucun
    téléchargement (`telecharger` remplacé par un `mock` qui échoue s'il est appelé).
  - `test_binaire_absent_telecharge_a_l_inspection` : l'archive est dans le cache après `plan_rtk`,
    action `rtk-pose`, rien dans `XDG_BIN_HOME`.
  - `test_somme_d_archive_fausse` : erreur qui contient la somme attendue et la somme lue ; rien posé.
  - `test_cache_corrompu_retelecharge_une_fois` : cache faux puis source juste → une action, aucune
    erreur ; source fausse → une erreur, `telecharger` appelé une fois de plus seulement.
  - `test_hors_ligne` : `telecharger` lève `OSError` → erreur qui nomme l'URL.
  - `test_autre_version_remplacee` : binaire d'une autre somme → `rtk-pose` et `rtk-remplace`.
  - `test_pose` : `appliquer(("rtk-pose", ...))` pose un exécutable 755 dont la somme est l'attendue.
  - `test_pose_binaire_faux` : somme du binaire extrait différente → `OSError`, destination intacte.
- [ ] **Step 2 :** échec constaté.
- [ ] **Step 3 : implémenter** `cache_home`, `telecharger`, `sha256`, `plan_rtk`, `appliquer`.
- [ ] **Step 4 : brancher dans `deploy.py`** : `"rtk": atelier.plan_rtk` après `"bin"` dans
  `DESTINATIONS` ; `apply` appelle `atelier.appliquer(action)` pour tout type inconnu et lève
  `OSError` si elle rend `False` ; `"rtk-remplace"` entre dans `NOTES`.
- [ ] **Step 5 : isoler `tests/test_deploy.py`** : `run()` pose `HOME` temporaire, `XDG_CACHE_HOME`
  temporaire et `DUNEI_ATELIER_TOML` vers un fichier de test dont le binaire factice est déjà en place
  dans `local-bin` avec la bonne somme, pour que les tests existants n'agissent jamais sur rtk.
  Ajouter `test_install_pose_rtk` (binaire absent → posé par `deploy.py`) et
  `test_install_refuse_archive_fausse` (code 1, « rien n'a été modifié », aucun fichier créé dans
  `cfg`).
- [ ] **Step 6 :** `make test` puis `make check` passent.
- [ ] **Step 7 : commit** « Atelier : rtk épinglé, téléchargé et vérifié à l'inspection (L1-26) ».

### Task 3 : destination `atelier` : clone et liens

**Files :**
- Modify : `atelier.py`, `deploy.py` (`DESTINATIONS`, `describe`, `NOTES`), `tests/test_deploy.py`
- Test : `tests/test_atelier.py`

**Interfaces :**
- Consumes : `lire_atelier`, `appliquer` (tâche 2).
- Produces :
  - `gh_accessible(depot: str) -> str` : chaîne vide si `gh auth status` puis `gh repo view <depot>`
    réussissent, sinon la cause en une phrase avec la commande à lancer.
  - `plan_atelier(repo: Path, home: Path) -> tuple[list[tuple], list[str]]`. Actions dans cet ordre :
    `("atelier-saute", cause)` (note, et rien d'autre) ; sinon `("atelier-clone", depot, clone)` si le
    clone manque ; puis la tâche 4 insère les siennes ; puis pour chaque lien dont la destination
    n'est pas déjà le bon lien `("atelier-lien", src: Path, dst: Path, neuf: bool)`, `neuf` vrai si le
    clone manquait à l'inspection.
  - `appliquer` traite `atelier-clone` (`gh repo clone <depot> <clone>`) et `atelier-lien` :
    dossier parent créé ; destination absente → lien ; fichier identique à `src` → lien par
    `os.replace` d'un lien temporaire ; fichier différent et `neuf` → renommé `<nom>.avant-dunei`, puis
    lien ; fichier différent et non `neuf` → contenu copié dans `src`, puis lien. Rend une note
    `("atelier-repris", dst)` ou `("atelier-garde", dst)` par une liste `atelier.NOTES_APPLIQUEES`, que
    `deploy.main` affiche avec les autres notes.
- Erreurs d'inspection : clone qui existe sans être un dépôt git, ou dont `origin` n'est pas `depot` ;
  destination qui est un dossier ; lien symbolique vers un autre chemin que `src`.

- [ ] **Step 1 : tests qui échouent**, classe `AtelierTest`. Un dépôt git nu temporaire joue
  `dunei-atelier` ; un faux `gh` dans le `PATH` répond à `auth status` et `repo view` par
  `$FAKE_GH_AUTH` (0 ou 1) et à `repo clone <depot> <dest>` par `git clone <dépôt nu> <dest>` :
  - `test_gh_deconnecte_saute` : une seule action, `atelier-saute`, qui contient `gh auth login` ;
    aucune erreur.
  - `test_machine_neuve` : pas de clone, pas de `~/.claude` → après `appliquer` de toutes les actions,
    les 5 destinations sont des liens vers le clone.
  - `test_neuf_garde_le_fichier_par_defaut` : `~/.claude/settings.json` préexistant et différent, clone
    absent → lien posé, `settings.json.avant-dunei` porte l'ancien contenu, note `atelier-garde`.
  - `test_reprise_d_un_lien_remplace` : clone présent, `settings.json` devenu fichier différent → le
    clone porte le nouveau contenu, la destination est redevenue un lien, note `atelier-repris`,
    `git -C clone status --porcelain` le montre.
  - `test_fichier_identique_devient_lien`.
  - `test_deuxieme_passage_rien` : `plan_atelier` rend `([], [])` une fois tout posé.
  - `test_lien_etranger_refuse`, `test_clone_qui_n_est_pas_git_refuse`, `test_autre_origine_refusee`,
    `test_dossier_a_la_place_refuse` : une erreur chacun, qui nomme le chemin.
- [ ] **Step 2 :** échec constaté.
- [ ] **Step 3 : implémenter** `gh_accessible`, `plan_atelier` et les deux branches d'`appliquer`.
- [ ] **Step 4 : brancher** `"atelier": atelier.plan_atelier` après `"rtk"` ; `atelier-saute` dans
  `NOTES` ; `deploy.main` affiche aussi `atelier.NOTES_APPLIQUEES`. Dans `tests/test_deploy.py`, le faux
  `gh` par défaut répond « non connecté », pour que les tests existants ne voient que la note.
- [ ] **Step 5 :** `make test` puis `make check` passent.
- [ ] **Step 6 : commit** « Atelier : clone privé et liens, reprise d'un lien remplacé (L1-26) ».

### Task 4 : plugins et identité git

**Files :** Modify : `atelier.py`, `deploy.py` (`describe`, `NOTES`) ; Test : `tests/test_atelier.py`

**Interfaces :**
- Produces : actions `("atelier-plugins", clone: Path)` et `("atelier-include", gitconfig: Path)`, placées
  par `plan_atelier` après `atelier-clone` et avant les liens ; `atelier-include` seulement si
  `git config --global --get-all include.path` ne contient pas le chemin.
  `appliquer` :
  - `atelier-plugins` : lit `enabledPlugins` dans `clone/claude/settings.json`, compare aux `id` de
    `claude plugin list --json`, lance `claude plugin install <id>` pour chaque manquant ; `claude`
    introuvable → note `("atelier-sans-claude",)` dans `NOTES_APPLIQUEES`, rien d'autre.
  - `atelier-include` : `git config --global --add include.path <chemin>` (crée `~/.gitconfig` s'il
    manque).

- [ ] **Step 1 : tests qui échouent** (faux `claude` qui consigne ses appels et répond à
  `plugin list --json` par `$FAKE_PLUGINS`) :
  - `test_installe_les_plugins_manquants` : `enabledPlugins` à deux clés, une installée → un seul
    `claude plugin install superpowers@claude-plugins-official`.
  - `test_plugins_tous_presents_rien`.
  - `test_sans_claude_signale` : `claude` absent du `PATH` → note, aucune exception.
  - `test_gitconfig_absent_cree_avec_inclusion` : `HOME` sans `.gitconfig` → fichier créé, inclusion seule.
  - `test_gitconfig_de_gh_garde` : `.gitconfig` avec les assistants de `gh` → assistants conservés,
    inclusion ajoutée une fois ; second `plan_atelier` sans `atelier-include`.
  - `test_ordre` : dans les actions d'une machine neuve, `atelier-clone` < `atelier-plugins` <
    `atelier-include` < premier `atelier-lien`.
- [ ] **Step 2 :** échec constaté. **Step 3 :** implémenter. **Step 4 :** `make check` passe.
- [ ] **Step 5 : commit** « Atelier : plugins depuis enabledPlugins, identité git par inclusion (L1-26) ».

### Task 5 : relevé d'état, bilan et `dunei-maj`

**Files :** Modify : `atelier.py`, `deploy.py` (`main`), `config/bin/dunei-maj`,
`tests/test_dunei_maj.py` ; Test : `tests/test_atelier.py`

**Interfaces :**
- Produces : `etat_atelier(repo: Path) -> list[str]` : une phrase par écart, vide si tout va bien ou si
  le clone n'existe pas : fichiers modifiés ou non suivis (`git status --porcelain`), commits en avance
  sur la branche suivie (`git rev-list --count @{u}..HEAD`, sans réseau), destination d'un lien devenue
  fichier. Ligne de commande `python3 atelier.py --etat` : imprime ces phrases, code 0 toujours.
- `deploy.main` imprime `etat_atelier` après les notes, préfixé « atelier : ».
- `dunei-maj` termine par `python3 "<dépôt>/atelier.py" --etat`, le dépôt retrouvé par
  `readlink -f "$0"` ; s'il manque, rien.

- [ ] **Step 1 : tests qui échouent** : `test_etat_propre_vide`, `test_etat_modifie`,
  `test_etat_en_avance`, `test_etat_lien_devenu_fichier`, `test_etat_sans_clone_vide` ; dans
  `tests/test_dunei_maj.py`, `test_signale_l_atelier` (faux `python3` qui consigne son appel).
- [ ] **Step 2 :** échec constaté. **Step 3 :** implémenter. **Step 4 :** `make check` passe.
- [ ] **Step 5 : commit** « Atelier : relevé des changements non envoyés, dans make install et dunei-maj
  (L1-26) ».

### Task 6 : création de `dunei-atelier` et premier passage sur `caladan`

Tâche menée par Claude dans la session principale, pas par un sous-agent : elle touche le vrai `~`.

- [ ] **Step 1 :** `gh repo create JuNeI23/dunei-atelier --private --clone` dans `~/dunei-atelier`.
- [ ] **Step 2 : verser les fichiers actuels tels quels** : `~/.claude/settings.json` →
  `claude/settings.json`, `~/.claude/CLAUDE.md`, `~/.claude/RTK.md` → `claude/`, `~/CLAUDE.md` →
  `maison/CLAUDE.md`, `~/.config/rtk/config.toml` → `rtk/`, `~/.claude/projects/-home-junei-DuneI/memory/*`
  → `memoire/`, `user.name` et `user.email` de `~/.gitconfig` seuls → `git/gitconfig`. Un `README.md` dit
  ce qu'est le dépôt et qu'il ne contient aucun secret.
- [ ] **Step 3 : ajouter la règle d'envoi** à la fin de `claude/CLAUDE.md` :

```markdown
# Atelier
`~/dunei-atelier` (dépôt privé `JuNeI23/dunei-atelier`) porte tes réglages, ces instructions et ta mémoire
de DuneI. Toute modification d'un de ses fichiers, mémoire comprise, est validée puis envoyée aussitôt sur
`main`, sans branche ni PR, avec ta ligne `Co-Authored-By`. Rien de secret n'y entre.
```

- [ ] **Step 4 :** `grep -rE "sk-ant|ghp_|gho_|token|password" ~/dunei-atelier` ne trouve rien de
  secret ; premier commit et envoi.
- [ ] **Step 5 :** `python3 deploy.py --dry-run` : rtk conforme, aucune
  action ; liens annoncés ; inclusion annoncée. Puis `make install`.
- [ ] **Step 6 : vérifier** que `~/.claude/settings.json` est un lien, que `~/.gitconfig` garde les
  assistants de `gh` et inclut l'atelier, que `git config user.email` répond.
- [ ] **Step 7 : demander à Nicolas d'ouvrir une nouvelle session** dans `~/DuneI` : elle doit citer la
  règle « jamais `firefox --headless` » sans la chercher, et ses commandes doivent passer par rtk.
  Seulement ensuite, retirer `~/.claude/projects/-home-junei-DuneI/memory/`.

### Task 7 : recette en machine virtuelle

- [ ] **Step 1 :** dans la machine de `setup/vm.sh` (phase 1 déjà faite ou à refaire), dérouler la phase 2
  du § 6 de la spec, `PATH` ajouté à la main.
- [ ] **Step 2 : critère 1** : premier lancement de `claude` connecté, permissions refusées visibles
  (`/permissions`), context7 et superpowers actifs (`/plugin`), une commande `git status` condensée par
  rtk, mémoire relue.
- [ ] **Step 3 : risques du § 7** : `claude plugin install` sur marché jamais chargé ; un `/config` puis
  `ls -l ~/.claude/settings.json` (lien conservé ou remplacé ?) ; rtk sans `filters.toml`. Consigner
  chaque constat. **Si le lien est remplacé à chaque écriture, s'arrêter et revenir vers Nicolas.**

### Task 8 : documentation, PR, fusion

**Files :** Modify : carnet (phase 2, nouvelle section « Atelier — L1-26 », historique), backlog (L1-26,
ligne « améliorer l'atelier » au lot à choisir, L1-25 enrichi, décompte, historique), journal (D61 :
réinstallation au lieu du chiffrement sur place ; D62 : atelier en deux dépôts ; D63 : rtk épinglé ; D64 :
envoi par Claude), notes de direction (état d'avancement, dernier paragraphe : prochaine étape **L1-25**
avec les écarts de procédure), spec (statut, version), `CLAUDE.md` du dépôt (Repères : `atelier.toml`,
`~/dunei-atelier`).

- [ ] **Step 1 :** écrire ces mises à jour, numéros de version et tables d'historique compris.
- [ ] **Step 2 :** `make check` ; relecture finale de la branche.
- [ ] **Step 3 :** PR ; fusion par `gh pr merge <n> --merge` après validation de Nicolas, puis procédure
  après fusion du carnet (D32).

## Historique des versions

| Version | Date | Changement |
| --- | --- | --- |
| 0.1 | 2026-10-17 | Version initiale |
