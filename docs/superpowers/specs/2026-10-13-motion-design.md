# Mouvement : `motion.toml` et `generate_motion.py`

Version 0.1 · 2026-10-13 · backlog L1-23, volet mouvement de L1-24 · statut : à valider

## 1. Objet

Le mouvement de DuneI n'a aujourd'hui qu'une seule source fiable : les réglages validés au ressenti
dans le banc `proto/motion/`, exportés dans `proto/motion/export.toml`. Cette fonctionnalité en fait
une source unique, `motion.toml`, et un générateur, `generate_motion.py`. Le générateur vérifie les
règles du chapitre 6 de la bible, puis écrit deux fichiers :

- `generated/motion.lua` : les ressorts et les animations du compositeur Hyprland ;
- `generated/motion.json` : les mêmes ressorts, destinés à la future coque Quickshell.

**Critères de réussite**

1. `make motion` produit les deux fichiers depuis `motion.toml`, sans aucune valeur recopiée à la main.
2. Toute infraction aux règles de la bible ou à l'API Hyprland 0.56.2 bloque la génération, avec un
   message explicite.
3. `make check` passe et refuse toute modification manuelle de `generated/`.
4. Le module Lua se charge dans un interpréteur Lua nu, sans Hyprland, et déclare les 27 éléments
   d'animation.

**Hors périmètre**

- Le branchement dans la configuration Hyprland réelle de la machine. C'est la fonctionnalité
  suivante, testée à chaud avec l'accord de Nicolas, et elle inclut aussi `hyprland-tokens.lua`.
- Les variables CSS de mouvement (décision A : Lua et JSON maintenant, CSS plus tard).
- La relecture de `motion.toml` par le banc.
- Les exceptions `noanim` des couches de la coque DuneI, qui relèvent de `modules/rules`.

## 2. Décisions déjà prises

| Sujet | Décision |
| --- | --- |
| Vocabulaire Hyprland | Clé `dampening`, argument `spring =`, `speed = 1` sans effet sur un ressort (D13). |
| Transitions | Sept transitions : les six de la bible, plus `navigate` pour le changement de bureau (décision C). |
| Cibles | Lua et JSON maintenant, CSS reporté (décision A). |
| Code | Un paquet séparé, `dunei_motion/`, sur le modèle de `dunei_theme/`. |
| Correspondance Hyprland | Le tableau de la section 5, validé par Nicolas. |
| Règles de la bible | Bloquantes : une infraction empêche la génération. |

## 3. Le fichier source `motion.toml`

Il est placé à la racine du dépôt. Les valeurs sont celles de `proto/motion/export.toml`, sans arrondi
supplémentaire.

```toml
version = "0.1.0"

[meta]
name   = "DuneI"
prefix = "dunei"                  # Préfixe des courbes Hyprland, par exemple dunei-state-in.

[rules]                           # Règles chiffrées du chapitre 6 de la bible, vérifiées à chaque génération.
exit_ratio         = 0.70         # Une sortie dure environ 70 % de l'entrée.
exit_tolerance     = 0.10         # Les rapports compris entre 0,60 et 0,80 sont acceptés.
overshoot_allowed  = ["window"]   # Seules ces transitions peuvent dépasser leur cible (ζ < 1).
stagger_allowed    = ["reveal"]   # Seules ces transitions peuvent échelonner leurs éléments.
stagger_cap        = 5            # Nombre maximal d'éléments échelonnés dans une cascade.
reduced_fade_ms    = 100          # Durée du fondu qui remplace tout mouvement en mode réduit.

[transitions.state]
usage      = "Changement d'état sur place : survol, focus, pression, sélection."
mass       = 0.50
stiffness  = 1100
dampening  = 50                   # Nom de clé de Hyprland 0.56.2 (D13).
exit_ratio = 0.70
```

| Transition | m | k | c | `exit_ratio` | Champs propres |
| --- | --- | --- | --- | --- | --- |
| `state` | 0,50 | 1100 | 50 | 0,70 | |
| `reveal` | 1,00 | 600 | 50 | 0,70 | `stagger_ms = 40` |
| `overlay` | 1,00 | 400 | 44 | 0,70 | |
| `window` | 0,70 | 300 | 27 | 0,70 | `overshoot = true` |
| `reflow` | 0,80 | 500 | 40 | absent | `symmetric = true` |
| `spectacle` | 1,00 | 150 | 25 | 0,70 | |
| `navigate` | 0,30 | 600 | 30 | absent | `symmetric = true` |

