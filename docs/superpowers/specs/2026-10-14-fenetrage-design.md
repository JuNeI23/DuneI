# Fenêtrage : disposition, bordure, couche 2 et décorations

Version 0.2 · 2026-10-14 · backlog L1-12 à L1-15 · carnet « Géométrie », « Fenêtre active et inactive », « Variables d'environnement » · statut : validée, implémentée

## 1. Objet

Le tuilage de `caladan` vit encore en partie dans `generique.lua`, hors du dépôt : la disposition, le
flou, les valeurs d'ombre et les règles de fenêtre. Les jetons n'en couvrent qu'une part (gouttières,
rayon, bordure, absence d'ombre). La couche 2 n'existe pas : une fenêtre flottante ne se distingue en
rien d'une tuile, et le plein écran garde ses effets.

Cette fonctionnalité :

- fixe la disposition du tuilage (dwindle) dans un module versionné ;
- retire la bordure des fenêtres et modifie la bible en conséquence ;
- donne une ombre aux seules fenêtres flottantes et dépouille le plein écran de tout effet ;
- supprime les décorations Qt côté client ;
- retire de `generique.lua` les blocs que DuneI remplace.

Les raccourcis et les bureaux (L1-16) font l'objet d'une feature distincte, `feat/raccourcis`.

**Critères de réussite**

1. `hyprctl getoption` donne : `general:layout` = `dwindle`, `dwindle:preserve_split` = vrai,
   `general:border_size` = 0, `decoration:shadow:enabled` = vrai, `range` = 16, `render_power` = 2,
   `offset` = [0, 4].
2. Une fenêtre tuilée n'a aucune ombre ; une fenêtre flottante en a une. Vérifié par capture grim et
   profil de pixels autour des deux fenêtres.
3. Une fenêtre en plein écran n'a ni coins arrondis ni ombre.
4. Un dialogue réel (sélecteur de fichiers de Firefox) s'ouvre en flottant sans règle dédiée.
5. `QT_WAYLAND_DISABLE_WINDOWDECORATION` vaut `1` dans l'environnement des clients lancés par Hyprland.
6. Aucune couleur, durée, taille ni aucun rayon n'est écrit dans `config/hypr/modules/` : les valeurs
   d'apparence viennent de `generated/`.
7. `generique.lua` ne contient plus les blocs `general`, `decoration`, `dwindle`, `master`,
   `scrolling` ni aucune règle de fenêtre, et la session se charge sans erreur (`hyprctl configerrors`
   vide).
8. Nicolas valide le résultat à l'écran.

**Hors périmètre**

- L'indication de la fenêtre active : aucune au lot 1. Elle revient au modificateur `inactive` des
  composants (L2-03).
- Le flou : invisible au lot 1, toutes les fenêtres étant opaques. Il se règle au lot 2 avec le voile
  des overlays d'attention.
- Une ombre courte dans la gouttière de la fenêtre active : piste notée pour le lot 2, non étudiée.
- L'intensité du voile d'un dialogue modal sur sa fenêtre parente (`dim_modal`, actif par défaut) :
  lot 2.
- Les barres de titre dessinées par GTK : elles ne se retirent pas depuis le compositeur ; la curation
  du lot 3 les traite (bible, ch. 12).
- Les variables de session `XDG_CURRENT_DESKTOP`, `XDG_SESSION_TYPE`, `MOZ_ENABLE_WAYLAND` et
  `QT_QPA_PLATFORM` : déjà présentes ou inutiles en Qt 6 ; elles relèvent de la feature session (L1-10).
- Les raccourcis, les gestes et les bureaux virtuels : `feat/raccourcis`.

## 2. Décisions prises pendant la conception

| Sujet | Décision | Raison |
| --- | --- | --- |
| Découpage | Deux features : fenêtrage (L1-12 à L1-15), puis raccourcis (L1-16) | Validation à l'œil d'un côté, au doigt de l'autre (Nicolas) |
| Disposition | dwindle | scrolling essayé en direct sur la session, jugé « nul » à l'usage par Nicolas ; master et monocle écartés |
| Placement d'une nouvelle fenêtre | Suit la souris (`force_split = 0`, défaut, non écrit) | Jugé plus intuitif par Nicolas que le côté fixe proposé |
| Découpe figée | `preserve_split = true` | Repris du générique : sans lui, une découpe change de sens au redimensionnement |
| Bordure | Aucune, ni active ni inactive | Jugée laide par Nicolas, sur le modèle de macOS. La bible est modifiée, ce n'est pas une dérogation |
| Fenêtre active au lot 1 | Aucun repère | Une lueur intérieure (`decoration.glow`) a été essayée en trois variantes et rejetée ; le repère vient au lot 2, à la manière de macOS : le chrome des fenêtres inactives perd sa couleur |
| Ombre des flottantes | Une seule ombre : portée 16, décalage 0/4, puissance 2, noir à 36 % | Hyprland ne dessine qu'une ombre par fenêtre ; un greffon maison à deux ombres coûterait une maintenance à chaque version. Trois candidates puis deux moyennes essayées à l'écran, 16/4 retenue |
| Coins | Arc de cercle (`rounding_power = 2`, défaut, non écrit), rayon 12 | Point ouvert de l'annexe C, fermé par Nicolas |
| Plein écran | Aucun coin, aucune ombre ; le rayon passe par un jeton `radii.fullscreen = 0` | Bible : « média plein écran, tous effets désactivés ». Aucun rayon en dur dans `modules/`, à la demande de Nicolas |
| Flou | Renvoyé au lot 2 | Sans effet visible tant que les fenêtres sont opaques |
| Contenu inactif | Ni terni ni estompé (`dim_inactive` reste désactivé) | Bible, ch. 7 |

