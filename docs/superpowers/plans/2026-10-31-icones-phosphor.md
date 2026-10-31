# Thème d'icônes DuneI, première tranche Phosphor — plan d'exécution

> **Pour les agents :** sous-compétence requise : superpowers:subagent-driven-development (recommandé) ou
> superpowers:executing-plans, tâche par tâche. Les étapes se cochent (`- [ ]`).

**But :** livrer un thème XDG « DuneI » tiré de Phosphor, qui fournit les icônes de la coque et du futur popover
réseau, hérite d'Adwaita pour le reste, et devient le thème d'icônes de GTK et de la coque.

**Architecture :** les SVG Phosphor utiles sont versionnés sous `icones/phosphor/` ; une table
`icones/correspondances.toml` associe chaque nom freedesktop à un nom Phosphor ; `generate_icones.py` écrit le thème
dans `generated/icons/DuneI/` ; `deploy.py` le lie sous `$XDG_DATA_HOME/icons/DuneI` et le déclare à GTK ; les
coques Quickshell le nomment par leur directive `IconTheme`.

**Techno :** Python 3 (bibliothèque standard, `tomllib`), SVG, spécification freedesktop des thèmes d'icônes,
Quickshell, GTK 3 et 4 (`settings.ini`, `gsettings`).

**Conception :** `docs/superpowers/specs/2026-10-31-icones-phosphor-design.md` (à lire avec ce plan).

## Contraintes globales

- Phosphor `@phosphor-icons/core` 2.1.1, licence MIT, archive npm
  `https://registry.npmjs.org/@phosphor-icons/core/-/core-2.1.1.tgz`, épinglée par sha256.
- Nom et héritage du thème lus dans `tokens.toml` `[icons]` : `xdg_theme = "DuneI"`,
  `xdg_inherits = ["Adwaita", "breeze-dark", "hicolor"]`. Jamais écrits en dur ailleurs.
- Chaque nom fourni l'est sous `<nom>-symbolic.svg` et `<nom>-fill-symbolic.svg` (limite de D82).
- Graisse unique, `regular` par défaut, lue dans la table ; variante pleine tirée de `fill`.
- `make install` ne touche jamais au réseau ; seul `make phosphor`, lancé à la main, télécharge.
- `generated/` ne s'édite jamais à la main (D77) : il se régénère.
- Qt hors périmètre (thème de plateforme reporté, décision de Nicolas) ; aucun paquet ajouté.
- Règles du dépôt : chaque fonction commentée (titre et rôle, entrées, sortie, erreurs, dépendances), code minimal,
  français accentué dans le code, les commentaires et les messages ; commits signés
  `Co-Authored-By: <modèle> <noreply@anthropic.com>`.

## Points de vigilance

1. Un nom ajouté à `icones.js` ou à un QML de production sans ligne dans la table : `make test` doit échouer, pas
   la barre retomber en silence sur Adwaita (tâche 4).
2. Un `~/.config/gtk-3.0/settings.ini` ou `gtk-4.0/settings.ini` déjà écrit par Nicolas ou par une application :
   refus avec message, jamais d'écrasement (tâche 3).
3. `$XDG_DATA_HOME` défini : le thème va dessous, pas dans `~/.local/share` (tâche 3).
4. Un nom Phosphor de la table absent des SVG versionnés, dans l'une des deux graisses : le générateur échoue avec un
   message qui nomme le fichier (tâche 2).
5. Un SVG Phosphor qui porte `currentColor` ailleurs que sur la racine, ou une racine sans `fill` : la sortie reste
   recolorable (tâche 2).

---

### Tâche 1 : sources Phosphor versionnées et table de correspondance

**Fichiers :**
- Créer : `icones/correspondances.toml`, `icones/phosphor/LICENSE`, `icones/phosphor/<graisse>/*.svg`,
  `icones/phosphor/fill/*.svg`, `phosphor.py`
