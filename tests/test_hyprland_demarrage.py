"""Module demarrage — exécuté par Lua avec un faux hl ; le signal hyprland.start est déclenché à la main."""

import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LUA = shutil.which("lua") or shutil.which("luajit")

# Faux hl : chaque appel imprime une ligne ; les gestionnaires d'événements sont gardés dans HANDLERS.
FAKE = r"""
HANDLERS = {}
hl = {
    config = function(t) print("config", tostring(t.misc.disable_hyprland_logo), tostring(t.misc.disable_splash_rendering)) end,
    define_submap = function(n, f) print("submap", n); f() end,
    bind = function(k, f) print("bind", k, type(f)) end,
    on = function(e, f) print("on", e); HANDLERS[e] = f end,
    dispatch = function(d) print("dispatch", d) end,
    dsp = { submap = function(n) return "submap:" .. n end },
    exec_cmd = function(c) print("exec", c) end,
}
"""


@unittest.skipUnless(LUA, "aucun interpréteur Lua")
class DemarrageTest(unittest.TestCase):
    """Mode enregistré, logo masqué ; au premier lancement depuis le démarrage seulement : mode bloquant
    d'abord, verrou ensuite."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        t = Path(self.tmp.name)
        self.amorcage, self.etat = t / "boot_id", t / "etat" / "dunei" / "verrou-initial"
        self.amorcage.write_text("id-1\n", encoding="utf-8")
        (t / "modules").symlink_to(ROOT / "config" / "hypr" / "modules")

    def tearDown(self):
        self.tmp.cleanup()

    def lines(self, code: str) -> list[list[str]]:
        """Exécute code après le faux hl, HOME pointé sur /maison, M pointé sur les fichiers d'essai."""
        script = (f'package.path = "{self.tmp.name}/?.lua"\n' + FAKE
                  + f'M = require("modules.demarrage")\nM.AMORCAGE = "{self.amorcage}"\nM.ETAT = "{self.etat}"\n' + code)
        res = subprocess.run([LUA, "-e", script], capture_output=True, text=True,
                             env={"HOME": "/maison", "PATH": "/usr/bin:/bin"})
        self.assertEqual(res.returncode, 0, res.stderr)
        return [l.split("\t") for l in res.stdout.splitlines()]

    def test_apply_registers_without_locking(self):
        out = self.lines('M.apply({ verrouilleur = "v" })\n')
        self.assertEqual(out, [["config", "true", "true"], ["submap", "verrou-initial"],
                               ["bind", "F24", "function"], ["on", "hyprland.start"]])
        self.assertFalse(self.etat.exists())

    def test_first_start_enters_mode_then_locks(self):
        out = self.lines('M.apply({ verrouilleur = "pidof x || x --a" })\nHANDLERS["hyprland.start"]()\n')
        self.assertEqual(out[-2:], [["dispatch", "submap:verrou-initial"],
                                    ["exec", "/maison/.config/hypr/scripts/dunei-verrou-initial 'pidof x || x --a'"]])
        self.assertEqual(self.etat.read_text(), "id-1\n")

    def test_second_start_same_boot_does_not_lock(self):
        self.lines('M.apply({ verrouilleur = "v" })\nHANDLERS["hyprland.start"]()\n')
        out = self.lines('M.apply({ verrouilleur = "v" })\nHANDLERS["hyprland.start"]()\n')
        self.assertFalse([l for l in out if l[0] in ("dispatch", "exec")])

    def test_new_boot_locks_again(self):
        self.lines('M.apply({ verrouilleur = "v" })\nHANDLERS["hyprland.start"]()\n')
        self.amorcage.write_text("id-2\n", encoding="utf-8")
        out = self.lines('M.apply({ verrouilleur = "v" })\nHANDLERS["hyprland.start"]()\n')
        self.assertEqual(out[-2][0], "dispatch")

    def test_unreadable_boot_id_locks(self):
        self.amorcage.unlink()
        self.assertEqual(self.lines('print(tostring(M.premier()))\nprint(tostring(M.premier()))\n'),
                         [["true"], ["true"]])

    def test_quoting_survives_apostrophes(self):
        out = self.lines('print(M.citer("l\'écran"))\n')
        self.assertEqual(out, [["'l'\\''écran'"]])
