"""Socle du module QML Composants — états, héritage par remontée et Surface, éprouvés dans un vrai Quickshell.

La coque d'essai coque/Composants/essai n'ouvre aucune fenêtre : elle instancie un arbre fixe (une Surface
fenêtre contenant une Surface panneau contenant une sonde) et répond par le journal aux appels IPC. Ignoré
sans session Wayland ou sans Quickshell (contrôle de GitHub), comme tests/test_coque_theme.py dont le harnais
est repris.
"""

import os
import shutil
import time
import unittest
from pathlib import Path

from tests.test_coque_theme import QS, ROOT, EssaiCoque

# Messages d'erreur du moteur JavaScript ou d'une liaison QML qui ne doivent jamais atteindre le journal.
ERREURS = ("TypeError", "ReferenceError", "Unable to assign")


@unittest.skipUnless(os.environ.get("WAYLAND_DISPLAY") and QS, "session Wayland et Quickshell requis")
class CoqueComposantsTest(EssaiCoque, unittest.TestCase):
    """Lance la coque d'essai du module Composants et lit les valeurs qu'elle journalise."""

    essai = ROOT / "coque" / "Composants" / "essai"
    teintes = (55,)

    def demarrer(self) -> None:
        """Pose les tokens de la teinte 55, lance la coque d'essai et attend qu'elle soit prête.

        Entrées : aucune. Sortie : aucune.
        Erreurs : échec du test si la coque ne se déclare pas prête dans le délai.
        Dépendances : installer, lancer, attendre.
        """
        self.installer(55)
        self.lancer(self.dir)
        self.attendre("essai : prêt true")

    def valeur(self, cle: str) -> str:
        """Appelle une fonction IPC de lecture et rend la valeur qu'elle journalise.

        Entrée : cle — nom de la fonction IPC, qui journalise « essai : <cle> <valeur> ».
        Sortie : la valeur de la ligne écrite par cet appel.
        Erreurs : échec du test si la ligne n'arrive pas dans le délai ; CalledProcessError si l'appel échoue.
        Dépendances : ipc, attendre, journal.
        """
        prefixe = f"essai : {cle} "
        avant = self.journal().count(prefixe)
        self.ipc(cle)
        self.attendre(prefixe, avant + 1)
        return [ligne for ligne in self.journal().splitlines() if prefixe in ligne][-1].split(prefixe, 1)[1]

    def test_un_seul_theme(self):
        # La coque importe "Theme", Surface importe "../Theme" depuis le lien Composants : un seul singleton.
        self.demarrer()
        self.attendre("Theme : mouvement chargé")
        # Les lectures sont asynchrones : un second singleton journaliserait son chargement un peu plus tard.
        time.sleep(0.5)
        self.assertEqual(self.journal().count("Theme : chargé"), 1, self.journal())
        self.assertEqual(self.journal().count("Theme : mouvement chargé"), 1, self.journal())

    def test_cran(self):
        self.demarrer()
        self.assertEqual(self.valeur("cran"), "surfacePanel, surfaceRaised, controlRaised, controlRaised")

    def test_interaction_ordre(self):
        self.demarrer()
        self.assertEqual(self.valeur("interaction"), "disabled, pressed, hover, rest")

    def test_selection(self):
        self.demarrer()
        self.assertEqual(self.valeur("selection"), "none, activeMuted, active, inactive")

    def test_heritage(self):
        self.demarrer()
        self.assertEqual(self.valeur("sonde"), "surfacePanel false")
        self.ipc("inactif", "true")
        self.assertEqual(self.valeur("sonde"), "surfacePanel true")
        self.ipc("inactif", "false")
        self.assertEqual(self.valeur("sonde"), "surfacePanel false")

    def test_heritage_reparentage(self):
        self.demarrer()
        self.assertEqual(self.valeur("sonde"), "surfacePanel false")
        self.ipc("reparenter")
        # Même objet, mêmes liaisons : la remontée suit le nouveau parent, déclaré inactif au rôle surfaceRaised.
        self.assertEqual(self.valeur("sonde"), "surfaceRaised true")
        self.assertEqual(self.valeur("naissances"), "1")

    def test_aucune_erreur_avant_tokens(self):
        self.lancer(self.dir)
        self.attendre("Theme : coque-tokens.json introuvable")
        self.assertEqual(self.valeur("sonde"), "surfacePanel false")
        shutil.copy(Path(self.gen.name) / "motion" / "motion.json", self.dir / "motion.json")
        self.remplacer(55)
        self.attendre("essai : prêt true")
        self.assertEqual(self.valeur("sonde"), "surfacePanel false")
        for erreur in ERREURS:
            with self.subTest(erreur=erreur):
                self.assertNotIn(erreur, self.journal())


if __name__ == "__main__":
    unittest.main()
