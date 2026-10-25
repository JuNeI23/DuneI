# L'élévation — plan d'implémentation

> **Pour les agents :** sous-skill requis : superpowers:subagent-driven-development (recommandé) ou
> superpowers:executing-plans, tâche par tâche. Les étapes se cochent (`- [ ]`).

**But :** dessiner la matière des surfaces de la coque — verre dépoli teinté, reflet tramé, liserés d'un pixel
physique, ombres portées et internes — à partir des tokens.

**Architecture :** les tokens (`tokens.toml`) gagnent une section `[glass]` ; le générateur en tire les réglages
du flou et des règles de calque pour Hyprland, et les opacités du verre pour la coque. Un shader unique,
`materiau.frag`, compilé en `.qsb` dans `generated/`, peint le fond des surfaces E2 et E3 et le creux des champs ;
les ombres portées passent par `RectangularShadow`.

**Technologies :** Python 3 (unittest), TOML, Lua (config Hyprland 0.56), QML sur Quickshell 0.3.2, Qt 6.12
(`ShaderEffect`, `RectangularShadow`), `qsb` de qt6-shadertools.

**Spec :** `docs/superpowers/specs/2026-10-25-elevation-design.md` (v1.1). Le plan s'en déduit ; l'exécutant lit
les deux.

## Contraintes globales

- Toute valeur vient des tokens ; aucune couleur littérale dans un `*.qml` hors `essai/` (`tests/test_coque_qml.py`).
- `generated/` ne s'édite jamais à la main ; il se régénère par `make generes` et se versionne (D77).
- Chaque fonction, chaque composant QML porte l'en-tête de commentaire du projet : titre et rôle, entrées, sorties,
  erreurs, dépendances (voir `coque/Composants/Surface.qml`).
- Commentaires, docs et messages de commit en français correct ; chaque commit finit par la ligne
  `Co-Authored-By` du modèle qui l'a écrit.
- Valeurs de départ : verre E2 0,85, E3 0,88 ; reflet +0,020 L sur moins de 80 px ; liseré clair 8 %, sombre
  12 % ; ombre noire 36 %, portée 16, décalage 4.
- Le seuil `ignore_alpha` passe de 0,5 (spec) à **0,6** : le repérage du code a trouvé `render.scrim` à 0,55, au-
  dessus de 0,5. Le seuil doit dépasser `shade_opacity` (0,36) **et** `scrim` (0,55), et rester sous l'opacité
  minimale du verre (0,85). La spec est corrigée à la tâche 6.
- Hyprland n'a qu'un thème (celui par défaut) : les réglages du flou et des règles de calque sont **sans
  surcharge de moment**. Seules les opacités du verre, lues par la coque, peuvent varier entre jour et nuit.
- `qsb` est appelé par son chemin, `/usr/lib/qt6/bin/qsb` (variable `QSB` du Makefile), car il est hors PATH.
- Travailler dans `~/DuneI`, branche `feat/elevation`.

## Points de vigilance de la relecture

Cas que la spec implique sans qu'une tâche les teste naturellement ; chacun reçoit son test dans la tâche
indiquée.

1. **Facteur d'échelle fractionnaire** (1,25, 1,5) : le liseré reste d'un pixel physique, net. → tâche 3,
   uniforme `dpr` et test de la propriété exposée.
2. **Menu plus haut que 80 px** : verre et liserés, mais pas de reflet. → tâche 3, test `test_reflet_borne`.
3. **Bascule jour/nuit à chaud** (`dunei-theme`) : le matériau suit sans redémarrer la coque (opacité, reflet,
   liserés). → tâche 3, test `test_materiau_suit_le_moment`.
4. **Voile de la fenêtre d'attention et scrim** : jamais floutés. → tâche 1, validation `ignore_alpha` ; tâche 5,
   vérification à l'écran.
5. **Popups des applications** : jamais floutés (pas de `decoration:blur:popups`). → tâche 1,
   `test_blur_popups_global_inactif`.

---

### Tâche 1 : les tokens du verre et la config Hyprland générée

**Fichiers :**
- Modifier : `tokens.toml` (`[surface_material]` :294-303, `[moments.jour.elevation.field]` :553-555, nouvelle
  section `[glass]` après `[surface_material]`)
