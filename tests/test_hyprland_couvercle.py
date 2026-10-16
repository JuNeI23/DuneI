"""Module couvercle — exécuté par Lua avec un faux hl ; l'état du couvercle est imposé par M.etat."""

import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LUA = shutil.which("lua") or shutil.which("luajit")

# Faux hl : MONITORS est la liste des écrans actifs ; chaque effet imprime une ligne.
FAKE = r"""
MONITORS = {}
hl = {
    get_monitors = function()
        local t = {}
        for _, n in ipairs(MONITORS) do t[#t + 1] = { name = n } end
        return t
    end,
    monitor = function(r) print("monitor", r.output, tostring(r.disabled)) end,
    exec_cmd = function(c) print("exec", c) end,
    bind = function(k, f, o) print("bind", k, type(f), tostring(o.locked), tostring(o.submap_universal), tostring(o.description ~= nil)) end,
    on = function(e, f) print("on", e, type(f)) end,
}
M = require("modules.couvercle")
M.etat = "echo 'b false'"
"""


@unittest.skipUnless(LUA, "aucun interpréteur Lua")
class CouvercleTest(unittest.TestCase):
    """Écran interne désactivé couvercle fermé quand un autre écran est actif, rétabli sinon."""

    def lines(self, code: str) -> list[list[str]]:
        """Exécute code après le faux hl et rend les lignes imprimées, découpées sur les tabulations."""
        with tempfile.TemporaryDirectory() as tmp:
            hypr = Path(tmp)
            (hypr / "modules").symlink_to(ROOT / "config" / "hypr" / "modules")
            script = f'package.path = "{hypr}/?.lua"\n' + FAKE + code
            res = subprocess.run([LUA, "-e", script], capture_output=True, text=True)
            self.assertEqual(res.returncode, 0, res.stderr)
            return [l.split("\t") for l in res.stdout.splitlines()]

    def test_internal_detection(self):
        out = self.lines('for _, n in ipairs({ "eDP-1", "LVDS-2", "DSI-1", "DP-1", "HDMI-A-1" }) do '
                         'print(n, tostring(M.est_interne(n))) end\n'
                         'M.interne = "DP-3"\nprint("DP-3", tostring(M.est_interne("DP-3")), tostring(M.est_interne("eDP-1")))\n')
        self.assertEqual(out, [["eDP-1", "true"], ["LVDS-2", "true"], ["DSI-1", "true"], ["DP-1", "false"],
                               ["HDMI-A-1", "false"], ["DP-3", "true", "false"]])

    def test_close_with_external(self):
        out = self.lines('MONITORS = { "eDP-1", "DP-1" }\nM.evaluer(true)\nprint("etat", M.desactive)\n')
        self.assertEqual(out, [["monitor", "eDP-1", "true"], ["etat", "eDP-1"]])

    def test_close_without_external(self):
        self.assertEqual(self.lines('MONITORS = { "eDP-1" }\nM.evaluer(true)\n'), [])

    def test_open_restores_by_reload(self):
        out = self.lines('MONITORS = { "eDP-1", "DP-1" }\nM.evaluer(true)\n'
                         'MONITORS = { "DP-1" }\nM.evaluer(false)\nprint("etat", tostring(M.desactive))\n')
        self.assertEqual(out, [["monitor", "eDP-1", "true"], ["exec", "hyprctl reload"], ["etat", "nil"]])

    def test_external_removed_while_closed(self):
        out = self.lines('MONITORS = { "eDP-1", "DP-1" }\nM.evaluer(true)\n'
                         'MONITORS = {}\nM.etat = "echo \'b true\'"\nM.evaluer()\n')
        self.assertEqual(out, [["monitor", "eDP-1", "true"], ["exec", "hyprctl reload"]])

    def test_second_close_does_nothing(self):
        out = self.lines('MONITORS = { "eDP-1", "DP-1" }\nM.evaluer(true)\n'
                         'MONITORS = { "DP-1", "HDMI-A-1" }\nM.evaluer(true)\n'
                         'M.etat = "echo \'b true\'"\nM.evaluer()\n')
        self.assertEqual(out, [["monitor", "eDP-1", "true"]])

    def test_reload_while_closed(self):
        # Un rechargement réapplique la règle machine : l'écran interne revient, puis apply le redésactive.
        out = self.lines('M.desactive = "eDP-1"\nMONITORS = { "eDP-1", "DP-1" }\nM.etat = "echo \'b true\'"\nM.apply()\n')
        self.assertEqual(out[-1], ["monitor", "eDP-1", "true"])
        self.assertNotIn(["exec", "hyprctl reload"], out)

    def test_apply_binds_and_subscribes(self):
        out = self.lines('MONITORS = { "eDP-1" }\nM.apply()\n')
        self.assertEqual(out, [["bind", "switch:on:Lid Switch", "function", "true", "true", "true"],
                               ["bind", "switch:off:Lid Switch", "function", "true", "true", "true"],
                               ["on", "monitor.added", "function"], ["on", "monitor.removed", "function"]])

    def test_lid_state(self):
        out = self.lines('for _, c in ipairs({ "echo \'b true\'", "echo \'b false\'", "false", "true" }) do '
                         'M.etat = c; print(tostring(M.ferme())) end\n')
        self.assertEqual(out, [["true"], ["false"], ["false"], ["false"]])


if __name__ == "__main__":
    unittest.main()
