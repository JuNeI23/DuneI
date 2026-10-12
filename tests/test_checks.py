"""Tests de checks — sur des modèles fabriqués, indépendants des valeurs de tokens.toml."""

import unittest

from dunei_theme.checks import check
from dunei_theme.color import Oklch


def model(text_l=0.95, surface_l=0.18, on_accent_l=0.99, offsets=(0, 120, 240), heights=(32, 28)):
    """Modèle minimal conforme par défaut ; chaque paramètre permet d'introduire un défaut."""
    surf = Oklch(surface_l, 0.0, 0.0)
    return {
        "roles": {"text-primary": Oklch(text_l, 0.0, 0.0), "surface-window": surf,
                  "surface-panel": surf, "surface-raised": surf},
        "accent": Oklch(0.53, 0.0, 0.0),
        "on_accent": Oklch(on_accent_l, 0.0, 0.0),
        "raw": {
            "meta": {"contrast_target_body": 90, "contrast_floor": 75},
            "theme": {"accent_chroma": 0.1, "chroma_ceiling": 0.16},
            "categorical": {"min_angular_separation": 30, "hue_offsets": list(offsets)},
            "scaling": {"height_multiple": 4},
            "density": {"normal": {"control_height": heights[0], "row_height": heights[1]}},
            "surface_material": {"sheen_max_height": 60},
        },
    }


def has(warns, *words):
    """Vrai si un avertissement contient tous les mots donnés."""
    return any(all(w in x for w in words) for x in warns)


class CheckTest(unittest.TestCase):

    def test_conforming_model(self):
        self.assertEqual(check(model()), [])

    def test_body_below_floor(self):
        w = check(model(text_l=0.6))
        self.assertTrue(has(w, "text-primary", "surface-panel", "plancher"))
        self.assertFalse(has(w, "text-primary", "cible"))

    def test_body_below_target_only(self):
        w = check(model(text_l=0.86))
        self.assertTrue(has(w, "text-primary", "surface-window", "cible"))
        self.assertFalse(has(w, "plancher"))

    def test_on_accent_below_floor(self):
        self.assertTrue(has(check(model(on_accent_l=0.2)), "on_accent", "plancher"))

    def test_height_multiple(self):
        self.assertTrue(has(check(model(heights=(30, 28))), "control_height", "multiple de 4"))
        self.assertFalse(has(check(model(heights=(32, 28))), "multiple"))

    def test_angular_wraparound(self):
        """350° et 10° sont à 20° l'un de l'autre via le bouclage 360°."""
        self.assertTrue(has(check(model(offsets=(10, 180, 350))), "350° et 10°"))
        self.assertFalse(has(check(model(offsets=(0, 120, 240))), "trop proches"))


if __name__ == "__main__":
    unittest.main()
