"""Cible Hyprland — chaque valeur du module Lua dérive des tokens, et le module est du Lua valide."""

import copy
import re
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

from dunei_theme.color import Oklch, to_srgb255
from dunei_theme.emitters.hyprland import emit
from dunei_theme.model import load, resolve

ROOT = Path(__file__).resolve().parent.parent
LUA = shutil.which("lua") or shutil.which("luajit")
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


def code(lua: str) -> str:
    """Le module sans ses commentaires. Entrée : texte Lua. Sortie : texte sans `-- …`."""
    return re.sub(r"--[^\n]*", "", lua)


class HyprlandTest(unittest.TestCase):
    """Le module généré pour la source réelle et pour une source altérée."""

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


if __name__ == "__main__":
    unittest.main()
