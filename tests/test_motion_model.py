"""Modèle — résolution de motion.toml en ressorts et en animations."""

import unittest
from pathlib import Path

from dunei_motion.model import load, resolve

ROOT = Path(__file__).resolve().parent.parent


class ModelTest(unittest.TestCase):
    """Résolution de la source réelle."""

    @classmethod
    def setUpClass(cls):
        cls.model = resolve(load(ROOT / "motion.toml"))

    def test_curves(self):
        curves = self.model["curves"]
        self.assertEqual(len(curves), 15)
        self.assertEqual(list(curves), sorted(curves))
        self.assertEqual(curves["dunei-state-out"], {"mass": 0.5, "stiffness": 2244.9, "dampening": 71.43})
        self.assertEqual(curves["dunei-reduced"], {"mass": 1, "stiffness": 4406.3, "dampening": 132.76})
        self.assertEqual(curves["dunei-reflow-in"], curves["dunei-reflow-out"])

    def test_transitions(self):
        t = self.model["transitions"]
        self.assertEqual(len(t), 7)
        self.assertEqual(t["navigate"]["in"], t["navigate"]["out"])
        self.assertEqual(t["navigate"]["in"]["settle_ms"], 186)
        self.assertEqual(t["window"]["in"]["zeta"], 0.93)
        self.assertTrue(t["window"]["overshoot"])
        self.assertEqual(t["reveal"]["stagger"], {"ms": 40, "cap": 5})
        self.assertNotIn("stagger", t["state"])
        self.assertEqual(self.model["reduced"]["settle_ms"], 103)

    def test_animations(self):
        normal = {a["leaf"]: a for a in self.model["animations"]}
        self.assertEqual(len(self.model["animations"]), 27)
        self.assertEqual(self.model["animations"][0]["leaf"], "global")
        self.assertEqual(normal["windowsIn"], {"leaf": "windowsIn", "enabled": True, "speed": 1,
                                               "spring": "dunei-window-in", "style": "popin 90%"})
        self.assertEqual(normal["windowsMove"]["spring"], "dunei-reflow-in")
        self.assertEqual(normal["borderangle"], {"leaf": "borderangle", "enabled": False})

    def test_reduced_animations(self):
        reduced = {a["leaf"]: a for a in self.model["reduced_animations"]}
        self.assertEqual(len(reduced), 27)
        self.assertEqual(reduced["windowsIn"]["style"], "popin 100%")
        self.assertEqual(reduced["windowsMove"], {"leaf": "windowsMove", "enabled": False})
        self.assertEqual(reduced["borderangle"], {"leaf": "borderangle", "enabled": False})
        self.assertNotIn("style", reduced["fadeIn"])
        self.assertEqual(reduced["specialWorkspaceIn"]["style"], "fade")
        springs = {a["spring"] for a in reduced.values() if a["enabled"]}
        self.assertEqual(springs, {"dunei-reduced"})


if __name__ == "__main__":
    unittest.main()