- Modifier : `Makefile` (cible `phosphor`, commentaire d'en-tête)
- Test : `tests/test_icones.py`

**Interfaces :**
- Produit : `icones/correspondances.toml` au format
  ```toml
  [source]
  version = "2.1.1"
  url = "https://registry.npmjs.org/@phosphor-icons/core/-/core-2.1.1.tgz"
  sha256 = "<somme relevée à l'étape 3>"
  graisse = "regular"
  [barre]                       # noms demandés par la coque de production
  "battery-level-0" = "battery-empty"
  # … une ligne par nom de la table du § 5 de la conception, plages développées
  [reseau]                      # noms du popover réseau (L2-11)
  "network-wireless-no-route" = "wifi-x"
  ```
- Produit : `phosphor.charger(chemin: Path) -> tuple[dict, dict[str, str]]` (source, puis tous les groupes fusionnés
  nom freedesktop → nom Phosphor ; `ValueError` si un nom apparaît dans deux groupes).
- Produit : SVG sous `icones/phosphor/<graisse>/<nom>.svg` et `icones/phosphor/fill/<nom>-fill.svg`, noms tels que
  dans l'archive (`assets/<graisse>/…`, `assets/fill/…`).

- [x] **Étape 1 : écrire les tests qui échouent** dans `tests/test_icones.py` :
  - `test_table_complete` : la table contient exactement les noms du § 5 de la conception (liste écrite dans le
    test : 11 `battery-level-N`, 10 `-charging`, `battery-level-100-charged`, 7 `network-wireless-*` de la barre,
    `bluetooth-active`, `bluetooth-disabled`, `preferences-system-notifications`, `notifications-disabled`,
    `weather-clear`, `weather-clear-night`, `emblem-system`, `system-search`, `edit-clear`, `network-vpn`, puis le
    groupe réseau).
  - `test_sources_presentes` : pour chaque valeur de la table, `icones/phosphor/<graisse>/<v>.svg` et
    `icones/phosphor/fill/<v>-fill.svg` existent.
  - `test_aucun_svg_orphelin` : aucun SVG versionné n'est absent de la table.
  - `test_doublon_refuse` : `charger` sur une table temporaire où un nom figure dans deux groupes lève `ValueError`.
- [x] **Étape 2 : lancer** `python3 -m unittest tests.test_icones -v` ; attendu : échec (module ou table absents).
- [x] **Étape 3 : écrire `phosphor.py`** : `charger` (ci-dessus) et `rafraichir(repo: Path) -> list[str]`
  (télécharge l'archive par `urllib`, vérifie la somme, refuse sinon ; vide `icones/phosphor/<graisse>/` et
  `fill/`, y extrait les seuls SVG nommés par la table et `LICENSE` ; rend la liste des fichiers écrits). Lancer une
  première fois avec une somme vide qui fait afficher la somme réelle, la recopier dans la table après l'avoir
  vérifiée face à `npm view @phosphor-icons/core@2.1.1 dist.integrity` ou au registre. Cible
  `phosphor: ; $(PY) phosphor.py` dans le `Makefile`, documentée en tête.
- [x] **Étape 4 : lancer** `make phosphor`, puis les tests ; attendu : tout passe.
- [x] **Étape 5 : valider** `git add icones phosphor.py Makefile tests/test_icones.py` et commit.

### Tâche 2 : générateur du thème

**Fichiers :**
- Créer : `generate_icones.py`
- Modifier : `Makefile` (cible `icones`, ajoutée à `generes` et à `install`), `.gitignore` si besoin
- Créer (généré) : `generated/icons/DuneI/index.theme`, `generated/icons/DuneI/symbolic/*.svg`
- Test : `tests/test_icones.py`

**Interfaces :**
- Consomme : `phosphor.charger`.
- Produit : `generate_icones.index_theme(nom: str, herite: list[str]) -> str` ;
  `generate_icones.recolorable(svg: str) -> str` ;
  `generate_icones.generer(repo: Path, sortie: Path) -> list[Path]` (écrit `sortie/DuneI/…`, rend les chemins
  écrits ; `FileNotFoundError` dont le message nomme le SVG source manquant).
- `index.theme` : `[Icon Theme]`, `Name=DuneI`, `Comment=…`, `Inherits=Adwaita,breeze-dark,hicolor`,
  `Directories=symbolic` ; `[symbolic]` : `Size=16`, `MinSize=8`, `MaxSize=512`, `Type=Scalable`.
- `recolorable` : sur la racine `<svg>`, `fill="currentColor"` et `class="ColorScheme-Text"`, puis une feuille
  `<style>.ColorScheme-Text{color:#bebebe}</style>` en premier enfant ; tout autre attribut et le dessin intacts.

- [x] **Étape 1 : écrire les tests qui échouent** :
  - `test_index_theme` : `index_theme("DuneI", ["Adwaita","breeze-dark","hicolor"])` contient
    `Inherits=Adwaita,breeze-dark,hicolor`, `Directories=symbolic`, `Type=Scalable`.
  - `test_recolorable` : sur `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 256" fill="currentColor"><path d="M0 0"/></svg>`,
    la sortie contient une seule fois `class="ColorScheme-Text"`, la règle `.ColorScheme-Text{color:#bebebe}`, garde
    `viewBox="0 0 256 256"` et `<path d="M0 0"/>` ; sur une racine sans `fill`, la sortie porte `fill="currentColor"`.
  - `test_generer_deux_variantes` : dans un dossier temporaire, chaque nom de la table donne
    `symbolic/<nom>-symbolic.svg` et `symbolic/<nom>-fill-symbolic.svg`, et le second provient du SVG `fill`.
  - `test_source_manquante` : avec une table temporaire qui nomme un SVG absent, `FileNotFoundError` dont le message
    contient le chemin.
  - `test_genere_a_jour` : `generated/icons/DuneI/` égale une génération fraîche dans un dossier temporaire.
- [x] **Étape 2 : lancer** les tests ; attendu : échec.
- [x] **Étape 3 : écrire `generate_icones.py`** (interface ci-dessus, `--out generated` comme les autres
  générateurs ; `nom` et `herite` lus dans `tokens.toml` `[icons]`) ; `generer` vide `sortie/DuneI` avant d'écrire.
  Cible `icones: ; $(PY) generate_icones.py --out generated`, ajoutée aux dépendances de `generes` et `install`.
- [x] **Étape 4 : lancer** `make icones && make check` ; attendu : tout passe, `generated/icons/DuneI` suivi par git.
- [x] **Étape 5 : valider** et commit (le crochet pre-commit accepte `generated/` régénéré).

### Tâche 3 : déploiement et déclaration à GTK

**Fichiers :**
- Modifier : `deploy.py` (fonction `data_home`, destination `icones`, action `gsettings`, constantes)
- Test : `tests/test_deploy.py`

**Interfaces :**
- Consomme : `generated/icons/DuneI/` (tâche 2), `tokens.toml` `[icons].xdg_theme`.
- Produit : `data_home(env) -> Path` ($XDG_DATA_HOME, sinon `~/.local/share`), sur le modèle de `config_home` ;
  `plan_icones(repo: Path, home: Path) -> tuple[list[tuple], list[str]]`, inscrite dans `DESTINATIONS` après
  `coque` ; action `("gsettings", schéma, clé, valeur)`, décrite « régler {0} {1} à {2} » et exécutée par
  `gsettings set`.
- Actions de `plan_icones`, dans l'ordre :
  1. `mkdir` de `data_home/icons` s'il manque, puis `link` de `repo/generated/icons/DuneI` vers
     `data_home/icons/DuneI` (même garde que `plan_coque` : lien étranger ou dossier réel → erreur) ;
  2. `ecrire` de `home/gtk-3.0/settings.ini` et `home/gtk-4.0/settings.ini`, contenu
     `[Settings]\ngtk-icon-theme-name=DuneI\n` précédé de la marque DuneI (`MARK`), seulement s'il manque ou diffère ;
     fichier présent sans la marque → erreur, jamais d'écrasement ;
  3. `gsettings` sur `org.gnome.desktop.interface icon-theme DuneI` si `gsettings get` rend une autre valeur ;
     rien si `gsettings` est absent (signalement dans `NOTES`).

- [x] **Étape 1 : écrire les tests qui échouent** dans `tests/test_deploy.py`, sur une maison temporaire :
  - `test_icones_premier_passage` : actions `mkdir`, `link`, deux `ecrire`, `gsettings` (gsettings simulé, valeur
    `'Adwaita'`) ;
  - `test_icones_idempotent` : après application, plan vide ;
  - `test_icones_xdg_data_home` : avec `XDG_DATA_HOME` défini, le lien va dessous ;
  - `test_icones_settings_etranger` : un `settings.ini` sans la marque donne une erreur qui le nomme, et aucune
    action `ecrire` sur lui ;
  - `test_icones_lien_etranger` : un dossier réel à `data_home/icons/DuneI` donne une erreur.
- [x] **Étape 2 : lancer** `python3 -m unittest tests.test_deploy -v` ; attendu : échec sur ces seuls tests.
- [x] **Étape 3 : écrire** `data_home`, `plan_icones` et l'action `gsettings` (description et exécution).
- [x] **Étape 4 : lancer** `make check` ; attendu : tout passe.
- [x] **Étape 5 : valider** et commit.

### Tâche 4 : la coque lit DuneI

**Fichiers :**
- Modifier : première ligne de `coque/shell.qml`, `coque/Barre/essai/shell.qml`, `coque/Composants/essai/shell.qml`,
  `coque/outils/planche/shell.qml`, `coque/outils/verre/shell.qml` (`//@ pragma IconTheme DuneI`) et leurs
  commentaires qui nomment Adwaita ; commentaire de `coque/Composants/Icone.qml:25` ;
  `coque/outils/planche/README.md:133`
- Test : `tests/test_barre.py`, `tests/test_coque_composants.py`

**Interfaces :**
- Consomme : `generated/icons/DuneI/symbolic/` (tâche 2), `phosphor.charger` (tâche 1).

- [x] **Étape 1 : adapter les tests**, qui doivent échouer :
  - `test_barre.py` : `test_icones_existent` et `test_icones_fixes_existent` cherchent `<nom>-symbolic.svg` et
    `<nom>-fill-symbolic.svg` dans `generated/icons/DuneI/symbolic/`, sans saut conditionnel ; nouveau
    `test_icones_js_couvertes` : tout littéral `"[a-z0-9-]+"` rendu par les fonctions d'icône de
    `coque/Barre/icones.js`, plus `emblem-system`, `network-vpn`, `system-search`, `edit-clear`, figure dans la table
    (les paliers construits par concaténation sont développés dans le test, comme `ICONES` le fait déjà) ;
    `test_coque_et_unite` attend `//@ pragma IconTheme ` suivi de `xdg_theme` lu dans `tokens.toml`.
  - `test_coque_composants.py` : `test_recherche` garde son assertion (les icônes se chargent), commentaire mis à
    DuneI ; les tests de l'étoile (`ETOILE`, ligne 216) restent sur Adwaita : ils éprouvent l'héritage, puisque
    `starred` n'est pas dans DuneI ; leur commentaire le dit.
- [x] **Étape 2 : lancer** `make test` ; attendu : échec du test de directive.
- [x] **Étape 3 : changer les cinq directives** et les commentaires.
- [x] **Étape 4 : lancer** `make check`, puis `make install` et `systemctl --user restart dunei-coque.service` ;
  attendu : tests verts, `journalctl --user -u dunei-coque -n 50` sans avertissement d'icône introuvable.
- [x] **Étape 5 : valider** et commit.

### Tâche 5 : recette à l'écran avec Nicolas

Aucun code ; ce qui est constaté va dans le carnet.

- [x] **Étape 1 : mesure** `coque/outils/mesure.sh` avant (sur `main`) et après ; relever PSS et processeur.
- [x] **Étape 2 : barre au jour et à la nuit**, capturée avec grim à l'échelle réelle (région de la barre), en
  `regular` ; puis, pour comparer, `graisse = "light"` et `"bold"` dans la table, `make phosphor icones install`,
  redémarrage de la coque, capture ; trois captures côte à côte montrées à Nicolas. Il choisit ; la table garde son
  choix, `make phosphor icones` remet le dépôt à cette seule graisse.
- [x] **Étape 3 : GTK** : sélecteur de fichiers de Firefox (Ctrl+O), capturé ; loupe et effacement viennent de DuneI,
  dossiers d'Adwaita, aucun carré vide.
- [x] **Étape 4 : retour arrière** : `gsettings set org.gnome.desktop.interface icon-theme Adwaita`, constater dans
  Firefox, puis `make install` remet DuneI.
- [x] **Étape 5 : validation** de Nicolas à l'écran, notée telle quelle.

### Tâche 6 : documentation

**Fichiers :** `docs/journal-decisions.md` (D101), backlog, bible (chapitre 9), carnet, notes de direction ; table
« Historique des versions » et numéro de version de chacun.

- [x] **Étape 1 : D101** : première tranche Phosphor avancée avant L2-11 ; MacTahoe écarté ; SVG versionnés et
  `make phosphor` hors ligne de l'installation ; correspondances partagées (batterie, Wi-Fi, `wifi-x`) ; graisse
  retenue à l'écran ; Qt reporté ; coût si faux.
- [x] **Étape 2 : backlog** : L4-12 « en cours (D101) », première tranche décrite ; nouvelle ligne pour le thème de
  plateforme Qt de toute la session (`QT_QPA_PLATFORMTHEME`, polices, couleurs, dialogues ; Dolphin), au numéro
  libre suivant du lot 2 ; décompte d'éléments mis à jour.
- [x] **Étape 3 : bible, chapitre 9** : trait de Phosphor non calé au pixel sous 24 px, si Nicolas l'a accepté ;
  emplacement de la table et des sources.
- [x] **Étape 4 : carnet** : section de la feature, mesures, captures, recette ; **notes de direction** : paragraphe
  du jour, dernier paragraphe « Prochaine étape : L2-11 », en rappelant ce que Nicolas a dit de `nmtui`, du partage
  de connexion et des notifications.
- [ ] **Étape 5 : valider**, pousser la branche, ouvrir la PR.