- Modifier : `dunei_theme/emitters/hyprland.py` (`_validate` :24, `emit` :55, nouvelle `emit_layer_rules`)
- Modifier : `dunei_theme/emitters/quickshell.py` (`_theme` :148, bloc `material` :188-195, nouveau bloc `glass`)
- Modifier : `dunei_theme/emitters/__init__.py` (`TARGETS`)
- Modifier : `config/hypr/modules/regles.lua` (`M.apply` :19-22), `deploy.py:72` (`COPIES`)
- Régénérer : `generated/`, `tests/golden/hue-*` (`make tokens golden`)
- Tests : `tests/test_hyprland.py`, `tests/test_quickshell_emitter.py`, `tests/test_hyprland_modules.py`

**Interfaces :**
- Produit, dans `tokens.toml` :
  ```toml
  [glass]
  namespaces = ["dunei-barre", "dunei-attention"]   # calques de la coque floutés
  xray = ["dunei-barre"]          # jamais un calque qui porte de l'E3
  ignore_alpha = 0.6              # > shade_opacity et scrim, < opacité minimale du verre
  blur_size = 8
  blur_passes = 2
  e2_opacity = 0.85
  e3_opacity = 0.88
  ```
  et `inset_shadow_opacity = 0.22` dans `[surface_material]` ; `inset_shadow = true` dans
  `[moments.jour.elevation.field]`.
- Produit, dans `coque-tokens.json`, pour chaque `themes.<f>.<m>` : `glass = {e2: 0.85, e3: 0.88}` et
  `material.insetShadow` (couleur `#AArrggbb`, via `_argb`).
- Produit `emit_layer_rules(model) -> str` : un fichier Lua `generated/hyprland-layers.lua` qui retourne une liste
  de tables `{ name = "dunei-verre-<ns>", match = { namespace = "^<ns>$" }, blur = true, blur_popups = true,
  ignore_alpha = 0.6, xray = <bool> }`, une par namespace.
- Produit, dans `hyprland-tokens.lua`, `decoration.blur = { enabled = true, size = 8, passes = 2,
  popups = false, new_optimizations = true }`.
- Produit, dans `regles.lua`, une seconde boucle :
  `for _, r in ipairs(require("generated.hyprland-layers")) do hl.layer_rule(r) end`.

- [ ] **Étape 1 : écrire les tests qui échouent**

  Dans `tests/test_hyprland.py`, nouvelle classe `LayerRulesTest` :
  - `test_une_regle_par_namespace` : la liste chargée par `lua -e dofile` (sur le modèle de
    `test_rules_load_as_list` :171) a deux entrées, de namespaces `^dunei-barre$` et `^dunei-attention$`, toutes
    deux `blur = true`, `blur_popups = true`, `ignore_alpha = 0.6`.
  - `test_xray_sur_la_barre_seule` : `xray` vrai pour `dunei-barre`, faux pour `dunei-attention`.
  - `test_ignore_alpha_borne` : avec `ignore_alpha = 0.5` et `scrim` 0,55, `emit_layer_rules` lève
    `ValueError` dont le message contient `ignore_alpha` ; avec `ignore_alpha = 0.9` (> 0,85), idem.
  - `test_xray_hors_namespaces` : un `xray` qui nomme un namespace absent de `namespaces` lève `ValueError`.

  Dans `HyprlandTest` : `test_blur_popups_global_inactif` — `decoration.blur.popups` vaut `false` et
  `decoration.blur.enabled` vaut `true`.

  Dans `tests/test_quickshell_emitter.py` : `test_verre` — pour les quatre thèmes, `glass.e2 == 0.85`,
  `glass.e3 == 0.88` ; `test_creux_du_champ` — `elevation.field.insetShadow` vaut `true` au jour **et** à la nuit,
  et `material.insetShadow` est le noir à 22 % (`#38000000`).

  Dans `tests/test_hyprland_modules.py` : `regles.apply()` appelle `hl.layer_rule` une fois par entrée de
  `hyprland-layers.lua` (même technique de bouchon `hl` que les tests existants du module).

- [ ] **Étape 2 : lancer les tests, constater l'échec**

  `make tokens && python -m unittest tests.test_hyprland tests.test_quickshell_emitter tests.test_hyprland_modules`
  → échecs sur `LayerRulesTest`, `test_verre`, `test_creux_du_champ`.

