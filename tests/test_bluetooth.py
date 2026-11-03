"""Bibliothèque bluetooth.js — filtre, tri, icônes et résumé du popover Bluetooth (L2-14), éprouvés dans un vrai
Quickshell sans fenêtre. Ignoré sans session Wayland ou sans Quickshell, comme les autres tests de coque.
"""
import json
import os
import subprocess
import unittest

from tests.test_coque_theme import DELAI, QS, ROOT, EssaiCoque

ESSAI = ROOT / "coque" / "Bluetooth" / "essai"


@unittest.skipUnless(os.environ.get("WAYLAND_DISPLAY") and QS, "session Wayland et Quickshell requis")
class BluetoothJsTest(EssaiCoque, unittest.TestCase):
    """Appelle chaque fonction de bluetooth.js par l'IPC de la coque d'essai du Bluetooth."""

    essai = ESSAI
    teintes = (55,)

    def setUp(self):
        super().setUp()
        self.lancer(self.dir)
        self.attendre("bluetooth : prêt")

    def appeler(self, fonction: str, *args):
        """Appelle une fonction de bluetooth.js et rend sa valeur décodée.

        Entrées : fonction — nom exporté par bluetooth.js ; args — ses arguments, transmis en JSON dans {"args": [...]}.
        Sortie : la valeur retournée (décodée du JSON), ou la chaîne « erreur : <message> » si elle lève.
        Erreurs : CalledProcessError si l'appel IPC échoue. Dépendances : qs, lancer.
        """
        sortie = subprocess.run([QS, "ipc", "--pid", str(self.proc.pid), "call", "bluetooth", "appeler", fonction,
                                 json.dumps({"args": list(args)})], check=True, capture_output=True, text=True,
                                timeout=DELAI).stdout.strip()
        return sortie if sortie.startswith("erreur") else json.loads(sortie)

    def test_anonyme(self):
        self.assertTrue(self.appeler("anonyme", "CC-61-46-D7-21-45", "CC:61:46:D7:21:45"))
        self.assertTrue(self.appeler("anonyme", "cc:61:46:d7:21:45", "CC:61:46:D7:21:45"))
        self.assertTrue(self.appeler("anonyme", "", "CC:61:46:D7:21:45"))
        self.assertFalse(self.appeler("anonyme", "Daikin", "D4:95:8E:31:AC:B7"))

    def test_trier_appareils(self):
        appareils = [
            {"nom": "Zeta", "adresse": "Z", "appaire": True, "connecte": False},
            {"nom": "Bose", "adresse": "B", "appaire": True, "connecte": True},
            {"nom": "AA-BB", "adresse": "AA:BB", "appaire": True, "connecte": False},
            {"nom": "CC-DD", "adresse": "CC:DD", "appaire": False, "connecte": False},
            {"nom": "b", "adresse": "b1", "appaire": False, "connecte": False},
            {"nom": "A", "adresse": "a1", "appaire": False, "connecte": False},
        ]
        self.assertEqual(self.appeler("trierAppareils", appareils), {"mes": ["B", "AA:BB", "Z"], "proches": ["a1", "b1"]})
        self.assertEqual(self.appeler("trierAppareils", []), {"mes": [], "proches": []})

    def test_icone_appareil(self):
        attendus = {"audio-headset": "audio-headphones", "audio-headphones": "audio-headphones",
                    "audio-card": "audio-speakers", "input-mouse": "input-mouse", "input-keyboard": "input-keyboard",
                    "input-gaming": "input-gaming", "phone": "phone", "computer": "computer",
                    "xyz": "bluetooth-active", "": "bluetooth-active"}
        for icone, nom in attendus.items():
            with self.subTest(icone=icone):
                self.assertEqual(self.appeler("iconeAppareil", icone), nom)

    def test_resume(self):
        self.assertEqual(self.appeler("resume", False, None), "Désactivé")
        self.assertEqual(self.appeler("resume", True, None), "Aucun appareil connecté")
        self.assertEqual(self.appeler("resume", True, {"nom": "Bose NC 700 Headphones", "batterie": None}),
                         "Bose NC 700 Headphones")
        self.assertEqual(self.appeler("resume", True, {"nom": "Bose NC 700 Headphones", "batterie": 0.615}),
                         "Bose NC 700 Headphones · 62 %")

    def test_etat_reel_se_charge(self):
        # Le singleton réel se charge et compose une ligne d'état, quel que soit l'état de la radio de la machine.
        sortie = subprocess.run([QS, "ipc", "--pid", str(self.proc.pid), "call", "bluetooth", "resume"], check=True,
                                capture_output=True, text=True, timeout=DELAI).stdout.strip()
        self.assertNotEqual(sortie, "", "ligne d'état vide")
        self.assertNotRegex(self.journal(), r"TypeError|ReferenceError|is not a type|Cannot assign")
