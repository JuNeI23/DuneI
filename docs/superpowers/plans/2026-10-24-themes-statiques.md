# Les thèmes statiques — plan d'implémentation

Version 0.1 · 2026-10-24 · backlog L2-40

> **Pour les agents :** sous-compétence requise : superpowers:subagent-driven-development (recommandée) ou
> superpowers:executing-plans, tâche par tâche. Les étapes se cochent (`- [ ]`).

**But :** quatre thèmes de la coque (familles thématisée et à dominante, moments nuit et jour), précalculés dans
`coque-tokens.json` et choisis à chaud par la commande `dunei-theme`.

**Architecture :** `tokens.toml` garde ses sections actuelles, qui décrivent la nuit thématisée ; les tables
`[moments.<m>]` et `[familles.<f>]` ne portent que des surcharges, fusionnées dans cet ordre (base ← moment ←
famille) par `model.theme_data`. `resolve()` reste la seule résolution des couleurs. L'émetteur Quickshell résout
les quatre thèmes ; `Theme.qml` superpose la branche choisie par `~/.config/dunei/theme.json`.

**Technologies :** Python 3 (tomllib, unittest), QML sur Quickshell 0.3.2, bash et jq.

**Conception :** `docs/superpowers/specs/2026-10-24-themes-statiques-design.md` (v0.2). L'exécutant la lit avant
la première tâche.

## Contraintes globales

- La nuit thématisée garde au bit près ses valeurs : `make golden` ne change aucune cible des applications
  (`tokens.css`, `tokens.json`, `kdeglobals`, `gtk-*.css`, `appearance-portal.conf`, `hyprland-*.lua`,
  `fonts.conf`), à toutes les teintes de référence.
- Aucune couleur dans le QML ni dans `dunei-theme` : tout vient de `coque-tokens.json`.
- Le changement de thème s'applique d'un bloc, sans animation, dans la même image.
- `generated/` ne s'édite jamais à la main : `make tokens`, puis `make golden` pour les références.
- Chaque fonction porte l'en-tête du dépôt : rôle, entrées, sortie, erreurs, dépendances.
- Les commentaires et les messages sont en français correct, accentué.
- Une valeur de départ du jour (§ 5 de la conception) n'est pas un acquis : Nicolas la tranche à l'écran (tâche 7).
- Commits signés `Co-Authored-By` du modèle qui les écrit ; `git commit --no-verify` permis.

## Points de vigilance de la relecture

1. **Fichier du choix absent, vide ou portant un nom inconnu** : la coque reste sur le défaut et l'écrit une seule
   fois au journal (`console.warn`), sans `console.error` ni plantage. Testé à la tâche 5.
2. **`theme.json` remplacé par renommage** (écriture atomique de `dunei-theme`) : `FileView` doit le voir. Testé à
   la tâche 5 en écrivant le fichier comme le fait la commande.
3. **Teinte régénérée pendant un thème de jour** : la coque garde le jour et prend la nouvelle teinte. Testé à la
   tâche 5.
4. **`dunei-theme` avant le premier `make install`** (tokens introuvables) : code 1, message clair, aucun fichier
   écrit. Testé à la tâche 6.
5. **Interrupteur éteint au jour** : avec `control-raised` blanc, la piste éteinte et le `knob` blanc risquent de
   se confondre. Ce n'est pas testable par un contraste (l'ombre sépare les deux) : la tâche 7 le soumet à Nicolas
   à l'écran, et un rôle de piste propre s'ajoute s'il le demande. C'est un écart à la conception (§ 5.4, `knob`
   contre la piste éteinte) : le contrôle Lc ≥ 15 n'y porte que sur `knob` contre l'accent, et la tâche 8 corrige
   la conception en conséquence. Mesure : un blanc pur sur un gris à L 0,925 ne donne que Lc 14.

---

### Tâche 1 : la composition des thèmes dans le modèle, et le `knob`