- [ ] **Étape 3 : implémenter**

  - Tokens comme ci-dessus.
  - `hyprland._validate_glass(raw) -> None` (appelée par `emit_layer_rules`) : `ValueError` si
    `ignore_alpha <= max(shade_opacity, scrim)` ou `>= min(e2_opacity, e3_opacity)`, ou si un `xray` sort de
    `namespaces` ; messages au format existant, par exemple
    `f"glass.ignore_alpha = {v} : doit dépasser {plancher} (ombre, voile) et rester sous {plafond} (verre)"`.
  - `emit` ajoute `blur` dans la table `decoration`.
  - `TARGETS["hyprland-layers.lua"] = hyprland.emit_layer_rules`, et `"hyprland-layers.lua"` ajouté à
    `deploy.COPIES`.
  - `quickshell._theme` ajoute `glass` et `material.insetShadow`.

- [ ] **Étape 4 : régénérer et relancer**

  `make tokens golden && make test` → tout passe ; `git status` montre `generated/` et `tests/golden/` modifiés,
  dont le nouveau `hyprland-layers.lua`.

- [ ] **Étape 5 : vérifier sur la machine**

  `make install`, puis `hyprctl reload` et `hyprctl getoption decoration:blur:popups` → `int: 0`. Aucune erreur
  dans `hyprctl configerrors`.

- [ ] **Étape 6 : commit** — « Verre : tokens, flou et règles de calque générés (L2-04) ».

---

### Tâche 2 : le shader matériau et sa chaîne

**Fichiers :**
- Créer : `coque/Theme/materiau.frag`
- Modifier : `Makefile` (variable `QSB`, cible `shaders`, `generes` et `golden` inchangés hors dépendance),
  `.githooks/pre-commit:18`, `.github/workflows/controle.yml:20`, `deploy.py:78` (`COQUE`),
  `coque/outils/planche/planche.sh`, `tests/test_coque_theme.py` (harnais `EssaiCoque`)
- Modifier : `coque/Theme/Theme.qml` (nouvelle fonction `fichier`)
- Régénérer : `generated/materiau.frag.qsb`
- Tests : `tests/test_crochet.py`, `tests/test_shader.py` (nouveau)

