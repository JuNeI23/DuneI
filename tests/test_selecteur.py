"""Tests du sélecteur de fenêtres de la coque (L2-17).

Rôle : éprouve la logique pure de selecteur.js (filtre, avance en boucle, défilement, largeur des vignettes) dans un
vrai Quickshell, par l'IPC de la coque d'essai coque/Selecteur/essai/logique ; puis le sélecteur lui-même, sa fenêtre
ouverte pour de bon dans la session sans prendre le clavier, par la coque d'essai coque/Selecteur/essai/fenetre.
Entrées : aucune. Sorties : résultats unittest. Erreurs : échecs de test.
Dépendances : qs (Quickshell ≥ 0.3), tests.test_coque_theme (EssaiCoque), tests.test_lanceur (plein_ecran).
"""
import json
import os
import re
import subprocess
import time
import unittest

from tests.test_coque_theme import DELAI, QS, ROOT, EssaiCoque
from tests.test_lanceur import plein_ecran

# Fausses fenêtres de la coque d'essai de la fenêtre : quatre sur les bureaux 1 à 4, de la plus récente à la plus
# ancienne, et une du bureau spécial, que le sélecteur écarte. taille remplace le relevé de Hyprland.
FENETRES = [
    {"adresse": "0xb1", "classe": "kitty", "titre": "Terminal", "bureau": "1", "historique": 0, "taille": [1200, 800]},
    {"adresse": "0xb2", "classe": "firefox", "titre": "DuneI — Firefox", "bureau": "2", "historique": 1,
     "taille": [1920, 1080]},
    {"adresse": "0xb3", "classe": "code", "titre": "Code", "bureau": "3", "historique": 2, "taille": [800, 1200]},
    {"adresse": "0xb4", "classe": "org.kde.dolphin", "titre": "Fichiers", "bureau": "4", "historique": 3,
     "taille": [1000, 700]},
    {"adresse": "0xbs", "classe": "kitty", "titre": "Bloc-notes", "bureau": "special:accueil", "historique": 4},
]