Chaque transition porte une clé `usage`, qui décrit en une phrase quand l'employer.

**Valeurs dérivées, jamais écrites dans le fichier**

- **Ressort de sortie.** Il garde la même masse, avec k ÷ r² et c ÷ r (r = `exit_ratio`). ζ ne change
  pas et toutes les durées sont multipliées par r. Une transition symétrique utilise r = 1.
- **Ressort réduit.** C'est un ressort critique (m = 1, ζ = 1) dont la stabilisation à ±1 % dure
  `reduced_fade_ms`. Pour 100 ms, cela donne k 4406,3 et c 132,76.

**La table `[hyprland]`** associe chacun des 27 éléments d'animation à une transition, sous forme de
tables en ligne :

```toml
[hyprland]                        # Chaque élément d'animation de Hyprland reçoit une transition DuneI.
windowsIn   = { use = "window", phase = "in",  style = "popin 90%" }
windowsOut  = { use = "window", phase = "out", style = "popin 90%" }
windowsMove = { use = "reflow" }
borderangle = { enabled = false }
```

- `phase` vaut `in` ou `out` et choisit le ressort d'entrée ou de sortie. Sans `phase`, l'élément
  prend le ressort d'entrée.
- `style` est facultatif et doit être valide pour l’élément (section 7).
- `{ enabled = false }` désactive l'élément.

**La table `[hyprland_reduced]`** liste les écarts propres au mouvement réduit :

```toml
[hyprland_reduced]                # Écarts du mouvement réduit ; les autres éléments gardent leur entrée, sans style.
windowsIn    = { style = "popin 100%" }   # La fenêtre apparaît à sa taille finale ; seul le fondu reste.
windowsOut   = { style = "popin 100%" }
windowsMove  = { enabled = false }        # Les tuiles rejoignent leur place sans glisser.
workspacesIn = { style = "fade" }
workspacesOut = { style = "fade" }
layersIn     = { style = "fade" }
layersOut    = { style = "fade" }
zoomFactor   = { enabled = false }
```

En mouvement réduit, chaque élément actif utilise le ressort réduit. Il prend le style de
`[hyprland_reduced]` s'il y figure, sinon aucun style. Un élément y est désactivé s'il y est déclaré
`enabled = false`, ou s'il est déjà désactivé en mode normal.

## 4. Architecture

```
motion.toml ──► generate_motion.py ──► dunei_motion/
                                       ├── spring.py     simulation et dérivations du ressort
                                       ├── model.py      lecture du TOML et résolution
                                       ├── hyprland.py   éléments connus et styles valides (0.56.2)
                                       ├── checks.py     erreurs bloquantes et avertissements
                                       └── emitters/     lua.py, json_.py, registre TARGETS
                                                    │
                       ┌────────────────────────────┴───────────────┐
              generated/motion.lua                         generated/motion.json
                       │                                            │
       config/hypr/modules/motion.lua                    future coque Quickshell
             (application dans Hyprland)
```

| Unité | Rôle | Entrée | Sortie |
| --- | --- | --- | --- |
| `spring.simulate` | Intègre m·x″ = −k·(x − 1) − c·x′ par Euler semi-implicite au pas de 1 ms, comme `proto/motion/physics.js`. | m, k, c | durée de stabilisation à ±1 % (ms) et dépassement maximal |
| `spring.zeta` | Calcule le rapport d'amortissement ζ = c / (2·√(k·m)). | m, k, c | ζ |
| `spring.exit` | Dérive le ressort de sortie. | ressort, r | ressort |
| `spring.critical` | Cherche par dichotomie le ressort critique dont la stabilisation dure la durée demandée. | durée (ms) | ressort |
| `model.load` | Lit le fichier TOML. | chemin | dictionnaire brut |
| `model.resolve` | Calcule les ressorts d'entrée, de sortie et réduit, puis les deux listes d'animations. | dictionnaire brut | modèle résolu |
| `checks.errors` | Applique les contrôles bloquants au dictionnaire brut. | dictionnaire brut | liste de messages |
| `checks.warnings` | Applique les contrôles non bloquants au modèle résolu. | modèle résolu | liste de messages |
| `hyprland.style_error` | Reproduit `styleValidInConfigVar` de Hyprland 0.56.2. | élément, style | message, ou chaîne vide si le style est valide |
| `emitters.TARGETS` | Associe chaque nom de fichier à une fonction d'émission. | modèle résolu | texte du fichier |

