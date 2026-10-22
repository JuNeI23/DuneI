"""Cible coque-tokens.json — valeurs de design de la coque Quickshell, hors états."""

import json
import re
import unittest
from pathlib import Path

from dunei_theme.color import oklch, to_hex
from dunei_theme.emitters.quickshell import emit
from dunei_theme.model import load, resolve

ROOT = Path(__file__).resolve().parent.parent
GOLDEN_HUES = (0, 55, 200, 265)


class QuickshellEmitterTest(unittest.TestCase):
    """Vérifie le schéma, les couleurs et les tailles du fichier produit pour la coque."""

    def setUp(self):
        self.data = load(ROOT / "tokens.toml")
        self.model = resolve(self.data, 55.0)
        self.text = emit(self.model)
        self.out = json.loads(self.text)

    def test_ligne_de_marque(self):
        self.assertIn("GÉNÉRÉ depuis tokens.toml", self.text.splitlines()[1])

    def test_cles_premier_niveau(self):
        self.assertEqual(list(self.out), [
            "_generated", "hue", "color", "disabled", "elevation", "material", "render",
            "space", "density", "radius", "window", "layout", "breakpoints", "typo", "icons"])

    def test_roles_en_srgb(self):
        c, m = self.out["color"], self.model
        self.assertEqual(c["surfaceRaised"], to_hex(m["roles"]["surface-raised"]))
        self.assertEqual(c["accent"], to_hex(m["accent"]))
        self.assertEqual(c["onAccent"], to_hex(m["on_accent"]))
        self.assertEqual(c["info"], to_hex(m["semantic"]["info"]))

    def test_materiau_argb(self):
        self.assertEqual(self.out["material"]["edgeLight"], "#14ffffff")
        self.assertTrue(self.out["render"]["scrim"].startswith("#8c"))

    def test_elevation(self):
        e = self.out["elevation"]
        self.assertIsNone(e["e1"]["sheenTop"])
        fill = self.model["elevation"]["e2"]
        self.assertEqual(e["e2"]["sheenTop"], to_hex(oklch(fill.l + 0.020, fill.c, fill.h, self.data["theme"]["chroma_ceiling"])))

    def test_tailles_inchangees(self):
        o = self.out
        self.assertEqual(o["space"]["panelPadding"], 12)
        self.assertEqual(o["radius"]["control"], 6)
        self.assertEqual(o["density"]["compact"]["controlHeight"], 24)
        self.assertEqual(o["typo"]["weightMedium"], 550)

    def test_couleurs_valides(self):
        motif = re.compile(r"^#([0-9a-f]{2})?[0-9a-f]{6}$")

        def chaines(v):
            """Parcourt récursivement un JSON et rend ses chaînes."""
            if isinstance(v, str):
                yield v
            elif isinstance(v, dict):
                for x in v.values():
                    yield from chaines(x)
            elif isinstance(v, list):
                for x in v:
                    yield from chaines(x)

        for hue in GOLDEN_HUES:
            texte = emit(resolve(self.data, float(hue)))
            for s in chaines(json.loads(texte)):
                if s.startswith("#"):
                    with self.subTest(hue=hue, valeur=s):
                        self.assertRegex(s, motif)


if __name__ == "__main__":
    unittest.main()
