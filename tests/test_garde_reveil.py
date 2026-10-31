"""Garde du réveil : le bouton marche est ignoré quelques secondes autour de chaque mise en veille."""

import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
UNITES = ROOT / "systeme" / "etc" / "systemd" / "system"
SERVICE = UNITES / "dunei-garde-reveil.service"
RATTACHE = UNITES / "sleep.target.d" / "10-dunei.conf"


def lignes(f):
    """Lit un fichier d'unité ; sortie : ses lignes, commentaires exclus."""
    return [l for l in f.read_text(encoding="utf-8").splitlines() if l and not l.startswith("#")]


class GardeReveilTest(unittest.TestCase):
    """Le verrou de logind est pris avant la veille et retombe seul, une dizaine de secondes après le réveil (treize au total)."""

    def test_marque(self):
        for f in (SERVICE, RATTACHE):
            with self.subTest(fichier=f.name):
                self.assertIn("Posé par DuneI", f.read_text(encoding="utf-8").splitlines()[1])

    def test_rattachement(self):
        self.assertEqual(lignes(RATTACHE), ["[Unit]", "Wants=dunei-garde-reveil.service"])

    def test_service(self):
        l = lignes(SERVICE)
        self.assertIn("Before=sleep.target", l)
        self.assertIn("Type=exec", l)
        exe = next(x for x in l if x.startswith("ExecStart="))
        self.assertTrue(exe.startswith("ExecStart=/usr/bin/systemd-inhibit --what=handle-power-key --mode=block "))
        self.assertTrue(exe.endswith(" /usr/bin/sleep 13"))


if __name__ == "__main__":
    unittest.main()
