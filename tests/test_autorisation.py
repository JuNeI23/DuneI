"""Tests de l'agent d'authentification de la coque (L2-24).

Rôle : éprouve la logique pure d'autorisation.js (réglages et relevé de faillock, état, ligne d'état, rafale d'échecs)
dans un vrai Quickshell, par l'IPC de la coque d'essai coque/Autorisation/essai/logique ; puis le contrôleur
Autorisation, sans fenêtre ni clavier, puis son cadre, sa fenêtre ouverte pour de bon
dans la session sans prendre le clavier, par la coque d'essai coque/Autorisation/essai/fenetre, dont les flux et le
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
from tests.test_lanceur import plein_ecran

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
        self.assertEqual((self.etat()["ouvert"], self.etat()["etat"]), (True, "succes"))
        self.assertEqual(self.etat()["clavier"], False)
        self.jusqua(lambda: not self.etat()["ouvert"], "fermeture après « Autorisé »")
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
        self.saisie()
        self.appel("clore")
        self.assertEqual((self.appels(1), self.etat()["ouvert"], self.etat()["saisieOuverte"]), ([], False, False))

    def test_succes_dans_l_ordre_de_quickshell(self):
        """Au succès, Quickshell retire le flux avant de signaler la fin (essai réel 3) : « Autorisé » se montre quand
        même, puis l'île se ferme. Erreurs : assertion."""
        self.demander()
        self.saisie()
        self.appel("soumettre", SECRET)
        self.appel("poser", "0", '{"isSuccessful": true}')
        self.appel("clore")
        self.assertEqual((self.etat()["ouvert"], self.etat()["etat"], self.etat()["clavier"]), (True, "succes", False))
        self.jusqua(lambda: not self.etat()["ouvert"], "fermeture après « Autorisé »")
        self.assertEqual(self.appels(), [["submit", SECRET]])

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

    REGLE = "#%PAM-1.0\n# Posé par DuneI depuis systeme/\n"

    def agent(self, actif=True, bon=True, regle=REGLE) -> dict:
        """Démarre le faux agent sur une règle PAM factice, et attend 1,2 s (reprises comprises). Sortie : agentEtat."""
        chemin = self.dir / "polkit-1"
        if regle is not None:
            chemin.write_text(regle, encoding="utf-8")
        self.appel("agent", str(actif).lower(), str(chemin), str(bon).lower())
        time.sleep(1.2)
        return json.loads(self.appel("agentEtat"))

    def test_agent_enregistre(self):
        """Règle posée et agent en marche : un seul agent, aucun avis. Erreurs : assertion."""
        self.assertFalse(self.etat()["enregistre"])
        self.assertEqual(self.agent(), {"agents": 1, "avis": 0, "present": True})
        self.assertTrue(self.etat()["enregistre"])

    def test_agent_sans_regle(self):
        """Règle absente ou sans la marque de DuneI : rien n'est chargé. Erreurs : assertion."""
        self.assertEqual(self.agent(regle=None), {"agents": 0, "avis": 0, "present": False})
        self.assertEqual(self.agent(regle="#%PAM-1.0\nauth include system-auth\n"), {"agents": 0, "avis": 0, "present": False})

    def test_agent_debraye(self):
        """Mise en marche à faux : rien n'est chargé. Erreurs : assertion."""
        self.assertEqual(self.agent(actif=False), {"agents": 0, "avis": 0, "present": False})
        self.assertTrue(self.agent(actif=True)["present"])
        self.assertFalse(self.agent(actif=False)["present"])     # Débrayé à chaud, l'agent est retiré.

    def test_agent_refuse(self):
        """Agent qui ne s'enregistre pas : trois reprises, puis un seul avis. Erreurs : assertion."""
        self.assertEqual(self.agent(bon=False), {"agents": 4, "avis": 1, "present": True})

    def test_agent_flux(self):
        """Le flux de l'agent ouvre la demande ; son retrait la ferme. Erreurs : assertion."""
        self.agent()
        self.demander()
        self.appel("annuler")
        i = self.demander()
        self.appel("annuler")
        self.appel("poser", str(i), '{"isCompleted": false}')
        self.appel("fluxAgent", str(i))
        self.assertTrue(self.etat()["ouvert"])
        self.appel("fluxAgent", "-1")
        self.assertFalse(self.etat()["ouvert"])

    def test_identite(self):
        """L'utilisateur courant est retenu s'il figure dans la liste, sinon le choix de polkit reste. Erreurs : assertion."""
        moi = {"string": os.environ["USER"], "isGroup": False}
        root = {"string": "root", "isGroup": False}
        self.demander(identities=[root, moi], selectedIdentity=root)
        self.assertEqual(json.loads(self.appel("identite", "0")), moi)
        self.demander(identities=[root], selectedIdentity=root)
        self.assertEqual(json.loads(self.appel("identite", "1")), root)


