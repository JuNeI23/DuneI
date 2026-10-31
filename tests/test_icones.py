"""Sources Phosphor versionnées et table de correspondance (jamais de réseau)."""

import shutil
import tempfile
import tomllib
import unittest
from pathlib import Path

from generate_icones import composer, generer, index_theme, recolorable
from phosphor import charger, glyphes, nom_fichier

ROOT = Path(__file__).resolve().parent.parent
TABLE = ROOT / "icones" / "correspondances.toml"
SVG = ROOT / "icones" / "phosphor"

ATTENDUS = (
    [f"battery-level-{n}" for n in range(0, 101, 10)]
    + [f"battery-level-{n}-charging" for n in range(0, 100, 10)]
    + ["battery-level-100-charged"]
    + [f"network-wireless-signal-{s}" for s in ("none", "weak", "ok", "good", "excellent")]
    + ["network-wireless-disabled", "network-wireless-offline", "bluetooth-active", "bluetooth-disabled",
       "preferences-system-notifications", "notifications-disabled", "weather-clear", "weather-clear-night",
       "emblem-system", "system-search", "edit-clear", "network-vpn"]
    + ["network-wireless-no-route", "network-wireless-acquiring", "network-wireless-hotspot",
       "network-wireless-encrypted", "network-wired", "network-wired-acquiring", "network-wired-disconnected",
       "network-wired-offline", "network-wired-no-route", "view-refresh", "network-vpn-disabled",
       "view-reveal", "view-conceal", "edit-copy", "list-add", "go-next"]
)