Le flux de `generate_motion.py [--src motion.toml] [--out generated]` est le suivant :

1. Lecture du TOML, puis contrôles bloquants.
2. En cas d'erreur, les messages sont écrits sur la sortie d'erreur, aucun fichier n'est écrit et le
   code de retour vaut 1.
3. Sinon, résolution du modèle et affichage des avertissements.
4. Écriture de chaque cible de `TARGETS`, puis code de retour 0.

Les dérivations sont arrondies une seule fois, dans `model.resolve` : la raideur au dixième,
l'amortissement au centième, ζ au centième et les durées à la milliseconde. Les deux cibles écrivent
donc exactement les mêmes nombres.

## 5. Correspondance avec Hyprland

Hyprland 0.56.2 expose 34 nœuds d'animation (`hyprctl animations -j`, hors `__internal_fadeCTM`).
`[hyprland]` déclare les 26 nœuds terminaux, plus `global`, soit 27 éléments. Les nœuds parents
intermédiaires (`windows`, `layers`, `fade`, `fadeLayers`, `fadePopups`, `workspaces`,
`specialWorkspace`) ne sont pas écrits, puisque chacun de leurs enfants l'est. `global` est écrit
afin qu'un élément ajouté par une future version de Hyprland hérite de `state` plutôt que de la courbe
par défaut.

| Éléments | Transition | Phase | Style |
| --- | --- | --- | --- |
| `windowsIn`, `windowsOut` | `window` | in, out | `popin 90%` |
| `fadeIn`, `fadeOut` | `window` | in, out | |
| `windowsMove` | `reflow` | | |
| `workspacesIn`, `workspacesOut` | `navigate` | in, out | `slide` |
| `specialWorkspaceIn`, `specialWorkspaceOut` | `overlay` | in, out | `fade` |
| `layersIn`, `layersOut` | `overlay` | in, out | `popin 96%` |
| `fadeLayersIn`, `fadeLayersOut` | `overlay` | in, out | |
| `fadePopupsIn`, `fadePopupsOut` | `reveal` | in, out | |
| `border`, `fadeSwitch`, `fadeDim`, `fadeShadow`, `fadeGlow`, `zoomFactor` | `state` | | |
| `fadeDpms`, `monitorAdded` | `spectacle` | | |
| `borderangle`, `shadowangle`, `glowangle` | désactivés | | |
| `global` | `state` | | |

`popin 90%` pour les fenêtres et `popin 96%` pour les couches sont des valeurs de départ. La seconde
reprend l'échelle de la démo `overlay` du banc. Le banc ne règle pas les amplitudes, donc les deux
valeurs seront ajustées dans Hyprland au branchement.

## 6. Les fichiers générés

### `generated/motion.lua`

Comme `hyprland-tokens.lua`, le module retourne une table et ne déclenche rien au chargement.

```lua
-- GÉNÉRÉ depuis motion.toml par generate_motion.py. Ne pas modifier à la main.
-- Usage : require("modules.motion").apply(false)
return {
    -- Courbes : un ressort d'entrée et un ressort de sortie par transition, plus le fondu réduit.
    curves = {
        ["dunei-state-in"]  = { type = "spring", mass = 0.5, stiffness = 1100, dampening = 50 },
        ["dunei-state-out"] = { type = "spring", mass = 0.5, stiffness = 2244.9, dampening = 71.43 },
        ["dunei-reduced"]   = { type = "spring", mass = 1, stiffness = 4406.3, dampening = 132.76 },
    },
    -- Animations du mode normal, une entrée par élément de Hyprland.
    animations = {
        { leaf = "windowsIn", enabled = true, speed = 1, spring = "dunei-window-in", style = "popin 90%" },
        { leaf = "borderangle", enabled = false },
    },
    -- Animations du mouvement réduit : mêmes éléments, fondu court, sans déplacement ni changement d'échelle.
    reduced = {
        { leaf = "windowsIn", enabled = true, speed = 1, spring = "dunei-reduced", style = "popin 100%" },
        { leaf = "windowsMove", enabled = false },
    },
}
```

