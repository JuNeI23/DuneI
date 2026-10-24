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

    def test_timings(self):
        """Le délai d'infobulle et la période de l'indicateur d'activité sont exigés, numériques et strictement
        positifs."""
        for section, key in (("delays", "tooltip"), ("periods", "spinner")):
            with self.subTest(section=section):
                r = raw(); del r[section][key]
                self.check(r, section, key, "manquante")
                r = raw(); r[section][key] = 0
                self.check(r, section, key, "strictement")
                r = raw(); r[section][key] = "700"
                self.check(r, section, key, "type")
                r = raw(); r[section]["tooltipp"] = 1
                self.check(r, section, "tooltipp", "inconnue")

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

    def test_curve_below_hyprland_bound(self):
        r = raw(); r["transitions"]["spectacle"]["stiffness"] = 0.4
        self.check(r, "transitions.spectacle", "0.5")

    def test_reduced_moving_leaf_enabled(self):
        for leaf in ("zoomFactor", "monitorAdded", "windowsMove"):
            with self.subTest(leaf=leaf):
                r = raw(); r["hyprland_reduced"].pop(leaf, None)
                self.check(r, leaf, "désactivé")

    def test_reduced_override_moves(self):
        r = raw(); r["hyprland_reduced"]["workspacesIn"]["style"] = "slide"
        self.check(r, "hyprland_reduced.workspacesIn", "déplace")

    def test_reduced_override_without_style(self):
        r = raw(); r["hyprland_reduced"]["windowsIn"] = {}
        self.check(r, "hyprland_reduced.windowsIn", "déplace")

    def test_wrong_types(self):
        cases = [(("transitions", "state", "stiffness"), "1100"), (("rules", "exit_ratio"), "0.7"),
                 (("rules", "reduced_fade_ms"), "100"), (("rules", "overshoot_allowed"), 1),
                 (("hyprland", "border", "use"), ["state"]), (("hyprland", "windowsIn", "style"), 90),
                 (("hyprland_reduced", "windowsIn", "style"), 90), (("hyprland", "windowsIn", "enabled"), "false"),
                 (("transitions", "state", "overshoot"), "yes")]
        for path, value in cases:
            with self.subTest(path=path, value=value):
                r = raw(); node = r
                for key in path[:-1]:
                    node = node[key]
                node[path[-1]] = value
                self.check(r, path[-2], path[-1], "type")

    def test_value_rounding_to_zero(self):
        r = raw(); r["transitions"]["state"]["mass"] = 0.001
        self.check(r, "transitions.state", "mass", "strictement")

    def test_unknown_keys(self):
        for section, name, key in [("hyprland", "windowsOut", "phse"), ("transitions", "state", "overshot"),
                                   ("hyprland_reduced", "windowsIn", "stlye")]:
            with self.subTest(key=key):
                r = raw(); r[section][name][key] = "x"
                self.check(r, f"{section}.{name}", key, "inconnue")


class WarningsTest(unittest.TestCase):
    """Avertissements non bloquants."""

    def test_real_source_has_none(self):
        self.assertEqual(warnings(resolve(raw())), [])

    def test_short_reduced_fade(self):
        r = raw(); r["rules"]["reduced_fade_ms"] = 80
        self.assertTrue(has(warnings(resolve(r)), "reduced_fade_ms", "80"))


if __name__ == "__main__":
    unittest.main()