Constats faits sur la session réelle (Hyprland 0.56.2, échelle 1,25) :

- **La bordure de 2 px logiques était rendue sur 3 pixels physiques pleins**, sans pixel intermédiaire,
  sur les bords verticaux et horizontaux ; la gouttière de 8 px logiques mesurait 10 pixels physiques.
  Le point « bordure à 2,5 pixels » du carnet était donc sans objet, avant même le retrait de la bordure.
- **Une ombre noire est invisible sur un fond noir** : sur le terminal générique, aucune des candidates
  ne se voyait. Le jugement a été fait sur le fond d'écran.
- Les valeurs de `generique.lua` que DuneI ne réécrit pas sont toutes égales aux défauts de Hyprland
  (opacités 1, `rounding_power` 2, `resize_on_border` et `allow_tearing` désactivés), sauf la taille du
  flou (3 au lieu de 8), invisible au lot 1.

Faits tirés de la documentation de Hyprland 0.56 (wiki.hypr.land) :

- une règle de fenêtre peut retirer une ombre (`no_shadow`), pas en ajouter : l'ombre est activée
  globalement et retirée aux tuiles ;
- entre deux règles qui correspondent, la dernière déclarée l'emporte ; les effets dynamiques sont
  réévalués quand la propriété change (une fenêtre basculée en flottant reçoit son ombre) ;
- `decoration.shadow` : `enabled`, `range` (0 à 100), `render_power` (1 à 4), `offset` (vec2),
  `color`, `color_inactive` (repli sur `color`).

## 3. Architecture

### 3.1 Jetons (`tokens.toml`)

```toml
[radii]
fullscreen = 0               # plein écran : aucun effet, coins compris

[window]
border_width = 0             # aucune bordure de fenêtre ; la fenêtre active se signale au lot 2 (L2-03)

[window.floating_shadow]     # couche 2 seulement ; une ombre, faute de mieux dans Hyprland (D30)
range = 16
offset_y = 4
render_power = 2
```

La couleur de l'ombre n'a pas de nouveau jeton : elle se compose de `surface_material.shadow_color`
(noir) et de `surface_material.shade_opacity` (0,36).

`states.focus.ring_width` reste un jeton des composants (anneau de focus, lot 2) ; il ne sert plus à la
bordure de fenêtre.

### 3.2 Contrôles bloquants (`dunei_theme/emitters/hyprland.py`)

Placés dans l'émetteur Hyprland, seul chemin qui bloque `generate_tokens.py` : `checks.py` ne produit
que des avertissements. Tous les jetons sont des entiers ; la portée est comprise entre 1 et 100.

- `window.floating_shadow.range` et `offset_y` sont des multiples de 4 (bible, ch. 3, base 4) ;
- `render_power` est compris entre 1 et 4 (borne de Hyprland) ;
- `window.border_width` et `radii.fullscreen` sont des entiers positifs ou nuls.

### 3.3 Générateur (`dunei_theme/emitters/hyprland.py`)

`generated/hyprland-tokens.lua` garde son contrat (une table passée à `hl.config`) :

- `border_size` vient de `window.border_width` ;
- le bloc `col` (couleurs de bordure) disparaît ;
- `shadow` devient `{ enabled = true, range, render_power, offset = { 0, offset_y }, color }`, la
  couleur étant écrite dans un format accepté par l'API Lua (à vérifier à l'implémentation : chaîne
  `rgba(…)` ou entier `0xAARRGGBB`).

Nouveau fichier `generated/hyprland-rules.lua` : il **retourne une liste de règles de fenêtre**, que
le module applique. Ce sont les règles d'apparence, dérivées des jetons :

| Règle | Correspondance | Effets | Source |
| --- | --- | --- | --- |
| `couche-1-sans-ombre` | `float = false` | `no_shadow = true` | `elevation.e1.shadow = false` |
| `plein-ecran-nu` | `fullscreen = true` | `no_shadow = true`, `rounding = 0` | `radii.fullscreen` |

`deploy.py` ajoute `hyprland-rules.lua` à la liste des fichiers générés copiés sous
`~/.config/hypr/generated/`.

