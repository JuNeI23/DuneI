# Les tokens branchés sur Quickshell — plan d'implémentation

> **Pour les agents :** sous-compétence requise : superpowers:subagent-driven-development (recommandée) ou
> superpowers:executing-plans, tâche par tâche. Les étapes se cochent (`- [ ]`).

**But :** une cible du générateur prépare toutes les valeurs de design pour la coque, un singleton QML
`Theme` les expose et se met à jour d'un bloc quand le fichier change, et une planche de contrôle le prouve
à l'écran.

**Architecture :** `dunei_theme/emitters/quickshell.py` produit `generated/coque-tokens.json`, toutes couleurs
en sRGB et toutes combinaisons d'états précalculées. `deploy.py` copie ce fichier et `motion.json` sous
`$XDG_CONFIG_HOME/dunei/`. `coque/Theme/` est un module QML (singleton `Theme`, `ColorSpring`, `physics.js`)
qui lit ces deux fichiers par `FileView` surveillé. `coque/outils/planche/` affiche chaque token.

**Pile :** Python 3 (unittest), Quickshell 0.3.2 (QML, Qt 6), bash.

**Conception :** `docs/superpowers/specs/2026-10-22-tokens-quickshell-design.md` (v0.2, validée). Le plan
s'appuie sur elle ; la lire d'abord.

## Contraintes globales

- `generated/` et `tests/golden/` ne s'écrivent que par les générateurs (`make tokens`, `make golden`), jamais
  à la main (D77). Toute tâche qui change une sortie relance `make tokens` puis `make golden` et valide les
  fichiers régénérés.
- Conversion de couleur : uniquement `dunei_theme/color.py` (`oklch`, `to_hex`). Le QML n'a droit qu'à
  l'interpolation entre deux couleurs générées.
- Aucune valeur de design dans un fichier QML de `coque/` : ni couleur, ni taille, ni durée, ni valeur de repli.
- Chaque fonction (Python, QML, bash) est commentée : titre et rôle, entrées, sorties, erreurs, dépendances.
  Commentaires en phrases complètes, en français accentué.
- Code minimal ; agnostique de la machine (aucun chemin propre à `caladan`).
- `make check` passe à la fin de chaque tâche ; un commit par tâche, terminé par
  `Co-Authored-By: <modèle de l'auteur> <noreply@anthropic.com>`.
- Documentation Quickshell via context7, bibliothèque `/websites/quickshell_master`, pour `FileView`,
  `FloatingWindow` et les imports.
- Sobriété (D80) : la planche se lance à la demande ; relevé processeur au repos et mémoire avant fusion.

## Points d'attention de la relecture

1. **Fichier remplacé par renommage** (copie atomique de `deploy.py`) pendant que `Theme` surveille : il doit
   recharger, et continuer à surveiller après. Testé en tâche 4.
2. **Fichier lu à moitié écrit ou corrompu** (le générateur écrit en place par `write_text`) : `Theme` garde
   les valeurs précédentes et l'avertit dans le journal ; la lecture suivante réussie s'applique. Tâche 4.
3. **Fichier absent au démarrage** ou variable `DUNEI_TOKENS_DIR` vers un dossier inexistant : erreur lisible,
   aucun plantage, `Theme.ready` faux. Tâche 4.
4. **Changement d'état interrompu en vol** (survol quitté avant la fin du ressort) : la couleur repart de la
   couleur affichée, sans saut. Tâche 5, à l'écran.
5. **Couleur d'état hors gamut** (survol d'un accent à forte chroma, teinte 265) : sortie hexadécimale valide,
   rabattue par `color.py`. Tâche 2, sur les quatre teintes de référence.

---

### Tâche 1 : cible `coque-tokens.json`, valeurs hors états

**Fichiers :**
- Créer : `dunei_theme/emitters/quickshell.py`
- Modifier : `dunei_theme/emitters/__init__.py` (inscrire la cible)
- Test : `tests/test_quickshell_emitter.py`
- Régénérés : `generated/coque-tokens.json`, `tests/golden/hue-*/coque-tokens.json`