@unittest.skipUnless(os.environ.get("WAYLAND_DISPLAY") and QS, "session Wayland et Quickshell requis")
class LogiqueTest(EssaiCoque, unittest.TestCase):
    """La logique du sélecteur (selecteur.js), appelée par l'IPC d'une coque d'essai sans fenêtre."""

    essai = ROOT / "coque" / "Selecteur" / "essai" / "logique"
    teintes = ()
    cotes = {"hauteur": 140, "largeurMin": 100, "largeurMax": 320}

    def setUp(self):
        """Lance la coque d'essai de la logique et attend qu'elle soit prête.

        Entrées : aucune. Sortie : aucune ; self.proc tient la coque. Erreurs : échec du test si « essai : prêt »
        n'apparaît pas dans le délai. Dépendances : EssaiCoque.setUp, lancer, attendre.
        """
        super().setUp()
        self.lancer(self.dir)
        self.attendre("essai : prêt")

    def appeler(self, fonction: str, *args):
        """Appelle une fonction de selecteur.js et rend sa valeur décodée.

        Entrées : fonction — nom exporté par selecteur.js ; args — ses arguments, transmis en JSON dans
        {"args": [...]}. Sortie : la valeur retournée, décodée du JSON. Erreurs : échec du test si la fonction lève ;
        CalledProcessError si l'appel IPC échoue. Dépendances : qs, lancer.
        """
        sortie = subprocess.run([QS, "ipc", "--pid", str(self.proc.pid), "call", "essai", "appeler", fonction,
                                 json.dumps({"args": list(args)})], check=True, capture_output=True, text=True,
                                timeout=DELAI).stdout.strip()
        self.assertFalse(sortie.startswith("erreur"), sortie)
        return json.loads(sortie)

    def test_fenetres_filtre_et_ordre(self):
        """Vérifie que le bureau spécial et le bureau 5 sont exclus et que l'ordre suit l'historique croissant.

        Entrées : aucune. Sortie : aucune. Erreurs : échec d'assertion. Dépendances : appeler.
        """
        def f(adresse, bureau, historique):
            return {"adresse": adresse, "classe": "c", "titre": "t", "bureau": bureau, "historique": historique}
        entree = [f("a2", "1", 2), f("sp", "special:accueil", 0), f("a0", "2", 0), f("c5", "5", 1), f("a1", "4", 1)]
        self.assertEqual([x["adresse"] for x in self.appeler("fenetres", entree)], ["a0", "a1", "a2"])

    def test_avancer_boucle(self):
        """Vérifie l'avance et le recul en boucle de la sélection.

        Entrées : aucune. Sortie : aucune. Erreurs : échec d'assertion. Dépendances : appeler.
        """
        self.assertEqual(self.appeler("avancer", 2, 3, 1), 0)
        self.assertEqual(self.appeler("avancer", 0, 3, -1), 2)

    def test_decalage(self):
        """Vérifie le défilement : nul si la rangée tient, centré puis borné aux extrémités sinon.

        Entrées : aucune. Sortie : aucune. Erreurs : échec d'assertion. Dépendances : appeler.
        """
        self.assertEqual(self.appeler("decalage", 1, [200, 200], 16, 1000), 0)
        dix = [200] * 10
        total = 2000 + 16 * 9
        self.assertEqual(self.appeler("decalage", 9, dix, 16, 1000) + total, 1000)   # bord droit à la limite de la vue
        self.assertEqual(self.appeler("decalage", 0, dix, 16, 1000), 0)               # bord gauche à l'origine
        milieu = self.appeler("decalage", 4, dix, 16, 1000)                           # centrée sur la vignette 4
        self.assertEqual(milieu + 4 * 216 + 100, 500)

    def test_largeur_bornee(self):
        """Vérifie la largeur d'une vignette selon le format, bornée, et le repli quand la hauteur est nulle.

        Entrées : aucune. Sortie : aucune. Erreurs : échec d'assertion. Dépendances : appeler.
        """
        self.assertEqual(self.appeler("largeur", 1920, 1080, self.cotes), 249)
        self.assertEqual(self.appeler("largeur", 400, 2000, self.cotes), 100)
        self.assertEqual(self.appeler("largeur", 10000, 100, self.cotes), 320)
        self.assertEqual(self.appeler("largeur", 800, 0, self.cotes), 100)


