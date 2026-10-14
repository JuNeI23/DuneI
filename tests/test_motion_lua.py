"""Module d'application — config/hypr/modules/motion.lua, exécuté avec un faux hl qui enregistre les appels."""

import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

from dunei_motion.emitters import lua
from dunei_motion.model import load, resolve

ROOT = Path(__file__).resolve().parent.parent
LUA = shutil.which("lua") or shutil.which("luajit")

# Sonde : remplace hl par une version qui applique les bornes de Hyprland 0.56.2, applique le module,
# puis résume les appels sur une ligne.
PROBE = r"""
local curves, anims = {}, {}
hl = {
    curve = function(name, c)
        -- Hyprland 0.56.2 refuse la courbe si la masse, la raideur ou l'amortissement vaut 0,5 ou moins.
        assert(c.mass > 0.5 and c.stiffness > 0.5 and c.dampening > 0.5, name .. " : valeur refusée par Hyprland")
        curves[name] = c
    end,
    animation = function(a) anims[#anims + 1] = a end,
}
require("modules.motion").apply(REDUCED)
local missing, speed, used = 0, 0, {}
for _, a in ipairs(anims) do
    if a.enabled then
        if not curves[a.spring] then missing = missing + 1 end
        if a.speed ~= 1 then speed = speed + 1 end
        used[a.spring] = true
    end
end
local names = {}
for name in pairs(used) do names[#names + 1] = name end
table.sort(names)
print(#anims, missing, speed, anims[1].leaf, table.concat(names, ","))
"""


@unittest.skipUnless(LUA, "aucun interpréteur Lua")
class MotionLuaTest(unittest.TestCase):
    """Application des deux jeux d'animations."""

    def probe(self, reduced: bool) -> list[str]:
        """Exécute la sonde sur une génération fraîche. Entrée : mode réduit ou non. Sortie : champs imprimés."""
        model = resolve(load(ROOT / "motion.toml"))
        with tempfile.TemporaryDirectory() as tmp:
            (Path(tmp) / "generated").mkdir()
            (Path(tmp) / "generated" / "motion.lua").write_text(lua.emit(model), encoding="utf-8")
            script = (f'package.path = "{tmp}/?.lua;{ROOT}/config/hypr/?.lua"\n'
                      f"REDUCED = {str(reduced).lower()}\n" + PROBE)
            return subprocess.run([LUA, "-e", script], capture_output=True, text=True, check=True).stdout.split()

    def test_normal(self):
        count, missing, speed, first, names = self.probe(False)
        self.assertEqual((count, missing, speed, first), ("27", "0", "0", "global"))
        self.assertIn("dunei-window-in", names.split(","))
        self.assertNotIn("dunei-reduced", names.split(","))

    def test_reduced(self):
        count, missing, speed, first, names = self.probe(True)
        self.assertEqual((count, missing, speed, first), ("27", "0", "0", "global"))
        self.assertEqual(names, "dunei-reduced")


if __name__ == "__main__":
    unittest.main()
