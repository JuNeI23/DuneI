"""Tests de checks — sur des modèles fabriqués, indépendants des valeurs de tokens.toml."""

import unittest

from dunei_theme.checks import BODY_SURFACES, check, mesures, ordre, planchers
from dunei_theme.color import Oklch


def model(text_l=0.95, surface_l=0.18, on_accent_l=0.99, offsets=(0, 120, 240), heights=(32, 28), emphasis_l=0.97,
          secondary_l=0.80, tertiary_l=0.65, disabled_l=0.50, border_l=0.35, floors=None):
    """Modèle minimal conforme par défaut ; chaque paramètre permet d'introduire un défaut.

    Les luminosités des textes décroissent de text-emphasis à text-disabled, toutes au-dessus des bordures ;
    floors remplace les planchers par clé (par défaut, ceux-ci sont à 0 : seules les mesures voulues les franchissent).
    """
    surf = Oklch(surface_l, 0.0, 0.0)
    grey = lambda l: Oklch(l, 0.0, 0.0)
    keys = ["text-disabled", "text-tertiary", "text-secondary", "text-primary", "text-emphasis", "border-subtle",
            "border-default", "border-strong", "control-raised-text", "accent-standalone", "error", "warning",
            "success", "info", "categorical", "knob-accent", "knob-off"]
    return {
        "roles": {"text-primary": grey(text_l), "text-emphasis": grey(emphasis_l), "text-secondary": grey(secondary_l),
                  "text-tertiary": grey(tertiary_l), "text-disabled": grey(disabled_l),
                  "border-subtle": grey(border_l - 0.06), "border-default": grey(border_l - 0.03),
                  "border-strong": grey(border_l),
                  "surface-window": surf,
                  "surface-panel": surf, "surface-raised": surf, "control-raised": surf,
                  "control-off": grey(0.50)},
        "accent": Oklch(0.53, 0.0, 0.0),
        "accent_standalone": grey(0.80),
        "knob": grey(0.97),
        "categorical": [grey(0.80), grey(0.78)],
        "semantic": {k: grey(0.80) for k in ("error", "warning", "success", "info")},
        "on_accent": Oklch(on_accent_l, 0.0, 0.0),
        "raw": {
            "meta": {"contrast_target_body": 90, "contrast_floor": 75, "planchers": {k: 0 for k in keys} | (floors or {})},
            "theme": {"accent_chroma": 0.1, "chroma_ceiling": 0.16},
            "categorical": {"min_angular_separation": 30, "hue_offsets": list(offsets)},
            "scaling": {"height_multiple": 4},
            "density": {"normal": {"control_height": heights[0], "row_height": heights[1]}},
            "surface_material": {"sheen_max_height": 60},
            "role_text": {"control-raised": "text-emphasis"},
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

    def test_control_raised_pair(self):
        """Vérifie que le texte sur le fond des contrôles posés sur E3 est contrôlé en APCA, avec le texte que lui
        donne [role_text] : text-emphasis, et non text-primary."""
        self.assertIn("control-raised", BODY_SURFACES)
        self.assertTrue(has(check(model(emphasis_l=0.6)), "text-emphasis", "control-raised", "plancher"))
        self.assertFalse(has(check(model(text_l=0.6)), "control-raised"))

    def test_on_accent_below_floor(self):
        self.assertTrue(has(check(model(on_accent_l=0.2)), "on_accent", "plancher"))

    def test_plancher_franchi(self):
        """Un rôle sous son plancher est nommé ; la mesure est tronquée au dixième avant la comparaison."""
        m = model(floors={"text-secondary": 60})
        self.assertEqual(planchers(m), [])
        m["raw"]["meta"]["planchers"]["text-secondary"] = 200
        w = planchers(m)
        self.assertEqual(len(w), 1)
        self.assertTrue(has(w, "text-secondary", "plancher"))
        self.assertTrue(has(check(m), "text-secondary", "plancher"))
        self.assertIn("text-secondary", mesures(m))

    def test_knob_sur_piste_eteinte(self):
        """Le knob trop proche de la piste éteinte franchit le plancher knob-off."""
        m = model(floors={"knob-off": 15})
        self.assertEqual(planchers(m), [])
        m["roles"]["control-off"] = Oklch(0.96, 0.0, 0.0)
        self.assertTrue(has(planchers(m), "knob-off", "plancher"))

    def test_ordre_inverse(self):
        """text-tertiary plus contrasté que text-secondary renverse l'ordre des rôles."""
        self.assertEqual(ordre(model()), [])
        self.assertEqual(len(ordre(model(tertiary_l=0.85))), 3)  # un avertissement par surface
        self.assertTrue(has(ordre(model(emphasis_l=0.90)), "text-emphasis", "text-primary"))

    def test_texte_sous_bordure(self):
        """Le plus faible texte doit dépasser strictement la plus forte bordure."""
        w = ordre(model(disabled_l=0.35, border_l=0.35))
        self.assertTrue(has(w, "text-disabled", "border-strong"))
        self.assertEqual(ordre(model(disabled_l=0.50, border_l=0.35)), [])

    def test_height_multiple(self):
        self.assertTrue(has(check(model(heights=(30, 28))), "control_height", "multiple de 4"))
        self.assertFalse(has(check(model(heights=(32, 28))), "multiple"))

    def test_angular_wraparound(self):
        """350° et 10° sont à 20° l'un de l'autre via le bouclage 360°."""
        self.assertTrue(has(check(model(offsets=(10, 180, 350))), "350° et 10°"))
        self.assertFalse(has(check(model(offsets=(0, 120, 240))), "trop proches"))


if __name__ == "__main__":
    unittest.main()
