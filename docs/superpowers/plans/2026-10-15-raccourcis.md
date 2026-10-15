# Raccourcis : clavier, gestes, bureaux et entrée — plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Décrire les raccourcis et les gestes de DuneI comme des données contrôlées, lancer les
applications par rôle, configurer l'entrée (Compose sur AltGr, pavé tactile), puis retirer de
`generique.lua` tout ce que cette feature remplace.

**Architecture:** Deux tables de données Lua, `config/hypr/donnees/raccourcis.lua` et
`config/hypr/donnees/roles.lua`, sans aucun appel à `hl`. Le module `config/hypr/modules/clavier.lua`
les contrôle (collisions, descriptions, actions, rôles, directions), puis lie chaque entrée non réservée
par un dictionnaire d'actions, seul endroit qui connaît `hl.dsp`. Le pas de redimensionnement vient d'un
jeton, émis dans un nouveau fragment `generated/hyprland-binds.lua`. Le module `entree.lua` porte les
réglages communs de l'entrée ; la disposition du clavier physique va dans le fichier machine.

**Tech Stack:** Python 3 (`unittest`), Lua 5.5 (`/usr/bin/lua`, pour les tests), API `hl` de
Hyprland 0.56, uwsm, make, `hyprctl`, `wev`, grim.

**Spec:** `docs/superpowers/specs/2026-10-15-raccourcis-design.md` (version 0.3)

## Global Constraints

- Chaque fonction porte un commentaire : titre et rôle, entrée(s), sortie, erreurs, dépendances (CLAUDE.md, règle 2), en phrases complètes et professionnelles.
- Code minimal (règle 3), modulaire (règle 4), indépendant de la machine (règle 5) : aucun matériel nommé hors de `config/hypr/machines/`.
- Aucune valeur de design dans `config/hypr/modules/` ni dans `config/hypr/donnees/` : le pas de redimensionnement vient de `generated/hyprland-binds.lua`.
- Jeton exact : `window.resize_step = 48`, entier, membre de `spacing.scale`. Contrôle **bloquant** (`ValueError` dans l'émetteur Hyprland).
- Grammaire : `SUPER` agit ou va ; `SUPER + SHIFT` emporte la fenêtre active ; `SUPER + CTRL` redimensionne ; `SUPER + ALT` porte les actions rares ou système.
- Bureau spécial : un seul, nommé `accueil`.
- Applications lancées par `uwsm app -- <commande du rôle>` ; session fermée par `uwsm stop`, jamais par `hl.dsp.exit()`.
- Envoyer au bureau : `follow = false`, écrit explicitement.
- Touches réservées, jamais liées : `SUPER + L` (L2-22), `SUPER + slash` (L2-28), `Print` (L2-30), `Control_L` en appui long (L2-36, nouvel élément).
- Ordre du point d'entrée : `generique → jetons → mouvement → env → fenetres → regles → ecrans → entree → clavier → machine`.
- La touche micro lance `wpctl` seul : la diode relève de L1-08 (spec, section 3.9).
- `generated/` ne s'édite jamais à la main. `~/.config/hypr/generique.lua` est hors dépôt ; il est sauvegardé dans le dossier temporaire de la session avant toute modification.
- La session de Nicolas recharge seule quand un fichier qu'elle a chargé change : `config/hypr/hyprland.lua` et `config/hypr/machines/caladan.lua` ne sont modifiés qu'à la tâche 4, dans l'ordre qu'elle donne.
- Messages, commentaires et documentation en français, avec accents. Aucun secret dans git.
- Commits terminés par `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Tests : `make test` (équivalent : `python3 -m unittest discover -s tests -t .`). Instantanés : `make golden`, uniquement pour un changement de sortie voulu.

## Review Focus

1. La même touche écrite deux fois sous deux formes (`super+c` et `SUPER + C`, ou `ALT + SUPER + C` et `SUPER + ALT + C`) : la collision est détectée — test `test_collision_written_differently` (Task 2).
2. Un appui long et un appui simple sur la même touche ne sont pas une collision, Hyprland les distingue — test `test_long_press_is_distinct` (Task 2).
3. Une table fausse ne lie **rien** : la session ne se retrouve jamais à moitié configurée — test `test_invalid_table_binds_nothing` (Task 2).
4. Une machine sans `generique.lua` ni fragment machine reçoit quand même tous les raccourcis — tests `test_without_generic`, `test_without_machine` (Task 4).
5. Pendant la transition sur la session vivante, les raccourcis du générique et ceux de DuneI ne coexistent jamais (`SUPER + M` quitterait la session au lieu d'agrandir) : le générique est nettoyé avant que le point d'entrée change (Task 4, étapes 3 et 4), et `hyprctl binds -j` ne montre aucun doublon (Task 5).

---

### Task 1: Jeton `resize_step` et fragment `hyprland-binds.lua`

**Files:**
- Modify: `tokens.toml` (section `[window]`, vers la ligne 288)
- Modify: `dunei_theme/emitters/hyprland.py` (`_validate`, nouvelle fonction `emit_binds`)
- Modify: `dunei_theme/emitters/__init__.py` (registre `TARGETS`)
- Test: `tests/test_hyprland.py`
- Regenerate: `generated/hyprland-binds.lua`, `tests/golden/hue-*/hyprland-binds.lua`

**Interfaces:**
- Produces: `raw["window"]["resize_step"]` (int) ; `hyprland.emit_binds(model: dict) -> str` ; fichier `generated/hyprland-binds.lua` qui retourne `{ resize_step = 48 }`.

- [ ] **Step 1: Écrire les tests qui échouent**

Dans `tests/test_hyprland.py`, ajouter `emit_binds` à l'import :

```python
from dunei_theme.emitters.hyprland import emit, emit_binds, emit_rules
```

et ajouter cette classe avant `if __name__ == "__main__":` :

```python
class BindsTest(unittest.TestCase):
    """Fragment lu par les raccourcis : le pas de redimensionnement vient des jetons et reste sur l'échelle."""

    def setUp(self):
        self.data = load(ROOT / "tokens.toml")

    def binds(self, step) -> str:
        """Fragment émis pour un pas donné. Entrée : step — valeur de window.resize_step. Sortie : texte Lua."""
        alt = copy.deepcopy(self.data)
        alt["window"]["resize_step"] = step
        return emit_binds(resolve(alt))

    def test_step_follows_token(self):
        self.assertIn("resize_step = 48,", emit_binds(resolve(self.data)))
        self.assertIn("resize_step = 64,", self.binds(64))

    def test_rejects_step_off_scale(self):
        for step in (40, 0, -48):
            with self.subTest(step=step), self.assertRaisesRegex(ValueError, "resize_step"):
                self.binds(step)

    def test_rejects_non_integer_step(self):
        for step in (48.0, True, "48"):
            with self.subTest(step=step), self.assertRaisesRegex(ValueError, "resize_step"):
                self.binds(step)

    @unittest.skipUnless(LUA, "aucun interpréteur Lua")
    def test_binds_load_as_table(self):
        with tempfile.NamedTemporaryFile("w", suffix=".lua", encoding="utf-8") as fh:
            fh.write(emit_binds(resolve(self.data)))
            fh.flush()
            out = subprocess.run([LUA, "-e", f'print(dofile("{fh.name}").resize_step)'],
                                 capture_output=True, text=True, check=True).stdout.split()
        self.assertEqual(out, ["48"])
```

- [ ] **Step 2: Vérifier qu'ils échouent**

Run: `python3 -m unittest tests.test_hyprland -v 2>&1 | tail -5`
Expected: ERROR à l'import (`cannot import name 'emit_binds'`).

- [ ] **Step 3: Ajouter le jeton**

Dans `tokens.toml`, section `[window]`, après la ligne `border_width = 0 …` :

```toml
resize_step = 48             # px logiques, pas de SUPER + Ctrl + flèche ; membre de spacing.scale
```

- [ ] **Step 4: Étendre `_validate` et écrire `emit_binds`**

Dans `dunei_theme/emitters/hyprland.py`, dans `_validate` :

1. Compléter la docstring, dans « Erreurs », par : `ou si window.resize_step n'appartient pas à spacing.scale (le pas de redimensionnement reste sur l'échelle des espacements).`
2. Ajouter le jeton au dictionnaire contrôlé, juste après la ligne `tokens |= {"window.border_width": …}` :

```python
    tokens["window.resize_step"] = raw["window"]["resize_step"]