class CadreTest(ControleurTest):
    """Le cadre de la demande, sa fenêtre de calque ouverte pour de bon dans la session, sans clavier."""

    def setUp(self):
        """Comme ControleurTest, fenêtre construite. Erreurs : test sauté si la fenêtre active est en plein écran."""
        if plein_ecran():
            self.skipTest("fenêtre active en plein écran : la demande ne doit pas la couvrir")
        super().setUp()
        self.appel("fenetree", "true")

    def cadre(self) -> dict:
        """Ce que montre le cadre, une fois construit. Sortie : dictionnaire (voir essai.cadre)."""
        return self.jusqua(lambda: json.loads(self.appel("cadre")), "cadre")

    def montre(self, **attendus) -> dict:
        """Attend que le cadre montre les valeurs attendues (fondus posés). Sortie : le cadre. Erreurs : échec au délai."""
        return self.jusqua(lambda: (c := self.cadre()) and all(c[k] == v for k, v in attendus.items()) and c, attendus)

    def test_saisie(self):
        """Textes, champ et boutons en saisie ; Entrée et « Autoriser » envoient une fois et vident le champ."""
        self.demander(message="Lancer <b>x</b>", actionId="org.dunei.essai")
        self.saisie()
        c = self.montre(champ=True, fermer=False, ligne="org.dunei.essai", autoriser=[True, False], forme=[460, 134])
        self.assertEqual((c["titre"], c["message"], c["brut"], c["y"]),
                         ("Autorisation requise", "Lancer <b>x</b>", True, 0))
        self.assertGreater(c["saisieLargeur"], 300)
        self.assertEqual(c["role"], "controlRaised")     # Un cran au-dessus du conteneur E3 (bible).
        self.assertNotEqual(c["couvert"], "")
        self.appel("taper", SECRET)
        self.montre(autoriser=[True, True])
        self.appel("entree")
        self.assertEqual(self.appels(), [["submit", SECRET]])
        self.montre(longueur=0, champ=False, activite=True, ligne="Vérification")
        self.appel("emettre", "0", "authenticationFailed")
        self.appel("poser", "0", '{"isResponseRequired": true}')
        self.montre(champ=True, activite=False, ligne="Mot de passe incorrect.")
        self.appel("taper", SECRET)
        self.appel("cliquer", "autoriser")
        self.assertEqual(self.appels(), [["submit", SECRET]] * 2)

    def test_garde(self):
        """Pendant la garde, le champ et « Autoriser » sont inactifs ; une touche du cadre la relance."""
        self.demander()
        for _ in range(8):
            self.appel("touche", "a")
            self.assertFalse(self.etat()["saisieOuverte"])
        self.assertFalse(self.cadre()["champ"])
        self.saisie()
        self.montre(champ=True)

    def test_verrouille_fermer(self):
        """Verrouillé : champ inactif, « Fermer » seul, qui annule."""
        self.appel("lire", json.dumps({"faillock": releve(5), "conf": "deny = 5\n"}))
        self.demander()
        c = self.montre(fermer=True, autoriser=[False, False])
        self.assertFalse(c["champ"])
        self.appel("cliquer", "fermer")
        self.assertEqual(self.appels(), [["annuler"]])

    def test_echap_voile(self):
        """Échap annule une fois ; le voile ne ferme pas ; la presqu'île est rendue à la fermeture."""
        self.demander()
        self.cadre()
        self.appel("voile")
        self.assertEqual((self.appels(), self.etat()["ouvert"]), ([], True))
        self.appel("touche", "escape")
        self.assertEqual((self.appels(), self.etat()["ouvert"]), ([["annuler"]], False))
        self.jusqua(lambda: self.appel("couvert") == "", "presqu'île rendue")

    def test_annonce_et_succes(self):
        """L'île annonce avant de s'ouvrir, et dit « Autorisé » une fois la demande accordée, repliée."""
        self.demander()
        c = self.montre(annonce="Autorisation requise")
        self.montre(annonceOpacite=0, forme=[460, 134])
        self.appel("poser", "0", '{"isSuccessful": true, "isCompleted": true}')
        self.montre(annonce="Autorisé", forme=[190, 28], annonceOpacite=1)

    def test_message_tres_long(self):
        """Un message de 2 000 caractères, sur plusieurs lignes, laisse la carte dans l'écran et les boutons dedans."""
        self.demander(message="mot " * 400 + "\n" * 100 + "x" * 400, actionId="org." + "a" * 300)
        c = self.jusqua(lambda: (c := self.cadre()) and c["forme"] == [460, c["hauteur"]] and c, "île ouverte")
        self.assertLessEqual(c["hauteur"], c["ecran"] - 48)
        self.assertLessEqual(c["bas"], c["hauteur"])
        self.assertEqual(c["forme"], [460, c["hauteur"]])

    def test_seconde_demande_vide_le_champ(self):
        """La seconde demande vide le champ et change les textes."""
        self.demander()
        self.saisie()
        self.montre(champ=True)
        self.appel("taper", SECRET)
        self.demander(message="Seconde")
        self.montre(longueur=0, message="Seconde")

    def test_mouvement_reduit(self):
        """Mouvement réduit : la carte ne se déplace ni ne grandit, elle est posée d'emblée."""
        (self.dir / "mouvement.json").write_text('{"reduit": true}')
        time.sleep(0.5)
        self.demander()
        vus = set()
        fin = time.monotonic() + 1.2
        while time.monotonic() < fin:
            if c := json.loads(self.appel("cadre")):
                vus.add(tuple(c["forme"]))
        self.assertLessEqual(vus, {(95, 28), (190, 28), (460, 134)})


# Le cadre hérite des outils du contrôleur, pas de ses essais.
for _nom in [n for n in vars(ControleurTest) if n.startswith("test_")]:
    if _nom not in vars(CadreTest):
        setattr(CadreTest, _nom, None)
