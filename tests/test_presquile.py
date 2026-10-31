"""Module QML Presquile — logique pure des bureaux (bureaux.js) et forme de l'encoche (Encoche.qml), éprouvées dans
un vrai Quickshell ; la vitrine de capture n'ouvre sa fenêtre que sous la plateforme offscreen, jamais à l'écran.

Ignoré sans session Wayland ou sans Quickshell, comme les essais de la barre.
"""

import json
import os
import re
import subprocess
import time
import unittest

from tests.test_coque_composants import ERREURS
from tests.test_coque_theme import DELAI, QS, ROOT, EssaiCoque

ESSAI = ROOT / "coque" / "Presquile" / "essai"


class PresquileStructureTest(unittest.TestCase):
    """La surface de la presqu'île et son entrée dans la coque respectent la conception (lecture du source)."""

    @classmethod
    def setUpClass(cls):
        cls.surface = (ROOT / "coque" / "Presquile" / "Presquile.qml").read_text(encoding="utf-8")

    def test_calque(self):
        for ligne in ('WlrLayershell.namespace: "dunei-presquile"', "WlrLayershell.layer: WlrLayer.Top",
                      "WlrLayershell.keyboardFocus: WlrKeyboardFocus.None", "exclusionMode: ExclusionMode.Ignore",
                      'color: "transparent"'):
            with self.subTest(ligne=ligne):
                self.assertIn(ligne, self.surface)

    def test_ancrage_haut_seul(self):
        ancrage = re.search(r"anchors\s*\{([^}]*)\}", self.surface).group(1)
        self.assertEqual(re.findall(r"(\w+):\s*true", ancrage), ["top"])

    def test_masque_sur_le_corps(self):
        masque = re.search(r"mask:\s*Region\s*\{([^}]*)\}", self.surface)
        self.assertIsNotNone(masque)
        self.assertEqual(re.findall(r"item:\s*([\w.]+)", masque.group(1)), ["encoche.corps"])

    def test_module_et_ressort(self):
        self.assertRegex(self.surface, r"property Component module:\s*Component\s*\{\s*Bureaux\b")
        self.assertIn('transition: "window"', self.surface)

    def test_qmldir_et_coque(self):
        self.assertIn("Presquile 1.0 Presquile.qml", (ROOT / "coque" / "Presquile" / "qmldir").read_text("utf-8"))
        shell = re.sub(r"//[^\n]*", "", (ROOT / "coque" / "shell.qml").read_text(encoding="utf-8"))
        self.assertRegex(shell, r"(?s)delegate:\s*Scope\s*\{.*Barre\s*\{.*Presquile\s*\{")
        self.assertIn('import "Presquile"', shell)


@unittest.skipUnless(os.environ.get("WAYLAND_DISPLAY") and QS, "session Wayland et Quickshell requis")
class PresquileIpc(EssaiCoque):
    """Base des tests qui pilotent la coque d'essai de la presqu'île par IPC (sans fenêtre)."""

    essai = ESSAI
    teintes = (55,)
    environnement = {"QT_QPA_PLATFORM": "offscreen"}

    def setUp(self):
        super().setUp()
        self.installer(55)
        self.lancer(self.dir)
        self.attendre("Theme : chargé, teinte 55")

    def appeler(self, *commande) -> str:
        """Appelle une fonction IPC de la cible « presquile » et rend sa valeur de retour, sans espaces de fin.

        Entrée : commande — fonction puis arguments (convertis en texte, booléens en true/false).
        Sortie : texte retourné. Erreurs : CalledProcessError si l'appel échoue. Dépendances : qs, lancer.
        """
        args = [str(a).lower() if isinstance(a, bool) else str(a) for a in commande]
        sortie = subprocess.run([QS, "ipc", "--pid", str(self.proc.pid), "call", "presquile", *args],
                                check=True, capture_output=True, text=True, timeout=DELAI)
        return sortie.stdout.strip()

    def json(self, *commande):
        """Comme appeler, mais décode le JSON rendu. Sortie : valeur Python. Erreurs : celles de appeler et json."""
        return json.loads(self.appeler(*commande))


FOCUS3 = "hl.dsp.focus({ workspace = 3 })"


