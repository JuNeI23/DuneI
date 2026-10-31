"""Sources Phosphor versionnées et table de correspondance (jamais de réseau)."""

import shutil
import tempfile
import tomllib
import unittest
from pathlib import Path

from generate_icones import generer, index_theme, recolorable
from phosphor import charger, nom_fichier

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
       "network-wired-offline", "network-wired-no-route", "view-refresh", "network-vpn-disabled"]
)


class IconesTest(unittest.TestCase):

    def setUp(self):
        self.source, self.noms = charger(TABLE)
        self.graisse = self.source["graisse"]

    def test_table_complete(self):
        self.assertEqual(sorted(self.noms), sorted(ATTENDUS))

    def test_sources_presentes(self):
        for v in set(self.noms.values()):
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
        voulus = {(g, nom_fichier(v, g)) for v in self.noms.values() for g in (self.graisse, "fill")}
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
                brut = (SVG / "fill" / nom_fichier(phosphor, "fill")).read_text(encoding="utf-8")
                self.assertEqual(plein, recolorable(brut))

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


if __name__ == "__main__":
    unittest.main()