@unittest.skipUnless(os.environ.get("WAYLAND_DISPLAY") and QS, "session Wayland et Quickshell requis")
class FenetreTest(EssaiCoque, unittest.TestCase):
    """Le sélecteur de fenêtres, sa fenêtre de calque ouverte pour de bon dans la session, sans clavier
    (clavierExclusif faux), piloté par l'IPC « selecteur » (avancer, touche) et nourri de fausses fenêtres ; le lanceur,
    chargé dans la même coque, sert aux essais de la famille « attention ». Chaque essai est court : la coque est tuée
    à la fin, ce qui retire la fenêtre."""

    essai = ROOT / "coque" / "Selecteur" / "essai" / "fenetre"
    teintes = (55,)

    def setUp(self):
        """Lance la coque d'essai de la fenêtre, attend les jetons et injecte les fausses fenêtres.

        Entrées : aucune. Sortie : aucune ; self.proc tient la coque. Erreurs : test sauté si la fenêtre active est
        en plein écran ; échec si la coque n'est pas prête dans le délai. Dépendances : plein_ecran, installer,
        lancer, attendre, jusqua, injecter, FENETRES.
        """
        if plein_ecran():
            self.skipTest("fenêtre active en plein écran : la fenêtre du sélecteur ne doit pas la couvrir")
        super().setUp()
        self.installer(55)
        self.lancer(self.dir)
        self.attendre("essai : prêt")
        self.jusqua(lambda: self.appel("essai", "pret") == "true", "jetons chargés")
        self.injecter(FENETRES)

    def appel(self, cible: str, fonction: str, *args: str) -> str:
        """Appelle une fonction IPC de la coque d'essai et rend sa sortie brute.

        Entrées : cible, « selecteur », « lanceur » ou « essai » ; fonction ; args, ses arguments en chaînes.
        Sortie : texte rendu. Erreurs : CalledProcessError si l'appel échoue. Dépendances : qs, lancer.
        """
        return subprocess.run([QS, "ipc", "--pid", str(self.proc.pid), "call", cible, fonction, *args], check=True,
                              capture_output=True, text=True, timeout=DELAI).stdout.strip()

    def selecteur(self, fonction: str, *args: str) -> str:
        """Appelle la cible « selecteur ». Entrées : fonction, args. Sortie : texte rendu. Dépendances : appel."""
        return self.appel("selecteur", fonction, *args)

    def injecter(self, fenetres: list) -> None:
        """Remplace les fenêtres vues par le sélecteur. Entrée : fenetres, liste au format d'Applications.toplevels()
        (plus taille). Sortie : aucune. Dépendances : appel."""
        self.appel("essai", "injecter", json.dumps({"fenetres": fenetres}))

    def etat(self) -> dict:
        """État du sélecteur décodé du JSON de selecteur.etat. Sortie : dictionnaire. Dépendances : selecteur."""
        return json.loads(self.selecteur("etat"))

    def touche(self, nom: str, super_tenu: bool) -> None:
        """Presse une touche dans le sélecteur. Entrées : nom (« ReleaseSuper », « Backtab », « Escape »…) ;
        super_tenu, vrai si SUPER est tenu. Sortie : aucune. Dépendances : selecteur."""
        self.selecteur("touche", nom, "true" if super_tenu else "false")

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

    def ouvrir(self) -> dict:
        """Ouvre le sélecteur par un premier avancer(1). Sortie : l'état aussitôt après. Dépendances : selecteur, etat."""
        self.selecteur("avancer", "1")
        return self.etat()

    def sans_execution(self, attente: float = 1.3) -> None:
        """Vérifie qu'aucune action n'est exécutée, ni au retrait du calque ni à la garde d'une seconde.

        Entrée : attente, en secondes, au-delà de la garde. Sortie : aucune. Erreurs : échec d'assertion.
        Dépendances : journal.
        """
        time.sleep(attente)
        self.assertNotIn("essai : exécuté", self.journal())

    def test_moins_de_deux_fenetres(self):
        """Vérifie qu'avec une seule fenêtre retenue (l'autre est au bureau spécial), avancer n'ouvre rien.

        Entrées : aucune. Sortie : aucune. Erreurs : échec d'assertion. Dépendances : injecter, ouvrir.
        """
        self.injecter([FENETRES[0], FENETRES[4]])
        e = self.ouvrir()
        self.assertEqual((e["ouvert"], e["fenetre"]), (False, False))

    def test_ouverture_sur_la_deuxieme(self):
        """Vérifie que l'ouverture fige la liste des bureaux 1 à 4 dans l'ordre de l'historique et pose la sélection
        sur la deuxième fenêtre.

        Entrées : aucune. Sortie : aucune. Erreurs : échec d'assertion. Dépendances : ouvrir.
        """
        e = self.ouvrir()
        self.assertEqual((e["ouvert"], e["index"], e["adresses"]), (True, 1, ["0xb1", "0xb2", "0xb3", "0xb4"]))

    def test_avancer_et_reculer(self):
        """Vérifie que chaque avancer(1) avance d'un cran, que Maj + Tab (Backtab), SUPER tenu, recule, et que la
        sélection boucle aux deux bouts.

        Entrées : aucune. Sortie : aucune. Erreurs : échec d'assertion. Dépendances : ouvrir, selecteur, touche, etat.
        """
        self.ouvrir()
        self.selecteur("avancer", "1")
        self.selecteur("avancer", "1")
        self.assertEqual(self.etat()["index"], 3)
        self.touche("Backtab", True)
        self.assertEqual(self.etat()["index"], 2)
        self.selecteur("avancer", "1")
        self.selecteur("avancer", "1")
        self.assertEqual(self.etat()["index"], 0)
        self.touche("Backtab", True)
        e = self.etat()
        self.assertEqual((e["index"], e["ouvert"]), (3, True))

    def test_montre_apres_delai(self):
        """Vérifie que rien n'est montré à l'ouverture et que le sélecteur ne l'est qu'au délai delays.selecteur
        (150 ms), mesuré par la coque d'essai entre son ouverture (IPC « essai ouvrir ») et le passage de montre à vrai.

        Entrées : aucune. Sortie : aucune. Erreurs : échec d'assertion. Dépendances : appel, attendre, journal, etat.
        """
        self.appel("essai", "ouvrir")
        e = self.etat()
        self.assertEqual((e["ouvert"], e["montre"], e["fenetre"]), (True, False, True))
        self.attendre("essai : montré après")
        ms = int(re.search(r"essai : montré après (\d+) ms", self.journal())[1])
        # Le Timer de QML est un minuteur grossier de Qt, qui peut partir jusqu'à 5 % en avance.
        self.assertGreaterEqual(ms, 142)
        self.assertLess(ms, 400)
        self.assertTrue(self.etat()["montre"])

    def test_tap_bref_valide_sans_montrer(self):
        """Vérifie qu'un relâchement de SUPER avant le délai amène la deuxième fenêtre sans que rien ait été montré.

        Entrées : aucune. Sortie : aucune. Erreurs : échec d'assertion. Dépendances : ouvrir, touche, attendre,
        jusqua, journal, etat.
        """
        self.ouvrir()
        self.touche("ReleaseSuper", False)
        self.attendre("essai : exécuté amener 0xb2")
        e = self.jusqua(lambda: (e := self.etat()) and not e["fenetre"] and e, "fenêtre retirée")
        self.assertEqual((e["ouvert"], e["montre"]), (False, False))
        self.assertNotIn("essai : montré", self.journal())

    def test_echap_annule(self):
        """Vérifie qu'Échap ferme le sélecteur sans rien amener.

        Entrées : aucune. Sortie : aucune. Erreurs : échec d'assertion. Dépendances : ouvrir, attendre, touche,
        jusqua, sans_execution.
        """
        self.ouvrir()
        self.attendre("essai : montré après")
        self.touche("Escape", True)
        self.jusqua(lambda: not self.etat()["fenetre"], "fenêtre retirée")
        self.sans_execution()

    def test_relachement_perdu(self):
        """Vérifie que le premier événement clavier reçu sans SUPER tenu valide, comme le relâchement qu'il remplace.

        Entrées : aucune. Sortie : aucune. Erreurs : échec d'assertion. Dépendances : ouvrir, touche, attendre.
        """
        self.ouvrir()
        self.touche("a", False)
        self.attendre("essai : exécuté amener 0xb2")

    def test_backtab_sans_super(self):
        """Vérifie que Maj + Tab reçu sans SUPER tenu (relâchement perdu) valide au lieu de reculer.

        Entrées : aucune. Sortie : aucune. Erreurs : échec d'assertion. Dépendances : ouvrir, touche, attendre.
        """
        self.ouvrir()
        self.touche("Backtab", False)
        self.attendre("essai : exécuté amener 0xb2")

    def test_fenetre_disparue(self):
        """Vérifie qu'une fenêtre choisie fermée avant le relâchement n'est pas amenée, sans erreur au journal, et que
        la liste reste figée pendant le geste.

        Entrées : aucune. Sortie : aucune. Erreurs : échec d'assertion. Dépendances : ouvrir, injecter, etat, touche,
        jusqua, sans_execution, journal.
        """
        self.ouvrir()
        self.injecter([f for f in FENETRES if f["adresse"] != "0xb2"])
        self.assertEqual(self.etat()["adresses"], ["0xb1", "0xb2", "0xb3", "0xb4"])
        self.touche("ReleaseSuper", False)
        self.jusqua(lambda: not self.etat()["fenetre"], "fenêtre retirée")
        self.sans_execution()
        for motif in ("TypeError", "ReferenceError", "Error:", "WARN scene", "WARN qml"):
            self.assertNotIn(motif, self.journal())

    def test_action_apres_retrait(self):
        """Vérifie que la fenêtre choisie n'est amenée qu'au retrait du calque par Hyprland (closelayer), bien avant la
        garde d'une seconde : la ligne « exécuté » touche la ligne « calque retiré », émises dans la même notification.
        Tolérance : le seuil de 0,8 s laisse de la marge à une session chargée tout en excluant la garde d'une seconde ;
        le voisinage d'une ligne de part et d'autre admet qu'une autre ligne du journal s'intercale.

        Entrées : aucune. Sortie : aucune. Erreurs : échec d'assertion. Dépendances : ouvrir, attendre, touche, etat,
        journal.
        """
        self.ouvrir()
        self.attendre("essai : montré après")
        self.selecteur("avancer", "1")
        debut = time.monotonic()
        self.touche("ReleaseSuper", False)
        e = self.etat()
        self.assertEqual((e["ouvert"], e["sortant"], e["differee"]), (False, True, True))
        self.attendre("essai : exécuté amener 0xb3")
        self.assertLess(time.monotonic() - debut, 0.8)
        lignes = self.journal().splitlines()
        i = max(n for n, l in enumerate(lignes) if "exécuté amener 0xb3" in l)
        voisines = lignes[i - 1:i + 2]
        self.assertTrue(any("essai : calque retiré" in l for l in voisines), voisines)
        self.assertFalse(self.etat()["differee"])

    def test_lanceur_ferme(self):
        """Vérifie que le sélecteur, de la famille « attention », ferme le lanceur ouvert en s'ouvrant.

        Entrées : aucune. Sortie : aucune. Erreurs : échec d'assertion. Dépendances : appel, jusqua, ouvrir.
        """
        self.appel("lanceur", "ouvrir")
        self.jusqua(lambda: json.loads(self.appel("lanceur", "etat"))["fenetre"], "fenêtre du lanceur")
        self.assertTrue(self.ouvrir()["ouvert"])
        self.assertFalse(json.loads(self.appel("lanceur", "etat"))["ouvert"])

    def test_action_du_lanceur_retenue(self):
        """Vérifie que l'action choisie au lanceur, qui attend le retrait de son calque, ne part pas sous le sélecteur
        ouvert pendant ce retrait : ni au retrait du calque du lanceur, ni à sa garde d'une seconde.

        Entrées : aucune. Sortie : aucune. Erreurs : échec d'assertion ; test sauté si l'action est partie avant
        l'ouverture du sélecteur (session trop lente pour le scénario). Dépendances : appel, jusqua, ouvrir, journal,
        sans_execution, etat.
        """
        self.appel("lanceur", "ouvrir")
        self.jusqua(lambda: json.loads(self.appel("lanceur", "etat"))["fenetre"], "fenêtre du lanceur")
        self.appel("lanceur", "taper", "galerie")
        if json.loads(self.appel("lanceur", "etat"))["cles"][:1] != ["cmd:galerie"]:
            self.skipTest("« galerie » ne donne pas la commande en tête dans cette session")
        self.appel("lanceur", "touche", "return")
        self.assertTrue(self.ouvrir()["ouvert"])
        if "essai : exécuté" in self.journal():
            self.skipTest("action du lanceur partie avant l'ouverture du sélecteur : le scénario n'a pas pu être joué")
        self.sans_execution()
        self.assertTrue(self.etat()["ouvert"])
        # L'action du lanceur est abandonnée à l'ouverture du sélecteur : elle ne part pas non plus une fois celui-ci fermé.
        self.selecteur("annuler")
        self.sans_execution()
