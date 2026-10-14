"""Contrôles — chaque erreur est provoquée par une copie de motion.toml modifiée sur une seule clé."""

import copy
import unittest
from pathlib import Path

from dunei_motion.checks import errors, warnings
from dunei_motion.model import load, resolve

ROOT = Path(__file__).resolve().parent.parent
SOURCE = load(ROOT / "motion.toml")


def raw():
    """Copie indépendante de la source réelle, à altérer dans un test."""
    return copy.deepcopy(SOURCE)


def has(messages, *words):
    """Vrai si un message contient tous les mots donnés."""
    return any(all(w in m for w in words) for m in messages)


class ErrorsTest(unittest.TestCase):
    """Erreurs bloquantes."""

    def check(self, data, *words):
        """Vérifie qu'une erreur au moins contient tous les mots donnés."""
        err = errors(data)
        self.assertTrue(has(err, *words), err)

    def test_real_source_is_valid(self):
        self.assertEqual(errors(raw()), [])

    def test_unknown_version(self):
        r = raw(); r["version"] = "0.2.0"
        self.check(r, "version", "0.2.0")

    def test_missing_section(self):
        r = raw(); del r["hyprland_reduced"]
        self.check(r, "hyprland_reduced", "manquante")

    def test_missing_rule(self):
        r = raw(); del r["rules"]["stagger_cap"]
        self.check(r, "rules", "stagger_cap")

    def test_nonpositive_reduced_fade(self):
        r = raw(); r["rules"]["reduced_fade_ms"] = 0
        self.check(r, "reduced_fade_ms", "strictement")

    def test_missing_key(self):
        r = raw(); del r["transitions"]["state"]["stiffness"]
        self.check(r, "transitions.state", "stiffness", "manquante")

    def test_missing_exit_ratio(self):
        r = raw(); del r["transitions"]["state"]["exit_ratio"]
        self.check(r, "transitions.state", "exit_ratio", "manquante")

    def test_nonpositive_value(self):
        r = raw(); r["transitions"]["state"]["mass"] = 0
        self.check(r, "transitions.state", "mass", "strictement")

    def test_forbidden_overshoot(self):
        r = raw(); r["transitions"]["overlay"]["dampening"] = 20
        self.check(r, "transitions.overlay", "dépassement")

    def test_forbidden_overshoot_flag(self):
        r = raw(); r["transitions"]["state"]["overshoot"] = True
        self.check(r, "transitions.state", "overshoot")

    def test_exit_ratio_out_of_range(self):
        r = raw(); r["transitions"]["state"]["exit_ratio"] = 0.95
        self.check(r, "transitions.state", "exit_ratio", "0.95")

    def test_symmetric_with_exit_ratio(self):
        r = raw(); r["transitions"]["reflow"]["exit_ratio"] = 0.7
        self.check(r, "transitions.reflow", "symétrique")

    def test_forbidden_stagger(self):
        r = raw(); r["transitions"]["overlay"]["stagger_ms"] = 30
        self.check(r, "transitions.overlay", "cascade")

    def test_unknown_leaf(self):
        r = raw(); r["hyprland"]["windowIn"] = {"use": "window"}
        self.check(r, "hyprland.windowIn", "inconnu")

    def test_undeclared_leaf(self):
        r = raw(); del r["hyprland"]["fadeDim"]
        self.check(r, "fadeDim", "non déclaré")

    def test_entry_not_table(self):
        r = raw(); r["hyprland"]["border"] = "state"
        self.check(r, "hyprland.border", "table")

    def test_unknown_transition(self):
        r = raw(); r["hyprland"]["border"]["use"] = "etat"
        self.check(r, "hyprland.border", "etat")

    def test_invalid_phase(self):
        r = raw(); r["hyprland"]["windowsIn"]["phase"] = "entree"
        self.check(r, "hyprland.windowsIn", "entree")

    def test_invalid_style(self):
        r = raw(); r["hyprland"]["windowsIn"]["style"] = "fade"
        self.check(r, "hyprland.windowsIn", "fade", "invalide")

    def test_reduced_unknown_leaf(self):
        r = raw(); r["hyprland_reduced"]["windowIn"] = {"style": "fade"}
        self.check(r, "hyprland_reduced.windowIn")

    def test_reduced_invalid_style(self):
        r = raw(); r["hyprland_reduced"]["windowsIn"]["style"] = "fade"
        self.check(r, "hyprland_reduced.windowsIn", "invalide")

    def test_reduced_missing_override(self):
        r = raw(); del r["hyprland_reduced"]["workspacesIn"]
        self.check(r, "workspacesIn", "slide")

    def test_reduced_missing_override_default_style(self):
        r = raw(); del r["hyprland"]["workspacesIn"]["style"]; del r["hyprland_reduced"]["workspacesIn"]
        self.check(r, "workspacesIn", "par défaut")


class WarningsTest(unittest.TestCase):
    """Avertissements non bloquants."""

    def test_real_source_has_none(self):
        self.assertEqual(warnings(resolve(raw())), [])

    def test_short_reduced_fade(self):
        r = raw(); r["rules"]["reduced_fade_ms"] = 80
        self.assertTrue(has(warnings(resolve(r)), "reduced_fade_ms", "80"))


if __name__ == "__main__":
    unittest.main()
