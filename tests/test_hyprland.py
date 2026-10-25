"""Cible Hyprland — chaque valeur du module Lua dérive des tokens, et le module est du Lua valide."""

import copy
import re
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

from dunei_theme.color import Oklch, to_srgb255
from dunei_theme.emitters.hyprland import emit, emit_binds, emit_layer_rules, emit_rules
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
        "size": str(raw["glass"]["blur_size"]),
        "passes": str(raw["glass"]["blur_passes"]),
        "color": f'"rgba({r:02x}{g:02x}{b:02x}{round(mat["shade_opacity"] * 255):02x})"',
        "background_color": '"rgba({:02x}{:02x}{:02x}ff)"'.format(*to_srgb255(model["roles"]["surface-base"])),
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

    def test_blur_popups_global_inactif(self):
        """Le flou global reste actif pour le verre, mais jamais pour les popups des applications."""
        for m in self.models:
            lua = emit(m)
            self.assertRegex(lua, r"popups\s*=\s*false")
            self.assertRegex(lua, r"blur\s*=\s*\{\s*enabled\s*=\s*true")

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

    def test_shadow_rejects_range_out_of_bounds(self):
        for value in (0, -4, 104):
            with self.subTest(range=value), self.assertRaisesRegex(ValueError, "range"):
                emit(self.bad(range=value))

    def test_rejects_non_integers(self):
        for key, value in (("render_power", 2.5), ("range", 16.0), ("offset_y", True)):
            with self.subTest(**{key: value}), self.assertRaisesRegex(ValueError, key):
                emit(self.bad(**{key: value}))
        alt = copy.deepcopy(self.data)
        alt["window"]["border_width"] = 1.5
        with self.assertRaisesRegex(ValueError, "border_width"):
            emit(resolve(alt))

    def test_rejects_negative_fullscreen_radius(self):
        alt = copy.deepcopy(self.data)
        alt["radii"]["fullscreen"] = -1
        with self.assertRaisesRegex(ValueError, "radii.fullscreen"):
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


class RulesTest(unittest.TestCase):
    """Règles de fenêtre générées : dérivées des jetons, dans l'ordre où la dernière l'emporte."""

    def setUp(self):
        self.data = load(ROOT / "tokens.toml")

    def rules(self, **edits) -> str:
        """Règles émises pour une source altérée. Entrée : e1_shadow, fullscreen. Sortie : texte Lua."""
        alt = copy.deepcopy(self.data)
        if "e1_shadow" in edits:
            alt["elevation"]["e1"]["shadow"] = edits["e1_shadow"]
        if "fullscreen" in edits:
            alt["radii"]["fullscreen"] = edits["fullscreen"]
        return emit_rules(resolve(alt))

    def test_rules_values(self):
        lua = self.rules()
        self.assertIn('{ name = "couche-1-sans-ombre", match = { float = false }, no_shadow = true },', lua)
        self.assertIn('{ name = "plein-ecran-nu", match = { fullscreen_state_internal = 2 }, no_shadow = true, rounding = 0 },', lua)

    def test_rules_follow_fullscreen_radius(self):
        self.assertIn("rounding = 4", self.rules(fullscreen=4))

    def test_rules_follow_e1_shadow(self):
        lua = self.rules(e1_shadow=True)
        self.assertNotIn("couche-1-sans-ombre", lua)
        self.assertIn("plein-ecran-nu", lua)

    def test_rules_order(self):
        lua = self.rules()
        self.assertLess(lua.index("couche-1-sans-ombre"), lua.index("plein-ecran-nu"))

    @unittest.skipUnless(LUA, "aucun interpréteur Lua")
    def test_rules_load_as_list(self):
        with tempfile.NamedTemporaryFile("w", suffix=".lua", encoding="utf-8") as fh:
            fh.write(self.rules())
            fh.flush()
            probe = f't = dofile("{fh.name}"); for _, r in ipairs(t) do print(r.name) end'
            out = subprocess.run([LUA, "-e", probe], capture_output=True, text=True, check=True).stdout.split()
        self.assertEqual(out, ["couche-1-sans-ombre", "plein-ecran-nu"])


class LayerRulesTest(unittest.TestCase):
    """Règles de calque du verre : une par namespace, jamais de flou sur l'ombre ni sur le voile."""

    def setUp(self):
        self.data = load(ROOT / "tokens.toml")

    def layers(self, **glass) -> str:
        """Règles émises pour un verre altéré. Entrée : clés de [glass]. Sortie : texte Lua."""
        alt = copy.deepcopy(self.data)
        alt["glass"].update(glass)
        return emit_layer_rules(resolve(alt))

    def probe(self, field: str) -> list[str]:
        """Champ de chaque règle, lu par Lua. Entrée : field — clé Lua. Sortie : valeurs imprimées."""
        with tempfile.NamedTemporaryFile("w", suffix=".lua", encoding="utf-8") as fh:
            fh.write(self.layers())
            fh.flush()
            lua = f't = dofile("{fh.name}"); for _, r in ipairs(t) do print({field}) end'
            return subprocess.run([LUA, "-e", lua], capture_output=True, text=True, check=True).stdout.split()

    @unittest.skipUnless(LUA, "aucun interpréteur Lua")
    def test_une_regle_par_namespace(self):
        self.assertEqual(self.probe("r.match.namespace"), ["^dunei-barre$", "^dunei-attention$"])
        self.assertEqual(self.probe("tostring(r.blur) .. tostring(r.blur_popups) .. r.ignore_alpha"),
                         ["truetrue0.6"] * 2)

    @unittest.skipUnless(LUA, "aucun interpréteur Lua")
    def test_xray_sur_la_barre_seule(self):
        self.assertEqual(self.probe("tostring(r.xray)"), ["true", "false"])

    def test_ignore_alpha_borne(self):
        for value in (0.5, 0.9):
            with self.subTest(ignore_alpha=value), self.assertRaisesRegex(ValueError, "ignore_alpha"):
                self.layers(ignore_alpha=value)

    def test_ignore_alpha_borne_par_le_jour(self):
        """Une surcharge de jour sous le seuil est refusée : la config Hyprland est unique."""
        alt = copy.deepcopy(self.data)
        alt["moments"]["jour"].setdefault("glass", {})["e2_opacity"] = 0.55
        with self.assertRaisesRegex(ValueError, "ignore_alpha"):
            emit_layer_rules(resolve(alt))

    def test_xray_hors_namespaces(self):
        with self.assertRaisesRegex(ValueError, "xray"):
            self.layers(xray=["dunei-inconnu"])


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


if __name__ == "__main__":
    unittest.main()
