"""Point d'entrée — config/hypr/hyprland.lua exécuté par Lua avec un faux hl, dans un dossier imitant ~/.config/hypr."""

import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LUA = shutil.which("lua") or shutil.which("luajit")

# Sonde : remplace hl, exécute le point d'entrée, puis imprime la suite des appels sans répétition
# consécutive et le nombre d'animations.
PROBE = r"""
local events, animations = {}, 0
local function note(e) if events[#events] ~= e then events[#events + 1] = e end end
hl = {
    config = function(t) note("config:" .. (t.source or "dunei")) end,
    curve = function() end,
    animation = function() animations = animations + 1; note("animation") end,
}
dofile(ENTRY)
print(table.concat(events, ","), animations)
"""


@unittest.skipUnless(LUA, "aucun interpréteur Lua")
class EntryTest(unittest.TestCase):
    """Ordre d'application du point d'entrée, avec et sans configuration générique."""

    def probe(self, generic: bool) -> list[str]:
        """Exécute la sonde. Entrée : présence d'un generique.lua de test. Sortie : champs imprimés."""
        with tempfile.TemporaryDirectory() as tmp:
            hypr = Path(tmp) / "hypr"
            (hypr / "generated").mkdir(parents=True)
            for name in ("hyprland-tokens.lua", "motion.lua"):
                shutil.copy(ROOT / "generated" / name, hypr / "generated" / name)
            (hypr / "modules").symlink_to(ROOT / "config" / "hypr" / "modules")
            if generic:
                (hypr / "generique.lua").write_text('hl.config({ source = "generique" })\n', encoding="utf-8")
            script = (f'package.path = "{hypr}/?.lua;{hypr}/?/init.lua"\n'
                      f'ENTRY = "{ROOT}/config/hypr/hyprland.lua"\n' + PROBE)
            return subprocess.run([LUA, "-e", script], capture_output=True, text=True, check=True).stdout.split()

    def test_with_generic(self):
        self.assertEqual(self.probe(True), ["config:generique,config:dunei,animation", "27"])

    def test_without_generic(self):
        self.assertEqual(self.probe(False), ["config:dunei,animation", "27"])


if __name__ == "__main__":
    unittest.main()
