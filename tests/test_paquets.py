"""Paquets — lecture et contrôle de paquets.toml, dans des dossiers temporaires."""

import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest import mock

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


class MaterielTest(unittest.TestCase):
    def racine(self, cpu="AuthenticAMD", cartes=None, hote=None):
        """Fabrique une racine temporaire : cpuinfo, cartes {nom: fabricant} et connecteur, nom d'hôte."""
        d = tempfile.TemporaryDirectory()
        self.addCleanup(d.cleanup)
        root = Path(d.name)
        (root / "proc").mkdir()
        (root / "proc/cpuinfo").write_text(f"processor\t: 0\nvendor_id\t: {cpu}\n", encoding="utf-8")
        for nom, vendor in (cartes or {}).items():
            (root / f"sys/class/drm/{nom}/device").mkdir(parents=True)
            (root / f"sys/class/drm/{nom}/device/vendor").write_text(vendor + "\n", encoding="utf-8")
        if cartes:
            (root / "sys/class/drm/card1-eDP-1").mkdir()
        if hote is not None:
            (root / "etc").mkdir()
            (root / "etc/hostname").write_text(hote, encoding="utf-8")
        return root

    def test_caladan(self):
        root = self.racine(cartes={"card1": "0x1002"})
        self.assertEqual(paquets.detecter(root), ({"amd"}, {"amd"}))

    def test_deux_cartes(self):
        root = self.racine(cartes={"card0": "0x8086", "card1": "0x10de"})
        self.assertEqual(paquets.detecter(root)[1], {"intel", "nvidia"})

    def test_carte_inconnue(self):
        root = self.racine(cartes={"card0": "0x1af4"})
        self.assertEqual(paquets.detecter(root)[1], {"inconnu:0x1af4"})

    def test_aucune_carte(self):
        self.assertEqual(paquets.detecter(self.racine())[1], set())

    def test_vendor_illisible(self):
        root = self.racine(cartes={"card0": "0x1002"})
        (root / "sys/class/drm/card0/device/vendor").unlink()
        self.assertEqual(paquets.detecter(root)[1], set())

    def test_nom_hote(self):
        self.assertEqual(paquets.nom_hote(self.racine(hote="caladan\n")), "caladan")
        self.assertIsNone(paquets.nom_hote(self.racine(hote="a.b")))
        self.assertIsNone(paquets.nom_hote(self.racine()))
        self.assertIsNone(paquets.nom_hote(self.racine(hote="")))

    def test_sysroot(self):
        self.assertEqual(paquets.sysroot({"DUNEI_SYSROOT": "/tmp/x"}), Path("/tmp/x"))
        self.assertEqual(paquets.sysroot({}), Path("/"))


class VoulusTest(unittest.TestCase):
    def setUp(self):
        self.m, err = paquets.lire(ROOT)
        self.assertEqual(err, [])

    def test_caladan_voulus(self):
        v, avert = paquets.voulus(self.m, "caladan", {"amd"}, {"amd"})
        self.assertTrue({"amd-ucode", "vulkan-radeon", "mesa", "sof-firmware", "wofi"} <= v)
        self.assertFalse({"vulkan-intel", "intel-ucode"} & v)
        self.assertEqual(avert, [])

    def test_nvidia_avertit(self):
        _, avert = paquets.voulus(self.m, "caladan", {"amd"}, {"nvidia"})
        self.assertTrue(any("aucun pilote décidé" in a for a in avert))

    def test_inconnu_avertit(self):
        v, avert = paquets.voulus(self.m, "caladan", {"amd"}, {"inconnu:0x1af4"})
        self.assertTrue(any("0x1af4" in a for a in avert))
        self.assertFalse({"vulkan-radeon", "vulkan-intel"} & v)

    def test_machine_sans_section(self):
        v, avert = paquets.voulus(self.m, "dunei-vm", {"amd"}, {"amd"})
        self.assertTrue(avert)
        self.assertIn("mesa", v)

    def test_hote_absent(self):
        v, avert = paquets.voulus(self.m, None, {"amd"}, {"amd"})
        self.assertTrue(any("nom d'hôte" in a for a in avert))
        self.assertIn("mesa", v)

    def test_aucune_carte_avertit(self):
        _, avert = paquets.voulus(self.m, "caladan", {"amd"}, set())
        self.assertTrue(any("aucune carte graphique" in a for a in avert))


