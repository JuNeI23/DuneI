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
