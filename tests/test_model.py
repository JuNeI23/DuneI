"""Modèle résolu — l'accent, le sur-accent et les sémantiques suivent les tokens explicites."""

import unittest
from pathlib import Path

from dunei_theme.checks import check
from dunei_theme.model import defaut, load, resolve, theme_data, themes

ROOT = Path(__file__).resolve().parent.parent
HUES = (0, 55, 200, 265)


class ModelTest(unittest.TestCase):
    """Contrats du moteur de thème, vérifiés sur plusieurs teintes."""

    @classmethod
    def setUpClass(cls):
        cls.data = load(ROOT / "tokens.toml")
        cls.steps = cls.data["lightness"]["steps"]
        cls.models = {h: resolve(cls.data, h) for h in HUES}

    def test_themes_conformes(self):
        """Chaque thème, à chaque teinte de référence, passe tous les contrôles (planchers et ordre compris)."""
        for f, m in themes(self.data):
            for h in HUES:
                with self.subTest(famille=f, moment=m, hue=h):
                    self.assertEqual(check(resolve(theme_data(self.data, f, m), h)), [])

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

    def test_nuit_thematisee_identique(self):
        for h in HUES:
            ref, got = resolve(self.data, h), resolve(theme_data(self.data, "thematisee", "nuit"), h)
            for cle in ("ramp", "roles", "elevation", "accent", "accent_standalone", "on_accent",
                        "categorical", "semantic"):
                with self.subTest(hue=h, cle=cle):
                    self.assertEqual(got[cle], ref[cle])

    def test_themes_et_defaut(self):
        self.assertEqual(themes(self.data), [("thematisee", "nuit"), ("thematisee", "jour"),
                                             ("dominante", "nuit"), ("dominante", "jour")])
        self.assertEqual(defaut(self.data), ("thematisee", "nuit"))

    def _jour(self, famille, h=55):
        """Modèle résolu du jour pour une famille, à une teinte."""
        return resolve(theme_data(self.data, famille, "jour"), h)

    def test_jour_monte_vers_le_blanc(self):
        for f in ("thematisee", "dominante"):
            e = self._jour(f)["elevation"]
            with self.subTest(famille=f):
                self.assertTrue(e["e0"].l < e["e1"].l < e["e2"].l < e["e3"].l)
                self.assertEqual((e["e3"].l, e["e3"].c), (1.0, 0))

    def test_jour_controle_blanc(self):
        for f in ("thematisee", "dominante"):
            with self.subTest(famille=f):
                self.assertEqual(self._jour(f)["roles"]["control-raised"].l, 1.0)

    def test_knob_jour(self):
        for f in ("thematisee", "dominante"):
            with self.subTest(famille=f):
                k = self._jour(f)["knob"]
                self.assertEqual((k.l, k.c), (1.0, 0))

    def test_semantiques_par_moment(self):
        nuit = resolve(theme_data(self.data, "thematisee", "nuit"), 55)["semantic"]
        for f, h in (("thematisee", 55), ("dominante", 55), ("thematisee", 200)):
            jour = self._jour(f, h)["semantic"]
            for k, c in nuit.items():
                with self.subTest(famille=f, hue=h, k=k):
                    self.assertAlmostEqual(jour[k].h, c.h, places=6)
                    self.assertAlmostEqual(jour[k].c, c.c, places=6)
                    self.assertLess(jour[k].l, c.l)
        self.assertEqual(self._jour("thematisee")["semantic"], self._jour("dominante")["semantic"])

    def test_dominante_neutres(self):
        m = resolve(theme_data(self.data, "dominante", "nuit"), 55)
        self.assertTrue(all(c.c == 0 for c in m["ramp"]))
        self.assertEqual(m["accent"], self.models[55]["accent"])

    def test_fusion_profonde(self):
        data = {"a": {"x": 1, "y": 2}, "moments": {"m": {"a": {"x": 3}}}, "familles": {"f": {}}}
        self.assertEqual(theme_data(data, "f", "m")["a"], {"x": 3, "y": 2})
        self.assertEqual(data["a"], {"x": 1, "y": 2})

    def test_theme_inconnu(self):
        with self.assertRaisesRegex(KeyError, "famille inconnue : verre"):
            theme_data(self.data, "verre", "nuit")
        with self.assertRaisesRegex(KeyError, "moment inconnu : aube"):
            theme_data(self.data, "thematisee", "aube")

    def test_knob_nuit(self):
        for famille in ("thematisee", "dominante"):
            m = resolve(theme_data(self.data, famille, "nuit"), 55)
            with self.subTest(famille=famille):
                self.assertEqual(m["knob"], m["roles"]["text-emphasis"])


if __name__ == "__main__":
    unittest.main()
