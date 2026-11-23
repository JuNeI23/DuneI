"""Tests du menu de déconnexion de la coque (L2-23) : logique pure et contrôleur Deconnexion.

Rôle : éprouve la logique pure de deconnexion.js (validation des actions, avance en boucle, lettre d'accès, double
appui) dans un vrai Quickshell, par l'IPC de la coque d'essai coque/Deconnexion/essai/logique ; puis le contrôleur
Deconnexion lui-même, sa fenêtre ouverte pour de bon dans la session sans prendre le clavier, par la coque d'essai
coque/Deconnexion/essai/fenetre, dont l'exécuteur journalise « essai : exécuté <id> » au lieu de lancer la commande :
aucune vraie veille, extinction, déconnexion ni aucun verrouillage pendant les tests.
Entrées : aucune. Sorties : résultats unittest. Erreurs : échecs de test.
Dépendances : qs (Quickshell ≥ 0.3), tests.test_coque_theme (EssaiCoque), tests.test_lanceur (plein_ecran).
"""
import json
import os
import subprocess
import time
import unittest

from tests.test_coque_theme import DELAI, QS, ROOT, EssaiCoque
from tests.test_lanceur import plein_ecran

# Actions de la fiche, dans son ordre, au format de coque/Deconnexion/actions.json.
ACTIONS = [
    {"id": "verrouiller", "libelle": "Verrouiller", "lettre": "L", "icone": "system-lock-screen",
     "commande": ["loginctl", "lock-session"], "confirmer": False},
    {"id": "veille", "libelle": "Veille", "lettre": "S", "icone": "system-suspend",
     "commande": ["systemctl", "suspend"], "confirmer": False},
    {"id": "deconnexion", "libelle": "Déconnexion", "lettre": "D", "icone": "system-log-out",
     "commande": ["uwsm", "stop"], "confirmer": True},
    {"id": "redemarrer", "libelle": "Redémarrer", "lettre": "R", "icone": "system-reboot",
     "commande": ["systemctl", "reboot"], "confirmer": True},
    {"id": "eteindre", "libelle": "Éteindre", "lettre": "E", "icone": "system-shutdown",
     "commande": ["systemctl", "poweroff"], "confirmer": True},
]


@unittest.skipUnless(os.environ.get("WAYLAND_DISPLAY") and QS, "session Wayland et Quickshell requis")
class LogiqueTest(EssaiCoque, unittest.TestCase):
    """La logique du menu de déconnexion (deconnexion.js), appelée par l'IPC d'une coque d'essai sans fenêtre."""

    essai = ROOT / "coque" / "Deconnexion" / "essai" / "logique"
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
        """Appelle une fonction de deconnexion.js et rend sa valeur décodée.

        Entrées : fonction, nom exporté par deconnexion.js ; args, ses arguments, transmis en JSON dans
        {"args": [...]}. Sortie : la valeur retournée, décodée du JSON. Erreurs : échec du test si la fonction lève ;
        CalledProcessError si l'appel IPC échoue. Dépendances : qs, lancer.
        """
        sortie = subprocess.run([QS, "ipc", "--pid", str(self.proc.pid), "call", "essai", "appeler", fonction,
                                 json.dumps({"args": list(args)})], check=True, capture_output=True, text=True,
                                timeout=DELAI).stdout.strip()
        self.assertFalse(sortie.startswith("erreur"), sortie)
        return json.loads(sortie)

    def test_suivant_boucle(self):
        """Vérifie l'avance et le recul en boucle du curseur.

        Entrées : aucune. Sortie : aucune. Erreurs : échec d'assertion. Dépendances : appeler.
        """
        self.assertEqual(self.appeler("suivant", 4, 1, 5), 0)
        self.assertEqual(self.appeler("suivant", 0, -1, 5), 4)

    def test_index_lettre(self):
        """Vérifie que la lettre d'accès retrouve son action sans tenir compte de la casse, et -1 sinon.

        Entrées : aucune. Sortie : aucune. Erreurs : échec d'assertion. Dépendances : appeler, ACTIONS.
        """
        self.assertEqual(self.appeler("indexLettre", ACTIONS, "e"), 4)
        self.assertEqual(self.appeler("indexLettre", ACTIONS, "Z"), -1)

    def test_appui(self):
        """Vérifie le double appui : Veille part d'emblée ; Éteindre non armé s'arme, armé s'exécute.

        Entrées : aucune. Sortie : aucune. Erreurs : échec d'assertion. Dépendances : appeler, ACTIONS.
        """
        self.assertEqual(self.appeler("appui", ACTIONS, -1, 1), {"arme": -1, "executer": True})
        self.assertEqual(self.appeler("appui", ACTIONS, -1, 4), {"arme": 4, "executer": False})
        self.assertEqual(self.appeler("appui", ACTIONS, 4, 4), {"arme": 4, "executer": True})

    def test_actions_invalides(self):
        """Vérifie que valider écarte une entrée à lettre en double (sans égard à la casse) et une entrée incomplète
        (sans commande), et garde les autres dans leur ordre.

        Entrées : aucune. Sortie : aucune. Erreurs : échec d'assertion. Dépendances : appeler, ACTIONS.
        """
        double = dict(ACTIONS[0], id="doublon", lettre="e")
        incomplete = {k: v for k, v in ACTIONS[1].items() if k != "commande"} | {"id": "incomplete", "lettre": "X"}
        gardees = self.appeler("valider", ACTIONS[:2] + [incomplete] + ACTIONS[2:] + [double])
        self.assertEqual([a["id"] for a in gardees], [a["id"] for a in ACTIONS])


