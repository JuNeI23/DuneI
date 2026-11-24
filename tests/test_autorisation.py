"""Tests de l'agent d'authentification de la coque (L2-24).

Rôle : éprouve la logique pure d'autorisation.js (réglages et relevé de faillock, état, ligne d'état, rafale d'échecs)
dans un vrai Quickshell, par l'IPC de la coque d'essai coque/Autorisation/essai/logique ; puis le contrôleur
Autorisation, sans fenêtre ni clavier, par la coque d'essai coque/Autorisation/essai/fenetre, dont les flux et le
lecteur de faillock sont factices. Aucun essai n'ouvre de conversation PAM ni polkit, et aucun ne lance faillock.
Entrées : aucune. Sorties : résultats unittest. Erreurs : échecs de test.
Dépendances : qs (Quickshell ≥ 0.3), tests.test_coque_theme (EssaiCoque).
"""
import json
import os
import subprocess
import time
import unittest
from datetime import datetime, timedelta

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


SECRET = "factice-7d1f"     # Mot de passe factice, qui ne doit paraître dans aucun journal.


def releve(n: int) -> str:
    """Relevé de faillock de n échecs valides, dans la minute passée. Entrée : n. Sortie : texte. Erreurs : aucune."""
    t = datetime.now() - timedelta(seconds=30)
    return ENTETE + f"{t:%Y-%m-%d %H:%M:%S} SVC   polkit-1                                         V\n" * n


