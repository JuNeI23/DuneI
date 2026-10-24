"""Cible coque-tokens.json — valeurs de design de la coque Quickshell, hors états."""

import json
import re
import unittest
from pathlib import Path

from dunei_theme.color import Oklch, oklch, to_hex
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
            "_generated", "hue", "color", "states", "focus", "disabled", "elevation", "material", "render",
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

    def test_liseres_physiques(self):
        self.assertEqual(list(self.out["render"]), ["scrim", "neverAnimateBlurRadius", "hairlinePhysical"])
        self.assertIs(self.out["render"]["hairlinePhysical"], self.data["scaling"]["hairlines_in_physical_pixels"])

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

    def test_cotes_des_controles(self):
        """Vérifie que les cotes des contrôles (case, radio, interrupteur, curseur, jauge, onglets, pastilles,
        compteur, bascule) passent en camelCase dans density."""
        d = self.out["density"]["comfortable"]
        self.assertEqual({k: d[k] for k in ("checkSize", "switchWidth", "switchHeight", "switchThumb", "sliderTrack",
                                             "sliderHandle", "sliderWidth", "fieldWidth", "radioDot", "sliderBar",
                                             "segmentInset", "sliderBarIcon", "pastille", "stepperWidth",
                                             "toggleSize")},
                         {"checkSize": 16, "switchWidth": 38, "switchHeight": 22, "switchThumb": 18,
                          "sliderTrack": 4, "sliderHandle": 20, "sliderWidth": 160, "fieldWidth": 200,
                          "radioDot": 6, "sliderBar": 22, "segmentInset": 2, "sliderBarIcon": 14, "pastille": 12,
                          "stepperWidth": 16, "toggleSize": 32})
        c = self.out["density"]["compact"]
        self.assertEqual({k: c[k] for k in ("switchWidth", "switchHeight", "switchThumb", "sliderHandle", "sliderWidth",
                                             "radioDot", "sliderBar", "segmentInset", "sliderBarIcon", "pastille",
                                             "stepperWidth", "toggleSize")},
                         {"switchWidth": 32, "switchHeight": 18, "switchThumb": 14, "sliderHandle": 18,
                          "sliderWidth": 140, "radioDot": 6, "sliderBar": 18, "segmentInset": 2, "sliderBarIcon": 12,
                          "pastille": 12, "stepperWidth": 14, "toggleSize": 28})
        self.assertEqual(self.out["density"]["compact"]["fieldWidth"], 180)

    def test_states_complet(self):
        """Vérifie la présence des 64 combinaisons, chacune avec un fond et un texte."""
        for r in ("surfaceWindow", "surfacePanel", "surfaceRaised", "controlRaised"):
            for s in ("none", "active", "inactive", "activeMuted"):
                for i in ("rest", "hover", "pressed", "disabled"):
                    with self.subTest(r=r, s=s, i=i):
                        self.assertEqual(set(self.out["states"][r][s][i]), {"fill", "text"})

    def test_control_raised(self):
        """Vérifie que le rôle des contrôles sur E3 est l'échelon 4 de la rampe, un cran au-dessus de surfaceRaised."""
        m = self.model
        self.assertEqual(self.out["color"]["controlRaised"], to_hex(m["ramp"][4]))
        self.assertEqual(self.out["states"]["controlRaised"]["none"]["rest"]["fill"], to_hex(m["ramp"][4]))
        self.assertGreater(m["roles"]["control-raised"].l, m["roles"]["surface-raised"].l)

    def test_states_valeurs(self):
        """Vérifie les règles de la bible sur la teinte 55 et le rôle surfacePanel."""
        m, ce = self.model, self.data["theme"]["chroma_ceiling"]
        st, panel, acc = self.out["states"]["surfacePanel"], m["roles"]["surface-panel"], m["accent"]
        txt = to_hex(m["roles"]["text-primary"])
        self.assertEqual(st["none"]["rest"]["fill"], to_hex(panel))
        self.assertEqual(st["none"]["hover"]["fill"], to_hex(oklch(panel.l + 0.04, panel.c, panel.h, ce)))
        self.assertEqual(st["active"]["rest"], {"fill": to_hex(acc), "text": to_hex(m["on_accent"])})
        self.assertEqual(st["active"]["pressed"]["fill"], to_hex(oklch(acc.l - 0.03, acc.c, acc.h, ce)))
        self.assertEqual(st["activeMuted"]["rest"]["fill"], to_hex(oklch(acc.l, 0, acc.h, ce)))
        self.assertEqual(st["inactive"]["rest"], {"fill": to_hex(m["ramp"][4]), "text": txt})
        self.assertEqual(st["none"]["disabled"]["fill"], to_hex(oklch(panel.l, panel.c * 0.15, panel.h, ce)))
        self.assertEqual(st["active"]["disabled"]["fill"],
                         to_hex(oklch(acc.l + (panel.l - acc.l) * 0.55, acc.c * 0.15, acc.h, ce)))

    def test_semantiques_pastilles(self):
        """Vérifie les variantes de survol et de pression d'error, warning et success, propres aux pastilles de
        fenêtre : la luminosité monte ou descend des écarts de la section pastilles (et non de ceux des états), en
        OKLCH, chroma et teinte inchangés ; les trois teintes d'une même pastille restent distinctes."""
        p = self.data["pastilles"]
        for k in ("error", "warning", "success"):
            s, c = self.model["semantic"][k], self.out["color"]
            with self.subTest(teinte=k):
                for suffixe, dl in (("Hover", p["hover_lightness_delta"]), ("Pressed", p["pressed_lightness_delta"])):
                    self.assertEqual(c[f"{k}{suffixe}"], to_hex(Oklch(round(s.l + dl, 3), s.c, s.h)))
                self.assertEqual(len({c[k], c[f"{k}Hover"], c[f"{k}Pressed"]}), 3)
        self.assertGreater(p["hover_lightness_delta"], self.data["states"]["hover"]["lightness_delta"])
        self.assertLess(p["pressed_lightness_delta"], self.data["states"]["pressed"]["lightness_delta"])

    def test_glyphes_des_pastilles_lisibles(self):
        """Vérifie, à chaque teinte de référence, que le glyphe des pastilles (color.surfaceBase) garde un contraste
        d'au moins 3:1, celui demandé à un élément graphique, sur chaque teinte au repos, survolée et pressée."""

        def luminance(hexa: str) -> float:
            """Luminance relative WCAG d'une couleur #rrggbb. Entrée : hexa. Sortie : réel de 0 à 1.
            Erreurs : ValueError sur une chaîne mal formée. Dépendances : aucune."""
            lin = [(v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4)
                   for v in (int(hexa[i:i + 2], 16) / 255 for i in (1, 3, 5))]
            return 0.2126 * lin[0] + 0.7152 * lin[1] + 0.0722 * lin[2]

        for hue in GOLDEN_HUES:
            c = json.loads(emit(resolve(self.data, float(hue))))["color"]
            fond = luminance(c["surfaceBase"])
            for k in ("error", "warning", "success"):
                for suffixe in ("", "Hover", "Pressed"):
                    with self.subTest(teinte=hue, couleur=k + suffixe):
                        self.assertGreaterEqual((luminance(c[k + suffixe]) + 0.05) / (fond + 0.05), 3)

    def test_focus(self):
        """Vérifie l'anneau de focus : couleurs, épaisseur et décalages."""
        a = self.model["accent_standalone"]
        self.assertEqual(self.out["focus"], {
            "color": to_hex(a), "colorMuted": to_hex(oklch(a.l, 0, a.h, self.data["theme"]["chroma_ceiling"])),
            "width": 2, "offset": 2, "rowOffset": -1})

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
