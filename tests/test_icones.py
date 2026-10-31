"""Sources Phosphor versionnées et table de correspondance (jamais de réseau)."""

import tempfile
import unittest
from pathlib import Path

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


if __name__ == "__main__":
    unittest.main()