```

3. À la fin de la fonction, après la boucle sur `border_width` et `radii.fullscreen` :

```python
    if tokens["window.resize_step"] not in raw["spacing"]["scale"]:
        raise ValueError(f"window.resize_step = {tokens['window.resize_step']} n'appartient pas à "
                         f"spacing.scale {raw['spacing']['scale']}")
```

Puis ajouter à la fin du fichier :

```python
def emit_binds(model: dict) -> str:
    """Module Lua des valeurs lues par les raccourcis.

    Entrée : model — sortie de model.resolve.
    Sortie : contenu de hyprland-binds.lua (une table Lua retournée, lue par modules/clavier.lua).
    Erreurs : KeyError si le TOML brut manque ; ValueError transmise par _validate.
    Dépendances : _validate.
    """
    raw = model["raw"]
    _validate(raw)
    return "\n".join([
        "-- GÉNÉRÉ depuis tokens.toml — NE PAS MODIFIER À LA MAIN",
        "-- Usage : local pas = require(\"generated.hyprland-binds\").resize_step",
        "return {",
        f"    resize_step = {raw['window']['resize_step']},",
        "}",
    ]) + "\n"
```

Le contrôle de type existant (`type(val) is not int`) refuse déjà `48.0`, `True` et `"48"`.

- [ ] **Step 5: Inscrire la cible**

Dans `dunei_theme/emitters/__init__.py`, après la ligne `"hyprland-rules.lua": …` :

```python
    "hyprland-binds.lua": hyprland.emit_binds,  # valeurs lues par les raccourcis (pas de redimensionnement)
```

- [ ] **Step 6: Régénérer et vérifier**

Run: `make tokens && make golden && python3 -m unittest tests.test_hyprland tests.test_golden -v 2>&1 | tail -3 && git status --short`
Expected: `OK` ; nouveaux fichiers `generated/hyprland-binds.lua` et `tests/golden/hue-{0,55,200,265}/hyprland-binds.lua` ; aucun autre fichier de `generated/` ni de `tests/golden/` modifié.

Run: `cat generated/hyprland-binds.lua`
Expected:
```lua
-- GÉNÉRÉ depuis tokens.toml — NE PAS MODIFIER À LA MAIN
-- Usage : local pas = require("generated.hyprland-binds").resize_step
return {
    resize_step = 48,
}
```

- [ ] **Step 7: Lancer toute la suite**

Run: `make test 2>&1 | tail -3`
Expected: `OK`. (Les tests de `deploy.py` ne sont pas encore concernés : `COPIES` change à la tâche 3.)

- [ ] **Step 8: Commit**

```bash
git add tokens.toml dunei_theme/emitters/hyprland.py dunei_theme/emitters/__init__.py tests/test_hyprland.py generated/hyprland-binds.lua tests/golden
git commit -m "Raccourcis : jeton window.resize_step et fragment hyprland-binds.lua

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Tables de données et module `clavier.lua`

**Files:**
- Create: `config/hypr/donnees/roles.lua`
- Create: `config/hypr/donnees/raccourcis.lua`
- Create: `config/hypr/modules/clavier.lua`
- Test: `tests/test_hyprland_clavier.py`

Aucun de ces fichiers n'est chargé par la session tant que le point d'entrée ne change pas (tâche 4).

**Interfaces:**
- Consumes: `generated/hyprland-binds.lua` → `{ resize_step = <int> }` (tâche 1).
- Produces:
  - `require("donnees.roles")` → table `{ terminal, fichiers, navigateur, lanceur }` de chaînes (commandes) ;
  - `require("donnees.raccourcis")` → `{ special = "accueil", touches = { <entrée>… }, gestes = { <geste>… } }`. Entrée : `touches` (chaîne au format de `hl.bind`), `action` (nom de `ACTIONS`), paramètres `direction` (`left|right|up|down`), `bureau` (entier ou `"e+1"`/`"e-1"`), `role`, `commande` ; `description` (obligatoire) ; `drapeaux` (table facultative) ; ou `reserve` (élément du backlog) sans action. Geste : `fingers`, `direction`, `action` (`workspace` ou `special`), `description` ;
  - `require("modules.clavier")` → `M.ACTIONS` (table nom → fonction(e, c) renvoyant un répartiteur), `M.normalise(touches: string, long: boolean?) -> string|nil`, `M.verifier(d, roles)` (lève une erreur), `M.apply(d?, roles?, binds?)`.

- [ ] **Step 1: Écrire les tests qui échouent**

Créer `tests/test_hyprland_clavier.py` :