class ControleTest(unittest.TestCase):
    def setUp(self):
        self.m = {"depots": ["core", "extra"], "groupes": {"base": ["vim"]}, "provisoire": {"wofi": "L2-16"},
                  "materiel": {"processeur": {"amd": ["amd-ucode"]}, "graphique": {"intel": ["vulkan-intel"]}},
                  "machines": {"caladan": ["steam"]}}
        self.tous = {"vim", "wofi", "amd-ucode", "vulkan-intel", "steam"}

    def test_depot_tiers(self):
        err = paquets.controler(self.m, ["core", "extra", "chaotic-aur"], self.tous)
        self.assertEqual(len(err), 1)
        self.assertIn("chaotic-aur", err[0])

    def test_nom_introuvable(self):
        err = paquets.controler(self.m, ["core"], self.tous - {"vim"})
        self.assertEqual(len(err), 1)
        self.assertIn("vim", err[0])

    def test_liste_materielle_absente_de_la_machine(self):
        err = paquets.controler(self.m, ["core"], self.tous - {"vulkan-intel"})
        self.assertTrue(any("vulkan-intel" in e for e in err))

    def test_base_vide(self):
        err = paquets.controler(self.m, ["core"], set())
        self.assertEqual(len(err), 1)
        self.assertIn("non synchronisée", err[0])

    def test_tout_va_bien(self):
        self.assertEqual(paquets.controler(self.m, ["core", "extra"], self.tous), [])


class CalculTest(unittest.TestCase):
    def test_categories(self):
        p = paquets.calculer(voulus={"a", "b", "c"}, installes={"b", "c", "x", "y", "o"},
                             explicites={"c", "x", "y"}, non_requis={"y"}, orphelins={"o"})
        self.assertEqual(p, {"manquants": ["a"], "a_expliciter": ["b"], "excedent_requis": ["x"],
                             "excedent_libre": ["y"], "orphelins": ["o"]})

    def test_rien_a_faire(self):
        p = paquets.calculer({"a"}, {"a"}, {"a"}, {"a"}, set())
        self.assertEqual(p, {k: [] for k in ("manquants", "a_expliciter", "excedent_requis",
                                              "excedent_libre", "orphelins")})


class EtatTest(unittest.TestCase):
    def etat(self, reponses):
        """Appelle paquets.etat avec subprocess.run remplacé : reponses associe le début de la commande à (code, sortie, erreur)."""
        def faux(cmd, **_):
            code, out, err = reponses.get(cmd[1] if cmd[0] == "pacman" else cmd[0], (0, "", ""))
            return subprocess.CompletedProcess(cmd, code, out, err)
        with mock.patch("subprocess.run", side_effect=faux):
            return paquets.etat()

    def test_lecture_et_code_1_vide(self):
        r = {"pacman-conf": (0, "core\nextra\n", ""), "-Sl": (0, "core vim 9 \nextra git 2 [installed]\n", ""),
             "-Qq": (0, "vim\ngit\n", ""), "-Qqe": (0, "vim\n", ""), "-Qqett": (1, "", ""), "-Qqdt": (1, "", "")}
        self.assertEqual(self.etat(r), (["core", "extra"], {"vim", "git"}, {"vim", "git"}, {"vim"}, set(), set()))

    def test_echec_lisible(self):
        with self.assertRaises(RuntimeError) as c:
            self.etat({"-Qq": (2, "", "base verrouillée")})
        self.assertIn("base verrouillée", str(c.exception))


if __name__ == "__main__":
    unittest.main()
