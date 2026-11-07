"""Module QML Galerie — logique pure de la galerie de fonds (galerie.js, fichiers.js), éprouvée par IPC dans un vrai
Quickshell sans fenêtre.

Ignoré sans session Wayland ou sans Quickshell, comme les essais de la presqu'île.
"""

import json
import os
import subprocess
import unittest

from tests.test_coque_theme import DELAI, QS, ROOT, EssaiCoque

ESSAI = ROOT / "coque" / "Galerie" / "essai"


@unittest.skipUnless(os.environ.get("WAYLAND_DISPLAY") and QS, "session Wayland et Quickshell requis")
class GalerieIpc(EssaiCoque):
    """Base des tests qui pilotent la coque d'essai de la galerie par IPC (sans fenêtre)."""

    essai = ESSAI
    teintes = (55,)
    environnement = {"QT_QPA_PLATFORM": "offscreen"}

    def setUp(self):
        super().setUp()
        self.installer(55)
        self.lancer(self.dir)
        self.attendre("Theme : chargé, teinte 55")

    def appeler(self, *commande) -> str:
        """Appelle une fonction IPC de la cible « galerie-essai » et rend sa valeur de retour, sans espaces de fin.

        Entrée : commande — fonction puis arguments (convertis en texte, booléens en true/false).
        Sortie : texte retourné. Erreurs : CalledProcessError si l'appel échoue. Dépendances : qs, lancer.
        """
        args = [str(a).lower() if isinstance(a, bool) else str(a) for a in commande]
        sortie = subprocess.run([QS, "ipc", "--pid", str(self.proc.pid), "call", "galerie-essai", *args],
                                check=True, capture_output=True, text=True, timeout=DELAI)
        return sortie.stdout.strip()

    def json(self, *commande):
        """Comme appeler, mais décode le JSON rendu. Sortie : valeur Python. Erreurs : celles de appeler et json."""
        return json.loads(self.appeler(*commande))


class LogiqueTest(GalerieIpc, unittest.TestCase):
    """Les fonctions pures de galerie.js et de fichiers.js."""

    def test_borner(self):
        self.assertEqual(self.json("borner", 5, 3), 2)
        self.assertEqual(self.json("borner", -1, 3), 0)
        self.assertEqual(self.json("borner", 0, 0), -1)

    def test_borner_apres_retrait(self):
        """Une image retirée du dossier pendant l'ouverture : l'index sorti des bornes y revient."""
        self.assertEqual(self.json("borner", 3, 3), 2)

    def test_deplacer_sans_boucle(self):
        self.assertEqual(self.json("deplacer", 0, -1, 4), 0)
        self.assertEqual(self.json("deplacer", 3, 1, 4), 3)
        self.assertEqual(self.json("deplacer", 1, 1, 4), 2)

    def test_initial(self):
        chemins = "\n".join(["/a.jpg", "/b.jpg", "/c.jpg"])
        self.assertEqual(self.json("initial", chemins, "/b.jpg"), 1)
        self.assertEqual(self.json("initial", chemins, "/absent.jpg"), 0)
        self.assertEqual(self.json("initial", "", "/b.jpg"), -1)

    def test_cran_molette(self):
        self.assertEqual(self.json("cran", 0, 120, 120), {"pas": 1, "reste": 0})
        self.assertEqual(self.json("cran", 0, -240, 120)["pas"], -2)

    def test_cran_accumule(self):
        self.assertEqual(self.json("cran", 0, 50, 120), {"pas": 0, "reste": 50})
        self.assertEqual(self.json("cran", 50, 80, 120), {"pas": 1, "reste": 10})

    def test_identique(self):
        self.assertEqual(self.appeler("identique", "/a.jpg", "/a.jpg"), "true")
        self.assertEqual(self.appeler("identique", "/a.jpg", "/b.jpg"), "false")
        self.assertEqual(self.appeler("identique", "", ""), "false")

    def test_filtres(self):
        filtres = self.json("filtres")
        for f in ("jpg", "jpeg", "png", "gif", "bmp", "webp", "tif", "tiff"):
            self.assertIn("*." + f, filtres)
            self.assertIn("*." + f.upper(), filtres)
        self.assertNotIn("*.avif", filtres)

    def test_url_caracteres(self):
        """Espace, « # » et « ? » sont encodés : la vignette s'affiche, le chemin n'est pas tronqué."""
        self.assertEqual(self.appeler("url", "/a b/#c?.jpg"), "file:///a%20b/%23c%3F.jpg")

    def test_developper(self):
        self.assertEqual(self.appeler("developper", "~/x", "/home/n"), "/home/n/x")
        self.assertEqual(self.appeler("developper", "/abs/x", "/home/n"), "/abs/x")
