"""Cible Hyprland — chaque valeur du module Lua dérive des tokens, et le module est du Lua valide."""

import copy
import re
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

from dunei_theme.color import to_hex
from dunei_theme.emitters.hyprland import emit
from dunei_theme.model import load, resolve

ROOT = Path(__file__).resolve().parent.parent
LUA = shutil.which("lua") or shutil.which("luajit")


def expected(model: dict) -> dict:
    """Valeurs attendues — recalculées depuis le modèle, jamais recopiées.

    Entrée : model — sortie de model.resolve.
    Sortie : {option Lua: valeur textuelle attendue}. Erreurs : KeyError si un token manque.
    Dépendances : color.to_hex.
    """
    raw = model["raw"]
    d = raw["density"]["comfortable"]
    return {
        "gaps_in": str(d["tiling_gutter"] // 2),
        "gaps_out": str(d["tiling_margin"]),
        "border_size": str(raw["states"]["focus"]["ring_width"]),
        "active_border": f'"{to_hex(model["accent"])}"',
        "inactive_border": f'"{to_hex(model["roles"]["border-subtle"])}"',
        "rounding": str(raw["radii"]["window"]),
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
        alt["states"]["focus"]["ring_width"] = 3
        self.models = [resolve(self.data), resolve(self.data, 200), resolve(alt)]

    def test_values_derive_from_tokens(self):
        for m in self.models:
            lua = emit(m)
            for key, val in expected(m).items():
                with self.subTest(hue=m["hue"], option=key):
                    self.assertRegex(lua, rf"\b{key}\s*=\s*{re.escape(val)}")
            self.assertRegex(lua, r"shadow\s*=\s*\{ enabled = false \}")  # E1 : aucune ombre

    def test_no_literal_outside_model(self):
        for m in self.models:
            body = code(emit(m))
            allowed = set(expected(m).values())
            literals = re.findall(r'"#[0-9a-f]{6}"|\b\d+(?:\.\d+)?\b', body)
            with self.subTest(hue=m["hue"]):
                self.assertTrue(literals)
                self.assertEqual(set(literals) - allowed, set())

    @unittest.skipUnless(LUA, "aucun interpréteur Lua")
    def test_lua_loads_and_returns_table(self):
        lua = emit(self.models[0])
        with tempfile.NamedTemporaryFile("w", suffix=".lua", encoding="utf-8") as fh:
            fh.write(lua)
            fh.flush()
            probe = (f't = dofile("{fh.name}"); '
                     'print(t.general.gaps_in, t.general.col.active_border, t.decoration.rounding)')
            out = subprocess.run([LUA, "-e", probe], capture_output=True, text=True, check=True).stdout.split()
        exp = expected(self.models[0])
        self.assertEqual(out, [exp["gaps_in"], exp["active_border"].strip('"'), exp["rounding"]])


if __name__ == "__main__":
    unittest.main()
