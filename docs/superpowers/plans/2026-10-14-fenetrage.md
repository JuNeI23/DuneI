# Fenêtrage : disposition, bordure, couche 2 et décorations — plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fixer la disposition dwindle dans un module versionné, retirer la bordure des fenêtres, donner
une ombre aux seules fenêtres flottantes, dépouiller le plein écran de tout effet, supprimer les
décorations Qt, puis retirer de `generique.lua` les blocs que DuneI remplace.

**Architecture:** Les valeurs d'apparence vivent dans `tokens.toml` et passent par l'émetteur Hyprland
de `dunei_theme` : `hyprland-tokens.lua` (table pour `hl.config`, contrat inchangé) et un nouveau
`hyprland-rules.lua` (liste de règles de fenêtre dérivées des jetons). Trois modules écrits à la main,
`env.lua`, `fenetres.lua` et `regles.lua`, appliquent le comportement et les règles générées ; le point
d'entrée les appelle avant `ecrans` et le fragment machine.

**Tech Stack:** Python 3 (`unittest`), Lua 5.5 (`/usr/bin/lua`, pour les tests), API `hl` de
Hyprland 0.56.2, make, `hyprctl`, grim.

**Spec:** `docs/superpowers/specs/2026-10-14-fenetrage-design.md`

## Global Constraints

- Chaque fonction porte un commentaire : titre et rôle, entrée(s), sortie, erreurs, dépendances (CLAUDE.md, règle 2), en phrases complètes et professionnelles.
- Code minimal (règle 3), modulaire (règle 4), indépendant de la machine (règle 5).
- Aucune couleur, durée, taille ni aucun rayon écrit dans `config/hypr/modules/` : les valeurs d'apparence viennent de `generated/`.
- Jetons exacts : `radii.fullscreen = 0` ; `window.border_width = 0` ; `window.floating_shadow` = `range 16`, `offset_y 4`, `render_power 2`. Couleur de l'ombre : `surface_material.shadow_color` à l'opacité `surface_material.shade_opacity` (0,36), soit `rgba(0000005c)`.
- Disposition : `general.layout = "dwindle"`, `dwindle.preserve_split = true` ; `force_split` et `rounding_power` ne sont pas écrits (défauts de Hyprland).
- Ordre du point d'entrée : `generique → jetons → mouvement → env → fenetres → regles → ecrans → machine`.
- Noms des règles : `couche-1-sans-ombre`, `plein-ecran-nu` (générées) ; `sans-agrandissement`, `glisser-xwayland` (comportement).
- Les contrôles de l'ombre et de la bordure sont **bloquants** : ils lèvent `ValueError` dans l'émetteur, que `generate_tokens.py` transforme en refus d'écrire (`checks.py` ne produit que des avertissements).
- `generated/` ne s'édite jamais à la main. `~/.config/hypr/generique.lua` n'est modifié qu'avec l'accord explicite de Nicolas.
- Messages, commentaires et documentation en français, avec accents. Aucun secret dans git.
- Commits terminés par `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Tests : `make test` (équivalent : `python3 -m unittest discover -s tests -t .`). Instantanés : `make golden`, uniquement pour un changement de sortie voulu.

## Review Focus

1. Une portée, un décalage ou une puissance d'ombre invalide (18, 6, 0 ou 5) : la génération refuse et n'écrit rien — tests `test_shadow_rejects_*` (Task 1).
2. `elevation.e1.shadow` passe à vrai : la règle `couche-1-sans-ombre` disparaît, le plein écran reste nu — test `test_rules_follow_e1_shadow` (Task 2).
3. Une fenêtre flottante en plein écran : la règle `plein-ecran-nu` vient après `couche-1-sans-ombre`, pour que la dernière règle qui correspond l'emporte — test `test_rules_order` (Task 2) ; vérification sur la session (Task 4).
4. Une machine neuve sans `generique.lua` : le point d'entrée charge tout de même les trois modules et les règles — test `test_without_generic` (Task 3).
5. Une fenêtre basculée de flottante à tuilée perd son ombre à chaud (effet dynamique) — vérification sur la session (Task 4).

---

### Task 1: Jetons de fenêtre et émetteur `hyprland-tokens.lua`

**Files:**
- Modify: `tokens.toml` (section `[radii]` vers la ligne 280 ; nouvelle section après `[radii]`)
- Modify: `dunei_theme/emitters/hyprland.py`
- Test: `tests/test_hyprland.py`
- Regenerate: `generated/hyprland-tokens.lua`, `tests/golden/hue-*/hyprland-tokens.lua`

**Interfaces:**
- Produces: `raw["window"]["border_width"]` (int), `raw["window"]["floating_shadow"]` (`range`, `offset_y`, `render_power`, int), `raw["radii"]["fullscreen"]` (int) ; `hyprland._rgba(col: Oklch, alpha: float) -> str` (`"rgba(rrggbbaa)"`) ; `hyprland._validate(raw: dict) -> None` (lève `ValueError`).

- [ ] **Step 1: Ajouter les jetons à `tokens.toml`**

Dans `[radii]`, après `small   = 4` :

```toml
fullscreen = 0               # plein écran : aucun effet, coins compris (bible, annexe E)
```

Juste après le bloc `[radii]` (avant la section suivante) :

```toml
[window]
border_width = 0             # aucune bordure de fenêtre ; la fenêtre active se signale au lot 2 (L2-03, D29)