class IconesTest(unittest.TestCase):

    def setUp(self):
        self.source, self.noms = charger(TABLE)
        self.graisse = self.source["graisse"]

    def test_table_complete(self):
        self.assertEqual(sorted(self.noms), sorted(ATTENDUS))

    def test_sources_presentes(self):
        for v in {g for n in self.noms.values() for g in glyphes(n)}:
            for g in (self.graisse, "fill"):
                self.assertTrue((SVG / g / nom_fichier(v, g)).is_file(), f"{g}/{v}")

    def test_variants_suivent_la_graisse(self):
        icones = tomllib.loads((ROOT / "tokens.toml").read_text(encoding="utf-8"))["icons"]
        self.assertEqual(icones["variants"], [self.graisse, "fill"])

    def test_licence_phosphor(self):
        licence = SVG / "LICENSE"
        self.assertTrue(licence.is_file())
        self.assertIn("MIT", licence.read_text(encoding="utf-8"))

    def test_aucun_svg_orphelin(self):
        voulus = {(g, nom_fichier(v, g)) for n in self.noms.values() for v in glyphes(n) for g in (self.graisse, "fill")}
        presents = {(p.parent.name, p.name) for p in SVG.glob("*/*.svg")}
        self.assertEqual(presents - voulus, set())

    def test_doublon_refuse(self):
        with tempfile.TemporaryDirectory() as d:
            t = Path(d) / "t.toml"
            t.write_text('[source]\ngraisse = "regular"\n[a]\n"x" = "bell"\n[b]\n"x" = "sun"\n', encoding="utf-8")
            with self.assertRaises(ValueError):
                charger(t)

    def test_index_theme(self):
        t = index_theme("DuneI", ["Adwaita", "breeze-dark", "hicolor"])
        for attendu in ("Inherits=Adwaita,breeze-dark,hicolor", "Directories=symbolic", "Type=Scalable"):
            self.assertIn(attendu, t)

    def test_recolorable(self):
        svg = ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 256" fill="currentColor">'
               '<path d="M0 0"/></svg>')
        r = recolorable(svg)
        self.assertEqual(r.count('class="ColorScheme-Text"'), 1)
        self.assertIn(".ColorScheme-Text{color:#bebebe}", r)
        self.assertIn('viewBox="0 0 256 256"', r)
        self.assertIn('<path d="M0 0"/>', r)
        self.assertEqual(r.count('fill="currentColor"'), 1)
        sans = recolorable('<svg viewBox="0 0 1 1"><path d="M0 0"/></svg>')
        self.assertIn('fill="currentColor"', sans)

    def test_generer_deux_variantes(self):
        with tempfile.TemporaryDirectory() as d:
            generer(ROOT, Path(d))
            for nom, phosphor in self.noms.items():
                self.assertTrue((Path(d) / "DuneI" / "symbolic" / f"{nom}-symbolic.svg").is_file())
                plein = (Path(d) / "DuneI" / "symbolic" / f"{nom}-fill-symbolic.svg").read_text(encoding="utf-8")
                bruts = [(SVG / "fill" / nom_fichier(g, "fill")).read_text(encoding="utf-8") for g in glyphes(phosphor)]
                self.assertEqual(plein, recolorable(composer(*bruts) if len(bruts) == 2 else bruts[0]))

    def test_source_manquante(self):
        with tempfile.TemporaryDirectory() as d:
            repo = Path(d)
            (repo / "icones").mkdir()
            shutil.copy(ROOT / "tokens.toml", repo / "tokens.toml")
            (repo / TABLE.relative_to(ROOT)).write_text(
                '[source]\ngraisse = "regular"\n[a]\n"x" = "absent"\n', encoding="utf-8")
            with self.assertRaises(FileNotFoundError) as e:
                generer(repo, repo / "out")
            self.assertIn("absent.svg", str(e.exception))

    def test_genere_a_jour(self):
        with tempfile.TemporaryDirectory() as d:
            generer(ROOT, Path(d))
            frais = sorted(p.relative_to(d) for p in Path(d).rglob("*") if p.is_file())
            suivi = sorted(p.relative_to(ROOT / "generated" / "icons") for p in (ROOT / "generated" / "icons").rglob("*") if p.is_file())
            self.assertEqual(frais, suivi)
            for p in frais:
                self.assertEqual((Path(d) / p).read_bytes(), (ROOT / "generated" / "icons" / p).read_bytes(), str(p))

    def test_glyphes(self):
        self.assertEqual(glyphes("bell"), ["bell"])
        self.assertEqual(glyphes("wifi-high+warning-circle"), ["wifi-high", "warning-circle"])

    def test_composer(self):
        base = '<svg viewBox="0 0 256 256" fill="currentColor"><path d="M1 1"/></svg>'
        badge = '<svg viewBox="0 0 256 256" fill="currentColor"><path d="M2 2"/><circle r="3"/></svg>'
        svg = composer(base, badge)
        self.assertEqual(svg.count("<svg"), 1)
        self.assertIn('viewBox="0 0 256 256"', svg)
        # La base est évidée sous la pastille (masque), la pastille est réduite et épaissie.
        self.assertRegex(svg, r'<g mask="url\(#[a-z]+\)"><path d="M1 1"/></g>')
        self.assertRegex(svg, r'<g transform="translate\([\d. ]+\) scale\([\d.]+\)" stroke="currentColor" '
                              r'stroke-width="\d+" stroke-linejoin="round"><path d="M2 2"/><circle r="3"/></g>')
        self.assertIn("<mask", svg)

    def test_icone_composee_generee(self):
        # « Sans internet » est un SVG unique composé de deux glyphes (wifi-high et warning-circle).
        self.assertEqual(glyphes(self.noms["network-wireless-no-route"]), ["wifi-high", "warning-circle"])
        self.assertEqual(glyphes(self.noms["network-wired-no-route"]), ["network", "warning-circle"])
        with tempfile.TemporaryDirectory() as d:
            generer(ROOT, Path(d))
            for nom in ("network-wireless-no-route", "network-wired-no-route"):
                for suffixe in ("", "-fill"):
                    svg = (Path(d) / "DuneI" / "symbolic" / f"{nom}{suffixe}-symbolic.svg").read_text(encoding="utf-8")
                    self.assertEqual(svg.count("<svg"), 1, nom)
                    self.assertIn("<mask", svg)
                    self.assertIn('class="ColorScheme-Text"', svg)


if __name__ == "__main__":
    unittest.main()
