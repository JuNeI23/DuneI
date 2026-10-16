"""Contrôles de l'échelle d'inactivité — energie.toml refusé palier par palier, avant toute génération."""

import copy
import unittest
from pathlib import Path

from dunei_energie.checks import errors
from dunei_energie.model import load, resolve

ROOT = Path(__file__).resolve().parent.parent


class ChecksTest(unittest.TestCase):
    """Chaque règle de la spec (section 3.3) refuse son cas fautif, avec le nom du palier en cause."""

    def setUp(self):
        self.raw = load(ROOT / "energie.toml")

    def refused(self, change, *words: str):
        """Applique change à une copie de la source, puis exige une erreur contenant chaque mot."""
        raw = copy.deepcopy(self.raw)
        change(raw)
        err = " | ".join(errors(raw))
        self.assertTrue(err, "aucune erreur")
        for w in words:
            self.assertIn(w, err)

    def test_real_source_is_valid(self):
        self.assertEqual(errors(self.raw), [])

    def test_resolve(self):
        m = resolve(self.raw)
        self.assertEqual(m["verrouiller"], "loginctl lock-session")
        self.assertEqual(m["niveau"], 10)
        self.assertEqual(m["paliers"]["batterie"],
                         [("attenuation", 150), ("verrouillage", 300), ("ecran", 330), ("veille", 900)])
        self.assertEqual(m["paliers"]["secteur"], [("attenuation", 300), ("verrouillage", 600), ("ecran", 630)])

    def test_order(self):
        self.refused(lambda r: r["paliers"]["ecran"].update(batterie=200), "palier ecran, batterie", "verrouillage")

    def test_equal_delays(self):
        self.refused(lambda r: r["paliers"]["verrouillage"].update(secteur=300), "palier verrouillage, secteur")

    def test_sleep_requires_lock(self):
        def change(r):
            del r["paliers"]["verrouillage"]["batterie"]
            del r["paliers"]["ecran"]["batterie"]
        self.refused(change, "palier veille, batterie", "exige le palier verrouillage")

    def test_positive_integer(self):
        for bad in (0, -5, 1.5, "300", True):
            with self.subTest(valeur=bad):
                self.refused(lambda r: r["paliers"]["attenuation"].update(batterie=bad), "palier attenuation, batterie")

    def test_level(self):
        for bad in (0, 101, 9.5, "10"):
            with self.subTest(valeur=bad):
                self.refused(lambda r: r["attenuation"].update(niveau=bad), "niveau")

    def test_unknown_names(self):
        self.refused(lambda r: r["paliers"].update(sieste={"batterie": 10}), "palier inconnu « sieste »")
        self.refused(lambda r: r["paliers"]["veille"].update(solaire=10), "alimentation inconnue « solaire »")
        self.refused(lambda r: r.update(extra={}), "section inconnue « extra »")
        self.refused(lambda r: r["commandes"].update(eteindre="x"), "clé inconnue « eteindre »")

    def test_commands(self):
        self.refused(lambda r: r["commandes"].update(verrouilleur=" "), "« verrouilleur » manquante ou vide")
        self.refused(lambda r: r.pop("commandes"), "« verrouiller » manquante ou vide")

    def test_version(self):
        self.refused(lambda r: r.update(version="9"), "version « 9 »")

    def test_wrong_table_types_do_not_raise(self):
        for change in (lambda r: r.update(paliers=3), lambda r: r["paliers"].update(veille=3),
                       lambda r: r.update(attenuation="x"), lambda r: r.update(commandes=[])):
            with self.subTest():
                raw = copy.deepcopy(self.raw)
                change(raw)
                self.assertTrue(errors(raw))


if __name__ == "__main__":
    unittest.main()
