"""Application Paramètres — logique pure de recherche.js, éprouvée dans un vrai Quickshell sans fenêtre.

Ignoré sans session Wayland ou sans Quickshell (comme les autres tests de coque) : le JavaScript tourne dans le
moteur de Quickshell, jamais dans un interpréteur de substitution.
"""

import json
import os
import subprocess
import unittest

from tests.test_coque_theme import DELAI, QS, ROOT, EssaiCoque

ESSAI = ROOT / "coque" / "Parametres" / "essai"
# Index factice : deux réglages de la page Wi-Fi, dont un qui exige un réseau joint, et un de la page VPN.
INDEX = [
    {"page": "wifi", "chemin": ["wifi", "masque"], "libelle": "Réseau masqué", "motsCles": ["caché", "SSID"], "exige": ""},
    {"page": "wifi", "chemin": ["wifi", "details", "ip"], "libelle": "Adresse IP", "motsCles": ["IPv4", "réseau local"],
     "exige": "joint"},
    {"page": "vpn", "chemin": ["vpn", "demarrage"], "libelle": "Connexion au démarrage", "motsCles": ["automatique"],
     "exige": ""},
]


@unittest.skipUnless(os.environ.get("WAYLAND_DISPLAY") and QS, "session Wayland et Quickshell requis")
class RechercheTest(EssaiCoque, unittest.TestCase):
    """Appelle chaque fonction de recherche.js par l'IPC de la coque d'essai des paramètres."""

    essai = ESSAI
    teintes = ()

    def setUp(self):
        super().setUp()
        self.lancer(self.dir)
        self.attendre("parametres : prêt")

    def appeler(self, fonction: str, *args):
        """Appelle une fonction de recherche.js et rend sa valeur décodée.

        Entrées : fonction — nom exporté par recherche.js ; args — ses arguments, transmis en JSON dans
        {"args": [...]} (un tableau nu serait déformé par la ligne de commande de qs ipc).
        Sortie : la valeur retournée (décodée du JSON), ou la chaîne « erreur : <message> » si elle lève.
        Erreurs : CalledProcessError si l'appel IPC échoue. Dépendances : qs, lancer.
        """
        sortie = subprocess.run([QS, "ipc", "--pid", str(self.proc.pid), "call", "parametres", "appeler", fonction,
                                 json.dumps({"args": list(args)})], check=True, capture_output=True, text=True,
                                timeout=DELAI).stdout.strip()
        return sortie if sortie.startswith("erreur") else json.loads(sortie)

    def test_recherche_sans_accent(self):
        self.assertEqual(self.appeler("normaliser", "Réseau MASQUÉ"), "reseau masque")
        self.assertEqual(self.appeler("chercher", INDEX, "reseau", []),
                         [{"page": "wifi", "chemin": ["wifi", "masque"], "libelle": "Réseau masqué"}])
        self.assertEqual([r["libelle"] for r in self.appeler("chercher", INDEX, "DÉMARRAGE", [])], ["Connexion au démarrage"])

    def test_recherche_mot_cle(self):
        self.assertEqual([r["libelle"] for r in self.appeler("chercher", INDEX, "ssid", [])], ["Réseau masqué"])
        self.assertEqual([r["libelle"] for r in self.appeler("chercher", INDEX, "cache", [])], ["Réseau masqué"])
        self.assertEqual(self.appeler("chercher", INDEX, "bluetooth", ["joint"]), [])

    def test_cible_absente_non_proposee(self):
        self.assertEqual(self.appeler("chercher", INDEX, "adresse", []), [])
        self.assertEqual(self.appeler("chercher", INDEX, "adresse", ["joint"]),
                         [{"page": "wifi", "chemin": ["wifi", "details", "ip"], "libelle": "Adresse IP"}])
        # L'ordre de l'index est conservé : « réseau » est un libellé puis un mot-clé.
        self.assertEqual([r["libelle"] for r in self.appeler("chercher", INDEX, "réseau", ["joint"])],
                         ["Réseau masqué", "Adresse IP"])

    def test_terme_vide(self):
        self.assertEqual(self.appeler("chercher", INDEX, "", ["joint"]), [])
        self.assertEqual(self.appeler("chercher", INDEX, "  ", ["joint"]), [])
