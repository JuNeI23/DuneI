"""Modèle résolu — l'accent, le sur-accent et les sémantiques suivent les tokens explicites."""

import unittest
from pathlib import Path

from dunei_theme.checks import check, mesures
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

    # Planchers qui diffèrent légitimement de la base, par moment, chacun consigné : sans cette liste blanche, une
    # surcharge de meta glissée dans un autre thème abaisserait la règle de la bible sans que rien ne le voie.
    DEROGATIONS = {
        "jour": {
            "knob-off": "le knob blanc sur la piste éteinte grise du jour : la nuit, sur fond sombre, mesure Lc 98 (D83)",
            "on-accent-muted": "accent muet du jour validé à 0,78 par Nicolas : état inactif volontairement atténué (D83)",
        },
    }

    def test_seuils_de_la_bible_hors_jour_thematise(self):
        """Hors du jour thématisé (D84), un thème garde la cible, le plancher absolu et les planchers de la base ;
        seules les dérogations listées ci-dessus, propres à un moment, peuvent s'en écarter."""
        base = self.data["meta"]
        for f, m in themes(self.data):
            if (f, m) == ("thematisee", "jour"):
                continue
            meta = theme_data(self.data, f, m)["meta"]
            with self.subTest(famille=f, moment=m):
                self.assertEqual(meta["contrast_target_body"], base["contrast_target_body"])
                self.assertEqual(meta["contrast_floor"], base["contrast_floor"])
                permis = set(self.DEROGATIONS.get(m, {}))
                ecarts = {k for k in base["planchers"] if meta["planchers"].get(k) != base["planchers"][k]}
                self.assertLessEqual(ecarts, permis, "plancher abaissé hors dérogation consignée")
                self.assertEqual(set(meta["planchers"]), set(base["planchers"]))

    def test_profil_de_mauvaise_longueur(self):
        """Un neutral_profile qui n'a pas autant de facteurs que d'échelons est refusé, jamais tronqué."""
        data = {**self.data, "lightness": {**self.data["lightness"], "neutral_profile": [1.0, 1.0]}}
        with self.assertRaises(ValueError):
            resolve(data, 55)

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
            for cle in ("ramp", "roles", "elevation", "accent", "accent_standalone", "accent_discret",
                        "on_accent", "categorical", "semantic"):
                with self.subTest(hue=h, cle=cle):
                    self.assertEqual(got[cle], ref[cle])

    def test_accent_discret(self):
        """L'accent discret garde la teinte de l'accent, avec 0,6 fois sa chroma et la luminosité de [accent]."""
        for h in HUES:
            m = self.models[h]
            with self.subTest(hue=h):
                self.assertEqual(m["accent_discret"].l, self.data["accent"]["discret_lightness"])
                self.assertAlmostEqual(m["accent_discret"].c, m["accent"].c * 0.6)
                self.assertEqual(m["accent_discret"].h, m["accent"].h)

    def test_accent_discret_css(self):
        """La feuille CSS publie --accent-discret avec la valeur du modèle."""
        from dunei_theme.emitters import css
        self.assertIn(f"--accent-discret: {self.models[55]['accent_discret'].css()};", css.emit(self.models[55]))

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
                # Le jour thématisé a une base colorée : E3 y est teinté et plus sombre que le blanc pur.
                if f == "dominante":
                    self.assertEqual((e["e3"].l, e["e3"].c), (1.0, 0))
                else:
                    self.assertGreater(e["e3"].c, 0)

    def test_jour_controle_blanc(self):
        for f in ("thematisee", "dominante"):
            with self.subTest(famille=f):
                # Seule la thématisée de jour, à base colorée, n'a pas de contrôle blanc : il suit E3 (0,88).
                attendu = 1.0 if f == "dominante" else self._jour(f)["elevation"]["e3"].l
                self.assertEqual(self._jour(f)["roles"]["control-raised"].l, attendu)

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
        # Le jour thématisé descend ses sémantiques (fonds colorés plus sombres) : même teinte et chroma, L plus bas.
        jt, jd = self._jour("thematisee")["semantic"], self._jour("dominante")["semantic"]
        for k in jd:
            with self.subTest(k=k):
                self.assertEqual((jt[k].c, jt[k].h), (jd[k].c, jd[k].h))
                self.assertLess(jt[k].l, jd[k].l)

    def test_dominante_neutres(self):
        m = resolve(theme_data(self.data, "dominante", "nuit"), 55)
        self.assertTrue(all(c.c == 0 for c in m["ramp"]))
        self.assertEqual(m["accent"], self.models[55]["accent"])

    def test_fusion_profonde(self):
        data = {"a": {"x": 1, "y": 2}, "moments": {"m": {"a": {"x": 3}}}, "familles": {"f": {}}}
        self.assertEqual(theme_data(data, "f", "m")["a"], {"x": 3, "y": 2})
        self.assertEqual(data["a"], {"x": 1, "y": 2})

    def test_fusion_croisee(self):
        """Vérifie l'ordre base, moment, famille, famille × moment ; la table croisée ne vaut que pour son moment
        et ne se fusionne pas dans [moments]."""
        data = {"a": {"x": 1, "y": 1, "z": 1}, "moments": {"m": {"a": {"x": 2, "y": 2}}, "n": {}},
                "familles": {"f": {"a": {"y": 3}, "moments": {"m": {"a": {"y": 5, "z": 4}}}}}}
        self.assertEqual(theme_data(data, "f", "m")["a"], {"x": 2, "y": 5, "z": 4})
        self.assertEqual(theme_data(data, "f", "n")["a"], {"x": 1, "y": 3, "z": 1})
        self.assertEqual(theme_data(data, "f", "m")["moments"], data["moments"])
        data["familles"]["f"]["moments"]["aube"] = {}
        with self.assertRaisesRegex(KeyError, "moment inconnu : aube"):
            theme_data(data, "f", "n")

    def test_dominante_nuit_plus_sombre(self):
        """Vérifie que la dominante de nuit descend ses surfaces et son contrôle de 0,03 (border-subtle, au même échelon
        que le contrôle, les suit) sans toucher aux textes, et
        que la dominante de jour garde les luminosités du jour thématisé."""
        th, do = (resolve(theme_data(self.data, f, "nuit"), 55)["roles"] for f in ("thematisee", "dominante"))
        for r in th:
            with self.subTest(role=r):
                ecart = 0.03 if r.startswith("surface-") or r in ("control-raised", "control-off", "border-subtle") else 0
                self.assertAlmostEqual(do[r].l, th[r].l - ecart, places=6)
        # Le jour thématisé a sa propre échelle (base colorée) ; la dominante de jour garde celle de [moments.jour].
        jt, jd = self._jour("thematisee")["roles"], self._jour("dominante")["roles"]
        self.assertNotEqual({r: c.l for r, c in jt.items()}, {r: c.l for r, c in jd.items()})

    def test_jour_thematise_infuse(self):
        """Vérifie que les surfaces claires du jour thématisé portent la teinte (chroma ≥ 0,012), que E3 et le
        contrôle sont teintés eux aussi (base colorée, aucun gris neutre), et que la dominante de jour reste
        strictement neutre."""
        for h in HUES:
            r = self._jour("thematisee", h)["roles"]
            with self.subTest(hue=h):
                for s in ("surface-base", "surface-window", "surface-panel"):
                    self.assertGreaterEqual(r[s].c, 0.012)
                self.assertGreater(r["surface-raised"].c, 0)
                self.assertGreater(r["control-raised"].c, 0)
                self.assertTrue(all(c.c == 0 for c in self._jour("dominante", h)["ramp"]))

    def test_piste_eteinte(self):
        """Vérifie le rôle control-off : à la nuit, la piste éteinte d'aujourd'hui sur un panneau (surface-raised) ;
        au jour, un gris clair tranché à l'écran par Nicolas (L 0,80 à 0,90 ; 0,70 à 0,80 sur la base colorée du jour
        thématisé) sur lequel le knob blanc se détache (|Lc| ≥ 15)."""
        for f in ("thematisee", "dominante"):
            nuit = resolve(theme_data(self.data, f, "nuit"), 55)
            with self.subTest(famille=f):
                self.assertEqual(nuit["roles"]["control-off"], nuit["roles"]["surface-raised"])
                for h in HUES:
                    jour = self._jour(f, h)
                    bas, haut = (0.70, 0.80) if f == "thematisee" else (0.80, 0.90)
                    self.assertTrue(bas <= jour["roles"]["control-off"].l <= haut)
                    self.assertEqual(check(jour), [])
                    self.assertGreaterEqual(mesures(jour)["knob-off"], 15)

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