class BureauxTest(PresquileIpc, unittest.TestCase):
    """Appelle chaque fonction de bureaux.js par l'IPC de la coque d'essai de la presqu'île."""

    def test_index_pilule(self):
        for args, attendu in (((1, 4), "0"), ((4, 4), "3"), ((5, 4), "-1"), ((0, 4), "-1"), ((-98, 4), "-1")):
            self.assertEqual(self.appeler("indexPilule", *args), attendu, args)

    def test_pas_molette(self):
        for args, attendu in (((0, 120), {"pas": -1, "reste": 0}), ((0, 40), {"pas": 0, "reste": 40}),
                              ((100, 40), {"pas": -1, "reste": 20}), ((0, -240), {"pas": 2, "reste": 0})):
            self.assertEqual(self.json("pasMolette", *args), attendu, args)

    def test_cible_molette(self):
        for args, attendu in (((1, -1, 4), "0"), ((4, 1, 4), "0"), ((2, 1, 4), "3"), ((3, 5, 4), "4"),
                              ((7, 1, 4), "0")):
            self.assertEqual(self.appeler("cibleMolette", *args), attendu, args)

    def test_lire_special(self):
        self.assertEqual(self.appeler("lireSpecial", "special:accueil,eDP-1"), "special:accueil")
        self.assertEqual(self.appeler("lireSpecial", ",eDP-1"), "")

    def test_commande_bureau(self):
        self.assertEqual(self.appeler("commandeBureau", 3), FOCUS3)

    def test_commandes_clic(self):
        self.assertEqual(self.json("commandesClic", 2, 2, ""), [])
        self.assertEqual(self.json("commandesClic", 3, 1, ""), [FOCUS3])
        self.assertEqual(self.json("commandesClic", 1, 1, "special:accueil"),
                         ['hl.dsp.workspace.toggle_special("accueil")'])
        self.assertEqual(self.json("commandesClic", 3, 1, "special:accueil"),
                         ['hl.dsp.workspace.toggle_special("accueil")', FOCUS3])


class BureauxModuleTest(PresquileIpc, unittest.TestCase):
    """Module « bureaux » de la presqu'île, éprouvé sans Hyprland : l'essai écrit idActif et special directement."""

    def etat(self, idActif, special="", survol=-1):
        """Pose idActif, special et le point survolé sur le module d'essai et rend son état (JSON de bureauxEtat)."""
        return self.json("bureauxEtat", idActif, special or "-", survol)

    def test_nombre_de_points(self):
        self.assertEqual(len(self.etat(2)["largeurs"]), 4)

    def test_pilule_sur_le_bureau_actif(self):
        # Bureau 2 actif : le point 1 (index 1) vise la pilule de 22, les autres le point de 7.
        self.assertEqual(self.etat(2)["largeurs"], [7, 22, 7, 7])

    def test_aucune_pilule_hors_plage(self):
        self.assertEqual(self.etat(7)["largeurs"], [7, 7, 7, 7])

    def test_pilule_grisee_sous_un_special(self):
        # Spécial ouvert : la pilule prend la couleur des points inactifs ; fermé, elle prend l'accent discret.
        ouvert = self.etat(2, "special:accueil")
        self.assertEqual(ouvert["couleurs"][1], ouvert["couleurs"][0])
        ferme = self.etat(2)
        self.assertEqual(ferme["couleurs"][1], ferme["accentDiscret"])
        self.assertNotEqual(ferme["couleurs"][1], ferme["couleurs"][0])

    def test_survol(self):
        # Le point survolé prend textTertiary, rôle de la rampe du thème, et se distingue des points inactifs.
        etat = self.etat(2, survol=0)
        self.assertEqual(etat["couleurs"][0], etat["textTertiary"])
        self.assertNotEqual(etat["couleurs"][0], etat["couleurs"][2])
        # La pilule survolée garde l'accent discret, hors bureau spécial.
        self.assertEqual(self.etat(2, survol=1)["couleurs"][1], etat["accentDiscret"])

    def test_survol_pilule_grisee(self):
        # Sous un spécial ouvert, la pilule grisée réagit au survol, puisqu'un clic la referme.
        etat = self.etat(2, "special:accueil", survol=1)
        self.assertEqual(etat["couleurs"][1], etat["textTertiary"])
        self.assertNotEqual(etat["couleurs"][1], etat["couleurs"][0])

    def test_largeur_implicite(self):
        # 4 × 7 + (22 − 7) + 3 × 8 + 2 × 14 = 95, sur la hauteur de la presqu'île.
        etat = self.etat(1)
        self.assertEqual((etat["largeur"], etat["hauteur"]), (95, 28))

    def regle(self, idActif):
        """Pose idActif et attend que les ressorts de largeur aient rejoint leur cible et que la rangée soit replacée ; rend l'état réglé."""
        for _ in range(100):
            etat = self.etat(idActif)
            # La rangée se replace à son prochain passage de mise en page : on attend aussi que la dernière zone touche le bord.
            if etat["reelles"] == etat["largeurs"] and abs(etat["zones"][-1][1] - etat["largeur"]) < 0.01:
                return etat
            time.sleep(0.05)
        self.fail("les ressorts de largeur n'ont pas rejoint leur cible")

    def test_zones_de_clic(self):
        # Pour chaque bureau actif, le centre de chaque point est dans sa zone, les zones se touchent et couvrent
        # toute la largeur du module.
        for actif in (1, 2, 3, 4):
            etat = self.regle(actif)
            zones, centres = etat["zones"], etat["centres"]
            for i, (debut, fin) in enumerate(zones):
                self.assertTrue(debut < centres[i] < fin, (actif, i, zones, centres))
            self.assertAlmostEqual(zones[0][0], 0)
            self.assertAlmostEqual(zones[-1][1], etat["largeur"])
            for (_, fin), (debut, _) in zip(zones, zones[1:]):
                self.assertAlmostEqual(fin, debut)