```python
"""Module clavier — tables de données contrôlées puis liées, exécutées par Lua avec un faux hl."""

import shutil
import subprocess
import tempfile
import tomllib
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LUA = shutil.which("lua") or shutil.which("luajit")
STEP = tomllib.loads((ROOT / "tokens.toml").read_text(encoding="utf-8"))["window"]["resize_step"]

# Faux hl : hl.dsp enregistre le chemin et les arguments de chaque répartiteur ; bind et gesture
# impriment une ligne lisible. La description d'un raccourci est imprimée à part, comme un booléen.
FAKE = r"""
local function ser(v)
    if type(v) ~= "table" then return tostring(v) end
    local ks, out = {}, {}
    for k in pairs(v) do ks[#ks + 1] = k end
    table.sort(ks)
    for _, k in ipairs(ks) do out[#out + 1] = k .. "=" .. ser(v[k]) end
    return "{" .. table.concat(out, ",") .. "}"
end
local function dsp(path)
    return setmetatable({}, {
        __index = function(_, k) return dsp(path .. "." .. k) end,
        __call = function(_, a) return path .. "(" .. (a == nil and "" or ser(a)) .. ")" end,
    })
end
hl = {
    dsp = dsp("dsp"),
    bind = function(k, d, o)
        local f = {}
        for x, v in pairs(o) do if x ~= "description" then f[x] = v end end
        print("bind", k, d, ser(f), tostring(type(o.description) == "string" and o.description ~= ""))
    end,
    gesture = function(g) print("gesture", ser(g)) end,
    config = function(t) print("config", ser(t)) end,
}
"""

# Rôles d'essai : les logiciels réels sont provisoires, les tests n'en dépendent pas.
ROLES = '{ terminal = "T", fichiers = "F", navigateur = "N", lanceur = "L" }'

DIRS = {"left": (-1, 0), "right": (1, 0), "up": (0, -1), "down": (0, 1)}
HW = {
    "XF86AudioMute": ("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle", "{locked=true}"),
    "XF86AudioLowerVolume": ("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-", "{locked=true,repeating=true}"),
    "XF86AudioRaiseVolume": ("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+", "{locked=true,repeating=true}"),
    "XF86AudioMicMute": ("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle", "{locked=true}"),
    "XF86MonBrightnessDown": ("brightnessctl -e4 -n2 set 5%-", "{locked=true,repeating=true}"),
    "XF86MonBrightnessUp": ("brightnessctl -e4 -n2 set 5%+", "{locked=true,repeating=true}"),
}


def expected() -> dict[str, tuple[str, str]]:
    """Raccourcis attendus, d'après la section 3.3 de la spec.

    Entrée : aucune. Sortie : {combinaison: (répartiteur imprimé par le faux hl, drapeaux hors description)}.
    Erreurs : aucune. Dépendances : STEP, DIRS, HW.
    """
    e = {
        "SUPER + C": ("dsp.window.close()", "{}"),
        "SUPER + ALT + C": ("dsp.window.kill()", "{}"),
        "SUPER + M": ("dsp.window.fullscreen({action=toggle,mode=maximized})", "{}"),
        "SUPER + V": ("dsp.window.float({action=toggle})", "{}"),
        "SUPER + J": ("dsp.layout(togglesplit)", "{}"),
        "SUPER + ALT + P": ("dsp.window.pin({action=toggle})", "{}"),
        "SUPER + Tab": ("dsp.window.cycle_next({})", "{}"),
        "SUPER + S": ("dsp.workspace.toggle_special(accueil)", "{}"),
        "SUPER + SHIFT + S": ("dsp.window.move({follow=false,workspace=special:accueil})", "{}"),
        "SUPER + Q": ("dsp.exec_cmd(uwsm app -- T)", "{}"),
        "SUPER + E": ("dsp.exec_cmd(uwsm app -- F)", "{}"),
        "SUPER + F": ("dsp.exec_cmd(uwsm app -- N)", "{}"),
        "SUPER + R": ("dsp.exec_cmd(uwsm app -- L)", "{}"),
        "SUPER + ALT + M": ("dsp.exec_cmd(uwsm stop)", "{}"),
        "SUPER + ALT + R": ("dsp.reload_config()", "{}"),
        "SUPER + mouse:272": ("dsp.window.drag()", "{mouse=true}"),
        "SUPER + mouse:273": ("dsp.window.resize()", "{mouse=true}"),
        "SUPER + mouse_down": ("dsp.focus({workspace=e+1})", "{}"),
        "SUPER + mouse_up": ("dsp.focus({workspace=e-1})", "{}"),
    }
    for key, (cmd, flags) in HW.items():
        e[key] = (f"dsp.exec_cmd({cmd})", flags)
    for d, (x, y) in DIRS.items():
        e[f"SUPER + {d}"] = (f"dsp.focus({{direction={d}}})", "{}")
        e[f"SUPER + SHIFT + {d}"] = (f"dsp.window.move({{direction={d}}})", "{}")
        e[f"SUPER + CTRL + {d}"] = (f"dsp.window.resize({{relative=true,x={x * STEP},y={y * STEP}}})", "{}")
    for i in range(1, 11):
        e[f"SUPER + {i % 10}"] = (f"dsp.focus({{workspace={i}}})", "{}")
        e[f"SUPER + SHIFT + {i % 10}"] = (f"dsp.window.move({{follow=false,workspace={i}}})", "{}")
    return e


@unittest.skipUnless(LUA, "aucun interpréteur Lua")
class ClavierTest(unittest.TestCase):
    """La table réelle est liée comme la spec le demande ; une table fausse est refusée sans rien lier."""

    def run_lua(self, body: str) -> subprocess.CompletedProcess:
        """Exécute du Lua avec le faux hl, dans un dossier imitant ~/.config/hypr.

        Entrée : body — code Lua exécuté après le faux hl. Sortie : processus terminé (stdout, stderr).
        Erreurs : aucune ; le code de retour est laissé au test. Dépendances : FAKE, generated/.
        """
        with tempfile.TemporaryDirectory() as tmp:
            hypr = Path(tmp)
            (hypr / "generated").mkdir()
            shutil.copy(ROOT / "generated" / "hyprland-binds.lua", hypr / "generated")
            for d in ("modules", "donnees"):
                (hypr / d).symlink_to(ROOT / "config" / "hypr" / d)
            script = f'package.path = "{hypr}/?.lua"\n' + FAKE + body
            return subprocess.run([LUA, "-e", script], capture_output=True, text=True)

    def lines(self, body: str) -> list[list[str]]:
        """Lignes imprimées, découpées par tabulation. Erreurs : AssertionError si Lua échoue."""
        res = self.run_lua(body)
        self.assertEqual(res.returncode, 0, res.stderr)
        return [l.split("\t") for l in res.stdout.splitlines()]

    def apply_real(self) -> list[list[str]]:
        """Applique la table réelle avec les rôles d'essai."""
        return self.lines(f'require("modules.clavier").apply(nil, {ROLES})\n')

    def refusal(self, entries: str) -> str:
        """Message d'erreur de M.apply pour une table d'essai ; échoue si la table est acceptée.

        Entrée : entries — corps Lua de la liste touches. Sortie : stderr de Lua.
        """
        res = self.run_lua(f'require("modules.clavier").apply({{ special = "accueil", touches = {{ {entries} }}, '
                           f'gestes = {{}} }}, {ROLES})\n')
        self.assertNotEqual(res.returncode, 0, "la table aurait dû être refusée")
        self.assertNotIn("bind", res.stdout)
        return res.stderr

    def test_real_table_binds_as_specified(self):
        bound = {l[1]: (l[2], l[3]) for l in self.apply_real() if l[0] == "bind"}
        self.assertEqual(bound, expected())

    def test_every_bind_has_description(self):
        for l in self.apply_real():
            if l[0] == "bind":
                with self.subTest(touches=l[1]):
                    self.assertEqual(l[4], "true")

    def test_reserved_keys_are_not_bound(self):
        keys = {l[1] for l in self.apply_real() if l[0] == "bind"}
        for k in ("SUPER + L", "SUPER + slash", "Print", "Control_L"):
            self.assertNotIn(k, keys)

    def test_reserved_keys_are_declared(self):
        out = self.lines('for _, e in ipairs(require("donnees.raccourcis").touches) do '
                         'if e.reserve then print(e.touches, e.reserve) end end\n')
        self.assertEqual(sorted(map(tuple, out)), sorted([("SUPER + L", "L2-22"), ("SUPER + slash", "L2-28"),
                                                          ("Print", "L2-30"), ("Control_L", "L2-36")]))

    def test_gestures(self):
        gestures = [l[1] for l in self.apply_real() if l[0] == "gesture"]
        self.assertEqual(gestures, ["{action=workspace,direction=horizontal,fingers=3}",
                                    "{action=special,direction=down,fingers=3,workspace_name=accueil}"])

    def test_real_roles_cover_the_table(self):
        self.lines('local c = require("modules.clavier")\n'
                   'c.verifier(require("donnees.raccourcis"), require("donnees.roles"))\n')

    def test_collision_written_differently(self):
        for a, b in (("SUPER + C", "super+c"), ("SUPER + ALT + C", "ALT + SUPER + C"), ("SUPER + CTRL + x", "SUPER + CONTROL + X")):
            with self.subTest(a=a, b=b):
                err = self.refusal(f'{{ touches = "{a}", action = "fermer", description = "a" }}, '
                                   f'{{ touches = "{b}", action = "tuer", description = "b" }}')
                self.assertIn("entrée 2", err)
                self.assertIn("déjà prise par l'entrée 1", err)

    def test_collision_with_reserved(self):
        err = self.refusal('{ touches = "SUPER + L", reserve = "L2-22", description = "a" }, '
                           '{ touches = "SUPER + L", action = "fermer", description = "b" }')
        self.assertIn("déjà prise par l'entrée 1", err)

    def test_long_press_is_distinct(self):
        out = self.lines(f'require("modules.clavier").apply({{ special = "accueil", gestes = {{}}, touches = {{ '
                         '{ touches = "Control_L", action = "fermer", description = "a" }, '
                         '{ touches = "Control_L", action = "tuer", drapeaux = { long_press = true }, description = "b" } '
                         f'}} }}, {ROLES})\n')
        self.assertEqual(len([l for l in out if l[0] == "bind"]), 2)

    def test_refusals(self):
        cases = {
            "combinaison vide": '{ touches = "SUPER + ", action = "fermer", description = "a" }',
            "description manquante": '{ touches = "SUPER + C", action = "fermer" }',
            "action inconnue « fermr »": '{ touches = "SUPER + C", action = "fermr", description = "a" }',
            "rôle inconnu « editeur »": '{ touches = "SUPER + C", action = "role", role = "editeur", description = "a" }',
            "direction inconnue « gauche »": '{ touches = "SUPER + C", action = "focus", direction = "gauche", description = "a" }',
        }
        for message, entry in cases.items():
            with self.subTest(message=message):
                err = self.refusal(entry)
                self.assertIn("raccourcis, entrée 1 (", err)
                self.assertIn(message, err)

    def test_invalid_table_binds_nothing(self):
        err = self.refusal('{ touches = "SUPER + C", action = "fermer", description = "a" }, '
                           '{ touches = "SUPER + V", action = "inconnue", description = "b" }')
        self.assertIn("entrée 2", err)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Vérifier qu'ils échouent**

Run: `python3 -m unittest tests.test_hyprland_clavier 2>&1 | tail -3`
Expected: FAILED (le lien `donnees` pointe vers un dossier absent, `module 'modules.clavier' not found`).

- [ ] **Step 3: Écrire `config/hypr/donnees/roles.lua`**

```lua
-- Rôles applicatifs : le logiciel qui tient chaque rôle. Une touche lance un rôle, jamais un logiciel :
-- changer de terminal, c'est changer une ligne ici. Tous les choix sont provisoires ; les applications
-- se choisissent au lot 3. modules/clavier.lua préfixe chaque commande par « uwsm app -- ».
return {
    terminal   = "kitty",
    fichiers   = "dolphin",
    navigateur = "firefox",
    lanceur    = "wofi --show drun",  -- remplacé par le lanceur DuneI (L2-16)
}
```

- [ ] **Step 4: Écrire `config/hypr/donnees/raccourcis.lua`**

```lua
-- Raccourcis et gestes de DuneI : des données seulement, contrôlées puis liées par modules/clavier.lua.
-- Grammaire (bible, ch. 7) : SUPER agit ou va ; SUPER + SHIFT emporte la fenêtre active ;
-- SUPER + CTRL redimensionne ; SUPER + ALT porte les actions rares ou système.
-- Une entrée : touches (syntaxe de hl.bind), action et ses paramètres, description (obligatoire ; la
-- future cheatsheet l'affichera), drapeaux éventuels. Une entrée « reserve » prend la touche pour un
-- élément du backlog sans rien lier.
local M = { special = "accueil" }

M.touches = {
    -- Fenêtre active
    { touches = "SUPER + C",       action = "fermer",   description = "Fermer la fenêtre" },
    { touches = "SUPER + ALT + C", action = "tuer",     description = "Tuer l'application qui ne répond plus" },
    { touches = "SUPER + M",       action = "agrandir", description = "Agrandir la fenêtre ou la rendre à sa tuile" },
    { touches = "SUPER + V",       action = "flottant", description = "Rendre la fenêtre flottante ou tuilée" },
    { touches = "SUPER + J",       action = "decoupe",  description = "Changer le sens de découpe" },
    { touches = "SUPER + ALT + P", action = "epingler", description = "Épingler la fenêtre flottante sur tous les bureaux" },
    { touches = "SUPER + Tab",     action = "suivante", description = "Passer à la fenêtre suivante" },
    -- Bureau spécial
    { touches = "SUPER + S",         action = "special", description = "Afficher ou masquer l'accueil" },
    { touches = "SUPER + SHIFT + S", action = "ranger",  description = "Ranger la fenêtre dans l'accueil" },
    -- Applications, par rôle (donnees/roles.lua)
    { touches = "SUPER + Q", action = "role", role = "terminal",   description = "Ouvrir un terminal" },
    { touches = "SUPER + E", action = "role", role = "fichiers",   description = "Ouvrir le gestionnaire de fichiers" },
    { touches = "SUPER + F", action = "role", role = "navigateur", description = "Ouvrir le navigateur" },
    { touches = "SUPER + R", action = "role", role = "lanceur",    description = "Ouvrir le lanceur" },
    -- Session
    { touches = "SUPER + ALT + M", action = "commande", commande = "uwsm stop", description = "Quitter la session" },
    { touches = "SUPER + ALT + R", action = "recharger", description = "Recharger la configuration" },
    -- Souris
    { touches = "SUPER + mouse:272", action = "glisser", drapeaux = { mouse = true }, description = "Déplacer la fenêtre à la souris" },
    { touches = "SUPER + mouse:273", action = "etirer",  drapeaux = { mouse = true }, description = "Redimensionner la fenêtre à la souris" },
    { touches = "SUPER + mouse_down", action = "bureau", bureau = "e+1", description = "Bureau occupé suivant" },
    { touches = "SUPER + mouse_up",   action = "bureau", bureau = "e-1", description = "Bureau occupé précédent" },
    -- Touches matérielles, actives écran verrouillé ; la diode du micro relève de L1-08
    { touches = "XF86AudioMute", action = "commande", commande = "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle",
      drapeaux = { locked = true }, description = "Couper ou rétablir le son" },
    { touches = "XF86AudioLowerVolume", action = "commande", commande = "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-",
      drapeaux = { locked = true, repeating = true }, description = "Baisser le volume" },
    { touches = "XF86AudioRaiseVolume", action = "commande", commande = "wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+",
      drapeaux = { locked = true, repeating = true }, description = "Monter le volume, jusqu'à 100 %" },
    { touches = "XF86AudioMicMute", action = "commande", commande = "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle",
      drapeaux = { locked = true }, description = "Couper ou rétablir le micro" },
    { touches = "XF86MonBrightnessDown", action = "commande", commande = "brightnessctl -e4 -n2 set 5%-",
      drapeaux = { locked = true, repeating = true }, description = "Baisser la luminosité" },
    { touches = "XF86MonBrightnessUp", action = "commande", commande = "brightnessctl -e4 -n2 set 5%+",
      drapeaux = { locked = true, repeating = true }, description = "Monter la luminosité" },
    -- Réservées : la touche est prise, rien n'est lié avant l'élément du backlog
    { touches = "SUPER + L",     reserve = "L2-22", description = "Verrouiller la session" },
    { touches = "SUPER + slash", reserve = "L2-28", description = "Afficher les raccourcis" },
    { touches = "Print",         reserve = "L2-30", description = "Capturer l'écran" },
    { touches = "Control_L",     reserve = "L2-36", drapeaux = { long_press = true },
      description = "Montrer le pointeur, Ctrl tenu une seconde" },
}

-- Focus, déplacement et redimensionnement, dans les quatre directions.
for _, d in ipairs({ { "left", "la gauche" }, { "right", "la droite" }, { "up", "le haut" }, { "down", "le bas" } }) do
    local t = M.touches
    t[#t + 1] = { touches = "SUPER + " .. d[1], action = "focus", direction = d[1], description = "Focus vers " .. d[2] }
    t[#t + 1] = { touches = "SUPER + SHIFT + " .. d[1], action = "deplacer", direction = d[1],
                  description = "Déplacer la fenêtre vers " .. d[2] }
    t[#t + 1] = { touches = "SUPER + CTRL + " .. d[1], action = "redimensionner", direction = d[1],
                  description = "Redimensionner la fenêtre vers " .. d[2] }
end

-- Dix bureaux ; la touche 0 mène au bureau 10. Envoyer ne suit pas la fenêtre.
for i = 1, 10 do
    local t, k = M.touches, tostring(i % 10)
    t[#t + 1] = { touches = "SUPER + " .. k, action = "bureau", bureau = i, description = "Aller au bureau " .. i }
    t[#t + 1] = { touches = "SUPER + SHIFT + " .. k, action = "envoyer", bureau = i,
                  description = "Envoyer la fenêtre au bureau " .. i .. ", sans la suivre" }
end

M.gestes = {
    { fingers = 3, direction = "horizontal", action = "workspace", description = "Changer de bureau" },
    { fingers = 3, direction = "down",       action = "special",   description = "Afficher ou masquer l'accueil" },
}

return M
```

- [ ] **Step 5: Écrire `config/hypr/modules/clavier.lua`**

```lua
-- Module clavier : contrôle puis lie les raccourcis et les gestes de donnees/raccourcis.lua.
-- Les tables ne contiennent que des données ; ce module est le seul à connaître l'API hl. Ajouter une
-- action, c'est ajouter une ligne à ACTIONS ; changer de compositeur, c'est réécrire ACTIONS seul.
local M = {}

-- Vecteur de chaque direction, multiplié par le pas généré pour le redimensionnement.
local SENS = { left = { -1, 0 }, right = { 1, 0 }, up = { 0, -1 }, down = { 0, 1 } }
-- Actions qui exigent une direction de SENS.
local DIRIGEES = { focus = true, deplacer = true, redimensionner = true }
-- Nom canonique de chaque modificateur, pour reconnaître deux écritures de la même combinaison.
local MODS = { SUPER = "SUPER", SHIFT = "SHIFT", CTRL = "CTRL", CONTROL = "CTRL", ALT = "ALT" }

-- ACTIONS : construction du répartiteur de chaque action.
-- Entrées : e — entrée de la table ; c — contexte { roles, special, pas }.
-- Sortie : un répartiteur hl.dsp. Erreurs : celles de hl.dsp. Dépendances : API hl de Hyprland 0.56.
M.ACTIONS = {
    fermer         = function() return hl.dsp.window.close() end,
    tuer           = function() return hl.dsp.window.kill() end,
    agrandir       = function() return hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }) end,
    flottant       = function() return hl.dsp.window.float({ action = "toggle" }) end,
    decoupe        = function() return hl.dsp.layout("togglesplit") end,
    epingler       = function() return hl.dsp.window.pin({ action = "toggle" }) end,
    suivante       = function() return hl.dsp.window.cycle_next({}) end,
    focus          = function(e) return hl.dsp.focus({ direction = e.direction }) end,
    deplacer       = function(e) return hl.dsp.window.move({ direction = e.direction }) end,
    redimensionner = function(e, c)
        local v = SENS[e.direction]
        return hl.dsp.window.resize({ x = v[1] * c.pas, y = v[2] * c.pas, relative = true })
    end,
    bureau         = function(e) return hl.dsp.focus({ workspace = e.bureau }) end,
    envoyer        = function(e) return hl.dsp.window.move({ workspace = e.bureau, follow = false }) end,
    special        = function(_, c) return hl.dsp.workspace.toggle_special(c.special) end,
    ranger         = function(_, c) return hl.dsp.window.move({ workspace = "special:" .. c.special, follow = false }) end,
    role           = function(e, c) return hl.dsp.exec_cmd("uwsm app -- " .. c.roles[e.role]) end,
    commande       = function(e) return hl.dsp.exec_cmd(e.commande) end,
    recharger      = function() return hl.dsp.reload_config() end,
    glisser        = function() return hl.dsp.window.drag() end,
    etirer         = function() return hl.dsp.window.resize() end,
}

-- normalise : forme canonique d'une combinaison, pour détecter deux écritures de la même touche.
-- Entrées : touches — combinaison au format de hl.bind ; long — vrai pour un appui long.
-- Sortie : « MODS|TOUCHE », modificateurs triés, tout en majuscules, suffixé « |long » pour un appui
--          long ; nil si la combinaison ne nomme aucune touche. Erreurs : aucune. Dépendances : MODS.
function M.normalise(touches, long)
    local mods, keys = {}, {}
    for part in touches:gmatch("[^+]+") do
        local p = part:match("^%s*(.-)%s*$"):upper()
        if MODS[p] then mods[#mods + 1] = MODS[p] elseif p ~= "" then keys[#keys + 1] = p end
    end
    if #keys == 0 then return nil end
    table.sort(mods)
    return table.concat(mods, "+") .. "|" .. table.concat(keys, "+") .. (long and "|long" or "")
end

-- verifier : contrôle bloquant de la table, avant toute liaison.
-- Entrées : d — table de donnees/raccourcis.lua ; roles — table de donnees/roles.lua.
-- Sortie : aucune.
-- Erreurs : error() au premier défaut, avec le numéro et la combinaison de l'entrée : combinaison vide,
--           description manquante, action inconnue, rôle inconnu, direction inconnue, combinaison déjà
--           prise par une autre entrée (réservations comprises).
-- Dépendances : M.ACTIONS, M.normalise, SENS, DIRIGEES.
function M.verifier(d, roles)
    local vues = {}
    for i, e in ipairs(d.touches) do
        local nom = ("raccourcis, entrée %d (%s)"):format(i, tostring(e.touches))
        local cle = type(e.touches) == "string" and M.normalise(e.touches, e.drapeaux and e.drapeaux.long_press)
        if not cle then error(nom .. " : combinaison vide", 0) end
        if type(e.description) ~= "string" or e.description == "" then error(nom .. " : description manquante", 0) end
        if not e.reserve then
            if not M.ACTIONS[e.action] then error(nom .. " : action inconnue « " .. tostring(e.action) .. " »", 0) end
            if e.action == "role" and not roles[e.role] then error(nom .. " : rôle inconnu « " .. tostring(e.role) .. " »", 0) end
            if DIRIGEES[e.action] and not SENS[e.direction] then
                error(nom .. " : direction inconnue « " .. tostring(e.direction) .. " »", 0)
            end
        end
        if vues[cle] then error(nom .. " : combinaison déjà prise par l'entrée " .. vues[cle], 0) end
        vues[cle] = i
    end
end

-- apply : contrôle la table, puis lie chaque raccourci non réservé et chaque geste.
-- Entrées facultatives, pour les tests : d, roles, binds — par défaut donnees.raccourcis,
--          donnees.roles et generated.hyprland-binds.
-- Sortie : aucune. Erreurs : celles de M.verifier, levées avant toute liaison ; puis celles de hl.bind
--          et hl.gesture. L'erreur remonte dans Hyprland comme toute erreur de configuration.
-- Dépendances : M.verifier, M.ACTIONS, API hl de Hyprland 0.56.
function M.apply(d, roles, binds)
    d = d or require("donnees.raccourcis")
    roles = roles or require("donnees.roles")
    binds = binds or require("generated.hyprland-binds")
    M.verifier(d, roles)
    local c = { roles = roles, special = d.special, pas = binds.resize_step }
    for _, e in ipairs(d.touches) do
        if not e.reserve then
            local opts = { description = e.description }
            for k, v in pairs(e.drapeaux or {}) do opts[k] = v end
            hl.bind(e.touches, M.ACTIONS[e.action](e, c), opts)
        end
    end
    for _, g in ipairs(d.gestes) do
        hl.gesture({ fingers = g.fingers, direction = g.direction, action = g.action,
                     workspace_name = g.action == "special" and d.special or nil })
    end
end

return M
```

- [ ] **Step 6: Vérifier que les tests passent**

Run: `python3 -m unittest tests.test_hyprland_clavier -v 2>&1 | tail -15`
Expected: les 11 tests passent, `OK`.

Si `test_real_table_binds_as_specified` échoue, comparer l'écart à la spec (section 3.3) : la spec fait
foi ; une différence de forme du faux `hl` se corrige dans le test, une différence de fond dans la table.

- [ ] **Step 7: Lancer toute la suite**

Run: `make test 2>&1 | tail -3`
Expected: `OK`.

- [ ] **Step 8: Commit**

```bash
git add config/hypr/donnees config/hypr/modules/clavier.lua tests/test_hyprland_clavier.py
git commit -m "Raccourcis : tables de données et module clavier contrôlé

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Module `entree.lua` et déploiement de `donnees/` et de `hyprland-binds.lua`

**Files:**
- Create: `config/hypr/modules/entree.lua`
- Modify: `deploy.py:27-28` (`LINKS`, `COPIES`) et `deploy.py:113-115` (message de `hyprland.conf`)
- Test: `tests/test_hyprland_modules.py`, `tests/test_deploy.py`

**Interfaces:**
- Consumes: `config/hypr/donnees/` (tâche 2), `generated/hyprland-binds.lua` (tâche 1).
- Produces: `require("modules.entree").apply()` ; lien `~/.config/hypr/donnees` et copie `~/.config/hypr/generated/hyprland-binds.lua` après `make install`.

- [ ] **Step 1: Écrire les tests qui échouent**

Dans `tests/test_hyprland_modules.py`, remplacer la ligne `config = …` du faux `hl` par une version qui
reconnaît aussi la table d'entrée :

```python
    config = function(t)
        if t.input then
            print("input", t.input.kb_options, tostring(t.input.touchpad.natural_scroll),
                  tostring(t.input.touchpad.clickfinger_behavior), tostring(t.input.kb_layout))
        else
            print("config", t.general.layout, tostring(t.dwindle.preserve_split))
        end
    end,
```

et ajouter dans `ModulesTest` :

```python
    def test_entree(self):
        # La disposition dépend du clavier physique : elle vit dans le fichier machine, pas ici.
        self.assertEqual(self.run_module("entree"), ["input\tcompose:ralt\ttrue\ttrue\tnil"])
```

Dans `tests/test_deploy.py` :

1. Remplacer le corps de `test_copies_hyprland_files` :

```python
    def test_copies_hyprland_files(self):
        """Hyprland lit ces quatre fichiers générés : un oubli dans COPIES casserait tout le point d'entrée."""
        self.assertEqual(set(COPIES), {"hyprland-tokens.lua", "hyprland-rules.lua", "hyprland-binds.lua", "motion.lua"})
```

2. Dans `assert_deployed`, après la ligne qui vérifie le lien `machines` :

```python
        self.assertEqual(os.readlink(self.hypr / "donnees"), str(ROOT / "config" / "hypr" / "donnees"))
```

- [ ] **Step 2: Vérifier qu'ils échouent**

Run: `python3 -m unittest tests.test_hyprland_modules tests.test_deploy 2>&1 | tail -3`
Expected: FAILED (`module 'modules.entree' not found` ; `COPIES` sans `hyprland-binds.lua` ; lien `donnees` absent).

- [ ] **Step 3: Écrire `config/hypr/modules/entree.lua`**

```lua
-- Module d'entrée : réglages du clavier et du pavé tactile communs à toute machine.
-- La disposition dépend du clavier physique : elle vit dans machines/<nom-d-hôte>.lua. Seules les
-- valeurs différentes des défauts de Hyprland sont écrites ; restent aux défauts le focus qui suit la
-- souris, le pavé coupé pendant la frappe, le toucher qui vaut clic, l'accélération et les vitesses.
local M = {}

-- apply : déclare les réglages d'entrée de DuneI.
-- Entrée : aucune. Sortie : aucune. Erreurs : celles de hl.config.
-- Dépendances : API hl de Hyprland 0.56.
-- compose:ralt fait d'AltGr droite la touche Compose : AltGr relâchée, puis ' et e, donne é. Les
-- séquences viennent de la table Compose de la locale ; aucune n'est définie ici.
function M.apply()
    hl.config({
        input = {
            kb_options = "compose:ralt",
            touchpad = { natural_scroll = true, clickfinger_behavior = true },
        },
    })
end

return M
```

- [ ] **Step 4: Mettre à jour `deploy.py`**

```python
LINKS = ("config/hypr/modules", "config/hypr/machines", "config/hypr/donnees")  # Dossiers écrits à la main, liés sous hypr/ à leur nom.
COPIES = ("hyprland-tokens.lua", "hyprland-rules.lua", "hyprland-binds.lua", "motion.lua")  # Fichiers de generated/ lus par Hyprland.
```

et, dans `plan_hypr`, remplacer le message du `hyprland.conf` orphelin :

```python
        err.append(f"{dest / 'hyprland.conf'} existe : Hyprland l'ignorerait au profit du point d'entrée DuneI ; "
                   "le convertir en hyprland.lua d'abord")
```

Mettre à jour la docstring du module `deploy.py` si elle énumère les dossiers liés ou les fichiers
copiés (lire les lignes 1 à 20 et ajouter `donnees` et `hyprland-binds.lua` là où les autres sont cités).

- [ ] **Step 5: Vérifier que les tests passent**

Run: `make test 2>&1 | tail -3`
Expected: `OK`.

- [ ] **Step 6: Installer sur la session, sans rien activer**

Le point d'entrée ne change pas : la session ne charge ni `entree`, ni `clavier`, ni `donnees`.

Run: `make install && ls -l ~/.config/hypr/donnees ~/.config/hypr/generated/hyprland-binds.lua && hyprctl configerrors`
Expected: lien `donnees` vers le dépôt ; `hyprland-binds.lua` copié ; aucune erreur de configuration.

- [ ] **Step 7: Commit**

```bash
git add config/hypr/modules/entree.lua deploy.py tests/test_hyprland_modules.py tests/test_deploy.py
git commit -m "Raccourcis : module entree et déploiement des tables et du fragment généré

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Activation — générique nettoyé, point d'entrée et fichier machine

**Files:**
- Modify (hors dépôt) : `~/.config/hypr/generique.lua`
- Modify: `config/hypr/hyprland.lua`
- Modify: `config/hypr/machines/caladan.lua`
- Test: `tests/test_hyprland_entry.py`

Cette tâche se fait dans la session principale : chaque écriture de `hyprland.lua`, de `caladan.lua`
ou de `generique.lua` recharge la session de Nicolas. **L'ordre des étapes compte** (Review Focus 5) :
le générique perd ses raccourcis avant que le point d'entrée lie ceux de DuneI, pour qu'à aucun moment
`SUPER + M` ne quitte la session.

**Interfaces:**
- Consumes: `modules.entree` (tâche 3), `modules.clavier`, `donnees.*` (tâche 2), `generated.hyprland-binds` (tâche 1).

- [ ] **Step 1: Adapter le test du point d'entrée (il doit échouer)**

Dans `tests/test_hyprland_entry.py` :

1. Dans `PROBE`, remplacer la ligne `config = …` et ajouter `bind`, `gesture` et `dsp` à la table `hl` :

```lua
    config = function(t) note("config:" .. (t.source or (t.input and "input") or "dunei")) end,
    bind = function() note("bind") end,
    gesture = function() note("gesture") end,
    dsp = setmetatable({}, { __index = function(s) return s end, __call = function() return "dsp" end }),
```

Le faux `dsp` renvoie la même table pour tout accès (`hl.dsp.window.close`) et une valeur à tout appel :
seule la suite des appels intéresse ce test.

2. Dans `probe`, copier aussi le fragment des raccourcis et lier `donnees` :

```python
            for name in ("hyprland-tokens.lua", "hyprland-rules.lua", "hyprland-binds.lua", "motion.lua"):
                shutil.copy(ROOT / "generated" / name, hypr / "generated" / name)
            (hypr / "modules").symlink_to(ROOT / "config" / "hypr" / "modules")
            (hypr / "donnees").symlink_to(ROOT / "config" / "hypr" / "donnees")
```

3. Remplacer les trois attentes : la suite `monitor:*,config:dunei` est désormais suivie de
`config:input,bind,gesture` :

```python
    def test_with_generic(self):
        self.assertEqual(self.probe(True, True),
                         [f"config:generique,config:dunei,animation,{self.MODULES},monitor:*,config:dunei,"
                          "config:input,bind,gesture,monitor:essai", "27"])

    def test_without_generic(self):
        self.assertEqual(self.probe(False, True),
                         [f"config:dunei,animation,{self.MODULES},monitor:*,config:dunei,"
                          "config:input,bind,gesture,monitor:essai", "27"])

    def test_without_machine(self):
        self.assertEqual(self.probe(True),
                         [f"config:generique,config:dunei,animation,{self.MODULES},monitor:*,config:dunei,"
                          "config:input,bind,gesture", "27"])
```

4. Dans `AgnosticTest.test_no_output_named`, couvrir aussi les tables de données :

```python
        files = [ROOT / "config" / "hypr" / "hyprland.lua",
                 *sorted((ROOT / "config" / "hypr" / "modules").glob("*.lua")),
                 *sorted((ROOT / "config" / "hypr" / "donnees").glob("*.lua"))]
```

Run: `python3 -m unittest tests.test_hyprland_entry 2>&1 | tail -3`
Expected: FAILED sur les trois tests d'ordre (le point d'entrée n'appelle encore ni `entree` ni `clavier`).

- [ ] **Step 2: Sauvegarder le générique**

Run: `cp ~/.config/hypr/generique.lua "$SCRATCH/generique.lua.avant-raccourcis"` (où `$SCRATCH` est le
dossier temporaire de la session), puis `diff -q ~/.config/hypr/generique.lua "$SCRATCH/generique.lua.avant-raccourcis"`.
Expected: aucune différence.

- [ ] **Step 3: Retirer du générique l'entrée, les gestes et les raccourcis**

Annoncer à Nicolas que la session va perdre ses raccourcis pendant quelques secondes, puis retirer de
`~/.config/hypr/generique.lua`, en une seule écriture :

- le bloc « MY PROGRAMS » : les trois `local terminal`, `fileManager`, `menu` et leurs titres ;
- tout, depuis le titre du bloc « INPUT » jusqu'au titre du bloc « WINDOWS AND WORKSPACES » exclu :
  `hl.config({ input = … })`, `hl.gesture`, `hl.device` (`epic-mouse-v1`), `local mainMod` et tous les
  `hl.bind`.

```bash
python3 - "$HOME/.config/hypr/generique.lua" <<'EOF'
import re, sys
from pathlib import Path
p = Path(sys.argv[1])
s = p.read_text(encoding="utf-8")
s, n1 = re.subn(r"-+\n---- MY PROGRAMS ----\n-+\n.*?(?=\n-+\n---- AUTOSTART ----)", "", s, flags=re.S)
s, n2 = re.subn(r"-+\n---- INPUT ----\n-+\n.*?(?=-+\n---- WINDOWS AND WORKSPACES ----)", "", s, flags=re.S)
assert (n1, n2) == (1, 1), (n1, n2)
p.write_text(s, encoding="utf-8")
EOF
grep -c "hl.bind\|hl.gesture\|hl.device\|input\|mainMod\|terminal\|fileManager" ~/.config/hypr/generique.lua
```

Expected: le script se termine sans erreur ; le décompte vaut 0 (le mot « input » n'apparaît plus).
Le générique ne garde que l'en-tête, les commentaires d'autostart et de permissions, `XCURSOR_SIZE`,
`HYPRCURSOR_SIZE`, les courbes et animations, les règles commentées et `misc`.

Run: `hyprctl configerrors`
Expected: aucune erreur.

- [ ] **Step 4: Brancher le point d'entrée**

Dans `config/hypr/hyprland.lua`, entre le `require("modules.ecrans")` et le commentaire du fragment
machine :

```lua
-- Entrée commune : touche Compose, pavé tactile ; la disposition vit dans le fichier machine (L1-16).
require("modules.entree").apply()

-- Raccourcis et gestes, décrits par donnees/raccourcis.lua et donnees/roles.lua, contrôlés puis liés (L1-16).
require("modules.clavier").apply()
```

Run: `hyprctl configerrors && hyprctl -j binds | python3 -c 'import json,sys; print(len(json.load(sys.stdin)))'`
Expected: aucune erreur ; un nombre de raccourcis égal au nombre de clés de `expected()` dans
`tests/test_hyprland_clavier.py` (57).

- [ ] **Step 5: Déclarer la disposition dans le fichier machine**

Dans `config/hypr/machines/caladan.lua`, après la ligne d'écran interne :

```lua
-- Clavier interne en disposition britannique ; la touche Compose est commune (modules/entree.lua).
hl.config({ input = { kb_layout = "gb" } })
```

Mettre aussi à jour la première ligne de commentaire du fichier : « Le seul fichier où le matériel de
cette machine est nommé (écrans, disposition du clavier) ; chargé en dernier par modules/machine.lua. »

Run: `hyprctl configerrors && for o in input:kb_layout input:kb_options input:touchpad:natural_scroll input:touchpad:clickfinger_behavior; do hyprctl -j getoption $o | tr -d '\n'; echo; done`
Expected: aucune erreur ; `gb`, `compose:ralt`, vrai, vrai. Si `kb_options` ou les réglages du pavé
ont disparu, `hl.config` remplace la table `input` au lieu de la fusionner : déplacer alors l'appel du
fichier machine dans une variable lue par `entree.lua` (`require("modules.machine").clavier`) et
consigner le constat au journal.

- [ ] **Step 6: Vérifier la suite**

Run: `make test 2>&1 | tail -3`
Expected: `OK`.

- [ ] **Step 7: Commit**

```bash
git add config/hypr/hyprland.lua config/hypr/machines/caladan.lua tests/test_hyprland_entry.py
git commit -m "Raccourcis : point d'entrée branché, disposition dans le fichier machine

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Vérification sur la session et validation de Nicolas

**Files:** aucun, sauf correction d'un défaut constaté (retour à la tâche concernée, test d'abord).

Cette tâche se fait dans la session principale, avec Nicolas.

- [ ] **Step 1: Raccourcis liés (critère 1, Review Focus 5)**

```bash
hyprctl -j binds | python3 -c '
import json, sys, collections
b = json.load(sys.stdin)
keys = collections.Counter((x["modmask"], x["key"].lower(), x.get("longPress", False)) for x in b)
print("sans description :", [x["key"] for x in b if not x.get("description")])
print("doublons :", [k for k, n in keys.items() if n > 1])
print("réservées liées :", [x["key"] for x in b if x["key"].lower() in ("l", "slash", "print", "control_l") and x["modmask"] in (0, 64)])
'
```

Expected: trois listes vides. (`modmask` 64 = SUPER. Si le nom d'un champ diffère en 0.56, lire une
entrée brute avec `hyprctl -j binds | head -c 600` et adapter.)

- [ ] **Step 2: Envoyer sans suivre (critère 3)**

```bash
hyprctl dispatch 'hl.dsp.exec_cmd("kitty --class dunei-essai")'; sleep 1
avant=$(hyprctl -j activeworkspace | python3 -c 'import json,sys; print(json.load(sys.stdin)["id"])')
hyprctl dispatch 'hl.dsp.window.move({ window = "class:dunei-essai", workspace = 9, follow = false })'
apres=$(hyprctl -j activeworkspace | python3 -c 'import json,sys; print(json.load(sys.stdin)["id"])')
echo "$avant $apres"; hyprctl -j clients | python3 -c 'import json,sys; [print(c["class"], c["workspace"]["id"]) for c in json.load(sys.stdin) if c["class"] == "dunei-essai"]'
```

Expected: `avant` = `apres` ; la fenêtre d'essai est sur le bureau 9. Fermer ensuite la fenêtre d'essai
(`hyprctl dispatch 'hl.dsp.window.close({ window = "class:dunei-essai" })'`).

- [ ] **Step 3: Agrandir et la règle `plein-ecran-nu` (critère 9)**

Ouvrir une fenêtre d'essai tuilée à côté d'une autre, puis :

```bash
hyprctl dispatch 'hl.dsp.window.fullscreen({ window = "class:dunei-essai", mode = "maximized", action = "set" })'
hyprctl -j clients | python3 -c 'import json,sys; [print(c["fullscreen"], c.get("fullscreenClient")) for c in json.load(sys.stdin) if c["class"] == "dunei-essai"]'
hyprctl getprop class:dunei-essai rounding; hyprctl getprop class:dunei-essai no_shadow
```

Demander à Nicolas d'afficher ce bureau, capturer avec `grim -g "<x>,<y> 60x60"` le coin supérieur
gauche de la fenêtre (coordonnées lues dans `hyprctl -j clients`), et regarder la capture. Consigner le
constat (état `fullscreen` 1 ou 2, valeur de `rounding`, coins visibles ou non) : il tranche le point
ouvert de D31 et va au journal. Ne rien changer à la règle dans cette feature si l'état agrandi garde ses
coins : c'est le comportement attendu d'une fenêtre qui garde ses gouttières ; le signaler à Nicolas
pour décision.

- [ ] **Step 4: Pas de redimensionnement (critère 4)**

Avec deux tuiles côte à côte, lire la largeur de la fenêtre active (`hyprctl -j activewindow`, champ
`size`), demander à Nicolas d'appuyer une fois sur `SUPER + Ctrl + →`, relire la largeur.
Expected: + 48 px logiques (± 1 pour l'arrondi de la découpe).

- [ ] **Step 5: Accents (critère 5)**

Demander à Nicolas de taper, dans kitty puis dans Firefox, avec AltGr relâchée avant chaque séquence :
`^o ^a ^e ^i ^u`, `` `a `e `u ``, `'e`, `"e "i "u`, `,c`, `oe`, `<<`, `>>`, puis `'E` et `,C` avec Maj,
puis `'e` avec le Verrouillage majuscules.
Expected: `ô â ê î û à è ù é ë ï ü ç œ « » É Ç É`.

- [ ] **Step 6: Touches matérielles, gestes et souris (critères 6 et 7)**

Demander à Nicolas d'essayer : sourdine, volume −/+, sourdine micro, luminosité −/+. Le verrouillage
n'existe pas encore : vérifier seulement que `hyprctl -j binds` marque ces six entrées `locked`, et
le volume et la luminosité `repeating`. La diode du micro n'est pas jugée ici (L1-08). Si une touche
ne répond pas, relever son nom avec `wev -f wl_keyboard:key` et corriger
la table (tâche 2, test d'abord). Puis : glisser à trois doigts à l'horizontale (bureaux), vers le bas
(accueil) ; `SUPER + clic gauche` et `SUPER + clic droit` glissés ; `SUPER + molette`.

- [ ] **Step 7: Validation famille par famille (critère 12)**

Nicolas essaie chaque famille de la spec (section 3.3) : fenêtre, focus, déplacement, taille, bureaux,
accueil, applications, recharger. Toute retouche passe par la table et ses tests, puis `make install`.

- [ ] **Step 8: Sortie de session (critère 8), en tout dernier**

Claude Code tourne dans la session : `SUPER + Alt + M` ferme aussi cette conversation. L'essai se fait
après le commit de la documentation (tâche 6), quand Nicolas le décide ; il rapporte le résultat dans la
session suivante, qui vérifie `journalctl --user -b -u 'wayland-wm@*' | tail` (arrêt propre, sans
« killed »).

---

### Task 6: Documentation

**Files:**
- Modify: `docs/project_management/DuneI - Bible de Design.md` (ch. 7, section « Clavier », et historique)
- Modify: `docs/journal-decisions.md`
- Modify: `docs/project_management/DuneI — Carnet d'installation, lot 1.md`
- Modify: `docs/project_management/DuneI — Périmètre et backlog de la 1.0.md`
- Modify: `docs/project_management/DuneI - Notes de Direction.md`
- Modify: `docs/superpowers/specs/2026-10-15-raccourcis-design.md` (statut « implémentée », version 0.4)

Chaque document reçoit un numéro de version en tête et une ligne dans sa table « Historique des
versions » (CLAUDE.md). Lire la version courante de chacun avant de l'incrémenter.

- [ ] **Step 1: Bible**

Dans la section « Clavier » du chapitre 7, après la phrase « Tout est atteignable à la tabulation… » :

```markdown
**Grammaire des raccourcis du système.** `SUPER` agit ou va ; `SUPER + Maj` emporte la fenêtre active
(la même action, la fenêtre suit) ; `SUPER + Ctrl` redimensionne ; `SUPER + Alt` porte les actions rares
ou système, que la touche supplémentaire protège d'un appui accidentel. Un raccourci qui déroge à cette
grammaire est une dérogation, consignée au journal.
```

- [ ] **Step 2: Journal**

Ajouter, après D32, une section `## 2026-10-15 — Raccourcis (L1-16)` avec, dans le style des décisions
précédentes (titre, décision, raison, qui a décidé, « *Touché : …* ») :

- **D33 · Grammaire des modificateurs ; table construite touche par touche.** Base ni carnet ni générique ; choix de Nicolas famille par famille ; collision `SUPER + M` relevée en conception (agrandir garde `M`, quitter prend `Alt + M`) ; focus Vim écarté (`J` = découpe).
- **D34 · Raccourcis en données, applications par rôle.** Approche A (table Lua + module) contre B (TOML et générateur) et C (appels directs) ; contrôles bloquants ; `uwsm app --` ; jeton `window.resize_step = 48`, membre de l'échelle.
- **D35 · Touches réservées pour le lot 2.** `SUPER + L`, `SUPER + /`, `Print`, Ctrl tenu une seconde ; halo du pointeur : Hyprland ne sait pas le dessiner, élément L2-36 ; appui long sur SUPER écarté (SUPER commence tous les raccourcis). Éteindre, redémarrer et veille sans raccourci, et pourquoi.
- **D36 · Compose sur AltGr ; disposition dans le fichier machine.** Séquences de la locale, aucune définie ; la disposition suit le clavier physique.
- **D37 · Sortie par `uwsm stop` ; touches multimédia retirées ; diode du micro renvoyée à L1-08.** Le relevé de la spec, section 3.9, recopié.
- Le constat de la tâche 5, étape 3, sur l'état agrandi et `plein-ecran-nu`, ajouté à D31 comme suite datée (« Suite du 2026-10-15 : … »).

- [ ] **Step 3: Carnet**

- Section « Bureaux et raccourcis » réécrite : la grammaire, la table finale de la spec (section 3.3),
  le bureau `accueil`, les réservations, les rôles provisoires (kitty au lieu de foot, en attente de L1-18).
- Section « Entrée » : la configuration réelle (`modules/entree.lua`, `kb_layout` dans le fichier
  machine), et la liste des séquences Compose.
- Section « Touches matérielles » : commandes réelles ; diode du micro renvoyée à L1-08 avec le relevé.
- Section « La configuration lit les fichiers générés » : le bloc du point d'entrée reçoit les deux
  `require` ; la phrase « Les modules du clavier et de l'entrée s'ajouteront… » est retirée.
- Section « Déploiement » : `donnees/` lié, `hyprland-binds.lua` copié ; le paragraphe « Machine
  installée directement en DuneI » ne dit plus que la session n'a aucun raccourci.
- Historique des versions.

- [ ] **Step 4: Backlog**

- L1-16 : « **fait (D33 à D37)** : table de données contrôlée, rôles, grammaire, Compose, touches réservées » et l'issue du point de D31.
- L1-08 : ajouter « diode du micro : ne suit pas `wpctl` (relevé du 2026-10-15) ; remède retenu : aligner les contrôles de `ctl-led` avec `amixer` (`alsa-utils`) ».
- Nouvel élément `| L2-36 | B | Écrit | Localiser le pointeur — halo autour du pointeur, Ctrl gauche tenu une seconde (touche réservée en L1-16) |`.
- L2-16, L2-22, L2-28, L2-30 : noter la touche réservée (`SUPER + R`, `SUPER + L`, `SUPER + /`, `Print`).
- Décomptes : 141 → 142 éléments, partout où le total est écrit (`grep -n "141" <backlog> <notes>`).
- Historique des versions.

- [ ] **Step 5: Notes de direction**

Ajouter à la fin du journal d'avancement un paragraphe **« Raccourcis — 15 octobre 2026. »** : table de
données contrôlée, rôles provisoires, grammaire inscrite à la bible, Compose sur AltGr, touches
réservées, `generique.lua` réduit aux courbes, à `misc` et au curseur ; diode du micro renvoyée à L1-08.
Dernière phrase : « Prochaine étape du lot 1 : **L1-08, le pont de la diode du micro**, puis la
vérification audio. » Mettre à jour les décomptes et l'historique des versions.

- [ ] **Step 6: Spec**

Statut « validée, implémentée », version 0.4, ligne d'historique.

- [ ] **Step 7: Commit**

```bash
git add docs
git commit -m "Raccourcis : documentation (bible, journal D33 à D37, carnet, backlog, notes de direction)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: Clôture de la branche

- [ ] **Step 1: Vérification finale**

Run: `make check && git status`
Expected: tests OK, aucun diff dans `generated/`, arbre propre.

- [ ] **Step 2: Pousser et ouvrir la PR**

```bash
git push -u origin feat/raccourcis
gh pr create --title "Raccourcis : clavier, gestes, bureaux et entrée (L1-16)" --body "<résumé, critères vérifiés, décisions D33 à D37, point de D31 tranché, diode renvoyée à L1-08>

🤖 Generated with [Claude Code](https://claude.com/claude-code)"
```

- [ ] **Step 3: Relecture finale de la branche**

Relecture complète par un relecteur neuf (superpowers:requesting-code-review) ; corriger les constats
critiques et importants, test d'abord, puis repousser.

- [ ] **Step 4: Fusion et procédure après fusion**

Quand la relecture est propre et que Nicolas a validé à l'écran (tâche 5) : `gh pr merge <n> --merge`,
sans `--delete-branch` (D32), puis appliquer la procédure après fusion du carnet. Rappeler à Nicolas
l'essai de `SUPER + Alt + M` (tâche 5, étape 8) s'il n'a pas encore été fait.