**Interfaces :**
- Produit le shader, uniformes (bloc `qt_*` standard de `ShaderEffect`, puis) :
  `vec4 fond` (couleur de l'échelon, alpha = opacité du verre ou 1), `vec4 refletHaut` (couleur du haut du
  reflet), `float reflet` (0 ou 1), `vec4 liseréClair`, `vec4 liseréSombre`, `float rayon` (px logiques),
  `vec2 taille` (px logiques), `float dpr`, `float creux` (0 surface, 1 champ), `vec4 ombreInterne`,
  `float profondeur` (px logiques de l'ombre interne).
- Algorithme (non déduit des tests, donc fixé ici) :
  - coordonnées physiques `p = qt_TexCoord0 * taille * dpr` ; distance signée au rectangle arrondi
    (`rayon * dpr`) ; couverture = `clamp(0.5 - d, 0, 1)` pour un bord antialiasé d'un pixel ;
  - reflet : `mix(refletHaut, fond, p.y / (taille.y * dpr))` si `reflet`, sinon `fond` ; mélange en sRGB entre
    deux bouts déjà calculés en OKLCH par le générateur (`sheenTop`), l'écart de 0,020 L rendant la différence
    avec une interpolation OKLCH imperceptible ;
  - bruit IGN : `fract(52.9829189 * fract(dot(gl_FragCoord.xy, vec2(0.06711056, 0.00583715))))`, centré
    (`- 0.5`) et divisé par 255, ajouté à la couleur avant sortie, seulement si `reflet` ;
  - liserés : le pixel physique de la rangée `floor(p.y) == 0` reçoit `liseréClair` en surimpression, la dernière
    rangée `liseréSombre` (couverture du coin appliquée) ;
  - creux : `ombreInterne` dont l'alpha décroît linéairement de 1 à 0 sur `profondeur * dpr` depuis le bord haut
    intérieur, multipliée par la couverture ;
  - sortie prémultipliée par l'alpha (convention Qt Quick) et par `qt_Opacity`.
- Produit `Theme.fichier(nom: string) -> url` : l'URL `file://` de `nom` dans le dossier des tokens
  (`DUNEI_TOKENS_DIR`, sinon `~/.config/dunei`), le même que celui de `coque-tokens.json`. Elle évite
  `Qt.resolvedUrl`, que les liens symboliques de la planche et des essais fausseraient.
- Produit la cible `make shaders` : `$(QSB) --qt6 -o generated/materiau.frag.qsb coque/Theme/materiau.frag` ;
  `generes: tokens motion energie shaders`.

- [ ] **Étape 1 : vérifier que `qsb` est déterministe**

  Compiler deux fois un fragment minimal et comparer : `cmp` doit réussir. **S'il échoue, s'arrêter et le
  signaler** : la décision « `.qsb` versionné » (spec § 5.2) serait à revoir avec Nicolas.

- [ ] **Étape 2 : écrire les tests qui échouent**

  `tests/test_shader.py`, classe `ShaderTest`, ignorée si `/usr/lib/qt6/bin/qsb` est absent :
  - `test_qsb_a_jour` : compilé dans un dossier temporaire, le `.qsb` est identique octet pour octet à
    `generated/materiau.frag.qsb` ;
  - `test_uniformes` : `qsb --dump generated/materiau.frag.qsb` liste chacun des uniformes ci-dessus.

  `tests/test_crochet.py` : le crochet appelle `make … shaders` (adapter `test_make_generes` :112 à la nouvelle
  liste de cibles).

- [ ] **Étape 3 : lancer, constater l'échec** — `python -m unittest tests.test_shader tests.test_crochet`.

- [ ] **Étape 4 : implémenter** le shader, la cible `shaders`, le crochet (`make -s -C "$t" tokens motion energie
  shaders`), `qt6-shadertools` dans le pacman de `controle.yml` (sur le modèle du commit d50156e), la copie du
  `.qsb` dans `deploy.COQUE`, dans `planche.sh` et dans le dossier temporaire d'`EssaiCoque`, et
  `Theme.fichier`.

- [ ] **Étape 5 : lancer** — `make check` → vert, `generated/materiau.frag.qsb` suivi par git.

- [ ] **Étape 6 : commit** — « Matériau : shader du reflet tramé, des liserés et du creux, compilé par qsb
  (L2-04, L2-05) ».

---

### Tâche 3 : `Materiau.qml`, `Surface` et le champ creusé

**Fichiers :**
- Créer : `coque/Composants/Materiau.qml` ; l'ajouter à `coque/Composants/qmldir`
- Modifier : `coque/Composants/Surface.qml`, `coque/Composants/Champ.qml:53-58`,
  `coque/Composants/Overlay.qml` (`Cadre` :68-93)
- Modifier : `coque/Composants/essai/shell.qml` (sondes)
- Tests : `tests/test_coque_composants.py`

**Interfaces :**
- Consomme : `Theme.fichier`, `Theme.elevation.<niveau>.{fill, sheen, sheenTop, edgeLight}`,
  `Theme.material.{edgeLight, edgeShadow, sheenMaxHeight, insetShadow}`, `Theme.glass.{e2, e3}`,
  `Theme.elevation.field.{fill, insetShadow}`.
- Produit `Materiau` (`ShaderEffect`) : propriétés `string niveau` (`e2`, `e3` ou `field`), `bool verre`
  (faux par défaut), `real rayon` ; propriétés en lecture `bool refletActif` (`sheen` du niveau **et**
  `height < sheenMaxHeight`), `real opacite` (`Theme.glass[niveau]` si `verre`, sinon 1), `real dpr`
  (`QsWindow.window?.devicePixelRatio ?? 1`). Il remplit les uniformes de la tâche 2.
- `Surface` gagne `property bool verre: false` : pour `e2` et `e3`, son fond devient un `Materiau` ; pour `e0` et
  `e1`, le `Rectangle` actuel reste.
- `Overlay.Cadre` pose `verre: true` sur sa `Surface` (le cadre est la seule surface d'une fenêtre de coque).
- `Champ` remplace le `Rectangle` de son `background` par un `Materiau { niveau: "field" }` quand
  `Theme.elevation.field.insetShadow` est vrai ; la bordure d'un pixel reste.

- [ ] **Étape 1 : écrire les tests qui échouent**, dans `CoqueComposantsTest` (sondes ajoutées à
  `essai/shell.qml`, lues par `self.valeur`) :
  - `test_materiau_sur_e2_e3` : une `Surface` de rôle `surfacePanel` contient un `Materiau` ; une de rôle
    `surfaceWindow`, non.
  - `test_verre_opacite` : `Surface { verre: true; role: "surfaceRaised" }` → `opacite == 0.88` ; sans `verre`
    → `1`.
  - `test_reflet_borne` : hauteur 32 → `refletActif` vrai la nuit ; hauteur 120 → faux.
  - `test_materiau_suit_le_moment` : après bascule du thème au jour (mécanisme des tests de L2-40 dans
    `test_coque_theme.py`), `refletActif` est faux et `opacite` reste celle de `glass` du jour.
  - `test_dpr_transmis` : avec `QT_SCALE_FACTOR=1.5`, `dpr == 1.5`.
  - `test_champ_creux` : le `background` d'un `Champ` est un `Materiau` de niveau `field`, la nuit et le jour.

- [ ] **Étape 2 : lancer, constater l'échec** — `python -m unittest tests.test_coque_composants` (local : exige
  Wayland et `qs`).

- [ ] **Étape 3 : implémenter** `Materiau.qml`, puis `Surface`, `Cadre`, `Champ`.

- [ ] **Étape 4 : lancer** — `make test` → vert ; `tests/test_coque_qml.py` passe (aucune couleur littérale).

- [ ] **Étape 5 : vérifier dans la planche** — `coque/outils/planche/planche.sh`, nuit puis jour, capture par
  grim de la fenêtre visée par son adresse : reflet sans bande, liseré net, champ creusé.

- [ ] **Étape 6 : commit** — « Matériau dans Surface, le cadre des overlays et le champ (L2-04) ».

---

### Tâche 4 : l'ombre d'élévation et la marge des overlays

**Fichiers :**
- Créer : `coque/Composants/OmbreElevation.qml` ; l'ajouter à `qmldir`
- Modifier : `coque/Composants/Overlay.qml` (`Cadre`, `fenetreContextuel` :144-178)
- Tests : `tests/test_coque_composants.py`

**Interfaces :**
- Consomme : `Theme.elevation.<niveau>.shadow`, `Theme.material.shade`, et la portée et le décalage de l'ombre
  flottante (`window.floating_shadow` de `tokens.toml`, à exposer dans `material` sous `shadowBlur` et
  `shadowOffsetY` si ce n'est pas déjà fait — ajouter alors le test correspondant à
  `tests/test_quickshell_emitter.py`).
- Produit `OmbreElevation` (`RectangularShadow`) : `required property Item cible`, `property string niveau`,
  visible si `Theme.elevation[niveau].shadow`, `readonly property real marge` (portée + décalage, 0 si
  invisible). `OmbreControle` reste tel quel pour les contrôles.
- `Cadre` porte une `OmbreElevation { niveau: "e3" }` et décale son contenu de `marge` ; `fenetreContextuel`
  agrandit son `implicitWidth` et son `implicitHeight` de `2 * marge`, et pose un `mask: Region { item: cadre }`
  pour que la marge laisse passer les clics.

- [ ] **Étape 1 : tests qui échouent** :
  - `test_ombre_e3_seulement_la_nuit` : la nuit, `OmbreElevation { niveau: "e2" }` invisible, `e3` visible ; le
    jour, les deux visibles.
  - `test_marge_du_contextuel` : la fenêtre du contextuel est plus grande que son cadre de `2 * marge` dans chaque
    dimension.
- [ ] **Étape 2 : lancer, constater l'échec.**
- [ ] **Étape 3 : implémenter.**
- [ ] **Étape 4 : lancer** — `make test` → vert.
- [ ] **Étape 5 : commit** — « Ombre d'élévation et marge d'ombre des overlays (L2-04) ».

---

### Tâche 5 : namespaces et banc d'essai du verre

**Fichiers :**
- Modifier : `coque/Composants/FenetreAttention.qml` (`WlrLayershell.namespace: "dunei-attention"`)
- Créer : `coque/outils/verre/shell.qml`, `coque/outils/verre/verre.sh`, `coque/outils/verre/README.md`, liens
  `Composants -> ../../Composants` et `Theme -> ../../Theme` (modèle : `coque/outils/planche/`)
- Tests : `tests/test_coque_composants.py`, `tests/test_outils.py` (nouveau, ou le test existant des outils s'il
  y en a un)

**Interfaces :**
- Le banc est un `ShellRoot` qui ouvre un `PanelWindow` ancré en haut, haut de 32 px, zone exclusive 32,
  `WlrLayershell.namespace: "dunei-barre"`, peint par une `Surface { role: "surfacePanel"; verre: true }`. Il
  porte trois boutons qui ouvrent, par `Overlays`, un menu (contextuel), un popover et une infobulle.
- `verre.sh` suit `planche.sh` : génère les tokens et le `.qsb` dans `${DUNEI_VERRE_DIR:-$XDG_RUNTIME_DIR/dunei-
  verre}`, accepte `theme <famille> <moment>`, lance `qs -n -p coque/outils/verre`.
- Le namespace de la barre est **celui de la future barre** (L2-08) : le banc et la barre ne tournent pas en même
  temps.

- [ ] **Étape 1 : tests qui échouent** :
  - `test_namespace_attention` : la fenêtre d'attention porte `dunei-attention` (sonde dans `essai/shell.qml`).
  - `test_namespaces_declares` : chaque `WlrLayershell.namespace` écrit dans `coque/**/*.qml` figure dans
    `[glass].namespaces` de `tokens.toml` (test statique, tourne aussi dans le conteneur).
- [ ] **Étape 2 : lancer, constater l'échec.**
- [ ] **Étape 3 : implémenter** le namespace et le banc.
- [ ] **Étape 4 : vérifier à l'exécution** — lancer `coque/outils/verre/verre.sh`, puis `hyprctl layers` montre
  `dunei-barre` ; ouvrir le menu et vérifier dans `hyprctl layers` que le popup relève bien de ce calque.
  Ouvrir la fenêtre d'attention (planche) : `hyprctl layers` montre `dunei-attention`. Si le menu n'est pas
  flouté, **s'arrêter et le signaler** avant d'essayer le repli `BackgroundEffect` (spec § 10).
- [ ] **Étape 5 : `make test`** → vert.
- [ ] **Étape 6 : commit** — « Namespaces des calques de coque et banc d'essai du verre (L2-04) ».

---

### Tâche 6 : validation à l'écran et documentation

**Fichiers :**
- Modifier : `docs/project_management/DuneI - Bible de Design.md` (§ 5, tableau des composants l. 822-852),
  `docs/journal-decisions.md`, `docs/project_management/DuneI — Périmètre et backlog de la 1.0.md` (L2-04, L2-05,
  L2-41), `docs/project_management/DuneI — Carnet d'installation, lot 1.md`,
  `docs/project_management/DuneI - Notes de Direction.md`, `docs/superpowers/specs/2026-10-25-elevation-design.md`
  (`ignore_alpha` 0,6, v1.2)

- [ ] **Étape 1 : recette à l'écran avec Nicolas** — spec § 8, points 1 à 6, dans la planche et le banc, les deux
  familles et les deux moments ; captures grim des fenêtres visées par adresse. Régler à l'écran l'opacité du
  verre, l'intensité du flou et la force des ombres ; reporter toute valeur changée dans `tokens.toml`, puis
  `make tokens golden && make test`. Relever la consommation de la coque avant et après (point 6).
- [ ] **Étape 2 : documenter**
  - Bible § 5 : verre dépoli teinté sur les fenêtres de coque (la translucidité tient à la fenêtre, pas au
    niveau), reflet et liserés tracés par shader, règle du champ en mode clair ; version et historique.
  - Journal : D85 (verre dépoli et ses choix techniques), D86 (L2-41 non retenu : pas de texture visible, le
    flou n'est pas du bruit), D87 (le champ clair et creusé en mode clair).
  - Backlog : L2-04, L2-05 faits ; L2-41 fermé, non retenu ; version et historique.
  - Carnet : le shader et sa compilation, les règles de calque, le banc d'essai, la procédure après fusion.
  - Notes de direction : état d'avancement ; dernier paragraphe = prochaine étape.
- [ ] **Étape 3 : `make check`** → vert.
- [ ] **Étape 4 : commit** — « Documentation de l'élévation (L2-04, L2-05, L2-41) », puis push et PR.