@unittest.skipUnless(os.environ.get("WAYLAND_DISPLAY") and QS, "session Wayland et Quickshell requis")
class ControleurTest(EssaiCoque, unittest.TestCase):
    """Le contrôleur Deconnexion, sa fenêtre de calque ouverte pour de bon dans la session, sans clavier
    (clavierExclusif faux), piloté par l'IPC « deconnexion » ; son exécuteur journalise au lieu d'exécuter. Le lanceur,
    chargé dans la même coque, sert à l'essai de la famille « attention ». Chaque essai est court : la coque est tuée à
    la fin, ce qui retire la fenêtre."""

    essai = ROOT / "coque" / "Deconnexion" / "essai" / "fenetre"
    teintes = (55,)

    def setUp(self):
        """Lance la coque d'essai du contrôleur et attend les jetons.

        Entrées : aucune. Sortie : aucune ; self.proc tient la coque. Erreurs : test sauté si la fenêtre active est
        en plein écran ; échec si la coque n'est pas prête dans le délai. Dépendances : plein_ecran, installer,
        lancer, attendre, jusqua.
        """
        if plein_ecran():
            self.skipTest("fenêtre active en plein écran : le menu ne doit pas la couvrir")
        super().setUp()
        self.installer(55)
        self.lancer(self.dir)
        self.attendre("essai : prêt")
        self.jusqua(lambda: self.appel("essai", "pret") == "true", "jetons chargés")

    def appel(self, cible: str, fonction: str, *args: str) -> str:
        """Appelle une fonction IPC de la coque d'essai et rend sa sortie brute.

        Entrées : cible, « deconnexion », « lanceur » ou « essai » ; fonction ; args, ses arguments en chaînes.
        Sortie : texte rendu. Erreurs : CalledProcessError si l'appel échoue. Dépendances : qs, lancer.
        """
        return subprocess.run([QS, "ipc", "--pid", str(self.proc.pid), "call", cible, fonction, *args], check=True,
                              capture_output=True, text=True, timeout=DELAI).stdout.strip()

    def etat(self) -> dict:
        """État du menu décodé du JSON de deconnexion.etat. Sortie : dictionnaire {ouvert, index, arme, ids, fenetre,
        sortant, differee}. Dépendances : appel."""
        return json.loads(self.appel("deconnexion", "etat"))

    def touches(self, *noms: str) -> None:
        """Presse des touches dans le menu, dans l'ordre. Entrée : noms (« Left », « Return », « e »…).
        Sortie : aucune. Dépendances : appel."""
        for nom in noms:
            self.appel("deconnexion", "touche", nom)

    def jusqua(self, condition, message: str):
        """Attend qu'une condition rende une valeur vraie et la rend.

        Entrées : condition, fonction sans argument ; message, ce qui est attendu. Sortie : la valeur rendue.
        Erreurs : échec du test au délai, avec le journal. Dépendances : journal.
        """
        fin = time.monotonic() + DELAI
        while time.monotonic() < fin:
            valeur = condition()
            if valeur:
                return valeur
            time.sleep(0.05)
        self.fail(f"{message} attendu :\n{self.journal()}")

    def basculer(self) -> dict:
        """Ouvre le menu par basculer et attend sa fenêtre. Sortie : l'état une fois la fenêtre construite.
        Dépendances : appel, jusqua, etat."""
        self.appel("deconnexion", "basculer")
        return self.jusqua(lambda: (e := self.etat())["fenetre"] and e, "fenêtre du menu")

    def sans_execution(self) -> None:
        """Vérifie qu'aucune action ne part, ni au retrait du calque ni à la garde d'une seconde de la scène.
        Entrées : aucune. Sortie : aucune. Erreurs : échec d'assertion. Dépendances : journal."""
        time.sleep(1.3)
        self.assertNotIn("essai : exécuté", self.journal())

    def test_basculer(self):
        """Vérifie que basculer ouvre le menu sur le premier bouton, désarmé, puis le ferme.

        Entrées : aucune. Sortie : aucune. Erreurs : échec d'assertion. Dépendances : basculer, appel, etat.
        """
        e = self.basculer()
        self.assertEqual((e["ouvert"], e["index"], e["arme"]), (True, 0, -1))
        self.assertEqual(e["ids"], [a["id"] for a in ACTIONS])
        self.appel("deconnexion", "basculer")
        self.assertFalse(self.etat()["ouvert"])

    def test_ouvrir_arme(self):
        """Vérifie que ouvrir("eteindre") ouvre le menu avec Éteindre sous le curseur et armé.

        Entrées : aucune. Sortie : aucune. Erreurs : échec d'assertion. Dépendances : appel, etat, sans_execution.
        """
        self.appel("deconnexion", "ouvrir", "eteindre")
        e = self.etat()
        self.assertEqual((e["ouvert"], e["index"], e["arme"]), (True, 4, 4))
        self.sans_execution()

    def test_ouvrir_menu_deja_ouvert(self):
        """Vérifie que ouvrir, menu déjà ouvert, le garde ouvert, déplace et arme le curseur, sans reconstruire la
        fenêtre ; un identifiant inconnu pose le curseur sur le premier bouton, désarmé.

        Entrées : aucune. Sortie : aucune. Erreurs : échec d'assertion. Dépendances : basculer, appel, etat, journal.
        """
        self.basculer()
        self.appel("deconnexion", "ouvrir", "redemarrer")
        e = self.etat()
        self.assertEqual((e["ouvert"], e["index"], e["arme"], e["fenetre"]), (True, 3, 3, True))
        self.appel("deconnexion", "ouvrir", "inconnu")
        e = self.etat()
        self.assertEqual((e["ouvert"], e["index"], e["arme"]), (True, 0, -1))
        time.sleep(0.3)  # Une reconstruction éventuelle aurait le temps de paraître au journal.
        self.assertEqual(self.journal().count("essai : fenêtre construite"), 1, self.journal())

    def test_fleches_boucle(self):
        """Vérifie que les flèches, Tab et Maj + Tab déplacent le curseur en boucle.

        Entrées : aucune. Sortie : aucune. Erreurs : échec d'assertion. Dépendances : basculer, touches, etat.
        """
        self.basculer()
        attendus = [("Left", 4), ("Right", 0), ("Tab", 1), ("Backtab", 0), ("Backtab", 4)]
        for nom, index in attendus:
            self.touches(nom)
            self.assertEqual(self.etat()["index"], index, nom)

    def test_verrouiller_un_appui(self):
        """Vérifie que la lettre L ferme le menu au premier appui et que le verrouillage attend le retrait du calque
        par Hyprland (closelayer) : aussitôt après l'appui, l'action est en attente et rien n'est exécuté ; elle part
        ensuite bien avant la garde d'une seconde de la scène (seuil de 0,8 s, comme test_scene), et le retrait a été
        vu. L'ordre des deux lignes dans le journal n'est pas comparé : elles naissent du même événement closelayer,
        servi à la scène et à la coque d'essai dans un ordre que Quickshell ne garantit pas.

        Entrées : aucune. Sortie : aucune. Erreurs : échec d'assertion. Dépendances : basculer, touches, etat,
        attendre, journal.
        """
        self.basculer()
        debut = time.monotonic()
        self.touches("l")
        e = self.etat()
        self.assertEqual((e["ouvert"], e["sortant"], e["differee"]), (False, True, "verrouiller"))
        self.assertNotIn("essai : exécuté", self.journal())
        self.attendre("essai : exécuté verrouiller")
        self.assertLess(time.monotonic() - debut, 0.8)
        self.assertIn("essai : calque retiré", self.journal())
        self.assertIsNone(self.etat()["differee"])

    def test_eteindre_double_appui(self):
        """Vérifie que E arme Éteindre sans rien exécuter, et qu'un second E l'exécute.

        Entrées : aucune. Sortie : aucune. Erreurs : échec d'assertion. Dépendances : basculer, touches, etat,
        attendre, journal.
        """
        self.basculer()
        self.touches("e")
        e = self.etat()
        self.assertEqual((e["ouvert"], e["index"], e["arme"]), (True, 4, 4))
        self.assertNotIn("essai : exécuté", self.journal())
        self.touches("e")
        self.assertFalse(self.etat()["ouvert"])
        self.attendre("essai : exécuté eteindre")

    def test_double_appui_moyens_mixtes(self):
        """Vérifie que le second appui peut venir d'un autre moyen : E arme, Entrée exécute.

        Entrées : aucune. Sortie : aucune. Erreurs : échec d'assertion. Dépendances : basculer, touches, attendre.
        """
        self.basculer()
        self.touches("e", "Return")
        self.attendre("essai : exécuté eteindre")

    def test_deplacer_desarme(self):
        """Vérifie que déplacer le curseur désarme : E, gauche, droite, puis Entrée réarme sans exécuter.

        Entrées : aucune. Sortie : aucune. Erreurs : échec d'assertion. Dépendances : basculer, touches, etat,
        sans_execution.
        """
        self.basculer()
        self.touches("e", "Left")
        self.assertEqual(self.etat()["arme"], -1)
        self.touches("Right", "Return")
        e = self.etat()
        self.assertEqual((e["ouvert"], e["index"], e["arme"]), (True, 4, 4))
        self.sans_execution()

    def test_lettre_autre_bouton_desarme(self):
        """Vérifie que la lettre d'un autre bouton désarme : E puis R arme Redémarrer à la place d'Éteindre, E réarme
        Éteindre, sans rien exécuter ; puis S met en veille, sans éteindre.

        Entrées : aucune. Sortie : aucune. Erreurs : échec d'assertion. Dépendances : basculer, touches, etat,
        sans_execution, attendre, journal.
        """
        self.basculer()
        self.touches("e", "r")
        e = self.etat()
        self.assertEqual((e["ouvert"], e["index"], e["arme"]), (True, 3, 3))
        self.touches("e")
        self.assertEqual(self.etat()["arme"], 4)
        self.sans_execution()
        self.touches("s")
        self.attendre("essai : exécuté veille")
        time.sleep(1.3)
        self.assertNotIn("essai : exécuté eteindre", self.journal())

    def test_echap_annule(self):
        """Vérifie qu'Échap ferme le menu armé sans rien exécuter, et que la réouverture repart désarmée.

        Entrées : aucune. Sortie : aucune. Erreurs : échec d'assertion. Dépendances : basculer, touches, etat,
        sans_execution.
        """
        self.basculer()
        self.touches("e", "Escape")
        e = self.etat()
        self.assertEqual((e["ouvert"], e["arme"]), (False, -1))
        self.sans_execution()
        e = self.basculer()
        self.assertEqual((e["ouvert"], e["index"], e["arme"]), (True, 0, -1))

    def test_ouvrir_arme_survol_immobile(self):
        """Vérifie la garde de mouvement réel du survol : menu ouvert sur Éteindre armé, un premier point du pointeur
        sur Déconnexion, sans déplacement, ne prend pas le curseur ni ne désarme, pas plus qu'un déplacement de 3 px,
        sous le seuil space.scale[0] (4 px) ; un déplacement au-delà le pose sur Déconnexion et désarme.

        Entrées : aucune. Sortie : aucune. Erreurs : échec d'assertion. Dépendances : appel, etat, jusqua,
        sans_execution.
        """
        self.appel("deconnexion", "ouvrir", "eteindre")
        self.jusqua(lambda: self.etat()["fenetre"], "fenêtre du menu")
        # Les points sont en coordonnées de la scène : l'apparition du cadre depuis le centre, à l'échelle
        # window.echelleApparition, doit être posée, sinon le centre du bouton se déplace entre deux points et simule
        # un mouvement que le pointeur n'a pas fait.
        time.sleep(1.0)
        self.assertEqual(self.appel("essai", "survoler", "2", "0", "0"), "ok")
        e = self.etat()
        self.assertEqual((e["index"], e["arme"]), (4, 4))
        self.assertEqual(self.appel("essai", "survoler", "2", "3", "0"), "ok")
        e = self.etat()
        self.assertEqual((e["index"], e["arme"]), (4, 4))
        self.assertEqual(self.appel("essai", "survoler", "2", "10", "0"), "ok")
        e = self.etat()
        self.assertEqual((e["index"], e["arme"]), (2, -1))
        self.sans_execution()

    def test_clic_sur_le_debord(self):
        """Vérifie qu'un clic sur le débord du bouton agrandi ne ferme pas le menu : menu ouvert sur Verrouiller, sous
        le curseur et donc agrandi de deconnexion.agrandi (débord de 13 px en haut), un clic simulé sur le voile 8 px
        au-dessus du bord de repos du bouton tombe dans la marge intérieure de la rangée et le menu reste ouvert ; un
        clic 60 px au-dessus, hors du cadre, le ferme, ce qui prouve que la simulation atteint bien le voile.

        Entrées : aucune. Sortie : aucune. Erreurs : échec d'assertion. Dépendances : basculer, appel, etat,
        sans_execution.
        """
        self.basculer()
        # L'apparition depuis le centre et l'agrandissement du bouton choisi doivent être posés.
        time.sleep(1.0)
        self.assertEqual(self.appel("essai", "cliquerAuDessus", "0", "8"), "ok")
        self.assertTrue(self.etat()["ouvert"])
        self.assertEqual(self.appel("essai", "cliquerAuDessus", "0", "60"), "ok")
        self.assertFalse(self.etat()["ouvert"])
        self.sans_execution()

    def test_libelle_confirmer(self):
        """Vérifie que le bouton armé peint « Confirmer » et reprend son libellé une fois désarmé.

        Entrées : aucune. Sortie : aucune. Erreurs : échec d'assertion. Dépendances : basculer, touches, appel.
        """
        self.basculer()
        self.assertEqual(self.appel("essai", "libelle", "4"), "Éteindre")
        self.touches("e")
        self.assertEqual(self.appel("essai", "libelle", "4"), "Confirmer")
        self.touches("Left")
        self.assertEqual(self.appel("essai", "libelle", "4"), "Éteindre")

    def test_lanceur_ferme_menu(self):
        """Vérifie que le lanceur, de la même famille « attention », ferme le menu en s'ouvrant, sans qu'aucune action
        parte.

        Entrées : aucune. Sortie : aucune. Erreurs : échec d'assertion. Dépendances : basculer, appel, etat,
        sans_execution.
        """
        self.basculer()
        self.touches("e")
        self.appel("lanceur", "ouvrir")
        self.assertFalse(self.etat()["ouvert"])
        self.assertTrue(json.loads(self.appel("lanceur", "etat"))["ouvert"])
        self.sans_execution()

    def test_journal_process(self):
        """Vérifie le journal des échecs du Process de lancement, par des commandes inoffensives et non par une action
        du menu : « false » finit en code 1, un programme introuvable ne démarre pas.

        Entrées : aucune. Sortie : aucune. Erreurs : échec d'assertion. Dépendances : appel, attendre.
        """
        self.appel("essai", "lancerFactice", "faux", "false")
        self.attendre("Déconnexion : faux a échoué (code 1)")
        self.appel("essai", "lancerFactice", "absent", "dunei-commande-introuvable")
        self.attendre("Déconnexion : absent n'a pas démarré")


class SourceTest(unittest.TestCase):
    """Garde-fous lus dans le source du menu, là où l'IPC ne peut rien simuler."""

    def test_auto_repetition_ecartee(self):
        """Vérifie que Keys.onPressed du cadre écarte l'auto-répétition avant d'appeler Deconnexion.touche : une touche
        tenue enfoncée exécuterait sinon une action armée (Éteindre) d'un seul geste. L'IPC « touche » passe à côté de
        Keys.onPressed, d'où la lecture du source.

        Entrées : aucune. Sortie : aucune. Erreurs : échec d'assertion. Dépendances : ROOT.
        """
        qml = (ROOT / "coque" / "Deconnexion" / "CadreDeconnexion.qml").read_text(encoding="utf-8")
        self.assertRegex(qml, r"Keys\.onPressed:[^}]*if \(event\.isAutoRepeat\) return[^}]*Deconnexion\.touche\(")


if __name__ == "__main__":
    unittest.main()
