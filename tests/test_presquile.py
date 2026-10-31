"""Module QML Presquile — logique pure des bureaux (bureaux.js) et forme de l'encoche (Encoche.qml), éprouvées dans
un vrai Quickshell ; la vitrine de capture n'ouvre sa fenêtre que sous la plateforme offscreen, jamais à l'écran.

Ignoré sans session Wayland ou sans Quickshell, comme les essais de la barre.
"""

import json
import os
import subprocess
import time
import unittest

from tests.test_coque_composants import ERREURS
from tests.test_coque_theme import DELAI, QS, ROOT, EssaiCoque

ESSAI = ROOT / "coque" / "Presquile" / "essai"


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


# Tracé de la variante D de la planche forme.html (132 × 34, évasement 13), validée à l'écran par Nicolas.
TRACE_PLANCHE = "M0 0 H132 C124 0 120 3 119 12 V20 C119 29 115 34 105 34 H27 C17 34 13 29 13 20 V12 C12 3 8 0 0 0 Z"


class EncocheTest(PresquileIpc, unittest.TestCase):
    """Forme de l'encoche continue : dimensions, corps servant de masque, tracé paramétrique et capture."""

    def test_dimensions(self):
        # Corps 96 × 34 et évasement 13 : 96 + 2 × 13 = 122 de large, le corps commence après l'évasement gauche.
        geometrie = self.json("encoche")
        geometrie.pop("trace")
        self.assertEqual(geometrie, {"largeur": 122, "hauteur": 34, "corpsX": 13, "corpsLargeur": 96,
                                     "corpsHauteur": 34})

    def test_etirement(self):
        # Porter le corps à 140 redessine la forme sans autre intervention ni erreur au journal.
        self.assertEqual(self.json("etirerEncoche", 140)["largeur"], 166)
        for erreur in ERREURS:
            with self.subTest(erreur=erreur):
                self.assertNotIn(erreur, self.journal())

    def test_trace_planche(self):
        # Au corps de la planche (106), le tracé paramétrique redonne exactement celui de la variante D.
        self.assertEqual(self.json("etirerEncoche", 106)["trace"], TRACE_PLANCHE)

    def test_capture(self):
        # La vitrine, rendue hors écran, s'enregistre en PNG : de quoi comparer la forme à la planche.
        chemin = self.dir / "encoche.png"
        self.appeler("capturer", chemin)
        fin = time.monotonic() + DELAI
        while not chemin.exists() and time.monotonic() < fin:
            time.sleep(0.05)
        self.assertEqual(chemin.read_bytes()[:8], b"\x89PNG\r\n\x1a\n", self.journal())