Les courbes sont triées par nom et les animations suivent l'ordre de `[hyprland]`, pour que la sortie
soit stable d'une génération à l'autre. Les transitions symétriques déclarent quand même leurs deux
courbes, identiques, afin que tout nom `dunei-<transition>-<phase>` existe.

### `config/hypr/modules/motion.lua`

C'est le seul code écrit à la main, et il ne contient aucune valeur.

```lua
-- Module de mouvement : applique dans Hyprland les ressorts générés depuis motion.toml.
local motion = require("generated.motion")
local M = {}

-- apply : déclare les courbes, puis le jeu d'animations normal ou réduit.
-- Entrée : reduced (booléen). Sortie : aucune. Erreurs : celles de hl.curve et hl.animation.
-- Dépendances : generated.motion, API hl de Hyprland 0.56.
function M.apply(reduced)
    for name, curve in pairs(motion.curves) do hl.curve(name, curve) end
    for _, animation in ipairs(reduced and motion.reduced or motion.animations) do hl.animation(animation) end
end

return M
```

Le point d'entrée appelle `require("modules.motion").apply(false)`. Un fragment chargé plus tard, celui
de la machine ou des préférences, peut appeler `apply(true)` : le dernier appel l'emporte, car
`hl.animation` remplace la configuration de l'élément. Cette forme remplace la variable globale
`dunei.reduced_motion` évoquée pendant la conception, qui aurait dû être définie avant le fragment
machine, alors que celui-ci est chargé en dernier.

### `generated/motion.json`

```json
{
  "_generated": "GÉNÉRÉ depuis motion.toml par generate_motion.py. Ne pas modifier à la main.",
  "version": "0.1.0",
  "rules": { "exit_ratio": 0.7, "exit_tolerance": 0.1, "stagger_cap": 5, "reduced_fade_ms": 100 },
  "transitions": {
    "reveal": {
      "usage": "…",
      "in":  { "mass": 1.0, "stiffness": 600.0, "dampening": 50.0, "zeta": 1.02, "settle_ms": 286 },
      "out": { "mass": 1.0, "stiffness": 1224.5, "dampening": 71.43, "zeta": 1.02, "settle_ms": 200 },
      "overshoot": false,
      "symmetric": false,
      "stagger": { "ms": 40, "cap": 5 }
    }
  },
  "reduced": { "mass": 1.0, "stiffness": 4406.3, "dampening": 132.76, "zeta": 1.0, "settle_ms": 100 }
}
```

`settle_ms` est la durée de stabilisation à ±1 %. Elle est indicative : la coque l'utilisera par
exemple pour savoir quand détruire un élément sorti. La clé `stagger` n'apparaît que sur les
transitions qui en ont une.

## 7. Contrôles

**Erreurs bloquantes**

| Contrôle | Exemple de message |
| --- | --- |
| La version de `motion.toml` est reconnue. | `version 0.2.0 inconnue (attendue : 0.1.0)` |
| Les clés obligatoires sont présentes. | `transitions.state : clé « stiffness » manquante` |
| La masse, la raideur et l'amortissement sont strictement positifs. | `transitions.state : mass doit être strictement positive` |
| Chaque élément de `[hyprland]` et `[hyprland_reduced]` existe dans Hyprland 0.56.2. | `hyprland.windowIn : élément Hyprland inconnu` |
| Les 27 éléments sont tous déclarés dans `[hyprland]`. | `hyprland : élément « fadeDim » non déclaré` |
| `use` désigne une transition existante et `phase` vaut `in` ou `out`. | `hyprland.border : transition « etat » inconnue` |
| Le style est valide pour l'élément, d'après `styleValidInConfigVar`. | `hyprland.windowsIn : style « fade » invalide (unknown style)` |
| ζ < 1 n'est permis qu'aux transitions de `overshoot_allowed`, et `overshoot = true` qu'à elles seules. | `transitions.overlay : ζ 0,85 < 1, dépassement interdit par la bible` |
| `exit_ratio` reste dans `rules.exit_ratio ± exit_tolerance`. | `transitions.state : exit_ratio 0,95 hors de 0,60–0,80` |
| Une transition symétrique ne porte pas d'`exit_ratio`. | `transitions.reflow : symétrique, exit_ratio interdit` |
| `stagger_ms` n'apparaît que sur les transitions de `stagger_allowed`. | `transitions.overlay : cascade interdite` |
| En mode réduit, un élément dont le style déplace ou change l'échelle figure dans `[hyprland_reduced]`. Seuls les styles vides, `fade`, `loop` et `once` en sont dispensés. | `hyprland_reduced : windowsIn doit remplacer le style « popin 90% »` |