**Interfaces :**
- Consomme : `model.resolve(data, hue)` (modèle avec `raw`), `color.to_hex(Oklch) -> "#rrggbb"`,
  `color.oklch(l, c, h, ceiling)`, `color.Oklch`.
- Produit : `emit(model: dict) -> str` ; `_camel(name: str) -> str` (`"surface-raised"` et
  `"panel_padding"` → `"surfaceRaised"`, `"panelPadding"`) ; `_argb(col: Oklch, alpha: float) -> str`
  (`"#AArrggbb"`, alpha arrondi sur 0–255, deux chiffres hexadécimaux en minuscules). Schéma du fichier,
  clés de premier niveau, dans cet ordre :
  - `_generated` : `"GÉNÉRÉ depuis tokens.toml — NE PAS MODIFIER À LA MAIN"` (deuxième ligne du fichier :
    `deploy._ours` s'y fie) ;
  - `hue` ;
  - `color` : les douze rôles en camelCase, `accent`, `accentStandalone`, `onAccent`, `error`, `warning`,
    `success`, `info`, `categorical` (liste) ;
  - `states` : réservé à la tâche 2 ;
  - `focus` : réservé à la tâche 2 ;
  - `disabled` : `{opacity, shadow}` de `[states.disabled]` ;
  - `elevation` : `e0`…`e3` → `{fill, sheen, sheenTop, edgeLight, shadow}`, où `sheenTop` vaut
    `to_hex(oklch(fill.l + sheen_delta, fill.c, fill.h, ceiling))` si `sheen`, sinon `null` ; `field` →
    `{fill, insetShadow}` ;
  - `material` : `{dither, sheenMaxHeight, edgeLight, edgeShadow, shade, overlayOutline}` ; `edgeLight` est
    le blanc (`Oklch(1, 0, 0)`) à `edge_light_opacity`, les trois autres sont `shadow_color` à leur opacité,
    tous par `_argb` ;
  - `render` : `{scrim, neverAnimateBlurRadius}`, `scrim` = `shadow_color` à `scrim_opacity` ;
  - `space`, `density` (`comfortable` et `compact`), `radius`, `window` (avec `floatingShadow`), `layout`,
    `breakpoints` : les sections de `tokens.toml` du même nom (`spacing`, `radii` renommées), clés en
    camelCase, valeurs inchangées ;
  - `typo` : `[type]` sans `fallback_chain`, clés en camelCase (`interface` = `"Source Sans 3"`, nom que
    fontconfig résout) ;
  - `icons` : `{source, variants, grid, stroke, sizes, xdgTheme}`.

- [ ] **Étape 1 : écrire les tests qui échouent** dans `tests/test_quickshell_emitter.py`, sur
  `json.loads(emit(resolve(load(ROOT/"tokens.toml"), 55.0)))` :
  - `test_ligne_de_marque` : `emit(...).splitlines()[1]` contient `"GÉNÉRÉ depuis tokens.toml"` ;
  - `test_cles_premier_niveau` : la liste des clés égale exactement celle du schéma ci-dessus, `states` et
    `focus` exclus jusqu'à la tâche 2 ;
  - `test_roles_en_srgb` : `out["color"]["surfaceRaised"] == to_hex(model["roles"]["surface-raised"])`, et
    de même pour `accent`, `onAccent`, `info` ;
  - `test_materiau_argb` : `out["material"]["edgeLight"] == "#14ffffff"` (0,08 × 255 = 20,4 → 0x14) et
    `out["render"]["scrim"]` commence par `"#8c"` (0,55 × 255 = 140,25 → 0x8c) ;
  - `test_elevation` : `out["elevation"]["e1"]["sheenTop"] is None`, `out["elevation"]["e2"]["sheenTop"]`
    égale `to_hex` de e2 relevé de 0,020 ;
  - `test_tailles_inchangees` : `out["space"]["panelPadding"] == 12`, `out["radius"]["control"] == 6`,
    `out["density"]["compact"]["controlHeight"] == 24`, `out["typo"]["weightMedium"] == 550` ;
  - `test_couleurs_valides` : pour chaque teinte de `GOLDEN_HUES` (0, 55, 200, 265), toute chaîne du fichier
    qui commence par `#` correspond à `^#([0-9a-f]{2})?[0-9a-f]{6}$`.
- [ ] **Étape 2 :** `python3 -m unittest tests.test_quickshell_emitter -v` → échec à l'import de
  `dunei_theme.emitters.quickshell`.
- [ ] **Étape 3 :** écrire `quickshell.py` selon les interfaces ; inscrire
  `"coque-tokens.json": quickshell.emit,  # coque Quickshell (L2-34)` dans `TARGETS`. Sérialisation :
  `json.dumps(..., indent=2, ensure_ascii=False) + "\n"`, comme `json_.py`.
- [ ] **Étape 4 :** les tests passent ; `make tokens && make golden` ; `make check` passe.
- [ ] **Étape 5 :** commit « Cible coque-tokens.json : couleurs sRGB, matière et tailles pour Quickshell (L2-34) ».

### Tâche 2 : combinaisons d'états et anneau de focus

**Fichiers :**
- Modifier : `dunei_theme/emitters/quickshell.py`
- Test : `tests/test_quickshell_emitter.py`
- Régénérés : `generated/coque-tokens.json`, `tests/golden/hue-*/coque-tokens.json`

**Interfaces :**
- Consomme : la tâche 1.
- Produit : `_states(model: dict) -> dict` et `_focus(model: dict) -> dict`, branchés sous `states` et
  `focus`. Forme : `states[rôle][sélection][interaction] = {"fill": "#rrggbb", "text": "#rrggbb"}` avec
  rôle ∈ `surfaceWindow`, `surfacePanel`, `surfaceRaised` ; sélection ∈ `none`, `active`, `inactive`,
  `activeMuted` ; interaction ∈ `rest`, `hover`, `pressed`, `disabled` (48 entrées par teinte).
  `focus = {color, colorMuted, width, offset, rowOffset}` (`width` 2, `offset` 2, `rowOffset` −1).

Règles (bible ch. 7, ordre base → sélection → survol → pression → désactivé ; `ceiling` =
`raw["theme"]["chroma_ceiling"]` ; toute couleur transformée passe par `oklch(..., ceiling)` puis `to_hex`) :
- fond de base : `none` → le rôle ; `active` → `accent` ; `inactive` → `ramp[selected_inactive.lightness_step]` ;
  `activeMuted` → `accent` de chroma × `container_inactive.accent_chroma_multiplier` (0) ;
- texte de base : `onAccent` pour `active` et `activeMuted`, `text-primary` sinon ;
- `hover` : L du fond + `hover.lightness_delta` (0,04) ; `pressed` : L du fond + `pressed.lightness_delta`
  (−0,03) ; texte inchangé ;
- `disabled` : fond → L rapprochée de celle du rôle de `lightness_toward_background` (0,55), chroma ×
  `chroma_multiplier` (0,15) ; texte → même transformation, rapproché du fond désactivé ;
- `focus.color` = `accent_standalone` (anneau accent lisible sur fond sombre, comme l'`accent_color` de
  libadwaita) ; `colorMuted` = la même de chroma 0 (conteneur inactif). *Choix de Claude, consigné en D81.*

- [ ] **Étape 1 : tests qui échouent** :
  - `test_states_complet` : 3 rôles × 4 sélections × 4 interactions présents, chacun avec `fill` et `text` ;
  - `test_states_valeurs` (teinte 55, rôle `surfacePanel`, attendus calculés dans le test avec `oklch` et
    `to_hex`) : `none.rest.fill` = rôle ; `none.hover.fill` = L + 0,04 ; `active.rest` = (`accent`,
    `on_accent`) ; `active.pressed.fill` = L de l'accent − 0,03 ; `activeMuted.rest.fill` = accent de
    chroma 0 ; `inactive.rest` = (`ramp[4]`, `text-primary`) ; `none.disabled.fill` = rôle de chroma × 0,15 ;
    `active.disabled.fill` = L `acc.l + (panel.l − acc.l) × 0,55`, chroma `acc.c × 0,15` ;
  - `test_focus` : `focus == {"color": to_hex(accent_standalone), "colorMuted": ..., "width": 2, "offset": 2, "rowOffset": -1}` ;
  - `test_cles_premier_niveau` mis à jour : `states` et `focus` à leur place.
- [ ] **Étape 2 :** les nouveaux tests échouent (`KeyError: 'states'`).
- [ ] **Étape 3 :** écrire `_states` et `_focus` ; `rowOffset` est une constante de la bible (« passe à −1 sur
  les rangées ») : l'ajouter à `tokens.toml` sous `[states.focus]` comme `ring_offset_row = -1`, avec son
  commentaire, plutôt que de l'écrire dans le générateur.
- [ ] **Étape 4 :** tests verts, dont `test_couleurs_valides` sur les quatre teintes ; `make tokens && make golden` ;
  `make check`.
- [ ] **Étape 5 :** commit « États composés et anneau de focus précalculés pour la coque (L2-34) ».

### Tâche 3 : déploiement sous `~/.config/dunei/`

**Fichiers :**
- Modifier : `deploy.py` (constante, `plan_coque`, inscription dans `DESTINATIONS` après `fontconfig`)
- Modifier : `Makefile` (commentaire de `make install` : ajouter `~/.config/dunei`)
- Test : `tests/test_deploy.py`

**Interfaces :**
- Produit : `COQUE = (("coque-tokens.json", "GÉNÉRÉ depuis tokens.toml"), ("motion.json", "GÉNÉRÉ depuis motion.toml"))` ;
  `plan_coque(repo: Path, home: Path) -> tuple[list[tuple], list[str]]`, sur le modèle de `plan_fontconfig` :
  `mkdir` de `home/"dunei"` s'il manque, `("copy", src, dest)` par fichier ; erreurs (messages, jamais
  d'exception) pour source absente (« lancer make tokens » ou « make motion »), `dunei` qui n'est pas un
  dossier réel, fichier étranger (lien, ou `_ours(dest, marque)` faux).
- Contrat pour la tâche 4 : chemins installés `$XDG_CONFIG_HOME/dunei/coque-tokens.json` et
  `$XDG_CONFIG_HOME/dunei/motion.json`.

- [ ] **Étape 1 : tests qui échouent** (dans le style des tests de `plan_fontconfig`, dossiers temporaires) :
  `test_coque_premier_passage` (mkdir puis deux copies), `test_coque_deja_pose` (deux copies, pas de mkdir),
  `test_coque_source_absente`, `test_coque_fichier_etranger` (un `motion.json` sans marque → erreur),
  `test_coque_dossier_lien` (`dunei` est un lien → erreur).
- [ ] **Étape 2 :** échec (`plan_coque` absent).
- [ ] **Étape 3 :** écrire `plan_coque`, l'inscrire, compléter la docstring du module (liste des destinations).
- [ ] **Étape 4 :** `make check` ; puis `make install` sur `caladan` et `ls ~/.config/dunei/` montre les deux
  fichiers.
- [ ] **Étape 5 :** commit « Déploiement des tokens de la coque sous ~/.config/dunei (L2-34) ».

### Tâche 4 : module `coque/Theme`

**Fichiers :**
- Créer : `coque/Theme/qmldir`, `coque/Theme/Theme.qml`, `coque/Theme/ColorSpring.qml`
- Déplacer : `proto/motion/physics.js` → `coque/Theme/physics.js` (`git mv`), puis lien
  `proto/motion/physics.js -> ../../coque/Theme/physics.js` ; corriger son en-tête (plus « prototype jetable »).
- Créer : `coque/Theme/essai/shell.qml` (coque d'essai sans fenêtre)
- Test : `tests/test_coque_theme.py`, `tests/test_coque_qml.py`

**Interfaces :**
- Consomme : contrat de la tâche 3 ; schéma des tâches 1 et 2 ; `motion.json` (`transitions.state.in` :
  `mass`, `stiffness`, `dampening`).
- Produit, singleton `Theme` :
  - `dir: string` = `$DUNEI_TOKENS_DIR` s'il est défini et non vide, sinon `$XDG_CONFIG_HOME/dunei`, sinon
    `$HOME/.config/dunei` (lu par `Quickshell.env`) ;
  - `ready: bool` ; `tokens: var` (objet entier) ; raccourcis `color`, `states`, `focus`, `disabled`,
    `elevation`, `material`, `render`, `space`, `radius`, `window`, `layout`, `breakpoints`, `typo`, `icons` ;
    `density` = `tokens.density.comfortable` (la préférence viendra de L2-26) ; `motion: var` ;
  - `stateColors(role: string, selection: string, interaction: string) -> {fill, text}`.
  - Journal : `console.info("Theme : chargé, teinte " + hue)` à chaque lecture appliquée ;
    `console.warn("Theme : <fichier> ignoré, <raison> ; valeurs précédentes gardées")` sur un contenu
    illisible ou sans `_generated`/`color`/`states` ; `console.error` si le fichier manque.
- Produit, `ColorSpring` (Item invisible) : `target: color` en entrée ; `value: color` en sortie ;
  `params: var` = `Theme.motion.transitions.state.in` par défaut. À chaque changement de `target`, l'origine
  devient la couleur affichée et la progression repart de 0 ; un `FrameAnimation` fait avancer la
  progression 0 → 1 avec `Physics.integrate(st, 1, mass, stiffness, dampening, dt)` et s'arrête sur
  `Physics.atRest` ; `value` est l'interpolation composante par composante (r, g, b, a) entre origine et
  cible. Avant le premier chargement, `value` suit `target` sans animation.

Bascule d'un bloc : `tokens` est remplacé par un seul objet après `JSON.parse` réussi ; ne pas utiliser de
`JsonAdapter` champ par champ.

- [ ] **Étape 1 : tests qui échouent.**
  - `tests/test_coque_qml.py::test_aucune_valeur_de_design` : aucun fichier `.qml` de `coque/` (hors
    `essai/`) ne contient `#` suivi de 3 à 8 chiffres hexadécimaux, `oklch`, `Qt.rgba(` ni `Qt.hsla(`.
  - `tests/test_coque_theme.py` (ignoré si `WAYLAND_DISPLAY` est vide ou si `qs` est introuvable, donc ignoré
    sur le contrôle de GitHub) : lance `qs -p coque/Theme/essai` avec `DUNEI_TOKENS_DIR` vers un dossier
    temporaire, sortie dans un fichier journal, puis :
    `test_chargement` (fichiers générés pour la teinte 55 → « chargé, teinte 55 ») ;
    `test_remplacement_par_renommage` (fichier teinte 200 écrit à côté puis `os.replace` → « teinte 200 »,
    puis un second renommage teinte 265 → « teinte 265 », preuve que la surveillance survit) ;
    `test_contenu_corrompu` (écriture de `{"_generated"` → « ignoré », aucune nouvelle ligne « chargé ») ;
    `test_fichier_absent` (dossier vide → ligne d'erreur, le processus tourne toujours).
- [ ] **Étape 2 :** échec (module absent).
- [ ] **Étape 3 :** écrire `qmldir` (`module Theme`, `singleton Theme 1.0 Theme.qml`, `ColorSpring 1.0 ColorSpring.qml`),
  `Theme.qml`, `ColorSpring.qml`, et `essai/shell.qml` (un `ShellRoot` qui ne fait que référencer `Theme`).
  Importer le module par chemin relatif (`import "../"` depuis `essai`) ; si Quickshell le refuse hors de la
  racine de la coque, poser un lien `essai/Theme -> ..` et le consigner dans le carnet. Si la surveillance se
  perd au renommage, la réarmer en réaffectant `path` dans `onFileChanged`.
- [ ] **Étape 4 :** `python3 -m unittest tests.test_coque_qml tests.test_coque_theme -v` sur `caladan` : tout
  passe, sans test ignoré ; `proto/motion/run.sh` et `proto/ilot/run.sh` démarrent toujours (lien vers
  `physics.js`) ; `make check`.
- [ ] **Étape 5 :** commit « Module QML Theme : tokens surveillés, bascule d'un bloc, ressort de couleur (L2-34) ».

### Tâche 5 : planche de contrôle

**Fichiers :**
- Créer : `coque/outils/planche/shell.qml`, `coque/outils/planche/planche.sh`, `coque/outils/planche/README.md`
- Déplacer : `proto/ilot/mesure.sh` → `coque/outils/mesure.sh` si sa logique se généralise par un argument
  (processus visé) ; sinon écrire `coque/outils/mesure.sh` qui ne relève que processeur au repos et PSS d'un
  `qs` donné.

**Interfaces :**
- Consomme : `Theme`, `ColorSpring` (tâche 4).
- Produit : `planche.sh [teinte]` lance la planche (`FloatingWindow`) sur un dossier de brouillon
  `${XDG_RUNTIME_DIR:-/tmp}/dunei-planche`, généré par `generate_tokens.py --out <dossier> --hue <teinte>`
  et `generate_motion.py --out <dossier>` ; `planche.sh teinte <n>` régénère seulement ce dossier, sans
  relancer la fenêtre. `generated/` n'est jamais touché.
- Contenu de la planche (tout tiré de `Theme`) : nuancier des rôles, de l'accent, des sémantiques et des
  catégorielles ; grille d'états `states` (rôles × sélections × interactions) ; quatre élévations avec
  `sheenTop`, arête et ombrage ; échelle d'espacement ; rayons ; échantillons `typo` aux graisses régulière
  et moyenne ; bouton d'essai : survol et pressé par la souris, interrupteurs « sélectionné »,
  « sélection inactive », « désactivé », « conteneur inactif », focus par tabulation, couleurs portées par
  deux `ColorSpring` (fond, texte).

- [ ] **Étape 1 :** écrire la planche et son script ; `planche.sh` puis `planche.sh teinte 200` : la planche
  bascule d'un bloc ; capture grim des deux teintes dans `.superpowers/preview/`.
- [ ] **Étape 2 :** relevé par `coque/outils/mesure.sh` : processeur au repos et PSS de la planche.
- [ ] **Étape 3 : validation à l'écran par Nicolas** (conception § 9, points 2 à 5) : comparaison avec GTK
  et Hyprland, bascule de teinte en direct, fichier corrompu sans effet, bouton d'essai interrompu en vol.
  Ne pas passer à la suite sans son accord.
- [ ] **Étape 4 :** `make check` ; commit « Planche de contrôle des tokens de la coque (L2-34) ».

### Tâche 6 : documentation

**Fichiers :** carnet (nouvelle section « Les tokens de la coque — L2-34 » : schéma du fichier, chemins,
variable `DUNEI_TOKENS_DIR`, lancement de la planche, relevés, choix d'import), backlog (L2-34 faite, version
et historique), journal (D81 : combinaisons d'états générées et interpolation sRGB mesurée à ΔE 0,013, JSON
surveillé plutôt que QML généré, emplacement `~/.config/dunei/`, anneau de focus sur l'accent autonome,
`ring_offset_row`), Notes de direction (état d'avancement ; dernier paragraphe : prochaine étape L2-01),
bible ch. 7 (préciser « anneau 2 px accent autonome » si Nicolas l'a validé à l'écran, version et historique),
conception (statut « implémentée », version 0.3).

- [ ] **Étape 1 :** écrire ces mises à jour, chaque document avec son numéro de version et sa ligne d'historique.
- [ ] **Étape 2 :** `make check` ; commit « Documentation de L2-34 : carnet, backlog, journal D81, direction ».
