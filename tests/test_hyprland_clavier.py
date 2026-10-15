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
    unbind = function(k) print("unbind", k) end,
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
        "SUPER + ALT + R": ("dsp.exec_cmd(hyprctl reload)", "{}"),
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
            "paramètre « commande » manquant": '{ touches = "SUPER + C", action = "commande", comande = "ls", description = "a" }',
            "paramètre « bureau » manquant": '{ touches = "SUPER + C", action = "envoyer", description = "a" }',
            "paramètre « role » manquant": '{ touches = "SUPER + C", action = "role", description = "a" }',
        }
        for message, entry in cases.items():
            with self.subTest(message=message):
                err = self.refusal(entry)
                self.assertIn("raccourcis, entrée 1 (", err)
                self.assertIn(message, err)

    def test_unbinds_every_key_before_binding(self):
        out = self.apply_real()
        unbound = [l[1] for l in out if l[0] == "unbind"]
        first_bind = next(i for i, l in enumerate(out) if l[0] == "bind")
        self.assertEqual(set(unbound), set(expected()) | {"SUPER + L", "SUPER + slash", "Print", "Control_L"})
        self.assertTrue(all(l[0] == "unbind" for l in out[:first_bind]))
        self.assertEqual(len(unbound), first_bind)

    def test_builder_error_names_entry_and_binds_nothing(self):
        res = self.run_lua(f'require("modules.clavier").apply(nil, {ROLES}, {{}})\n')
        self.assertNotEqual(res.returncode, 0)
        self.assertNotIn("bind", res.stdout)
        self.assertIn("raccourcis, entrée", res.stderr)
        self.assertIn("SUPER + CTRL + left", res.stderr)

    def gesture_refusal(self, gestes: str) -> str:
        """Message d'erreur de M.apply pour des gestes d'essai, avec une touche valide.

        Entrée : gestes — corps Lua de la liste gestes. Sortie : stderr de Lua.
        Erreurs : AssertionError si la table est acceptée ou si une touche a été liée.
        Dépendances : run_lua, ROLES.
        """
        res = self.run_lua(f'require("modules.clavier").apply({{ special = "accueil", gestes = {{ {gestes} }}, touches = {{ '
                           f'{{ touches = "SUPER + C", action = "fermer", description = "a" }} }} }}, {ROLES})\n')
        self.assertNotEqual(res.returncode, 0, "les gestes auraient dû être refusés")
        self.assertNotIn("bind", res.stdout)
        return res.stderr

    def test_gesture_refusals(self):
        cases = {
            "action inconnue « specail »": '{ fingers = 3, direction = "down", action = "specail", description = "a" }',
            "description manquante": '{ fingers = 3, direction = "down", action = "special" }',
            "doigts ou direction invalides": '{ fingers = "3", direction = "down", action = "special", description = "a" }',
            "déjà pris par le geste 1": '{ fingers = 3, direction = "down", action = "special", description = "a" }, '
                                        '{ fingers = 3, direction = "down", action = "workspace", description = "b" }',
        }
        for message, gestes in cases.items():
            with self.subTest(message=message):
                err = self.gesture_refusal(gestes)
                self.assertIn("raccourcis, geste", err)
                self.assertIn(message, err)

    def test_invalid_table_binds_nothing(self):
        err = self.refusal('{ touches = "SUPER + C", action = "fermer", description = "a" }, '
                           '{ touches = "SUPER + V", action = "inconnue", description = "b" }')
        self.assertIn("entrée 2", err)


if __name__ == "__main__":
    unittest.main()
