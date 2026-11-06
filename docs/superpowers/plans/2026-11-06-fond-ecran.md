# Application du fond d'écran : plan d'implémentation (L2-27)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal :** afficher une image de fond dans un calque de la coque, la changer par `dunei-fond <chemin>` avec la montée validée, et la reprendre au démarrage.

**Architecture :** `dunei-fond` écrit `bureau.json`, seule source de vérité. `Theme` en expose l'image et le fond ; le module `coque/Fond` affiche l'image, anime le changement et publie à `Theme` le fond réellement affiché, dont dépend le texte de la barre.

**Tech Stack :** Quickshell 0.3 / QML (Qt 6.12), Python 3 avec Pillow, Hyprland 0.57 en Lua, `unittest`.

**Spec :** `docs/superpowers/specs/2026-11-06-fond-ecran-design.md` (v0.2)

## Global Constraints

- Branche `feat/fond-ecran`, dans `~/DuneI` ; `generated/` ne s'édite jamais à la main (`make tokens`, puis `make golden` si le rendu change volontairement).
- Toute couleur et tout mouvement viennent de `Theme` ; ressort `spectacle` sans forcer le sens ; aucun jeton de mouvement créé.
- Dossier des images : `~/Documents/Images/Wallpapers`. Aucune image n'entre dans le dépôt.
- Fonction commentée : titre et rôle, entrées, sorties, erreurs, dépendances. Commentaires en français complet et accentué.
- Avant d'utiliser une API de Quickshell ou de Qt non employée dans le dépôt (`ShellScreen.devicePixelRatio`, `retainWhileLoading`, `autoTransform`), la vérifier dans context7.
- Essais à l'écran sur les bureaux 1 à 4 seulement ; chaque commit porte la ligne `Co-Authored-By` de son modèle.

## Review Focus

