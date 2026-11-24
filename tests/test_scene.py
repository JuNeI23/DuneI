"""Tests du socle Scene de la coque (L2-23) : contrôleur d'une attention et sa fenêtre FenetreScene.

Rôle : éprouve un Scene ouvert pour de bon dans la session, sans prendre le clavier, par la coque d'essai
coque/Composants/essai/scene : construction de la fenêtre à l'ouverture, sortie en fondu, action différée jusqu'au
retrait du calque de la scène (son namespace, et non celui d'un autre calque), délai d'affichage, réouverture
pendant la sortie et fermeture par le lanceur (registre Overlays).
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


@unittest.skipUnless(os.environ.get("WAYLAND_DISPLAY") and QS, "session Wayland et Quickshell requis")
class SceneTest(EssaiCoque, unittest.TestCase):
    """Un Scene dont le cadre est un rectangle de 200 × 100, sa fenêtre de calque ouverte pour de bon dans la
    session, sans clavier (clavierExclusif faux), piloté par l'IPC « essai » ; le lanceur, chargé dans la même coque,
    sert à l'essai de la famille « attention ». Chaque essai est court : la coque est tuée à la fin, ce qui retire la
    fenêtre."""

    essai = ROOT / "coque" / "Composants" / "essai" / "scene"
    teintes = (55,)

    def setUp(self):
        """Lance la coque d'essai de la scène et attend les jetons.

        Entrées : aucune. Sortie : aucune ; self.proc tient la coque. Erreurs : test sauté si la fenêtre active est
        en plein écran ; échec si la coque n'est pas prête dans le délai. Dépendances : plein_ecran, installer,
        lancer, attendre, jusqua.
        """
        if plein_ecran():
            self.skipTest("fenêtre active en plein écran : la scène ne doit pas la couvrir")
        super().setUp()
        self.installer(55)
        self.lancer(self.dir)
        self.attendre("essai : prêt")
        self.jusqua(lambda: self.appel("essai", "pret") == "true", "jetons chargés")

    def appel(self, cible: str, fonction: str, *args: str) -> str:
        """Appelle une fonction IPC de la coque d'essai et rend sa sortie brute.

        Entrées : cible, « essai » ou « lanceur » ; fonction ; args, ses arguments en chaînes.
        Sortie : texte rendu. Erreurs : CalledProcessError si l'appel échoue. Dépendances : qs, lancer.
        """
        return subprocess.run([QS, "ipc", "--pid", str(self.proc.pid), "call", cible, fonction, *args], check=True,
                              capture_output=True, text=True, timeout=DELAI).stdout.strip()

    def etat(self) -> dict:
        """État de la scène décodé du JSON d'essai.etat. Sortie : dictionnaire {ouvert, present, fenetre, sortant,
        differee, montre, opacite}. Dépendances : appel."""
        return json.loads(self.appel("essai", "etat"))

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
        """Ouvre la scène et attend sa fenêtre. Sortie : l'état une fois la fenêtre construite.
        Dépendances : appel, jusqua, etat."""
        self.appel("essai", "ouvrir")
        return self.jusqua(lambda: (e := self.etat())["fenetre"] and e, "fenêtre de la scène")

    def test_ouverture_construit_la_fenetre(self):
        """Vérifie qu'à l'ouverture la scène est ouverte et sa fenêtre construite.

        Entrées : aucune. Sortie : aucune. Erreurs : échec d'assertion. Dépendances : ouvrir.
        """
        e = self.ouvrir()
        self.assertEqual((e["ouvert"], e["present"], e["fenetre"]), (True, True, True))

    def test_sortie_en_fondu(self):
        """Vérifie qu'à la fermeture la scène passe aussitôt en sortie, fenêtre gardée, puis que la fenêtre est
        déchargée une fois le fondu posé.

        Entrées : aucune. Sortie : aucune. Erreurs : échec d'assertion. Dépendances : ouvrir, appel, etat, jusqua.
        """
        self.ouvrir()
        self.appel("essai", "fermer")
        e = self.etat()
        self.assertEqual((e["ouvert"], e["sortant"], e["present"], e["fenetre"]), (False, True, True, True))
        e = self.jusqua(lambda: (e := self.etat()) and not e["fenetre"] and e, "fenêtre retirée")
        self.assertEqual((e["present"], e["sortant"]), (False, False))

    def test_action_apres_retrait(self):
        """Vérifie que l'action ne part qu'au retrait du calque par Hyprland (closelayer), bien avant la garde d'une
        seconde : « essai : exécuté x » suit « essai : calque retiré ». Tolérance : le seuil de 0,8 s laisse de la marge
        à une session chargée tout en excluant la garde.

        Entrées : aucune. Sortie : aucune. Erreurs : échec d'assertion. Dépendances : ouvrir, appel, etat, attendre,
        journal.
        """
        self.ouvrir()
        debut = time.monotonic()
        self.appel("essai", "executer", "x")
        e = self.etat()
        self.assertEqual((e["ouvert"], e["sortant"], e["differee"]), (False, True, "x"))
        self.assertNotIn("essai : exécuté", self.journal())
        self.attendre("essai : exécuté x")
        self.assertLess(time.monotonic() - debut, 0.8)
        journal = self.journal()
        self.assertIn("essai : calque retiré", journal)
        self.assertLess(journal.index("essai : calque retiré"), journal.index("essai : exécuté x"), journal)
        self.assertIsNone(self.etat()["differee"])

    def test_reouverture_pendant_sortie(self):
        """Vérifie qu'une réouverture avant la fin du fondu de sortie reprend la même fenêtre, sans action en attente.

        Entrées : aucune. Sortie : aucune. Erreurs : échec d'assertion. Dépendances : ouvrir, appel, etat, journal.
        """
        self.ouvrir()
        self.appel("essai", "fermer")
        self.appel("essai", "ouvrir")
        e = self.etat()
        self.assertEqual((e["ouvert"], e["fenetre"], e["sortant"], e["differee"]), (True, True, False, None))
        time.sleep(0.5)
        self.assertTrue(self.etat()["fenetre"])
        self.assertEqual(self.journal().count("essai : fenêtre construite"), 1, self.journal())

    def test_apparition_depuis_le_centre(self):
        """Vérifie qu'une scène sans montée (montee faux) fait grandir son cadre depuis une échelle inférieure à 1
        (window.echelleApparition) et le pose à l'échelle 1 au bout de son ressort.

        Entrées : aucune. Sortie : aucune. Erreurs : échec d'assertion. Dépendances : appel, ouvrir, jusqua.
        """
        self.appel("essai", "apparition", "false")
        self.ouvrir()
        vues = []
        self.jusqua(lambda: vues.append(float(self.appel("essai", "echelle"))) or vues[-1] == 1, "cadre à l'échelle 1")
        self.assertLess(min(vues), 1, vues)

    def test_placement_fourni(self):
        """Vérifie que la fonction de placement fournie par le client (Scene.positionner) fixe le haut du cadre : posée
        à 40 px par l'IPC placer, le cadre s'arrête à y = 40 une fois la montée posée, au lieu d'être centré.

        Entrées : aucune. Sortie : aucune. Erreurs : échec d'assertion. Dépendances : appel, ouvrir, jusqua, etat.
        """
        self.appel("essai", "placer", "40")
        self.ouvrir()
        self.jusqua(lambda: self.etat()["haut"] == 40, "cadre posé à 40 px du haut")

    def test_lanceur_ferme_scene(self):
        """Vérifie que le lanceur, de la même famille « attention », ferme la scène en s'ouvrant, sans qu'aucune
        action parte, ni au retrait du calque ni à la garde d'une seconde.

        Entrées : aucune. Sortie : aucune. Erreurs : échec d'assertion. Dépendances : ouvrir, appel, etat, journal.
        """
        self.ouvrir()
        self.appel("lanceur", "ouvrir")
        self.assertFalse(self.etat()["ouvert"])
        self.assertTrue(json.loads(self.appel("lanceur", "etat"))["ouvert"])
        time.sleep(1.3)
        self.assertNotIn("essai : exécuté", self.journal())

    def test_retrait_d_un_autre_calque(self):
        """Vérifie que l'action en attente ne part qu'au retrait du calque de la scène, son propre namespace (espace),
        et pas au retrait d'un autre calque d'attention (le lanceur en fondu, dunei-attention). Les événements sont
        simulés par l'IPC evenement, qui appelle Scene.surEvenement comme le ferait Hyprland.rawEvent.

        Entrées : aucune. Sortie : aucune. Erreurs : échec d'assertion. Dépendances : appel, ouvrir, etat, attendre,
        journal, hyprctl (le calque porte bien le namespace posé).
        """
        self.appel("essai", "espace", "dunei-attention-essai")
        self.ouvrir()
        calques = subprocess.run(["hyprctl", "layers", "-j"], capture_output=True, text=True, timeout=DELAI).stdout
        self.assertIn('"namespace": "dunei-attention-essai"', calques)
        self.appel("essai", "executer", "x")
        self.appel("essai", "evenement", "closelayer", "dunei-attention")
        self.assertEqual(self.etat()["differee"], "x")
        self.assertNotIn("essai : exécuté", self.journal())
        self.appel("essai", "evenement", "closelayer", "dunei-attention-essai")
        self.attendre("essai : exécuté x")
        self.assertIsNone(self.etat()["differee"])

    def test_delai_invisible(self):
        """Vérifie qu'avec un délai d'affichage la fenêtre est construite dès l'ouverture mais que la scène n'est
        montrée qu'au terme du délai.

        Entrées : aucune. Sortie : aucune. Erreurs : échec d'assertion. Dépendances : appel, ouvrir, etat.
        """
        self.appel("essai", "delai", "300")
        e = self.ouvrir()
        self.assertEqual((e["fenetre"], e["montre"]), (True, False))
        time.sleep(0.5)
        self.assertTrue(self.etat()["montre"])

    def test_fermeture_avant_delai(self):
        """Vérifie qu'une fermeture avant le terme du délai ne montre rien et qu'aucun fondu de sortie n'est attendu :
        sortant repasse à faux en moins de 0,3 s.

        Entrées : aucune. Sortie : aucune. Erreurs : échec d'assertion. Dépendances : appel, ouvrir, etat, jusqua.
        """
        self.appel("essai", "delai", "300")
        self.ouvrir()
        debut = time.monotonic()
        self.appel("essai", "fermer")
        self.jusqua(lambda: not self.etat()["sortant"], "sortie posée")
        self.assertFalse(self.etat()["fenetre"])
        self.assertLess(time.monotonic() - debut, 0.3)
        time.sleep(0.4)
        self.assertFalse(self.etat()["montre"])

    def test_sans_delai_opaque_des_la_creation(self):
        """Vérifie que sans délai la surface est opaque dès la construction de la fenêtre : seul le fondu du
        compositeur porte l'entrée, sans ressort d'opacité par-dessus.

        Entrées : aucune. Sortie : aucune. Erreurs : échec d'assertion. Dépendances : ouvrir.
        """
        e = self.ouvrir()
        self.assertEqual((e["montre"], e["opacite"]), (True, 1))


if __name__ == "__main__":
    unittest.main()