@unittest.skipUnless(os.environ.get("WAYLAND_DISPLAY") and QS, "session Wayland et Quickshell requis")
class ControleurTest(EssaiCoque, unittest.TestCase):
    """Le contrôleur Autorisation, sans fenêtre, sur de faux flux, piloté par l'IPC « essai »."""

    essai = ROOT / "coque" / "Autorisation" / "essai" / "fenetre"
    teintes = (55,)

    def setUp(self):
        """Lance la coque d'essai et attend les jetons. Entrées : aucune. Sortie : aucune. Erreurs : échec au délai.
        Dépendances : installer, lancer, attendre, jusqua."""
        super().setUp()
        self.installer(55)
        self.lancer(self.dir)
        self.attendre("essai : prêt")
        self.jusqua(lambda: self.appel("pret") == "true", "jetons chargés")

    def appel(self, fonction: str, *args: str, cible: str = "essai") -> str:
        """Appelle une fonction IPC. Entrées : fonction, args, cible. Sortie : texte rendu.
        Erreurs : CalledProcessError. Dépendances : qs."""
        return subprocess.run([QS, "ipc", "--pid", str(self.proc.pid), "call", cible, fonction, *args], check=True,
                              capture_output=True, text=True, timeout=DELAI).stdout.strip()

    def etat(self) -> dict:
        """État de l'agent, par l'IPC « autorisation ». Sortie : {ouvert, etat, ligne, saisieOuverte}."""
        return json.loads(self.appel("etat", cible="autorisation"))

    def jusqua(self, condition, message: str):
        """Attend qu'une condition rende une valeur vraie et la rend. Entrées : condition, message.
        Sortie : la valeur. Erreurs : échec du test au délai. Dépendances : journal."""
        fin = time.monotonic() + DELAI
        while time.monotonic() < fin:
            valeur = condition()
            if valeur:
                return valeur
            time.sleep(0.05)
        self.fail(f"{message} attendu :\n{self.journal()}")

    def demander(self, **props) -> int:
        """Nouvelle demande factice. Entrées : propriétés du flux. Sortie : son rang."""
        return int(self.appel("demander", json.dumps(props)))

    def saisie(self) -> dict:
        """Attend la fin de la garde de frappe. Sortie : l'état."""
        return self.jusqua(lambda: (e := self.etat())["saisieOuverte"] and e, "saisie ouverte")

    def appels(self, i: int = 0) -> list:
        """Appels reçus par un faux flux. Entrée : i, son rang. Sortie : liste."""
        return json.loads(self.appel("appels", str(i)))["appels"]

    def vides(self) -> int:
        """Nombre de vidages du champ. Sortie : entier."""
        return json.loads(self.appel("appels", "0"))["vides"]

    def test_ouverture_envoi_succes(self):
        """Une demande ouvre, un envoi part une seule fois, le succès ferme. Erreurs : assertion."""
        self.demander()
        self.assertEqual((self.etat()["ouvert"], self.etat()["etat"]), (True, "saisie"))
        self.saisie()
        avant = self.vides()
        self.appel("soumettre", SECRET)
        self.appel("soumettre", SECRET)
        self.assertEqual(self.appels(), [["submit", SECRET]])
        self.assertEqual(self.etat()["etat"], "verification")
        self.assertGreater(self.vides(), avant)
        self.appel("poser", "0", '{"isSuccessful": true, "isCompleted": true}')
        self.assertEqual((self.etat()["ouvert"], self.etat()["etat"]), (False, "succes"))
        self.assertEqual(self.appels(), [["submit", SECRET]])
        self.assertNotIn(SECRET, self.journal())
        self.assertNotIn(SECRET, self.appel("etat", cible="autorisation"))

    def test_envois_refuses(self):
        """Réponse vide, hors demande de réponse ou sans flux : rien ne part. Erreurs : assertion."""
        self.appel("soumettre", SECRET)
        self.demander()
        self.saisie()
        self.appel("soumettre", "")
        self.appel("poser", "0", '{"isResponseRequired": false}')
        self.assertEqual(self.etat()["etat"], "attente")
        self.appel("soumettre", SECRET)
        self.assertEqual(self.appels(), [])

    def test_garde_de_frappe(self):
        """Tant que des touches tombent, la saisie reste fermée et rien ne part ; elle s'ouvre après. Erreurs : assertion."""
        self.appel("frapper", "true")
        self.demander()
        time.sleep(1)
        self.assertFalse(self.etat()["saisieOuverte"])
        self.appel("soumettre", SECRET)
        self.assertEqual(self.appels(), [])
        self.appel("frapper", "false")
        self.saisie()
        self.appel("frapper", "true")     # Une fois la saisie ouverte, taper ne la referme plus.
        time.sleep(0.3)
        self.assertTrue(self.etat()["saisieOuverte"])

    def test_seconde_demande(self):
        """La seconde demande reprend la fenêtre, champ vidé, garde relancée ; le premier flux est laissé (essai réel
        2a), et rien ne part sur aucun des deux. Erreurs : assertion."""
        self.demander()
        self.saisie()
        avant = self.vides()
        self.appel("frapper", "true")
        self.appel("frapper", "true")
        self.assertEqual(self.demander(message="Seconde"), 1)
        self.assertFalse(self.etat()["saisieOuverte"])
        self.assertGreater(self.vides(), avant)
        self.appel("soumettre", SECRET)
        self.appel("poser", "0", '{"isCancelled": true, "isCompleted": true}')
        self.assertTrue(self.etat()["ouvert"])
        self.assertEqual((self.appels(0), self.appels(1)), ([], []))
        self.appel("frapper", "false")
        self.saisie()
        self.appel("soumettre", SECRET)
        self.assertEqual((self.appels(0), self.appels(1)), ([], [["submit", SECRET]]))

    def test_annulation_unique(self):
        """Annuler, ou une autre attention ouverte, annule une seule fois. Erreurs : assertion."""
        self.demander()
        self.appel("annuler")
        self.appel("annuler")
        self.assertEqual((self.appels(0), self.etat()["ouvert"]), ([["annuler"]], False))
        self.demander()
        self.appel("attention")
        self.assertEqual((self.appels(1), self.etat()["ouvert"]), ([["annuler"]], False))

    def test_close_par_polkit(self):
        """Une demande close par polkit, ou un flux retiré, ferme sans annulation. Erreurs : assertion."""
        self.demander()
        self.appel("poser", "0", '{"isCancelled": true, "isCompleted": true}')
        self.assertEqual((self.appels(0), self.etat()["ouvert"]), ([], False))
        self.demander()
        self.appel("clore")
        self.assertEqual((self.appels(1), self.etat()["ouvert"]), ([], False))

    def test_echec_et_essais_restants(self):
        """Après un échec, faillock est relu et la ligne compte les essais restants. Erreurs : assertion."""
        self.demander()
        self.saisie()
        self.appel("lire", json.dumps({"faillock": releve(1), "conf": "deny = 5\n"}))
        self.appel("soumettre", SECRET)
        self.appel("emettre", "0", "authenticationFailed")
        self.appel("poser", "0", '{"isResponseRequired": true}')
        e = self.etat()
        self.assertEqual((e["etat"], e["ligne"]["texte"], e["saisieOuverte"]),
                         ("saisie", "Mot de passe incorrect. Quatre essais restants.", True))

    def test_lecteur_illisible(self):
        """Un lecteur qui lève laisse le champ ouvert. Erreurs : assertion."""
        self.appel("lire", "leve")
        self.demander()
        self.saisie()
        self.appel("soumettre", SECRET)
        self.appel("emettre", "0", "authenticationFailed")
        self.appel("poser", "0", '{"isResponseRequired": true}')
        e = self.etat()
        self.assertEqual((e["etat"], e["ligne"]["texte"]), ("saisie", "Mot de passe incorrect."))

    def test_verrouille(self):
        """Compte verrouillé à l'ouverture : rien ne part, l'heure est dite. Erreurs : assertion."""
        self.appel("lire", json.dumps({"faillock": releve(5), "conf": "deny = 5\n"}))
        self.demander()
        self.appel("soumettre", SECRET)
        e = self.etat()
        self.assertEqual((e["etat"], e["saisieOuverte"], self.appels()), ("verrouille", False, []))
        self.assertRegex(e["ligne"]["texte"], r"^Compte verrouillé\. Réessayer à \d+ h \d\d\.$")

    def test_rafale(self):
        """Trois échecs en chaîne annulent la demande, une fois. Erreurs : assertion."""
        self.demander()
        for _ in range(3):
            self.appel("emettre", "0", "authenticationFailed")
        self.assertEqual((self.appels(), self.etat()["ouvert"]), ([["annuler"]], False))

    def test_identite(self):
        """L'utilisateur courant est retenu s'il figure dans la liste, sinon le choix de polkit reste. Erreurs : assertion."""
        moi = {"string": os.environ["USER"], "isGroup": False}
        root = {"string": "root", "isGroup": False}
        self.demander(identities=[root, moi], selectedIdentity=root)
        self.assertEqual(json.loads(self.appel("identite", "0")), moi)
        self.demander(identities=[root], selectedIdentity=root)
        self.assertEqual(json.loads(self.appel("identite", "1")), root)