- Une image JPEG avec rotation EXIF doit s'afficher et se mesurer dans le même sens (`autoTransform: true`, `ImageOps.exif_transpose`).
- Un chemin relatif ou contenant des espaces et des accents doit fonctionner (`dunei-fond` écrit un chemin absolu, le calque l'encode en URL).
- Un PNG transparent doit donner un `fond` juste, composé sur l'aplat des jetons, sans planter sur un mode `P` ou `LA`.
- Une bascule jour/nuit pendant qu'une image est affichée ne doit ni relancer la montée ni changer l'image.
- Une image supprimée après son choix reste affichée jusqu'à la relance de la coque, où l'aplat reprend sans erreur fatale.

---

### Task 1 : commande `dunei-fond` et jetons

**Files:**
- Create : `config/bin/dunei-fond`, `tests/test_dunei_fond.py`
- Modify : `tokens.toml` (`[bureau]`), `dunei_theme/emitters/quickshell.py` (`_bureau`), `generated/`, `tests/golden/`

**Interfaces :**
- Produces : `bureau.json` = `{"origine":"fond","fond":"#rrggbb","image":"<absolu>"}` ou `{"origine":"theme","fond":<tokens.bureau.fond>}` ; `tokens.bureau.bande` (28) et `tokens.bureau.dossier` (`"Documents/Images/Wallpapers"`, relatif à `$HOME`).

- [ ] **Step 1 : écrire les tests qui échouent** dans `tests/test_dunei_fond.py`, sur le modèle de `tests/test_dunei_theme.py` (`generate_tokens.py --out`, `DUNEI_TOKENS_DIR`, `HOME` temporaire), images créées avec Pillow, sans session Hyprland (`PATH` sans `hyprctl`) sauf indication :
  - `test_applique` : image 1000 × 1000, haut blanc et reste noir, code 0, stdout = chemin absolu, `origine == "fond"`, `image` absolu ;
  - `test_bande_mesuree` : haut blanc, reste noir → `fond` de luminance relative ≥ 0,18 ; l'inverse → < 0,18 ;
  - `test_recadrage_ecran` : avec un faux `hyprctl` en tête du `PATH` qui répond un écran `1920×1200`, échelle 1,25, focalisé : image 1000 × 2000 dont une bande blanche occupe les 25 % du haut, le reste noir → le recadrage centré retire cette bande et `fond` est sombre ; sans `hyprctl`, `fond` est clair ;
  - `test_relatif_et_accents` : `./été à la plage.jpg` depuis le dossier de l'image donne le chemin absolu exact ;
  - `test_exif` : JPEG d'orientation EXIF 6 → la bande mesurée est celle de l'image redressée ;
  - `test_png_transparent` : PNG `RGBA` entièrement transparent → `fond` égal à `tokens.bureau.fond` ; même chose en mode `P` et `LA` sans erreur ;
  - `test_absente_ou_illisible` : chemin absent, puis fichier texte en `.jpg` → code 2, `bureau.json` inchangé ;
  - `test_tokens_illisibles` : `coque-tokens.json` corrompu → code 1, rien d'écrit ;
  - `test_aucun` : après une application, `--aucun` → `{"origine":"theme","fond":<jetons>}`, sans clé `image` ;
  - `test_etat` : sans argument, affiche `image` ou `aucun`, sans écrire ;
  - `test_atomique` : aucun fichier temporaire ne reste dans le dossier.
- [ ] **Step 2 : lancer les tests** : `python3 -m unittest tests.test_dunei_fond -v`. Attendu : échec, script absent.
- [ ] **Step 3 : ajouter les jetons** dans `[bureau]` : `bande = 28` (hauteur réelle de la barre, `Barre.qml`) et `dossier = "Documents/Images/Wallpapers"`, puis les émettre dans `_bureau` ; `make tokens`, puis `make golden`, en vérifiant que le seul écart concerne ces deux clés.
- [ ] **Step 4 : écrire `config/bin/dunei-fond`** (Python 3, exécutable, en-tête sur le modèle de `dunei-theme`) avec :
  - `lire_jetons(dossier: Path) -> dict` ;
  - `ecran_actif() -> tuple[int, int] | None`, d'après l'écran `focused` de `hyprctl monitors -j` en pixels logiques (`width/scale`, `height/scale`), `None` si la commande échoue ;
  - `mesurer(image: Image.Image, ecran: tuple[int, int] | None, bande: int, aplat: str) -> str`, qui redresse l'image, la compose sur `aplat`, applique le recadrage centré de `PreserveAspectCrop` et renvoie la moyenne de la bande en `#rrggbb` ; hors écran, la référence est `1536 × 960` pour fixer la proportion de la bande, sans recadrage ;
  - `ecrire(chemin: Path, contenu: dict) -> None`, par fichier temporaire du même dossier et `os.replace`.
- [ ] **Step 5 : relancer les tests** : `python3 -m unittest tests.test_dunei_fond tests.test_shellcheck -v`. Attendu : réussite ; si `test_shellcheck` balaie `config/bin/` sans distinguer le langage, le restreindre aux scripts `bash`.
- [ ] **Step 6 : valider** avec `git add` des fichiers de la tâche et `git commit -m "Fond d'écran : commande dunei-fond et jetons de la bande et du dossier (L2-27)"`.

### Task 2 : déploiement du dossier

**Files:**
- Modify : `deploy.py`, `tests/test_deploy.py`

**Interfaces :**
- Consumes : `tokens.bureau.dossier`.
- Produces : `plan_fonds(repo: Path, home: Path) -> tuple[list[tuple], list[str]]`.

- [ ] **Step 1 : écrire les tests qui échouent**, dans le style de `tests/test_deploy.py` :
  - `test_fonds_cree` : dossier absent → action `("mkdir", $HOME/Documents/Images/Wallpapers)` ;
  - `test_fonds_existant` : dossier présent, avec une image → aucune action ;
  - `test_fonds_pas_un_dossier` : un fichier à la place → une erreur, aucune action ;
  - `test_bureau_image_preservee` : à côté de `test_bureau_fond_preserve`, un `bureau.json` d'origine `fond` avec `image` ne produit aucune action.
- [ ] **Step 2 : lancer** `python3 -m unittest tests.test_deploy -v`. Attendu : échec sur `plan_fonds`.
- [ ] **Step 3 : écrire `plan_fonds`** sur le modèle de `plan_bin`, créer les parents absents, et l'inscrire dans `main` et dans l'en-tête de `deploy.py`. `home` y est le dossier de configuration racine, comme ailleurs : le dossier personnel se lit dans `os.environ["HOME"]`, comme le fait `bin_home`.
- [ ] **Step 4 : relancer** les tests de `tests.test_deploy`. Attendu : réussite.
- [ ] **Step 5 : valider** avec le message `Fond d'écran : make install crée le dossier des images (L2-27)`.

### Task 3 : `Theme` lit l'image et accepte le fond publié

**Files:**
- Modify : `coque/Theme/Theme.qml`, `tests/test_coque_theme.py`, sa coque d'essai si un appel IPC manque

**Interfaces :**
- Produces : `Theme.imageBureau: string` (`""` si absente) ; `Theme.fondFichier` existant ; `Theme.fondPublie: var` (null par défaut, écrit par le module `Fond`) ; `Theme.fondBureau = fondPublie ?? fondFichier ?? bureau.fond`.

- [ ] **Step 1 : écrire les tests qui échouent** à côté de `test_texte_bureau_suit_le_fichier` :
  - `test_image_lue` : `{"origine":"fond","fond":"#101010","image":"/tmp/x.jpg"}` → `imageBureau == "/tmp/x.jpg"` ;
  - `test_image_absente_ou_invalide` : sans clé, ou `"image": 3` → `imageBureau == ""`, `fond` toujours lu ;
  - `test_fond_publie_prioritaire` : un fichier sombre et `fondPublie` clair → texte foncé ; remis à null → texte clair ;
  - `test_sans_module_fond` : sans publication, le comportement de `test_texte_bureau_suit_le_fichier` reste vrai.
- [ ] **Step 2 : lancer** `python3 -m unittest tests.test_coque_theme -v`. Attendu : échec sur ces tests.
- [ ] **Step 3 : modifier `Theme.qml`** : ajouter `image` à `keys` du `Source`, ajouter `imageBureau` et `fondPublie`, changer `fondBureau`, documenter l'en-tête. Le fichier invalide (`onRejected`) remet aussi `imageBureau` à `""`.
- [ ] **Step 4 : relancer** les tests. Attendu : réussite.
- [ ] **Step 5 : valider** avec le message `Theme : image du bureau et fond publié par le calque (L2-27)`.

### Task 4 : l'affichage et sa machine d'états

**Files:**
- Create : `coque/Fond/Affichage.qml`, `coque/Fond/qmldir`, `coque/Fond/essai/shell.qml` (liens `Theme`, `Fond`, comme `coque/Presquile/essai/`), `tests/test_fond.py`

**Interfaces :**
- Consumes : `Theme.imageBureau`, `Theme.fondFichier`, `Theme.fondPublie`, `Theme.mouvementReduit`, `Ressort`.
- Produces : `Affichage { property real echelle }` (Item sans fenêtre, à remplir par son parent) ; sorties lues par les tests : `etat` (`"repos"`, `"charge"`, `"vol"`), `imageAffichee: string`, `enAttente: string`.

- [ ] **Step 1 : écrire les tests qui échouent** dans `tests/test_fond.py` (`EssaiCoque`, plateforme offscreen comme `test_presquile`, vitrine `FloatingWindow`, IPC `fond`), en écrivant `bureau.json` :
  - `test_pose_au_demarrage` : image valide au lancement → `imageAffichee` égale, jamais d'état `vol`, `fondPublie == fond` ;
  - `test_illisible_au_demarrage` : → `imageAffichee == ""`, `fondPublie == tokens.bureau.fond`, avertissement au journal, aucune erreur fatale ;
  - `test_montee` : changement valide → passe par `charge` et `vol`, puis `repos` ; `imageAffichee` ne change et `fondPublie` n'est publié qu'à l'atterrissage, pas au départ ;
  - `test_demande_en_vol` : deux changements pendant un vol → seul le dernier s'applique ensuite, avec son propre `fond` ;
  - `test_aucun_en_vol` et `test_aucun_au_repos` : image retirée d'un coup, à la fin du vol s'il y en a un ; `fondPublie == tokens.bureau.fond` ;
  - `test_illisible_au_changement` : l'image en place reste, `fondPublie` inchangé, avertissement au journal ;
  - `test_meme_image` : aucun vol ;
  - `test_chemin_accents` : un fichier `été à la plage.jpg` se charge ;
  - `test_mouvement_reduit` : préférence réduite → pas de déplacement (`y` de la couche haute à 0 pendant `vol`), opacité animée de 0 à 1 ;
  - `test_bascule_theme` : `theme.json` changé pendant le repos → aucun passage par `charge` ;
  - `test_reste_apres_suppression` : le fichier affiché est supprimé → l'image reste.
- [ ] **Step 2 : lancer** `python3 -m unittest tests.test_fond -v`. Attendu : échec, module absent.
- [ ] **Step 3 : écrire `Affichage.qml`** selon la section « Le calque » de la fiche :
  - deux `Image` en `PreserveAspectCrop`, `asynchronous`, `autoTransform: true`, `cache: false` et `sourceSize` en pixels physiques (`width * echelle`, `height * echelle`), `retainWhileLoading` sur la couche basse ;
  - `Ressort { transition: "spectacle"; nature: Theme.mouvementReduit ? "fondu" : "deplacement" }`. Avec le déplacement, il pilote `y` de `hauteur` à 0 ; avec le fondu, `y` reste à 0 et il pilote l'opacité ;
  - le drapeau `enVol` protège la fin de vol : `Ressort.poser()` met `moving` à faux, ce qui sans lui remplacerait l'image au départ. Il se lève après `poser()` et avant le changement de cible ;
  - une demande prend `Theme.imageBureau` et `Theme.fondFichier` ensemble, à sa réception ;
  - le chemin s'encode en URL par `"file://" + encodeURI(chemin)`.
- [ ] **Step 4 : relancer** `tests.test_fond`. Attendu : réussite.
- [ ] **Step 5 : valider** avec le message `Fond : affichage de l'image et montée au ressort spectacle (L2-27)`.

### Task 5 : le calque dans la session

**Files:**
- Create : `coque/Fond/Fond.qml`
- Modify : `coque/Fond/qmldir`, `coque/shell.qml`, `dunei_theme/emitters/hyprland.py` (`emit_layer_rules`), `tokens.toml` (`[bureau].namespace = "dunei-fond"`), `generated/`, `tests/golden/`, `tests/test_fond.py`, tests des règles de calque (`tests/test_hyprland_entry.py`, `tests/test_hyprland_modules.py`) au besoin

**Interfaces :**
- Consumes : `Affichage`.
- Produces : `Fond { required property var modelData }`.

- [ ] **Step 1 : écrire les tests qui échouent** :
  - `test_calque` (lecture du source, comme `PresquileStructureTest.test_calque`) : `WlrLayershell.namespace: "dunei-fond"`, `WlrLayershell.layer: WlrLayer.Background`, `WlrLayershell.keyboardFocus: WlrKeyboardFocus.None`, `exclusionMode: ExclusionMode.Ignore`, `mask: Region {}`, ancrage aux quatre bords, couleur `Theme.bureau?.fond` ;
  - `test_shell_ordre` : dans `coque/shell.qml`, `Fond` précède `Barre` et `Presquile` dans le `Variants` ;
  - `test_regle_no_anim` : `emit_layer_rules` produit une règle `name = "dunei-fond"`, `match = { namespace = "^dunei-fond$" }`, `no_anim = true`, sans `blur`.
- [ ] **Step 2 : lancer** ces tests. Attendu : échec.
- [ ] **Step 3 : écrire `Fond.qml`**, l'ajouter à `shell.qml`, ajouter la règle et le jeton ; `make tokens`, puis `make golden`, en vérifiant que l'écart se limite à cette règle et à ce jeton.
- [ ] **Step 4 : lancer** `make check`. Attendu : réussite complète.
- [ ] **Step 5 : valider** avec le message `Fond : calque de fond d'écran dans la coque, sans animation d'apparition (L2-27)`.

### Task 6 : mise en service, recette et documentation

**Files:**
- Modify : `docs/journal-decisions.md`, `docs/project_management/` (backlog, carnet, notes de direction, bible), la fiche si un écart apparaît

- [ ] **Step 1 : installer** `make install`, puis `systemctl --user restart dunei-coque` et `hyprctl reload config-only`. Attendu : barre et presqu'île de retour, aplat inchangé, et `pss` de la coque relevé avant et après la première image.
- [ ] **Step 2 : recette à l'écran avec Nicolas**, sur les bureaux 1 à 4, chaque point noté réussi ou non :
  - une image apparaît par `dunei-fond`, avec la montée de l'essai ;
  - texte de la barre lisible sur une image claire puis sombre, avec bascule à la fin de la montée ;
  - après `systemctl --user restart dunei-coque`, l'image se pose d'un coup, sans animation ;
  - verre de la barre et de la presqu'île vivant sur l'image ;
  - réveil de veille : image présente, changement possible, processeur au repos ;
  - mouvement réduit : fondu seul ;
  - redémarrage de session : image reprise ;
  - écran externe, ou « non éprouvé » si aucun n'est disponible.
- [ ] **Step 3 : documenter** : au journal, à partir de D121, le calque à la place du démon prévu par L2-27, le calcul sur la bande (écart à D90) et les mesures relevées ; backlog : L2-27 fait, nouvelles lignes pour la galerie (avec L2-48), le verre du jour (valeurs validées, popovers à trancher) et l'écart de `systemBarHeight` (32 contre 28), décomptes à jour ; carnet, bible (chapitre 2 et annexe E) ; notes de direction, avec la galerie comme prochaine étape au dernier paragraphe. Chaque document change de version et enrichit son historique.
- [ ] **Step 4 : vérifier** `make check` puis `git status`. Attendu : réussite, arbre propre après validation.
- [ ] **Step 5 : valider et pousser** avec le message `Fond d'écran : recette et documentation (L2-27, D121)`, puis `git push -u origin feat/fond-ecran` et ouvrir la PR ; la fusion attend la relecture finale et la validation à l'écran de Nicolas.

## Historique des versions

| Version | Date | Changement |
|---|---|---|
| 0.1 | 2026-11-06 | Première version, d'après la fiche v0.2 |
| 0.2 | 2026-11-06 | Réalisé : écarts au plan rapportés dans la fiche v0.3 et au journal (D121, D122) |