[window.floating_shadow]     # couche 2 seulement ; une seule ombre, Hyprland n'en dessine qu'une (D30)
range = 16                   # px logiques, multiple de 4
offset_y = 4                 # px logiques vers le bas, multiple de 4
render_power = 2             # dégradé, de 1 (doux) à 4 (rapide), bornes de Hyprland
```

- [ ] **Step 2: Réécrire les tests de `tests/test_hyprland.py`**

Remplacer `expected`, `setUp`, `test_values_derive_from_tokens`, `test_no_literal_outside_model` et
`test_lua_loads_and_returns_table`, et ajouter les tests de refus :

```python
LITERAL = r'"#[0-9a-f]{6}"|"rgba\([0-9a-f]{8}\)"|\b\d+(?:\.\d+)?\b'


def expected(model: dict) -> dict:
    """Valeurs attendues — recalculées depuis le modèle, jamais recopiées.

    Entrée : model — sortie de model.resolve.
    Sortie : {option Lua: valeur textuelle attendue}. Erreurs : KeyError si un token manque.
    Dépendances : color.to_srgb255.
    """
    raw = model["raw"]
    d, s, mat = raw["density"]["comfortable"], raw["window"]["floating_shadow"], raw["surface_material"]
    r, g, b = to_srgb255(Oklch(**mat["shadow_color"]))
    return {
        "gaps_in": str(d["tiling_gutter"] // 2),
        "gaps_out": str(d["tiling_margin"]),
        "border_size": str(raw["window"]["border_width"]),
        "rounding": str(raw["radii"]["window"]),
        "range": str(s["range"]),
        "render_power": str(s["render_power"]),
        "offset": f"{{ 0, {s['offset_y']} }}",
        "color": f'"rgba({r:02x}{g:02x}{b:02x}{round(mat["shade_opacity"] * 255):02x})"',
    }
```

```python
    def setUp(self):
        self.data = load(ROOT / "tokens.toml")
        # Source altérée : prouve que les valeurs suivent les tokens au lieu d'être en dur.
        alt = copy.deepcopy(self.data)
        alt["density"]["comfortable"].update(tiling_gutter=12, tiling_margin=16)
        alt["radii"]["window"] = 7
        alt["window"]["border_width"] = 3
        alt["window"]["floating_shadow"].update(range=24, offset_y=8, render_power=3)
        alt["surface_material"]["shade_opacity"] = 0.5
        self.models = [resolve(self.data), resolve(self.data, 200), resolve(alt)]

    def test_values_derive_from_tokens(self):
        for m in self.models:
            lua = emit(m)
            for key, val in expected(m).items():
                with self.subTest(hue=m["hue"], option=key):
                    self.assertRegex(lua, rf"\b{key}\s*=\s*{re.escape(val)}")
            self.assertRegex(lua, r"enabled\s*=\s*true")
            self.assertNotIn("active_border", lua)  # plus aucune couleur de bordure (D29)

    def test_no_literal_outside_model(self):
        for m in self.models:
            body = code(emit(m))
            allowed = set(re.findall(LITERAL, " ".join(f" {v} " for v in expected(m).values())))
            literals = re.findall(LITERAL, body)
            with self.subTest(hue=m["hue"]):
                self.assertTrue(literals)
                self.assertEqual(set(literals) - allowed, set())

    def bad(self, **shadow) -> dict:
        """Modèle dont l'ombre flottante est altérée. Entrée : clés de floating_shadow. Sortie : modèle résolu."""
        alt = copy.deepcopy(self.data)
        alt["window"]["floating_shadow"].update(shadow)
        return resolve(alt)

    def test_shadow_rejects_range_off_grid(self):
        with self.assertRaisesRegex(ValueError, "range"):
            emit(self.bad(range=18))

    def test_shadow_rejects_offset_off_grid(self):
        with self.assertRaisesRegex(ValueError, "offset_y"):
            emit(self.bad(offset_y=6))

    def test_shadow_rejects_render_power(self):
        for power in (0, 5):
            with self.subTest(render_power=power), self.assertRaisesRegex(ValueError, "render_power"):
                emit(self.bad(render_power=power))

    def test_rejects_negative_border(self):
        alt = copy.deepcopy(self.data)
        alt["window"]["border_width"] = -1
        with self.assertRaisesRegex(ValueError, "border_width"):
            emit(resolve(alt))

    @unittest.skipUnless(LUA, "aucun interpréteur Lua")
    def test_lua_loads_and_returns_table(self):
        lua = emit(self.models[0])
        with tempfile.NamedTemporaryFile("w", suffix=".lua", encoding="utf-8") as fh:
            fh.write(lua)
            fh.flush()
            probe = (f't = dofile("{fh.name}"); '
                     'print(t.general.border_size, t.decoration.rounding, t.decoration.shadow.range, t.decoration.shadow.offset[2])')
            out = subprocess.run([LUA, "-e", probe], capture_output=True, text=True, check=True).stdout.split()
        exp = expected(self.models[0])
        self.assertEqual(out, [exp["border_size"], exp["rounding"], exp["range"], exp["offset"].split()[2]])
```

Imports en tête du fichier : remplacer `from dunei_theme.color import to_hex` par
`from dunei_theme.color import Oklch, to_srgb255`.

- [ ] **Step 3: Lancer les tests, constater l'échec**

Run: `python3 -m unittest tests.test_hyprland -v`
Expected: FAIL — `border_size` vaut encore 2, `active_border` est présent, aucun `ValueError` levé.

- [ ] **Step 4: Réécrire l'émetteur**

`dunei_theme/emitters/hyprland.py`, en entier :

```python
"""Cible Hyprland 0.56 — modules Lua de géométrie, d'ombre et de règles de fenêtre.

Chaque module RETOURNE des données, sans appeler `hl` lui-même :
    hl.config(require("generated.hyprland-tokens"))
Données pures, sans effet de bord au chargement : la configuration choisit quand
et comment les appliquer, un fragment machine peut les surcharger ensuite, et le
fichier se vérifie avec un interpréteur Lua nu, sans Hyprland.
"""

from __future__ import annotations

from ..color import Oklch, to_srgb255


def _rgba(col: Oklch, alpha: float) -> str:
    """Couleur translucide au format Hyprland `rgba(rrggbbaa)`.

    Entrées : col — couleur ; alpha — opacité de 0 à 1.
    Sortie : chaîne hexadécimale. Erreurs : aucune. Dépendances : color.to_srgb255.
    """
    return "rgba({:02x}{:02x}{:02x}{:02x})".format(*to_srgb255(col), round(alpha * 255))


def _validate(raw: dict) -> None:
    """Contrôles bloquants des jetons de fenêtre.

    Entrée : raw — TOML brut du modèle.
    Sortie : aucune.
    Erreurs : ValueError si la portée ou le décalage de l'ombre flottante n'est pas un multiple de la
              base (bible, ch. 3), si render_power sort des bornes de Hyprland (1 à 4), ou si
              border_width ou radii.fullscreen est négatif.
    Dépendances : aucune.
    """
    s, base = raw["window"]["floating_shadow"], raw["scaling"]["height_multiple"]
    for key in ("range", "offset_y"):
        if s[key] % base:
            raise ValueError(f"window.floating_shadow.{key} = {s[key]} n'est pas un multiple de {base}")
    if not 1 <= s["render_power"] <= 4:
        raise ValueError(f"window.floating_shadow.render_power = {s['render_power']} hors des bornes de Hyprland (1 à 4)")
    for name, val in (("window.border_width", raw["window"]["border_width"]), ("radii.fullscreen", raw["radii"]["fullscreen"])):
        if val < 0:
            raise ValueError(f"{name} = {val} : entier positif ou nul attendu")


def emit(model: dict) -> str:
    """Module Lua des options `general` et `decoration` de Hyprland.

    Entrée : model — sortie de model.resolve.
    Sortie : contenu de hyprland-tokens.lua (une table Lua retournée).
    Erreurs : KeyError si le TOML brut manque ; ValueError transmise par _validate.
    Dépendances : _validate, _rgba, color.Oklch.
    """
    raw = model["raw"]
    _validate(raw)
    d, s, mat = raw["density"]["comfortable"], raw["window"]["floating_shadow"], raw["surface_material"]
    return "\n".join([
        "-- GÉNÉRÉ depuis tokens.toml — NE PAS MODIFIER À LA MAIN",
        "-- Usage : hl.config(require(\"generated.hyprland-tokens\"))",
        f"-- thème : teinte {model['hue']}°",
        "return {",
        "    general = {",
        # Hyprland applique gaps_in de chaque côté : deux voisines donnent la gouttière entière.
        f"        gaps_in     = {d['tiling_gutter'] // 2},",
        f"        gaps_out    = {d['tiling_margin']},",
        f"        border_size = {raw['window']['border_width']},",
        "    },",
        "    decoration = {",
        f"        rounding = {raw['radii']['window']},",
        # Ombre globale de la couche 2 ; hyprland-rules.lua la retire aux fenêtres tuilées.
        "        shadow = {",
        "            enabled      = true,",
        f"            range        = {s['range']},",
        f"            render_power = {s['render_power']},",
        f"            offset       = {{ 0, {s['offset_y']} }},",
        f"            color        = \"{_rgba(Oklch(**mat['shadow_color']), mat['shade_opacity'])}\",",
        "        },",
        "    },",
        "}",
    ]) + "\n"
```

- [ ] **Step 5: Lancer les tests, constater le succès**

Run: `python3 -m unittest tests.test_hyprland -v`
Expected: PASS, tous les tests.

- [ ] **Step 6: Régénérer et vérifier la sortie**

Run: `make tokens && make golden && git diff --stat generated/ tests/golden/ && sed -n 1,30p generated/hyprland-tokens.lua`
Expected: seuls les cinq `hyprland-tokens.lua` changent (générés et quatre instantanés) ; on y lit
`border_size = 0`, `range = 16`, `render_power = 2`, `offset = { 0, 4 }`, `color = "rgba(0000005c)"`.

Run: `make test`
Expected: OK.

- [ ] **Step 7: Commit**

```bash
git add tokens.toml dunei_theme/emitters/hyprland.py tests/test_hyprland.py generated/hyprland-tokens.lua tests/golden/
git commit -m "Fenêtrage : jetons de fenêtre, plus de bordure, ombre de la couche 2 (L1-13, L1-15)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Règles d'apparence générées, `hyprland-rules.lua`

**Files:**
- Modify: `dunei_theme/emitters/hyprland.py` (ajout de `emit_rules`)
- Modify: `dunei_theme/emitters/__init__.py` (inscription de la cible)
- Modify: `deploy.py:28` (`COPIES`)
- Test: `tests/test_hyprland.py` (nouvelle classe `RulesTest`)
- Regenerate: `generated/hyprland-rules.lua`, `tests/golden/hue-*/hyprland-rules.lua`

**Interfaces:**
- Consumes: `_validate(raw)` de la tâche 1 ; jetons `elevation.e1.shadow`, `radii.fullscreen`.
- Produces: `hyprland.emit_rules(model: dict) -> str` ; fichier `generated/hyprland-rules.lua` qui retourne une liste de tables `{ name = …, match = {…}, <effets> }`, dans l'ordre `couche-1-sans-ombre` (si `elevation.e1.shadow` est faux) puis `plein-ecran-nu`.

- [ ] **Step 1: Écrire les tests**

Ajouter à `tests/test_hyprland.py` (importer aussi `emit_rules` depuis `dunei_theme.emitters.hyprland`) :

```python
class RulesTest(unittest.TestCase):
    """Règles de fenêtre générées : dérivées des jetons, dans l'ordre où la dernière l'emporte."""

    def setUp(self):
        self.data = load(ROOT / "tokens.toml")

    def rules(self, **edits) -> str:
        """Règles émises pour une source altérée. Entrée : e1_shadow, fullscreen. Sortie : texte Lua."""
        alt = copy.deepcopy(self.data)
        if "e1_shadow" in edits:
            alt["elevation"]["e1"]["shadow"] = edits["e1_shadow"]
        if "fullscreen" in edits:
            alt["radii"]["fullscreen"] = edits["fullscreen"]
        return emit_rules(resolve(alt))

    def test_rules_values(self):
        lua = self.rules()
        self.assertIn('{ name = "couche-1-sans-ombre", match = { float = false }, no_shadow = true },', lua)
        self.assertIn('{ name = "plein-ecran-nu", match = { fullscreen = true }, no_shadow = true, rounding = 0 },', lua)

    def test_rules_follow_fullscreen_radius(self):
        self.assertIn("rounding = 4", self.rules(fullscreen=4))

    def test_rules_follow_e1_shadow(self):
        lua = self.rules(e1_shadow=True)
        self.assertNotIn("couche-1-sans-ombre", lua)
        self.assertIn("plein-ecran-nu", lua)

    def test_rules_order(self):
        lua = self.rules()
        self.assertLess(lua.index("couche-1-sans-ombre"), lua.index("plein-ecran-nu"))

    @unittest.skipUnless(LUA, "aucun interpréteur Lua")
    def test_rules_load_as_list(self):
        with tempfile.NamedTemporaryFile("w", suffix=".lua", encoding="utf-8") as fh:
            fh.write(self.rules())
            fh.flush()
            probe = f't = dofile("{fh.name}"); for _, r in ipairs(t) do print(r.name) end'
            out = subprocess.run([LUA, "-e", probe], capture_output=True, text=True, check=True).stdout.split()
        self.assertEqual(out, ["couche-1-sans-ombre", "plein-ecran-nu"])
```

- [ ] **Step 2: Lancer les tests, constater l'échec**

Run: `python3 -m unittest tests.test_hyprland -v`
Expected: FAIL — `ImportError: cannot import name 'emit_rules'`.

- [ ] **Step 3: Écrire `emit_rules`**

Ajouter à la fin de `dunei_theme/emitters/hyprland.py` :

```python
def emit_rules(model: dict) -> str:
    """Module Lua des règles de fenêtre d'apparence, dérivées des jetons.

    Entrée : model — sortie de model.resolve.
    Sortie : contenu de hyprland-rules.lua (une liste Lua retournée, appliquée par modules/regles.lua).
             La règle de la couche 1 n'existe que si E1 n'a pas d'ombre ; le plein écran vient en
             dernier, pour l'emporter sur une fenêtre flottante en plein écran.
    Erreurs : KeyError si le TOML brut manque ; ValueError transmise par _validate.
    Dépendances : _validate.
    """
    raw = model["raw"]
    _validate(raw)
    rules = [] if raw["elevation"]["e1"]["shadow"] else [
        '    { name = "couche-1-sans-ombre", match = { float = false }, no_shadow = true },']
    rules.append('    { name = "plein-ecran-nu", match = { fullscreen = true }, no_shadow = true, '
                 f'rounding = {raw["radii"]["fullscreen"]} }},')
    return "\n".join([
        "-- GÉNÉRÉ depuis tokens.toml — NE PAS MODIFIER À LA MAIN",
        "-- Usage : for _, r in ipairs(require(\"generated.hyprland-rules\")) do hl.window_rule(r) end",
        "return {",
        *rules,
        "}",
    ]) + "\n"
```

Dans `dunei_theme/emitters/__init__.py`, après la ligne `hyprland-tokens.lua` :

```python
    "hyprland-rules.lua": hyprland.emit_rules,  # règles de fenêtre d'apparence (couche 1, plein écran)
```

Dans `deploy.py`, ligne 28 :

```python
COPIES = ("hyprland-tokens.lua", "hyprland-rules.lua", "motion.lua")  # Fichiers de generated/ lus par Hyprland.
```

- [ ] **Step 4: Régénérer, lancer tous les tests**

Dans `tests/test_deploy.py`, `assert_deployed` code les noms en dur ; il lit désormais la liste de
`deploy.py`, pour qu'un fichier ajouté à `COPIES` soit vérifié sans retoucher le test :

```python
from deploy import COPIES, config_home, plan
...
        for name in COPIES:
```

Run: `make tokens && make golden && cat generated/hyprland-rules.lua && make test`
Expected: le fichier contient les deux règles dans l'ordre ; `make test` OK, `test_deploy` compris.

- [ ] **Step 5: Commit**

```bash
git add dunei_theme/emitters/ deploy.py tests/test_hyprland.py tests/test_deploy.py generated/hyprland-rules.lua tests/golden/
git commit -m "Fenêtrage : règles de fenêtre générées, couche 1 sans ombre, plein écran nu (L1-15)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Modules `env`, `fenetres`, `regles` et point d'entrée

**Files:**
- Create: `config/hypr/modules/env.lua`
- Create: `config/hypr/modules/fenetres.lua`
- Create: `config/hypr/modules/regles.lua`
- Modify: `config/hypr/hyprland.lua`
- Create: `tests/test_hyprland_modules.py`
- Modify: `tests/test_hyprland_entry.py`

**Interfaces:**
- Consumes: `generated/hyprland-rules.lua` (tâche 2).
- Produces: modules exposant `apply()` sans argument ; `regles.behaviour`, liste des deux règles de comportement.

- [ ] **Step 1: Écrire les tests des modules**

`tests/test_hyprland_modules.py` :

```python
"""Modules env, fenetres et regles — exécutés par Lua avec un faux hl, dans un dossier imitant ~/.config/hypr."""

import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LUA = shutil.which("lua") or shutil.which("luajit")

# Faux hl : chaque appel imprime une ligne lisible par les tests.
FAKE = r"""
hl = {
    env = function(k, v) print("env", k, v) end,
    config = function(t) print("config", t.general.layout, tostring(t.dwindle.preserve_split)) end,
    window_rule = function(r) print("rule", r.name) end,
}
"""


@unittest.skipUnless(LUA, "aucun interpréteur Lua")
class ModulesTest(unittest.TestCase):
    """Chaque module applique exactement ce que la spec demande."""

    def run_module(self, name: str) -> list[str]:
        """Exécute require("modules.<name>").apply() avec le faux hl.

        Entrée : name — nom du module. Sortie : lignes imprimées par le faux hl.
        Erreurs : CalledProcessError si le module échoue.
        """
        with tempfile.TemporaryDirectory() as tmp:
            hypr = Path(tmp)
            (hypr / "generated").mkdir()
            shutil.copy(ROOT / "generated" / "hyprland-rules.lua", hypr / "generated")
            (hypr / "modules").symlink_to(ROOT / "config" / "hypr" / "modules")
            script = f'package.path = "{hypr}/?.lua"\n' + FAKE + f'require("modules.{name}").apply()\n'
            return subprocess.run([LUA, "-e", script], capture_output=True, text=True, check=True).stdout.splitlines()

    def test_env(self):
        self.assertEqual(self.run_module("env"), ["env\tQT_WAYLAND_DISABLE_WINDOWDECORATION\t1"])

    def test_fenetres(self):
        self.assertEqual(self.run_module("fenetres"), ["config\tdwindle\ttrue"])

    def test_regles_generated_then_behaviour(self):
        self.assertEqual(self.run_module("regles"), ["rule\tcouche-1-sans-ombre", "rule\tplein-ecran-nu",
                                                     "rule\tsans-agrandissement", "rule\tglisser-xwayland"])


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Adapter le test du point d'entrée**

Dans `tests/test_hyprland_entry.py` :

- dans `PROBE`, ajouter au faux `hl` :

```lua
    env = function(k) note("env:" .. k) end,
    window_rule = function(t) note("rule:" .. t.name) end,
```

- dans `probe`, copier aussi le nouveau fichier généré :

```python
            for name in ("hyprland-tokens.lua", "hyprland-rules.lua", "motion.lua"):
```

- remplacer les trois tests d'ordre :

```python
    MODULES = ("env:QT_WAYLAND_DISABLE_WINDOWDECORATION,config:dunei,rule:couche-1-sans-ombre,"
               "rule:plein-ecran-nu,rule:sans-agrandissement,rule:glisser-xwayland")

    def test_with_generic(self):
        self.assertEqual(self.probe(True, True),
                         [f"config:generique,config:dunei,animation,{self.MODULES},monitor:*,config:dunei,monitor:essai", "27"])

    def test_without_generic(self):
        self.assertEqual(self.probe(False, True),
                         [f"config:dunei,animation,{self.MODULES},monitor:*,config:dunei,monitor:essai", "27"])

    def test_without_machine(self):
        self.assertEqual(self.probe(True),
                         [f"config:generique,config:dunei,animation,{self.MODULES},monitor:*,config:dunei", "27"])
```

- [ ] **Step 3: Lancer les tests, constater l'échec**

Run: `python3 -m unittest tests.test_hyprland_modules tests.test_hyprland_entry -v`
Expected: FAIL — `module 'modules.env' not found` ; l'ordre du point d'entrée ne contient pas encore les modules.

- [ ] **Step 4: Écrire les trois modules**

`config/hypr/modules/env.lua` :

```lua
-- Module d'environnement : variables transmises par Hyprland aux clients qu'il lance.
-- Les variables de session (XDG_*, MOZ_ENABLE_WAYLAND) relèvent de la feature session (L1-10).
local M = {}

-- apply : déclare les variables d'environnement de DuneI.
-- Entrée : aucune. Sortie : aucune. Erreurs : celles de hl.env.
-- Dépendances : API hl de Hyprland 0.56.
-- QT_WAYLAND_DISABLE_WINDOWDECORATION retire les barres de titre que Qt dessine lui-même ; Hyprland
-- n'en dessine aucune, la fenêtre n'a donc plus de décoration (L1-14). Seuls les clients lancés après
-- le chargement voient la variable.
function M.apply()
    hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
end

return M
```

`config/hypr/modules/fenetres.lua` :

```lua
-- Module des fenêtres : disposition du tuilage. L'apparence (gouttières, rayon, ombre) vient des jetons.
local M = {}

-- apply : choisit la disposition dwindle et fige le sens des découpes.
-- Entrée : aucune. Sortie : aucune. Erreurs : celles de hl.config.
-- Dépendances : API hl de Hyprland 0.56.
-- dwindle est la valeur par défaut, écrite parce qu'elle est une décision (D28). Une nouvelle fenêtre
-- s'ouvre du côté du pointeur (force_split par défaut) ; preserve_split empêche une découpe de changer
-- de sens quand on redimensionne.
function M.apply()
    hl.config({ general = { layout = "dwindle" }, dwindle = { preserve_split = true } })
end

return M
```

`config/hypr/modules/regles.lua` :

```lua
-- Module des règles de fenêtre : apparence générée depuis les jetons, puis comportement.
-- Aucune valeur de design n'est écrite ici ; elles viennent de generated/hyprland-rules.lua.
local generated = require("generated.hyprland-rules")
local M = {}

-- Règles de comportement, reprises de la configuration générique ; elles ne portent aucune valeur de design.
M.behaviour = {
    -- Une application ne peut pas s'agrandir d'elle-même et casser le tuilage.
    { name = "sans-agrandissement", match = { class = ".*" }, suppress_event = "maximize" },
    -- Correctif du glisser-déposer XWayland : les fenêtres de transfert, sans classe ni titre, ne prennent pas le focus.
    { name = "glisser-xwayland", no_focus = true,
      match = { class = "^$", title = "^$", xwayland = true, float = true, fullscreen = false, pin = false } },
}

-- apply : déclare les règles générées, puis les règles de comportement.
-- Entrée : aucune. Sortie : aucune. Erreurs : celles de hl.window_rule.
-- Dépendances : generated.hyprland-rules, API hl de Hyprland 0.56.
-- Entre deux règles qui correspondent, la dernière déclarée l'emporte : l'ordre du fichier généré compte.
function M.apply()
    for _, rule in ipairs(generated) do hl.window_rule(rule) end
    for _, rule in ipairs(M.behaviour) do hl.window_rule(rule) end
end

return M
```

- [ ] **Step 5: Brancher le point d'entrée**

Dans `config/hypr/hyprland.lua`, entre le bloc du mouvement et celui des écrans :

```lua
-- Variables transmises aux clients : décorations dessinées par Qt retirées (L1-14).
require("modules.env").apply()

-- Disposition du tuilage : dwindle, découpes figées (L1-12, D28).
require("modules.fenetres").apply()

-- Règles de fenêtre : apparence générée depuis les jetons (couche 1, plein écran), puis comportement (L1-15).
require("modules.regles").apply()
```

Mettre à jour le commentaire de la ligne des jetons : `-- Gouttières, rayon, bordure et ombre, produits par generate_tokens.py.`

- [ ] **Step 6: Lancer tous les tests**

Run: `make test`
Expected: OK, `test_hyprland_modules`, `test_hyprland_entry` et `AgnosticTest` compris.

- [ ] **Step 7: Commit**

```bash
git add config/hypr/ tests/test_hyprland_modules.py tests/test_hyprland_entry.py
git commit -m "Fenêtrage : modules env, fenetres et regles branchés dans le point d'entrée (L1-12, L1-14, L1-15)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Installation sur `caladan`, retrait du générique, vérification et validation

**Files:**
- Modify (hors dépôt, avec l'accord de Nicolas) : `~/.config/hypr/generique.lua`

Cette tâche se fait dans la session principale, avec Nicolas : elle touche sa session vivante.

- [ ] **Step 1: Installer**

Run: `make check && make install && hyprctl configerrors`
Expected: `make check` sans diff ; `hyprland-rules.lua` copié sous `~/.config/hypr/generated/` ; aucune erreur de configuration.

- [ ] **Step 2: Retirer les blocs du générique, avec l'accord explicite de Nicolas**

Montrer à Nicolas les blocs visés, puis, après son accord, les retirer de `~/.config/hypr/generique.lua` :
l'appel `hl.config` qui contient `general` et `decoration` ; les appels `hl.config` de `dwindle`,
`master` et `scrolling` ; les trois `hl.window_rule` (`suppress-maximize-events`, `fix-xwayland-drags`,
`move-hyprland-run`) et la variable `suppressMaximizeRule`. Conserver les animations, `misc`,
`input`, les gestes, `hl.device`, les raccourcis et les variables `XCURSOR_SIZE` et `HYPRCURSOR_SIZE`.

Run: `hyprctl reload && hyprctl configerrors && grep -c "window_rule\|dwindle\|decoration\|general" ~/.config/hypr/generique.lua`
Expected: aucune erreur ; le décompte vaut 0.

- [ ] **Step 3: Vérifier les options (critère 1)**

Run:
```bash
for o in general:layout dwindle:preserve_split general:border_size decoration:shadow:enabled decoration:shadow:range decoration:shadow:render_power decoration:shadow:offset decoration:shadow:color; do hyprctl -j getoption $o | tr -d '\n'; echo; done
```
Expected: `dwindle`, vrai, 0, vrai, 16, 2, `[0,4]`, couleur noire d'alpha 0x5c. Si la couleur n'est
pas acceptée sous la forme `rgba(0000005c)`, corriger `_rgba` (tâche 1) vers le format que Hyprland
accepte, régénérer et relancer.

- [ ] **Step 4: Vérifier l'ombre des tuiles et des flottantes (critère 2, Review Focus 5)**

Ouvrir une fenêtre d'essai flottante sur un bureau vide et une tuile à côté :

```bash
hyprctl eval 'hl.window_rule({ name = "essai-flottant", match = { class = "dunei-essai" }, float = true, size = { 700, 450 }, center = true })'
hyprctl dispatch 'hl.dsp.exec_cmd("kitty --class dunei-essai")'
hyprctl dispatch 'hl.dsp.exec_cmd("kitty --class dunei-tuile")'
```

Demander à Nicolas d'afficher ce bureau, capturer avec `grim`, puis mesurer le profil de pixels sous
le bord inférieur de chaque fenêtre (script Python avec PIL, comme pour la bordure dans la conception) :
dégradé sombre sous la flottante, fond d'écran intact sous la tuile. Basculer ensuite la flottante en
tuile (`hyprctl dispatch 'hl.dsp.window.float({ window = "class:dunei-essai", action = "toggle" })'`),
recapturer : l'ombre a disparu. Fermer les fenêtres d'essai ; `hyprctl reload` efface la règle d'essai.

- [ ] **Step 5: Vérifier le plein écran (critère 3, Review Focus 3)**

Avec la fenêtre d'essai flottante, la passer en plein écran
(`hyprctl dispatch 'hl.dsp.window.fullscreen({ window = "class:dunei-essai", action = "set" })'`),
puis lire `hyprctl getprop class:dunei-essai rounding` et `hyprctl getprop class:dunei-essai no_shadow`.
Expected: 0 et vrai. Capture grim des coins de l'écran : aucun arrondi.

- [ ] **Step 6: Vérifier les dialogues et l'environnement (critères 4 et 5)**

Demander à Nicolas d'ouvrir le sélecteur de fichiers de Firefox (Ctrl+O), puis :
`hyprctl -j clients | python3 -c 'import json,sys; [print(c["class"], c["title"], c["floating"]) for c in json.load(sys.stdin)]'`
Expected: la fenêtre du dialogue est flottante.

Run: `cat /proc/$(pgrep -nx kitty)/environ | tr '\0' '\n' | grep QT_WAYLAND_DISABLE_WINDOWDECORATION`
(sur un kitty lancé après le rechargement). Expected: `=1`.

Chercher une application Qt installée : `for b in /usr/bin/*; do ldd "$b" 2>/dev/null | grep -q libQt6Widgets && echo "$b"; done | head`.
Si une application graphique s'y trouve, la lancer et vérifier l'absence de barre de titre par capture ;
sinon, noter au carnet que la vérification est reportée au lot 3.

- [ ] **Step 7: Validation de Nicolas (critère 8)**

Nicolas regarde le résultat sur sa session : tuiles sans bordure, flottante ombrée, plein écran nu.
Toute retouche de valeur passe par `tokens.toml`, puis `make install`.

---

### Task 5: Documentation

**Files:**
- Modify: `docs/journal-decisions.md`
- Modify: `docs/project_management/DuneI - Bible de Design.md`
- Modify: `docs/project_management/DuneI — Carnet d'installation, lot 1.md`
- Modify: `docs/project_management/DuneI — Périmètre et backlog de la 1.0.md`
- Modify: `docs/project_management/DuneI - Notes de Direction.md`
- Modify: `docs/superpowers/specs/2026-10-14-fenetrage-design.md` (statut « validée », version 0.2)

- [ ] **Step 1: Journal**

Ajouter une section `## 2026-10-14 — Fenêtrage (L1-12 à L1-15)` après D27, avec quatre décisions au
format des précédentes (titre `### Dxx · …`, paragraphes, raison, vérification, ligne `*Touché : …*`) :

- **D28 · Disposition dwindle ; placement au pointeur.** scrolling a été essayé en direct sur la session
  et rejeté par Nicolas à l'usage ; master et monocle écartés. Placement : côté du pointeur (défaut),
  préféré par Nicolas au côté fixe proposé ; `preserve_split` repris du générique.
- **D29 · Plus de bordure de fenêtre.** Jugée laide par Nicolas, sur le modèle de macOS ; la bible est
  modifiée, pas dérogée. La fenêtre active se signalera au lot 2 comme sur macOS et Windows : le chrome
  des fenêtres inactives perd sa couleur (modificateur `inactive`, L2-03). Une lueur intérieure
  (`decoration.glow`, trois variantes) a été essayée et rejetée. Constat consigné : à l'échelle 1,25,
  la bordure de 2 px logiques était rendue sur 3 pixels physiques pleins, sans flou ; le point laissé
  par D27 est donc clos. `states.focus.ring_width` reste un jeton des composants.
- **D30 · Ombre des fenêtres flottantes : une couche.** Hyprland ne dessine qu'une ombre par fenêtre ;
  un greffon à deux ombres n'existe pas et coûterait une recompilation à chaque version. Trois
  candidates puis deux moyennes essayées à l'écran ; retenue : portée 16, décalage 0/4, puissance 2,
  noir à 36 %. Constat : une ombre noire est invisible sur fond noir. L'ombre est globale et retirée
  aux tuiles par une règle générée depuis `elevation.e1.shadow`.
- **D31 · Coins, flou et plein écran.** Coins en arc de cercle (`rounding_power` 2, défaut), point de
  l'annexe C fermé par Nicolas. Flou renvoyé au lot 2 : invisible tant que les fenêtres sont opaques.
  Plein écran sans coins ni ombre, son rayon passant par le jeton `radii.fullscreen = 0` à la demande de
  Nicolas, pour qu'aucun rayon ne soit écrit dans `modules/`.

Inclure dans D29 à D31 les relevés de la tâche 4 (valeurs `getoption`, profils de pixels, dialogue).

- [ ] **Step 2: Bible (version 0.7, ligne d'historique)**

- ch. 3, « Rayons » : `Fenêtre 12 · panneau 10 · contrôle 6 · minuscule 4 · plein écran 0.`
- ch. 7, « Modificateur de conteneur `inactive` » : ajouter « **C'est le seul repère de la fenêtre
  active.** Aucun contour n'est tracé autour des fenêtres : comme sur macOS, la fenêtre active se
  reconnaît à ce que ses accents gardent leur couleur. »
- ch. 8, « Trois couches », couche 1 : « La hiérarchie se lit par les gouttières et par le chrome de la
  fenêtre active, qui garde ses accents. Disposition dwindle. » ; couche 2 : « Ombre douce, une seule
  couche. »
- ch. 12, « Décorations de fenêtre » : remplacer « et la fenêtre active porte déjà notre bordure
  accentuée » par « et la fenêtre active se reconnaît à ses accents, que les fenêtres inactives
  perdent » ; remplacer « dans une tuile déjà bordée » par « dans une tuile ».
- annexe C : retirer la ligne « Courbure des coins et flou des fenêtres tuilées » ; ajouter « Flou des
  overlays et de la couche 1 | Lot 2, avec l'opacité du voile » et « Ombre courte dans la gouttière de
  la fenêtre active | Piste du lot 2, non étudiée ».
- annexe E, couche 1, « Fenêtre tuilée » : retirer « Inactive → modificateur `container_inactive` » au
  profit de « Aucune bordure. Fenêtre active : modificateur `container_inactive` sur les autres » ;
  couche 2, « Fenêtre flottante » : « Une ombre : portée 16, décalage 4, noir à 36 %. Seul dépassement
  autorisé du système » ; « Média plein écran » : ajouter « Rayon 0 ».

- [ ] **Step 3: Carnet (version 1.0)**

- « Variables d'environnement » : le bloc devient `config/hypr/modules/env.lua` avec la seule variable
  Qt ; expliquer que les autres sont déjà présentes dans la session (Hyprland, `MOZ_ENABLE_WAYLAND`) ou
  inutiles en Qt 6 (`QT_QPA_PLATFORM`), et relèvent de L1-10.
- « La configuration lit les fichiers générés » : nouveau point d'entrée avec `env`, `fenetres`,
  `regles` ; retirer la phrase qui annonce `env`, `input`, `keybinds` et `rules` au profit de
  « Les modules du clavier et de l'entrée arriveront avec la feature raccourcis ».
- « Géométrie » : extrait généré à jour (`border_size = 0`, ombre), `hyprland-rules.lua` et ses deux
  règles ; remplacer la phrase sur la bordure à 2,5 pixels par le constat des 3 pixels pleins et le
  retrait de la bordure (D29).
- « Fenêtre active et inactive » : réécrite selon D29.
- Résultat de la vérification Qt de la tâche 4 (faite, ou reportée au lot 3).
- Tableau du point de départ : la configuration générique perd `general`, `decoration`, les
  dispositions et les règles de fenêtre.

- [ ] **Step 4: Backlog (version 1.8)**

- L1-12 : « **fait (D28)** : dwindle, placement au pointeur, découpes figées ».
- L1-13 : « Fenêtre active ; inactive → modificateur de conteneur — **fait (D29)** : aucune bordure ;
  le repère de la fenêtre active revient à L2-03 ».
- L1-14 : « **fait** : Hyprland ne dessine aucune barre de titre ; `QT_WAYLAND_DISABLE_WINDOWDECORATION` ».
- L1-15 : « **fait (D30, D31)** : ombre des flottantes 16/4/2, plein écran sans coins ni ombre ».
- L2-03 : ajouter « — seul repère de la fenêtre active (D29) ».
- Nouvelle ligne au lot 2 : « Flou des overlays et de la couche 1 ; ombre de gouttière de la fenêtre
  active, à étudier (D31) ».

- [ ] **Step 5: Notes de direction (version 1.7)**

Dernier paragraphe de « État d'avancement » : fenêtrage fait (L1-12 à L1-15) ; prochaine étape :
**la feature raccourcis (L1-16)**, qui rapatrie le clavier et les bureaux de `generique.lua`.

- [ ] **Step 6: Spec**

Statut « validée », version 0.2, ligne d'historique « Implémentée ; vérifications de la tâche 4 ».

- [ ] **Step 7: Commit**

```bash
git add docs/
git commit -m "Fenêtrage : documentation (journal D28 à D31, bible, carnet, backlog, direction)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: Clôture de la branche

- [ ] **Step 1: Vérification finale**

Run: `make check && git status`
Expected: tests OK, aucun diff dans `generated/`, arbre propre.

- [ ] **Step 2: Pousser et ouvrir la PR**

```bash
git push -u origin feat/fenetrage
gh pr create --title "Fenêtrage : disposition, bordure, couche 2 et décorations (L1-12 à L1-15)" --body "<résumé, critères vérifiés, décisions D28 à D31>

🤖 Generated with [Claude Code](https://claude.com/claude-code)"
```

Nicolas fusionne.
