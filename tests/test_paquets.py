"""Paquets — lecture et contrôle de paquets.toml, dans des dossiers temporaires."""

import tempfile
import unittest
from pathlib import Path

import paquets

ROOT = Path(__file__).resolve().parent.parent
BASE = 'version = "0.1.0"\ndepots = ["core", "extra"]\n'


class LireTest(unittest.TestCase):
    def lire(self, corps: str, entete: str = BASE):
        """Écrit un paquets.toml temporaire (en-tête puis corps) et le lit avec paquets.lire."""
        with tempfile.TemporaryDirectory() as d:
            (Path(d) / paquets.FICHIER).write_text(entete + corps, encoding="utf-8")
            return paquets.lire(Path(d))

    def test_depot_reel(self):
        modele, err = paquets.lire(ROOT)
        self.assertEqual(err, [])
        self.assertEqual(modele["depots"], ["core", "extra"])
        self.assertIn("mesa", modele["groupes"]["session"])
        self.assertEqual(modele["provisoire"]["wofi"], "L2-16")
        self.assertEqual(modele["materiel"]["graphique"]["amd"], ["vulkan-radeon"])
        self.assertEqual(modele["materiel"]["graphique"]["intel"], ["vulkan-intel", "intel-media-driver"])
        self.assertEqual(modele["materiel"]["graphique"]["nvidia"], [])
        self.assertNotIn("amd-ucode", modele["machines"]["caladan"])
        self.assertNotIn("rust", [p for l in modele["groupes"].values() for p in l])

    def test_modele_minimal(self):
        modele, err = self.lire('[groupes]\nsocle = ["base"]\n[machines.hote]\npaquets = ["alsa-utils"]\n')
        self.assertEqual(err, [])
        self.assertEqual(modele["groupes"], {"socle": ["base"]})
        self.assertEqual(modele["machines"], {"hote": ["alsa-utils"]})
        self.assertEqual(modele["provisoire"], {})
        self.assertEqual(modele["materiel"], {"processeur": {}, "graphique": {}})

    def test_version_inattendue(self):
        modele, err = self.lire("", entete='version = "9"\ndepots = ["core", "extra"]\n')
        self.assertEqual(modele, {})
        self.assertTrue(any("version" in e for e in err))

    def test_doublon_entre_groupes(self):
        modele, err = self.lire('[groupes]\noutils = ["vim"]\nsocle = ["vim"]\n')
        self.assertEqual(modele, {})
        self.assertTrue(any("vim" in e and "deux fois" in e for e in err))

    def test_doublon_provisoire_groupe(self):
        modele, err = self.lire('[groupes]\nsocle = ["wofi"]\n[provisoire]\nwofi = "L2-16"\n')
        self.assertEqual(modele, {})
        self.assertTrue(any("wofi" in e for e in err))

    def test_doublon_machine_groupe(self):
        _, err = self.lire('[groupes]\nsocle = ["base"]\n[machines.h]\npaquets = ["base"]\n')
        self.assertTrue(any("base" in e for e in err))

    def test_materiel_repete_un_groupe(self):
        modele, err = self.lire('[groupes]\nsession = ["mesa"]\n[materiel.graphique.amd]\npaquets = ["mesa"]\n')
        self.assertEqual(modele, {})
        self.assertTrue(any("mesa" in e for e in err))

    def test_materiel_partage_permis(self):
        _, err = self.lire('[materiel.graphique.amd]\npaquets = ["x"]\n[materiel.graphique.intel]\npaquets = ["x"]\n')
        self.assertEqual(err, [])

    def test_nom_vide(self):
        modele, err = self.lire('[groupes]\nsocle = [""]\n')
        self.assertEqual(modele, {})
        self.assertTrue(err)

    def test_depots_inattendus(self):
        _, err = self.lire("", entete='version = "0.1.0"\ndepots = ["core", "chaotic-aur"]\n')
        self.assertTrue(any("depots" in e for e in err))

    def test_toml_illisible(self):
        modele, err = self.lire("[groupes\n")
        self.assertEqual(modele, {})
        self.assertTrue(any("illisible" in e for e in err))

    def test_fichier_absent(self):
        with tempfile.TemporaryDirectory() as d:
            modele, err = paquets.lire(Path(d))
        self.assertEqual(modele, {})
        self.assertTrue(any("illisible" in e for e in err))


if __name__ == "__main__":
    unittest.main()
