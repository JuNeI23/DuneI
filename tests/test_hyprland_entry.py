"""Point d'entrée — config/hypr/hyprland.lua exécuté par Lua avec un faux hl, dans un dossier imitant ~/.config/hypr ; agnosticisme de la configuration commune."""

import re
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LUA = shutil.which("lua") or shutil.which("luajit")

# Sonde : remplace hl, pointe le fragment machine sur un nom d'hôte de test, exécute le point d'entrée,
# puis imprime la suite des appels sans répétition consécutive et le nombre d'animations. Une règle
# d'écran s'imprime avec sa sortie, « * » pour la règle commune.
PROBE = r"""
local events, animations = {}, 0
local function note(e) if events[#events] ~= e then events[#events + 1] = e end end
hl = {
    config = function(t) note("config:" .. (t.source or (t.input and "input") or "dunei")) end,
    bind = function() note("bind") end,
    gesture = function() note("gesture") end,
    unbind = function() note("unbind") end,
    dsp = setmetatable({}, { __index = function(s) return s end, __call = function() return "dsp" end }),
    curve = function() end,
    animation = function() animations = animations + 1; note("animation") end,
    monitor = function(t) note("monitor:" .. (t.output == "" and "*" or t.output)) end,
    env = function(k) note("env:" .. k) end,
    window_rule = function(t) note("rule:" .. t.name) end,
}
require("modules.machine").file = HOST
dofile(ENTRY)
print(table.concat(events, ","), animations)
"""


@unittest.skipUnless(LUA, "aucun interpréteur Lua")
class EntryTest(unittest.TestCase):
    """Ordre d'application du point d'entrée, avec et sans configuration générique ni fragment machine."""

    def probe(self, generic: bool, machine: bool = False) -> list[str]:
        """Exécute la sonde.

        Entrées : generic — présence d'un generique.lua de test ; machine — présence d'un fragment pour
                  le nom d'hôte de test.
        Sortie : champs imprimés par la sonde.
        """
        with tempfile.TemporaryDirectory() as tmp:
            hypr = Path(tmp) / "hypr"
            (hypr / "generated").mkdir(parents=True)
            (hypr / "machines").mkdir()
            for name in ("hyprland-tokens.lua", "hyprland-rules.lua", "hyprland-binds.lua", "motion.lua"):
                shutil.copy(ROOT / "generated" / name, hypr / "generated" / name)
            (hypr / "modules").symlink_to(ROOT / "config" / "hypr" / "modules")
            (hypr / "donnees").symlink_to(ROOT / "config" / "hypr" / "donnees")
            if generic:
                (hypr / "generique.lua").write_text('hl.config({ source = "generique" })\n', encoding="utf-8")
            if machine:
                (hypr / "machines" / "essai.lua").write_text('hl.monitor({ output = "essai" })\n', encoding="utf-8")
            (hypr / "hostname").write_text("essai\n", encoding="utf-8")
            script = (f'package.path = "{hypr}/?.lua;{hypr}/?/init.lua"\n'
                      f'ENTRY = "{ROOT}/config/hypr/hyprland.lua"\nHOST = "{hypr / "hostname"}"\n' + PROBE)
            return subprocess.run([LUA, "-e", script], capture_output=True, text=True, check=True).stdout.split()

    MODULES = ("env:QT_WAYLAND_DISABLE_WINDOWDECORATION,config:dunei,rule:couche-1-sans-ombre,"
               "rule:plein-ecran-nu,rule:sans-agrandissement,rule:glisser-xwayland")

    def test_with_generic(self):
        self.assertEqual(self.probe(True, True),
                         [f"config:generique,config:dunei,animation,{self.MODULES},monitor:*,config:dunei,"
                          "config:input,unbind,bind,gesture,monitor:essai", "27"])

    def test_without_generic(self):
        self.assertEqual(self.probe(False, True),
                         [f"config:dunei,animation,{self.MODULES},monitor:*,config:dunei,"
                          "config:input,unbind,bind,gesture,monitor:essai", "27"])

    def test_without_machine(self):
        self.assertEqual(self.probe(True),
                         [f"config:generique,config:dunei,animation,{self.MODULES},monitor:*,config:dunei,"
                          "config:input,unbind,bind,gesture", "27"])


class AgnosticTest(unittest.TestCase):
    """La configuration commune ne nomme aucun matériel (règle 5) : les sorties vivent dans machines/."""

    PATTERN = re.compile(r"\b(?:e?DP|HDMI-[A-Z]|DVI-[A-Z]|VGA)-\d|desc:")

    def test_no_output_named(self):
        files = [ROOT / "config" / "hypr" / "hyprland.lua",
                 *sorted((ROOT / "config" / "hypr" / "modules").glob("*.lua")),
                 *sorted((ROOT / "config" / "hypr" / "donnees").glob("*.lua"))]
        for f in files:
            with self.subTest(fichier=f.name):
                self.assertIsNone(self.PATTERN.search(f.read_text(encoding="utf-8")))

    def test_caladan_names_its_panel(self):
        self.assertIsNotNone(self.PATTERN.search((ROOT / "config" / "hypr" / "machines" / "caladan.lua").read_text(encoding="utf-8")))


if __name__ == "__main__":
    unittest.main()
