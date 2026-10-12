"""Modèle résolu — l'accent, le sur-accent et les sémantiques suivent les tokens explicites."""

import unittest
from pathlib import Path

from dunei_theme.model import load, resolve

ROOT = Path(__file__).resolve().parent.parent
HUES = (0, 55, 200, 265)


class ModelTest(unittest.TestCase):
    """Contrats du moteur de thème, vérifiés sur plusieurs teintes."""

    @classmethod
    def setUpClass(cls):
        cls.data = load(ROOT / "tokens.toml")
        cls.steps = cls.data["lightness"]["steps"]
        cls.models = {h: resolve(cls.data, h) for h in HUES}

    def test_accent_steps(self):
        acc = self.data["accent"]
        for h, m in self.models.items():
            with self.subTest(hue=h):
                self.assertEqual(m["accent"].l, self.steps[acc["fill_step"]])
                self.assertEqual(m["accent_standalone"].l, self.steps[acc["standalone_step"]])
                self.assertEqual(m["accent"].h, h)

    def test_accent_independent_of_categorical(self):
        data = {**self.data, "categorical": {**self.data["categorical"], "lightness_step": 2}}
        self.assertEqual(resolve(data, 55)["accent"], self.models[55]["accent"])

    def test_on_accent_matches_tokens(self):
        acc = self.data["accent"]
        for h, m in self.models.items():
            with self.subTest(hue=h):
                self.assertEqual((m["on_accent"].l, m["on_accent"].c), (acc["on_lightness"], acc["on_chroma"]))

    def test_semantic_not_capped(self):
        for h, m in self.models.items():
            for name, col in m["semantic"].items():
                with self.subTest(hue=h, role=name):
                    self.assertEqual(tuple(col), tuple(self.data["semantic"][name][k] for k in "lch"))

    def test_lightness_invariant_across_hues(self):
        ref = [c.l for c in self.models[HUES[0]]["ramp"]]
        self.assertEqual(ref, self.steps)
        for h, m in self.models.items():
            with self.subTest(hue=h):
                self.assertEqual([c.l for c in m["ramp"]], ref)
                self.assertEqual([c.l for c in m["categorical"]], [c.l for c in self.models[HUES[0]]["categorical"]])
                self.assertEqual(m["accent"].l, self.models[HUES[0]]["accent"].l)

    def test_elevation_reads_tokens(self):
        for name, lvl in self.data["elevation"].items():
            with self.subTest(level=name):
                self.assertEqual(self.models[55]["elevation"][name], self.models[55]["ramp"][lvl["step"]])


if __name__ == "__main__":
    unittest.main()