# Tracé de la variante D de la planche forme.html (132 × 34, évasement 13), validée à l'écran par Nicolas.
TRACE_PLANCHE = "M0 0 H132 C124 0 120 3 119 12 V20 C119 29 115 34 105 34 H27 C17 34 13 29 13 20 V12 C12 3 8 0 0 0 Z"


class MontageTest(PresquileIpc, unittest.TestCase):
    """Premier montage de la surface : l'encoche prend sa taille d'un coup, sans partir de zéro."""

    def test_taille_immediate(self):
        self.assertEqual(self.json("montage", 95), {"valeur": 95, "mobile": False})

    def test_surface_pose_au_montage(self):
        source = (ROOT / "coque" / "Presquile" / "Presquile.qml").read_text(encoding="utf-8")
        self.assertIn("largeur.poser(); hauteur.poser()", source)
        self.assertRegex(source, r"implicitWidth: Math\.max\(largeur\.value, largeur\.cible\)")


class EncocheTest(PresquileIpc, unittest.TestCase):
    """Forme de l'encoche continue : dimensions, corps servant de masque, tracé paramétrique et capture."""

    def test_dimensions(self):
        # Corps 96 × 28 (hauteur des jetons) et évasement 13 : 96 + 2 × 13 = 122 de large, le corps commence après l'évasement gauche.
        geometrie = self.json("encoche")
        geometrie.pop("trace")
        self.assertEqual(geometrie, {"largeur": 122, "hauteur": 28, "corpsX": 13, "corpsLargeur": 96,
                                     "corpsHauteur": 28})

    def test_etirement(self):
        # Porter le corps à 140 redessine la forme sans autre intervention ni erreur au journal.
        self.assertEqual(self.json("etirerEncoche", 140)["largeur"], 166)
        for erreur in ERREURS:
            with self.subTest(erreur=erreur):
                self.assertNotIn(erreur, self.journal())

    def test_trace_planche(self):
        # Aux dimensions de la planche (106 × 34, évasement 13, rayon 10), le tracé paramétrique redonne exactement
        # celui de la variante D, quelle que soit la hauteur des jetons.
        self.assertEqual(self.appeler("tracerEncoche", 106, 34, 13, 10), TRACE_PLANCHE)

    def test_capture(self):
        # La vitrine, rendue hors écran, s'enregistre en PNG : de quoi comparer la forme à la planche.
        chemin = self.dir / "encoche.png"
        self.appeler("capturer", chemin)
        fin = time.monotonic() + DELAI
        while not chemin.exists() and time.monotonic() < fin:
            time.sleep(0.05)
        self.assertEqual(chemin.read_bytes()[:8], b"\x89PNG\r\n\x1a\n", self.journal())