### 3.4 Modules (`config/hypr/modules/`)

Chacun expose `apply()`, sur le modèle de `ecrans.lua`, avec l'en-tête de commentaires réglementaire.

- **`env.lua`** : `hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")` (L1-14). Hyprland ne dessine
  aucune barre de titre de lui-même : le masquage côté serveur est acquis ; cette variable retire celles
  que Qt dessine.
- **`fenetres.lua`** : `hl.config({ general = { layout = "dwindle" }, dwindle = { preserve_split = true } })`
  (L1-12). `dwindle` est le défaut, écrit malgré tout parce qu'il est une décision (D28).
- **`regles.lua`** : applique les règles de `generated.hyprland-rules`, puis les deux règles de
  comportement reprises du générique, qui ne portent aucune valeur de design :
  - `sans-agrandissement` : toutes les fenêtres, `suppress_event = "maximize"` ; une application ne
    peut pas s'agrandir d'elle-même et casser le tuilage ;
  - `glisser-xwayland` : fenêtres XWayland flottantes sans classe ni titre, hors plein écran et non
    épinglées, `no_focus = true` ; correctif du glisser-déposer XWayland.

La règle `move-hyprland-run` du générique n'est pas reprise : elle sert un lanceur que DuneI n'utilise
pas.

### 3.5 Point d'entrée (`config/hypr/hyprland.lua`)

Ordre de chargement après la feature :

```
generique → jetons → mouvement → env → fenetres → regles → ecrans → machine
```

Les trois nouveaux modules passent avant le fragment machine, qui garde le dernier mot.

### 3.6 Retrait du générique

À la main sur `caladan`, `generique.lua` étant hors du dépôt : retrait des blocs `general`,
`decoration`, `dwindle`, `master`, `scrolling` et des trois règles de fenêtre. Restent les animations
(écrasées par le mouvement), `misc`, l'entrée, les gestes et les raccourcis, qui partiront avec les
features suivantes.

## 4. Tests

**Automatiques** (`make test`, `make check`, `make golden`) :

- contrôles bloquants de la section 3.2, cas valides et invalides ;
- émetteur Hyprland : `border_size = 0`, absence de `col`, ombre activée avec ses valeurs et sa
  couleur composée ;
- `hyprland-rules.lua` : les deux règles, leurs correspondances et effets, fixés par `make golden` ;
- `hyprland-rules.lua` et les trois modules se chargent dans un interpréteur Lua nu, l'API `hl` étant
  simulée, comme pour les modules existants ;
- point d'entrée : présence et ordre des `require` ;
- `deploy.py` : `hyprland-rules.lua` copié.

**Sur la session réelle**, après `make install` : critères 1 à 7 de la section 1, avec `hyprctl`, grim
et un dialogue de Firefox. La suppression des décorations Qt se vérifie sur une application Qt installée
si une existe ; à défaut, le point est reporté au lot 3 et noté au carnet.

**Validation de Nicolas à l'écran** : critère 8.

## 5. Documentation

- **Journal** :
  - D28 : disposition dwindle, scrolling essayé puis rejeté ; placement à la souris ;
  - D29 : plus de bordure de fenêtre ; la fenêtre active se signale au lot 2 par le modificateur
    `inactive`, à la manière de macOS ; lueur essayée et rejetée ;
  - D30 : ombre des flottantes, une couche, 16/4/2, et pourquoi pas de greffon ;
  - D31 : coins en arc de cercle, flou renvoyé au lot 2, rayon plein écran 0 en jeton.
- **Bible** :
  - ch. 3 : rayon plein écran 0 ;
  - ch. 7 : le modificateur `inactive` est l'unique repère de fenêtre active ;
  - ch. 8 : la hiérarchie se lit par les gouttières et par le chrome de la fenêtre active ; disposition
    dwindle ;
  - ch. 12 : la phrase sur la « bordure accentuée » est réécrite ;
  - annexe C : coins fermés, flou rattaché au lot 2, nouvelle ligne pour l'ombre de gouttière ;
  - annexe E : la fenêtre flottante porte « une ombre » et non « 2 couches ».
- **Carnet** : sections « Géométrie » (extrait généré, plus de bordure, constat des 3 pixels),
  « Fenêtre active et inactive » (réécrite), « Variables d'environnement » (seule la variable Qt est
  posée par DuneI ; les autres relèvent de L1-10), point d'entrée et liste des modules.
- **Backlog** : L1-12 à L1-15 faits ; L2-03 précisé ; une ligne au lot 2 pour le flou et l'ombre de
  gouttière.
- **Notes de direction** : la prochaine étape est la feature raccourcis (L1-16).

## Historique des versions

| Version | Date | Changement |
| --- | --- | --- |
| 0.1 | 2026-10-14 | Version initiale, issue du brainstorming |
| 0.2 | 2026-10-14 | Implémentée ; critères vérifiés sur la session ; contrôles bloquants placés dans l'émetteur Hyprland |