**Avertissement**

- `reduced_fade_ms` est inférieur à 100 ms, le plancher de la bible.

**Styles valides** (Hyprland 0.56.2, `CHyprAnimationManager::styleValidInConfigVar`)

| Éléments | Styles |
| --- | --- |
| `windows*` | `slide…`, `gnome`, `gnomed`, `popin`, `popin N%` |
| `workspaces*`, `specialWorkspace*` | `slide`, `slidevert`, `fade`, `slide… N%` |
| `*angle` | `loop`, `once` |
| `layers*` | vide, `fade`, `slide…`, `popin`, `popin N%` |
| autres éléments | aucun style |

La liste des éléments et la table des styles vivent dans `dunei_motion/hyprland.py`, datées de la
version 0.56.2. Elles sont à revérifier à chaque mise à jour de Hyprland ; un test y aide (section 8).

## 8. Tests

Les tests suivent le modèle de `dunei_theme` (unittest, `make test`).

| Fichier | Ce qu'il prouve |
| --- | --- |
| `tests/test_motion_spring.py` | Le simulateur retrouve les durées mesurées par le banc : state 164 ms, reveal 286 ms, overlay 402 ms, window 274 ms, reflow 269 ms, spectacle 569 ms, navigate 186 ms. La sortie dérivée garde ζ et dure r fois l'entrée. Le ressort réduit se stabilise en 100 ms et vaut k 4406,3, c 132,76. |
| `tests/test_motion_checks.py` | Le vrai `motion.toml` ne produit aucune erreur. Chaque contrôle bloquant est déclenché par une copie du fichier modifiée sur une seule clé, et son message est vérifié. |
| `tests/test_motion_lua.py` | `lua` ou `luajit` charge `config/hypr/modules/motion.lua` avec un faux `hl` qui enregistre les appels. Il vérifie 27 animations dans chaque mode, que chaque ressort cité est déclaré, `speed = 1` partout, et que `apply(true)` n'utilise que `dunei-reduced`. Le test est ignoré si aucun interpréteur n'est installé. |
| `tests/test_motion_hyprland.py` | Si `hyprctl` répond, la liste des éléments connus est comparée à `hyprctl animations -j`, ce qui signale une mise à jour de Hyprland. Sinon, le test est ignoré. |
| `tests/test_golden.py` | Il est étendu à `tests/golden/motion/motion.lua` et `motion.json`. |

## 9. Construction

```make
motion:
	$(PY) generate_motion.py --out generated

check: tokens motion test
	git diff --exit-code generated/

golden:   # existant, complété par :
	$(PY) generate_motion.py --out tests/golden/motion >/dev/null
```

## 10. Documentation mise à jour avec l'implémentation

| Document | Changement |
| --- | --- |
| Bible, chapitre 6 | Ajouter `navigate` comme septième transition ; à la ligne 716, remplacer « CSS et module Lua » par « module Lua et JSON ». |
| Journal des décisions | D14 `navigate` ; D15 cibles Lua et JSON ; D16 correspondance Hyprland ; D17 paquet `dunei_motion` ; D18 règles bloquantes et `apply(reduced)`. |
| Backlog | L1-23 terminé ; L1-24 mis à jour pour son volet mouvement. |
| Carnet du lot 1 | Ligne 202 : `require("modules.motion").apply(false)` ; arbre du dépôt sans les mentions « MANQUANT » ; `make motion`. |
| Notes de direction | État du mouvement et prochaine étape (branchement dans Hyprland). |
| `proto/motion/README.md` | Le banc reste l'outil de réglage ; les valeurs validées sont reportées à la main dans `motion.toml`. |

## 11. Livraison

L'implémentation est faite sur la branche `proto/mouvement`, qui contient déjà le banc et les réglages
validés. Elle aboutit à une seule PR « Mouvement (L1-23) », que Nicolas fusionne.

## Historique des versions

| Version | Date | Changement |
| --- | --- | --- |
| 0.1 | 2026-10-13 | Conception validée section par section : format, fichiers générés, contrôles et tests. |
