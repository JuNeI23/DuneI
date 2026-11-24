"""Tests de l'agent d'authentification de la coque (L2-24).

Rôle : éprouve la logique pure d'autorisation.js (réglages et relevé de faillock, état, ligne d'état, rafale d'échecs)
dans un vrai Quickshell, par l'IPC de la coque d'essai coque/Autorisation/essai/logique. Aucun essai n'ouvre de
conversation PAM ni polkit, et aucun ne lance faillock.
Entrées : aucune. Sorties : résultats unittest. Erreurs : échecs de test.
Dépendances : qs (Quickshell ≥ 0.3), tests.test_coque_theme (EssaiCoque).
"""
import json
import os
import subprocess
import unittest
from datetime import datetime

from tests.test_coque_theme import DELAI, QS, ROOT, EssaiCoque

ENTETE = "junei:\nWhen                Type  Source                                           Valid\n"
# Relevé du 24 novembre, quatre échecs dont un périmé (I), tel que faillock --user l'écrit.
RELEVE = ENTETE + "".join(
    f"2026-11-24 {h} SVC   polkit-1                                         {v}\n"
    for h, v in (("16:20:00", "I"), ("16:27:56", "V"), ("16:27:57", "V"), ("16:27:59", "V")))
DEFAUTS = {"deny": 3, "fail_interval": 900, "unlock_time": 600}


def instant(heure: str) -> int:
    """Secondes Unix d'une heure locale du 24 novembre 2026.

    Entrée : heure, « HH:MM:SS ». Sortie : secondes. Erreurs : ValueError. Dépendances : datetime.
    """
    return int(datetime.fromisoformat(f"2026-11-24 {heure}").timestamp())


@unittest.skipUnless(os.environ.get("WAYLAND_DISPLAY") and QS, "session Wayland et Quickshell requis")
class LogiqueTest(EssaiCoque, unittest.TestCase):
    """La logique de l'agent (autorisation.js), appelée par l'IPC d'une coque d'essai sans fenêtre."""

    essai = ROOT / "coque" / "Autorisation" / "essai" / "logique"
    teintes = ()

    def setUp(self):
        """Lance la coque d'essai de la logique et attend qu'elle soit prête.

        Entrées : aucune. Sortie : aucune ; self.proc tient la coque. Erreurs : échec du test si « essai : prêt »
        n'apparaît pas dans le délai. Dépendances : EssaiCoque.setUp, lancer, attendre.
        """
        super().setUp()
        self.lancer(self.dir)
        self.attendre("essai : prêt")

    def appeler(self, fonction: str, *args):
        """Appelle une fonction d'autorisation.js et rend sa valeur décodée.

        Entrées : fonction, nom exporté ; args, ses arguments, transmis en JSON. Sortie : la valeur retournée.
        Erreurs : échec du test si la fonction lève ; CalledProcessError si l'appel IPC échoue. Dépendances : qs.
        """
        sortie = subprocess.run([QS, "ipc", "--pid", str(self.proc.pid), "call", "essai", "appeler", fonction,
                                 json.dumps({"args": list(args)})], check=True, capture_output=True, text=True,
                                timeout=DELAI).stdout.strip()
        self.assertFalse(sortie.startswith("erreur"), sortie)
        return json.loads(sortie)

    def test_lire_conf(self):
        """Vérifie les défauts, les réglages lus et les lignes ignorées. Sortie : aucune. Erreurs : assertion."""
        self.assertEqual(self.appeler("lireConf", ""), DEFAUTS)
        self.assertEqual(self.appeler("lireConf", "# deny = 9\n\ndeny = 5\nunlock_time=60 # dix\nfail_interval = x\naudit\n"),
                         {"deny": 5, "fail_interval": 900, "unlock_time": 60})

    def test_verrou_releve(self):
        """Vérifie verrou et essais restants sur le relevé réel. Sortie : aucune. Erreurs : assertion."""
        verrou = lambda h, conf=DEFAUTS, texte=RELEVE: self.appeler("verrou", texte, conf, instant(h))
        self.assertEqual(verrou("16:30:00"), {"restants": 0, "jusqua": instant("16:37:59")})
        self.assertEqual(verrou("16:40:00"), {"restants": 3, "jusqua": None})
        cinq = {**DEFAUTS, "deny": 5}
        self.assertEqual(verrou("16:30:00", cinq), {"restants": 2, "jusqua": None})
        self.assertEqual(verrou("17:00:00", cinq), {"restants": 5, "jusqua": None})
        self.assertEqual(verrou("16:30:00", cinq, ENTETE), {"restants": 5, "jusqua": None})

    def test_verrou_illisible(self):
        """Vérifie qu'un relevé illisible ne dit rien. Sortie : aucune. Erreurs : assertion."""
        for texte in ("", "n'importe quoi"):
            self.assertEqual(self.appeler("verrou", texte, DEFAUTS, instant("16:30:00")), {"restants": None, "jusqua": None})

    def test_etat(self):
        """Vérifie l'état et l'ordre de priorité. Sortie : aucune. Erreurs : assertion."""
        tout = {"termine": True, "verrouille": True, "enVol": True, "requis": True}
        for cle, attendu in (("termine", "succes"), ("verrouille", "verrouille"), ("enVol", "verification"),
                             ("requis", "saisie"), (None, "attente")):
            self.assertEqual(self.appeler("etat", tout), attendu)
            if cle:
                tout[cle] = False

    def test_ligne(self):
        """Vérifie le texte de la ligne d'état. Sortie : aucune. Erreurs : assertion."""
        for etat, donnees, texte, erreur in (
                ("saisie", {"echec": True, "restants": 4}, "Mot de passe incorrect. Quatre essais restants.", True),
                ("saisie", {"echec": True, "restants": 1}, "Mot de passe incorrect. Un essai restant.", True),
                ("saisie", {"echec": True, "restants": 12}, "Mot de passe incorrect. 12 essais restants.", True),
                ("saisie", {"echec": True, "restants": None}, "Mot de passe incorrect.", True),
                ("saisie", {"echec": False, "restants": 5}, "", False),
                ("saisie", {"echec": False, "supplement": "Texte inconnu"}, "Texte inconnu", False),
                ("verrouille", {"jusqua": instant("16:37:59")}, "Compte verrouillé. Réessayer à 16 h 38.", True),
                ("verrouille", {"jusqua": instant("16:05:00")}, "Compte verrouillé. Réessayer à 16 h 05.", True),
                ("verification", {"echec": True, "restants": 4}, "Vérification", False),
                ("attente", {}, "", False), ("succes", {"echec": True}, "", False)):
            with self.subTest(etat=etat, donnees=donnees):
                self.assertEqual(self.appeler("ligne", etat, donnees), {"texte": texte, "erreur": erreur})

    def test_rafale(self):
        """Vérifie la détection de trois échecs en moins d'une seconde. Sortie : aucune. Erreurs : assertion."""
        self.assertTrue(self.appeler("rafale", [0, 400], 900))
        self.assertFalse(self.appeler("rafale", [0, 400], 1200))
        self.assertFalse(self.appeler("rafale", [0], 100))
