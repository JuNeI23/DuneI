"""Bibliothèque audio.js — filtres, pourcentage, icônes et annonces de l'audio (L2-12), éprouvés dans un vrai
Quickshell sans fenêtre. Ignoré sans session Wayland ou sans Quickshell, comme les autres tests de coque.
"""
import json
import os
import subprocess
import unittest

from tests.test_coque_theme import DELAI, QS, ROOT, EssaiCoque

ESSAI = ROOT / "coque" / "Audio" / "essai"


@unittest.skipUnless(os.environ.get("WAYLAND_DISPLAY") and QS, "session Wayland et Quickshell requis")
class AudioJsTest(EssaiCoque, unittest.TestCase):
    """Appelle chaque fonction de audio.js par l'IPC de la coque d'essai de l'audio."""

    essai = ESSAI
    teintes = (55,)

    def setUp(self):
        super().setUp()
        self.lancer(self.dir)
        self.attendre("audio : prêt")

    def appeler(self, fonction: str, *args) -> str:
        """Appelle une fonction de audio.js et rend sa valeur encodée en JSON.

        Entrées : fonction — nom exporté par audio.js ; args — ses arguments, transmis en JSON dans {"args": [...]}.
        Sortie : le JSON retourné, ou la chaîne « erreur : <message> » si la fonction lève.
        Erreurs : CalledProcessError si l'appel IPC échoue. Dépendances : qs, lancer.
        """
        return subprocess.run([QS, "ipc", "--pid", str(self.proc.pid), "call", "audio", "appeler", fonction,
                               json.dumps({"args": list(args)})], check=True, capture_output=True, text=True,
                              timeout=DELAI).stdout.strip()

    def test_filtres(self):
        sortie = {"audio": {}, "isSink": True, "isStream": False}
        flux = {"audio": {}, "isSink": True, "isStream": True}
        micro = {"audio": {}, "isSink": False, "isStream": False}
        self.assertEqual(self.appeler("estSortie", sortie), "true")
        self.assertEqual(self.appeler("estSortie", flux), "false")
        self.assertEqual(self.appeler("estEntree", micro), "true")
        self.assertEqual(self.appeler("estSortie", {"audio": None, "isSink": True, "isStream": False}), "false")

    def test_pourcent_borne(self):
        self.assertEqual(self.appeler("pourcent", 0.7499847), "75")
        self.assertEqual(self.appeler("pourcent", 1.3), "100")
        self.assertEqual(self.appeler("pourcent", -0.1), "0")
        self.assertEqual(self.appeler("pourcent", None), "0")

    def test_icone_appareil(self):
        ia = lambda n, e: json.loads(self.appeler("iconeAppareil", n, e))
        self.assertEqual(ia({"name": "bluez_output.4C_87_5D", "properties": {}}, False), "audio-headphones")
        self.assertEqual(ia({"name": "alsa_output.pci", "properties": {}}, False), "audio-speakers")
        self.assertEqual(ia({"name": "alsa_input.pci", "description": "Ryzen HD Audio Controller Stereo Microphone",
                             "properties": {}}, True), "audio-headset")
        self.assertEqual(ia({"name": "alsa_input.pci", "description": "Ryzen HD Audio Controller Digital Microphone",
                             "properties": {}}, True), "audio-input-microphone")

    def test_annonce_micro(self):
        a = json.loads(self.appeler("annonce", "micro", None, None, False, True))
        self.assertEqual(a, {"genre": "micro", "appareil": "", "texte": "Micro coupé", "coupe": True})