**Fichiers :**
- Modifier : `dunei_theme/model.py`, `tokens.toml`
- Tester : `tests/test_model.py`

**Interfaces produites :**
- `themes(data: dict) -> list[tuple[str, str]]` : les couples (famille, moment), familles puis moments dans
  l'ordre du TOML.
- `defaut(data: dict) -> tuple[str, str]` : lu dans `[theme.defaut]`.
- `theme_data(data: dict, famille: str, moment: str) -> dict` : copie profonde de `data`, fusionnée récursivement
  avec `data["moments"][moment]` puis `data["familles"][famille]` ; un dictionnaire se fusionne clé à clé, toute
  autre valeur remplace. `KeyError("famille inconnue : <f>")` ou `KeyError("moment inconnu : <m>")`.
- `resolve()` garde sa signature et ajoute `model["knob"]` (Oklch). Clés TOML nouvelles et facultatives, lues par
  `resolve` : `lightness.neutral_profile` (12 facteurs ; absent, le facteur vaut `dark_chroma_boost` sous L 0,45
  et 1 au-dessus), `accent.fill_lightness` et `accent.standalone_lightness` (absentes, l'échelon fait foi),
  `categorical.lightness` (idem), `knob.role` ou `knob.lightness` (cette dernière donne un neutre de chroma 0).

- [ ] **Étape 1 : écrire les tests qui échouent**, dans `tests/test_model.py` :
  - `test_nuit_thematisee_identique` : `resolve(theme_data(data, "thematisee", "nuit"), h)` égale
    `resolve(data, h)` pour h dans (0, 55, 200, 265), sur `ramp`, `roles`, `elevation`, `accent`,
    `accent_standalone`, `on_accent`, `categorical`, `semantic`.
  - `test_themes_et_defaut` : `themes(data) == [("thematisee", "nuit"), ("dominante", "nuit")]` et
    `defaut(data) == ("thematisee", "nuit")` ; la tâche 3 y ajoutera le jour.
  - `test_dominante_neutres` : dans `resolve(theme_data(data, "dominante", "nuit"))`, chaque élément de `ramp` a
    `c == 0`, et `accent` égale celui de la nuit thématisée.
  - `test_fusion_profonde` : `theme_data` sur un dictionnaire fabriqué remplace une feuille sans perdre ses
    voisines (`{"a": {"x": 1, "y": 2}}` fusionné avec `{"a": {"x": 3}}` donne `{"a": {"x": 3, "y": 2}}`) et ne
    modifie pas `data`.
  - `test_theme_inconnu` : `theme_data(data, "verre", "nuit")` lève `KeyError` dont le message contient
    « famille inconnue : verre ».
  - `test_knob_nuit` : `model["knob"]` égale `model["roles"]["text-emphasis"]` dans les deux familles de nuit.

- [ ] **Étape 2 : lancer et voir échouer** : `python3 -m unittest tests.test_model -v` → `ImportError` ou
  `AttributeError` sur `theme_data`.

- [ ] **Étape 3 : implémenter** dans `model.py` les trois fonctions et les lectures facultatives de `resolve`, et
  ajouter à `tokens.toml` :
  ```toml
  [theme.defaut]
  famille = "thematisee"
  moment = "nuit"

  [knob]
  role = "text-emphasis"   # nuit : la couleur qu'ont aujourd'hui le disque et la poignée

  [moments.nuit]           # la base : aucune surcharge

  [familles.thematisee]    # la base : aucune surcharge

  [familles.dominante.theme]
  neutral_chroma = 0.0     # gris strictement neutres ; l'accent garde sa teinte
  ```
  Mettre à jour le commentaire de `[theme]` (« hue et chroma_scale sont les SEULES valeurs surchargeables à
  chaud… ») pour mentionner la famille et le moment, et celui de `[meta] mode`.

- [ ] **Étape 4 : lancer et voir passer** : `python3 -m unittest tests.test_model -v` → OK ; puis `make check` →
  OK, `generated/` inchangé (les cibles lisent le défaut, égal à la base).

- [ ] **Étape 5 : valider** : `git commit -m "Thèmes : composition par famille et moment, rôle knob (L2-40)"`.

### Tâche 2 : les planchers de contraste et l'ordre des rôles

**Fichiers :**
- Modifier : `dunei_theme/checks.py`, `tokens.toml`, `generate_tokens.py`
- Créer : `mesure_planchers.py`, à la racine, à côté de `extract_hue.py`
- Tester : `tests/test_checks.py`, `tests/test_model.py`

**Interfaces :**
- Consomme : `theme_data`, `themes`, `defaut` (tâche 1).
- Produit :
  - `mesures(model: dict) -> dict[str, float]` : pour chaque clé, le plus petit |Lc| sur ses fonds. Clés et
    fonds : chaque rôle `text-*` et `border-*` sur `surface-window`, `surface-panel`, `surface-raised` ;
    `control-raised-text` (`role_text` sur `control-raised`) ; `accent-standalone`, `error`, `warning`,
    `success`, `info` et `categorical` (toutes les catégorielles) sur les trois surfaces ; `knob-accent` (`knob`
    sur `accent`).
  - `planchers(model: dict) -> list[str]` : un avertissement par clé dont la mesure, tronquée au dixième, est sous
    `raw["meta"]["planchers"][clé]`.
  - `ordre(model: dict) -> list[str]` : un avertissement par surface où les Lc ne croissent pas strictement de
    `text-disabled` à `text-primary`, où `text-emphasis` est sous `text-primary`, ou où le plus faible texte ne
    dépasse pas la plus forte bordure.
  - `check()` y ajoute `planchers` et `ordre`.
  - `generate_tokens.py` contrôle chaque thème de `themes(data)` et préfixe ses avertissements de
    `[<famille>/<moment>]` ; les cibles reçoivent `resolve(theme_data(data, *defaut(data)), hue)`.
  - `mesure_planchers.py` : imprime la table `[meta.planchers]` du minimum de `mesures` sur la nuit thématisée
    aux teintes 0, 55, 200 et 265, chaque valeur arrondie à l'entier inférieur. Code 0. Sert une fois, puis à
    chaque révision de la nuit.

- [ ] **Étape 1 : écrire les tests qui échouent** :
  - `tests/test_checks.py` : `test_plancher_franchi` (modèle fabriqué dont `text-secondary` est sous son plancher
    → un avertissement qui nomme `text-secondary`) ; `test_ordre_inverse` (`text-tertiary` plus contrasté que
    `text-secondary` → un avertissement) ; `test_texte_sous_bordure` (plus faible texte égal à la plus forte
    bordure → un avertissement). Les modèles fabriqués de ce fichier gagnent les rôles et clés nécessaires.
  - `tests/test_model.py` : `test_themes_conformes` : pour h dans (0, 55, 200, 265) et chaque couple de
    `themes(data)`, `check(resolve(theme_data(data, f, m), h)) == []`.

- [ ] **Étape 2 : lancer et voir échouer** : `python3 -m unittest tests.test_checks tests.test_model -v` →
  `AttributeError` sur `mesures` ou `planchers`.

- [ ] **Étape 3 : implémenter** `mesures`, `planchers`, `ordre` et le contrôle par thème de `generate_tokens.py`.
  Écrire `mesure_planchers.py`, le lancer, coller sa sortie dans `tokens.toml` sous `[meta.planchers]`, avec un
  commentaire qui dit d'où viennent les valeurs et comment les remesurer.

- [ ] **Étape 4 : lancer et voir passer** : les deux modules de tests → OK ; `make check` → OK, `generated/`
  inchangé ; `python3 generate_tokens.py --out "$(mktemp -d)"` n'imprime aucun avertissement.

- [ ] **Étape 5 : valider** : `git commit -m "Contrôles : planchers de contraste par rôle et ordre des rôles, pour
  chaque thème (L2-40)"`.

### Tâche 3 : le moment de jour

**Fichiers :**
- Modifier : `tokens.toml`
- Tester : `tests/test_model.py`

**Interfaces :**
- Consomme : les clés facultatives de la tâche 1, les contrôles de la tâche 2.
- Produit : `[moments.jour]`, dont la tâche 4 émet le résultat.

- [ ] **Étape 1 : écrire les tests qui échouent**, dans `tests/test_model.py` :
  - `test_themes_et_defaut` passe à la liste complète des quatre couples (voir tâche 1).
  - `test_jour_monte_vers_le_blanc` : au jour, `elevation` e0 < e1 < e2 < e3 en luminosité, `e3.l == 1.0` et
    `e3.c == 0`, dans les deux familles.
  - `test_jour_controle_blanc` : au jour, `roles["control-raised"].l == 1.0`.
  - `test_knob_jour` : au jour, `knob == Oklch(1.0, 0, …)` (chroma 0), dans les deux familles.
  - `test_semantiques_par_moment` : au jour, `semantic[k].h` et `.c` égalent ceux de la nuit, `.l` est plus bas ;
    elles sont identiques dans les deux familles.
  - `test_themes_conformes` (tâche 2) couvre désormais les quatre thèmes.

- [ ] **Étape 2 : lancer et voir échouer** : `python3 -m unittest tests.test_model -v` → échec de
  `test_themes_et_defaut` et des tests du jour.

- [ ] **Étape 3 : écrire `[moments.jour]`** avec les valeurs de départ de la conception (§ 5.2 à 5.4) :
  - `lightness.steps = [0.925, 0.955, 0.975, 1.0, 0.89, 0.85, 0.76, 0.68, 0.60, 0.50, 0.25, 0.18]` ;
  - `lightness.neutral_profile = [0.3, 0.3, 0.3, 0.0, 0.6, 0.6, 1.0, 1.0, 1.0, 1.0, 1.4, 1.4]` (chroma 0,006
    au-dessus de L 0,9, 0,012 entre 0,8 et 0,9, 0,020 au-dessous, majoré sous L 0,45 ; blanc pur à E3) ;
  - `roles.control-raised = 3` ; `elevation.field = { step = 3, inset_shadow = false }` ;
  - `accent.fill_lightness = 0.53`, `accent.standalone_lightness = 0.47` ; `categorical.lightness = 0.50` ;
  - `semantic.<k>.l` : départ à la valeur de nuit moins 0,15, descendu par pas de 0,01 jusqu'à ce que
    `planchers` ne signale plus rien ;
  - `states.hover.lightness_delta = -0.03`, `states.pressed.lightness_delta = -0.06` ;
  - `elevation.e2` et `elevation.e3` : `sheen = false`, `edge_light = false`, `shadow = true` ;
    `surface_material.edge_light_opacity = 0.0` ; `knob.lightness = 1.0` (et pas de `role`) ;
  - `meta.mode = "light"`.

  Si un plancher ou l'ordre résiste, ajuster d'abord le rôle de texte concerné, jamais un plancher ; consigner
  chaque écart à la conception dans le message de validation.

- [ ] **Étape 4 : lancer et voir passer** : `python3 -m unittest tests.test_model tests.test_checks -v` → OK ;
  `make check` → OK, `generated/` inchangé.

- [ ] **Étape 5 : valider** : `git commit -m "Thèmes : le moment de jour, valeurs de départ (L2-40)"`.

### Tâche 4 : l'émetteur Quickshell à quatre thèmes

**Fichiers :**
- Modifier : `dunei_theme/emitters/quickshell.py`
- Tester : `tests/test_quickshell_emitter.py` ; références `tests/golden/hue-*/coque-tokens.json` par
  `make golden`

**Interfaces :**
- Consomme : `themes`, `defaut`, `theme_data`, `resolve` ; `model["knob"]`.
- Produit, dans `coque-tokens.json` :
  - au premier niveau, partagé : `_generated`, `hue`, `space`, `density`, `radius`, `window`, `layout`,
    `breakpoints`, `typo`, `icons` ;
  - `familles` (liste), `moments` (liste), `defaut` (`{famille, moment}`) ;
  - `themes[famille][moment]` = `{color, states, focus, disabled, elevation, material, render}`, mêmes clés
    qu'aujourd'hui, plus `color.knob` et `knob` = `{rest, disabled}` (le désactivé suit `eteint`, contre le
    désactivé de `control-raised` sans sélection) ; les clés `errorHover`… quittent `color` ;
  - `pastilles` = `{glyph, error, errorHover, errorPressed, warning, …, success, …}`, calculé une fois sur le
    thème par défaut, identique pour les quatre.
- `emit(model)` garde sa signature : il résout lui-même les quatre thèmes depuis `model["raw"]` et `model["hue"]`.

- [ ] **Étape 1 : relever l'existant** : copier `tests/golden/hue-55/coque-tokens.json` dans le brouillon de
  session (`$TMPDIR` ou le dossier scratchpad) sous le nom `avant.json`, pour l'étape 4.

- [ ] **Étape 2 : écrire les tests qui échouent**, dans `tests/test_quickshell_emitter.py` : adapter les lectures
  existantes à `themes.thematisee.nuit` ; ajouter :
  - `test_quatre_themes` : `themes` a les clés `thematisee` et `dominante`, chacune `nuit` et `jour`, et
    `defaut == {"famille": "thematisee", "moment": "nuit"}` ;
  - `test_pastilles_hors_moment` : `pastilles` existe au premier niveau, `glyph` égale
    `themes.thematisee.nuit.color.surfaceBase`, et aucune branche `color` n'a de clé finissant par `Hover` ou
    `Pressed` ;
  - `test_knob` : `color.knob` au jour vaut `#ffffff` ; `knob.disabled` diffère de `knob.rest` ;
  - rendre propres à la nuit les assertions d'ordre sombre (`control-raised.l > surface-raised.l`, l. 95) et le
    `sheenTop` (l. 48-52) ; le test APCA sur `controlRaised` (l. 97-113) porte sur les quatre thèmes.

- [ ] **Étape 3 : lancer et voir échouer** : `python3 -m unittest tests.test_quickshell_emitter -v`.

- [ ] **Étape 4 : implémenter**, puis vérifier la contrainte globale : `make tokens && make golden`, puis
  `git diff --stat tests/golden` ne montre que les `coque-tokens.json` ; et
  `jq --slurpfile a avant.json '.themes.thematisee.nuit as $n | [$a[0].color | to_entries[] | select(.key |
  test("Hover|Pressed") | not) | select($n.color[.key] != .value)] | length' tests/golden/hue-55/coque-tokens.json`
  imprime `0` ; même comparaison, entière, pour `states`, `focus`, `elevation`, `material` et `render`.

- [ ] **Étape 5 : lancer et voir passer** : `python3 -m unittest tests.test_quickshell_emitter tests.test_golden -v`
  → OK ; `make check` → OK.

- [ ] **Étape 6 : valider** : `git commit -m "Émetteur Quickshell : les quatre thèmes, le knob et les pastilles
  hors du moment (L2-40)"`.

### Tâche 5 : le module `Theme` et les composants

**Fichiers :**
- Modifier : `coque/Theme/Theme.qml`, `coque/Composants/Interrupteur.qml`, `coque/Composants/Curseur.qml`,
  `coque/Composants/Pastilles.qml`, `coque/outils/planche/shell.qml` (légende), la coque d'essai
  `coque/Theme/essai/`
- Tester : `tests/test_coque_theme.py`, `tests/test_coque_composants.py`

**Interfaces :**
- Consomme : la forme du JSON de la tâche 4.
- Produit :
  - `Theme.famille`, `Theme.moment` (chaînes, en lecture) ; `Theme.pastilles`, `Theme.knob` (raccourcis) ;
  - `Theme.tokens` reste l'objet que lisent les raccourcis et `ColorSpring`, mais devient **la vue du thème
    actif** : un nouvel objet à chaque lecture valide de l'un des deux fichiers, fait des clés partagées du
    fichier et de la branche `themes[famille][moment]`. L'identité neuve est ce qui fait basculer `ColorSpring`
    sans animation (D81).
  - Une troisième `Source` lit `theme.json` (clés exigées `famille`, `moment`). Absent : défaut silencieux, sans
    `console.error` (le `onLoadFailed` de cette source ne signale que l'illisible). Nom inconnu : défaut et
    `console.warn("Theme : thème <f>/<m> inconnu ; défaut <f>/<m> appliqué")`.

- [ ] **Étape 1 : écrire les tests qui échouent** :
  - `tests/test_coque_theme.py`, dans la coque d'essai : `test_bascule_jour` (écrire
    `{"famille": "dominante", "moment": "jour"}` par fichier temporaire puis `os.replace`, comme la commande ;
    `Theme.color.surfacePanel` devient la valeur `themes.dominante.jour.color.surfacePanel` du JSON, et
    `Theme.moment == "jour"`) ; `test_choix_absent` (pas de `theme.json` : thème par défaut, aucun
    `console.error` au journal) ; `test_choix_inconnu` (`"verre"` : défaut et un avertissement qui contient
    « inconnu ») ; `test_teinte_garde_le_jour` (jour choisi, régénération à une autre teinte : `Theme.moment`
    reste `"jour"` et `Theme.tokens.hue` change).
  - `tests/test_coque_composants.py` : le disque de l'interrupteur et la poignée du curseur prennent
    `Theme.color.knob` (`Theme.knob.disabled` désactivés) ; la pastille prend `Theme.pastilles` ; l'assertion
    « champ plus sombre que le panneau » (l. 283) devient propre à la nuit.

- [ ] **Étape 2 : lancer et voir échouer** : `python3 -m unittest tests.test_coque_theme tests.test_coque_composants -v`
  (session Wayland requise ; sans elle, les tests sont ignorés et l'exécutant le signale).

- [ ] **Étape 3 : implémenter** `Theme.qml`, puis les trois composants ; retirer des en-têtes d'`Interrupteur` et
  de `Curseur` la mention « un rôle propre (knob) viendra si un thème clair apparaît ». La légende de la planche
  affiche aussi `Theme.famille + "/" + Theme.moment`.

- [ ] **Étape 4 : lancer et voir passer** : même commande → OK ; `make check` → OK.

- [ ] **Étape 5 : valider** : `git commit -m "Coque : thème actif choisi par theme.json, knob et pastilles
  (L2-40)"`.

### Tâche 6 : la commande `dunei-theme`

**Fichiers :**
- Créer : `config/bin/dunei-theme` (exécutable ; `deploy.py` lie déjà tout `config/bin/` dans `~/.local/bin`)
- Tester : `tests/test_dunei_theme.py`, sur le modèle de `tests/test_dunei_maj.py`

**Interfaces :**
- Consomme : `familles`, `moments`, `defaut` de `coque-tokens.json`.
- Produit : `dunei-theme [jour|nuit|bascule|famille <nom>]`, comme au § 6.4 de la conception. Dossier :
  `$DUNEI_TOKENS_DIR`, sinon `${XDG_CONFIG_HOME:-$HOME/.config}/dunei`. Sans `theme.json`, l'état courant est le
  défaut. Sortie standard : `<famille> <moment>` après chaque appel. Codes : 0, 1 (tokens introuvables ou
  illisibles), 2 (argument ou nom inconnu, usage sur la sortie d'erreur).

- [ ] **Étape 1 : écrire les tests qui échouent** (dossier temporaire, `DUNEI_TOKENS_DIR`, tokens générés par
  `generate_tokens.py --out`) : `test_etat_par_defaut` (`thematisee nuit`, aucun fichier écrit) ;
  `test_jour_garde_la_famille` ; `test_bascule_aller_retour` ; `test_famille` ; `test_nom_inconnu` (code 2,
  `theme.json` inchangé) ; `test_sans_tokens` (code 1, rien d'écrit) ; `test_ecriture_atomique` (aucun fichier
  temporaire ne reste dans le dossier) ; `test_json_valide` (le fichier relu par `json.loads` a exactement les
  clés `famille` et `moment`).

- [ ] **Étape 2 : lancer et voir échouer** : `python3 -m unittest tests.test_dunei_theme -v`.

- [ ] **Étape 3 : écrire le script** : bash, `set -euo pipefail`, en-tête du dépôt comme `dunei-maj` ; lecture
  par `jq`, écriture par `mktemp` dans le même dossier puis `mv`.

- [ ] **Étape 4 : lancer et voir passer** : même commande → OK ; `make check` → OK.

- [ ] **Étape 5 : valider** : `git commit -m "dunei-theme : choisir la famille et le moment de la coque (L2-40)"`.

### Tâche 7 : la planche et la validation à l'écran

**Fichiers :**
- Modifier : `coque/outils/planche/planche.sh`, et les valeurs de `[moments.jour]` que Nicolas fait changer

**Interfaces :**
- Consomme : `dunei-theme` (tâche 6).
- Produit : `planche.sh theme <famille> <moment>`, qui appelle `config/bin/dunei-theme` avec
  `DUNEI_TOKENS_DIR` sur le brouillon ; l'en-tête du script le documente.

- [ ] **Étape 1 : ajouter la sous-commande** ; vérifier : planche ouverte, `planche.sh theme dominante jour` la
  bascule d'un bloc (capture grim de la fenêtre visée par son adresse Hyprland).
- [ ] **Étape 2 : passes de validation avec Nicolas**, dans une vraie fenêtre : les quatre thèmes aux teintes 55
  (`caladan`), 200 et 265. Points soumis à chaque passe : la hiérarchie des textes, l'élévation au jour (ombres),
  l'interrupteur éteint (point de vigilance 5), l'accent autonome et l'anneau de focus, les couleurs sémantiques,
  l'infusion du thématisé de jour. Chaque changement de valeur repasse par `make check` et `make golden`.
- [ ] **Étape 3 : relever** le processeur au repos de la planche, avant et après une bascule (règle de D80).
- [ ] **Étape 4 : valider** : `git commit -m "Planche : bascule de thème ; valeurs du jour validées à l'écran
  (L2-40)"`.

### Tâche 8 : la documentation

**Fichiers :**
- Modifier : bible (chapitres 2, 3 et 7), `docs/journal-decisions.md` (D83), backlog (L2-40 fait ; le bouton
  jour/nuit et les paramètres appelleront `dunei-theme`), carnet (section « Les thèmes statiques » : mode
  d'emploi de `dunei-theme`, relevés), notes de direction (état d'avancement, prochaine étape), conception
  (version 0.3, statut implémentée), ce plan (cases cochées). Chaque document : version en tête et ligne
  d'historique.

- [ ] **Étape 1 : écrire** D83 : le contrat révisé (famille et moment, planchers par rôle), les choix de la
  conception marqués « décision de Claude », les valeurs retenues à l'écran.
- [ ] **Étape 2 : mettre à jour** les autres documents ; la bible reprend le tableau des deux échelles et le
  rôle `knob`.
- [ ] **Étape 3 : vérifier** : `make check` → OK.
- [ ] **Étape 4 : valider** : `git commit -m "Documentation des thèmes statiques : D83, bible, carnet, backlog,
  direction (L2-40)"`.

## Historique des versions

| Version | Date | Changement |
| --- | --- | --- |
| 0.1 | 2026-10-24 | Version initiale, d'après la conception 0.2 |
