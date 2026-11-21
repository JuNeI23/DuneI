"""Tests du sélecteur de fenêtres de la coque (L2-17).

Rôle : éprouve la logique pure de selecteur.js (filtre, avance en boucle, défilement, largeur des vignettes) dans un
vrai Quickshell, par l'IPC de la coque d'essai coque/Selecteur/essai/logique.
Entrées : aucune. Sorties : résultats unittest. Erreurs : échecs de test.
Dépendances : qs (Quickshell ≥ 0.3), tests.test_coque_theme (EssaiCoque).
"""
import json
import os
import subprocess
import unittest

from tests.test_coque_theme import DELAI, QS, ROOT, EssaiCoque


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
