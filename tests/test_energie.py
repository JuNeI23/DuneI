"""Bibliothèque energie.js — texte d'estimation, paliers d'alerte, armement et libellé des profils de l'énergie
(L2-13), éprouvés dans un vrai Quickshell sans fenêtre. Ignoré sans session Wayland ou sans Quickshell.
"""
import json
import os
import subprocess
import unittest

from tests.test_coque_theme import DELAI, QS, ROOT, EssaiCoque

ESSAI = ROOT / "coque" / "Energie" / "essai"


@unittest.skipUnless(os.environ.get("WAYLAND_DISPLAY") and QS, "session Wayland et Quickshell requis")
class EnergieJsTest(EssaiCoque, unittest.TestCase):
    """Appelle chaque fonction de energie.js par l'IPC de la coque d'essai de l'énergie."""

    essai = ESSAI
    teintes = (55,)

    def setUp(self):
        super().setUp()
        self.lancer(self.dir)
        self.attendre("energie : prêt")

    def appeler(self, fonction: str, *args):
        """Appelle une fonction de energie.js et rend sa valeur décodée du JSON.

        Entrées : fonction — nom exporté par energie.js ; args — ses arguments, transmis en JSON dans {"args": [...]}.
        Sortie : la valeur retournée, ou la chaîne « erreur : <message> » si la fonction lève.
        Erreurs : CalledProcessError si l'appel IPC échoue. Dépendances : qs, lancer.
        """
        sortie = subprocess.run([QS, "ipc", "--pid", str(self.proc.pid), "call", "energie", "appeler", fonction,
                                 json.dumps({"args": list(args)})], check=True, capture_output=True, text=True,
                                timeout=DELAI).stdout.strip()
        return sortie if sortie.startswith("erreur") else json.loads(sortie)

    def test_estimation_decharge(self):
        self.assertEqual(self.appeler("texteEstimation", "decharge", 27600), "7 h 40 restantes")
        self.assertEqual(self.appeler("texteEstimation", "decharge", 2100), "35 min restantes")
        self.assertEqual(self.appeler("texteEstimation", "decharge", 3600), "1 h 00 restantes")

    def test_estimation_arrondie_a_la_minute(self):
        self.assertEqual(self.appeler("texteEstimation", "decharge", 2129), "35 min restantes")
        self.assertEqual(self.appeler("texteEstimation", "decharge", 2131), "36 min restantes")

    def test_estimation_charge(self):
        self.assertEqual(self.appeler("texteEstimation", "charge", 4200), "Plein dans 1 h 10")
        self.assertEqual(self.appeler("texteEstimation", "charge", 600), "Plein dans 10 min")

    def test_estimation_nulle_jamais_zero_minute(self):
        self.assertEqual(self.appeler("texteEstimation", "charge", 0), "Estimation en cours…")
        self.assertEqual(self.appeler("texteEstimation", "decharge", 0), "Estimation en cours…")
        self.assertEqual(self.appeler("texteEstimation", "decharge", 10), "Estimation en cours…")

    def test_estimation_etats_sans_duree(self):
        self.assertEqual(self.appeler("texteEstimation", "chargee", 0), "Chargée")
        self.assertEqual(self.appeler("texteEstimation", "secteur", 0), "Sur secteur")

    def test_palier(self):
        self.assertEqual(self.appeler("palier", False, True, 0, 20, 5), 0)
        self.assertEqual(self.appeler("palier", True, True, 21, 20, 5), 0)
        self.assertEqual(self.appeler("palier", True, True, 20, 20, 5), 1)
        self.assertEqual(self.appeler("palier", True, True, 6, 20, 5), 1)
        self.assertEqual(self.appeler("palier", True, True, 5, 20, 5), 2)
        self.assertEqual(self.appeler("palier", True, False, 3, 20, 5), 0)

    def test_avancer_suite_oscillante(self):
        arme, annonces = 0, []
        for pourcent in (21, 20, 21, 20, 6, 5):
            p = self.appeler("palier", True, True, pourcent, 20, 5)
            r = self.appeler("avancer", arme, p, True)
            arme = r["arme"]
            annonces.append(r["annonce"])
        self.assertEqual(annonces, [0, 1, 0, 0, 0, 2])

    def test_avancer_rearmement_au_branchement(self):
        self.assertEqual(self.appeler("avancer", 2, 0, False), {"arme": 0, "annonce": 0})
        self.assertEqual(self.appeler("avancer", 0, 1, True), {"arme": 1, "annonce": 1})

    def test_avancer_demarrage_critique(self):
        self.assertEqual(self.appeler("avancer", 0, 2, True), {"arme": 2, "annonce": 2})

    def test_nom_profil(self):
        self.assertEqual(self.appeler("nomProfil", 0), "Économie")
        self.assertEqual(self.appeler("nomProfil", 1), "Équilibré")
        self.assertEqual(self.appeler("nomProfil", 2), "Performance")
        self.assertEqual(self.appeler("nomProfil", 9), "")
