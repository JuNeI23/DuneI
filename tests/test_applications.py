"""Tests du module Applications de la coque (L2-69).

Rôle : éprouve la logique pure d'applications.js (résolution d'une entrée de bureau, fenêtres d'une application,
commandes de focus et de lancement) dans un vrai Quickshell, par l'IPC de la coque d'essai
coque/Applications/essai/logique.
Entrées : aucune. Sorties : résultats unittest. Erreurs : échecs de test.
Dépendances : qs (Quickshell ≥ 0.3), tests.test_coque_theme (EssaiCoque).
"""
import json
import subprocess
import unittest

from tests.test_coque_theme import DELAI, QS, ROOT, EssaiCoque

DOLPHIN = {"id": "org.kde.dolphin", "name": "Dolphin", "startupClass": "dolphin", "runInTerminal": False}
DISCORD = {"id": "com.discordapp.Discord", "name": "Discord", "startupClass": "", "runInTerminal": False}
HTOP = {"id": "htop", "name": "Htop", "startupClass": "", "runInTerminal": True}
E = [DOLPHIN, DISCORD, HTOP]


class ApplicationsTest(EssaiCoque, unittest.TestCase):
    """La logique des applications (applications.js), appelée par l'IPC d'une coque d'essai sans fenêtre."""

    essai = ROOT / "coque" / "Applications" / "essai" / "logique"
    teintes = ()

    def setUp(self):
        super().setUp()
        self.lancer(self.dir)
        self.attendre("essai : prêt")

    def appeler(self, fonction: str, *args):
        """Appelle une fonction d'applications.js et rend sa valeur décodée.

        Entrées : fonction — nom exporté par applications.js ; args — ses arguments, transmis en JSON dans
        {"args": [...]}. Sortie : la valeur retournée, décodée du JSON. Erreurs : échec du test si la fonction lève ;
        CalledProcessError si l'appel IPC échoue. Dépendances : qs, lancer.
        """
        sortie = subprocess.run([QS, "ipc", "--pid", str(self.proc.pid), "call", "essai", "appeler", fonction,
                                 json.dumps({"args": list(args)})], check=True, capture_output=True, text=True,
                                timeout=DELAI).stdout.strip()
        self.assertFalse(sortie.startswith("erreur"), sortie)
        return json.loads(sortie)

    def test_resoudre_id(self):
        self.assertEqual(self.appeler("resoudre", "org.kde.dolphin", "", E), DOLPHIN)
        self.assertEqual(self.appeler("resoudre", "org.kde.Dolphin.desktop", "", E), DOLPHIN)

    def test_resoudre_classe(self):
        self.assertEqual(self.appeler("resoudre", "dolphin", "", E), DOLPHIN)
        self.assertEqual(self.appeler("resoudre", "", "DOLPHIN", E), DOLPHIN)

    def test_resoudre_nom(self):
        self.assertEqual(self.appeler("resoudre", "", "discord", E), DISCORD)

    def test_resoudre_rien(self):
        for bureau, nom in (("", ""), ("", "notify-send"), ("inconnu", "Inconnu")):
            with self.subTest(bureau=bureau, nom=nom):
                self.assertIsNone(self.appeler("resoudre", bureau, nom, E))

    def test_resoudre_terminal(self):
        self.assertIsNone(self.appeler("resoudre", "htop", "", E))

    def test_fenetres(self):
        toplevels = [{"adresse": "a1", "classe": "org.kde.dolphin", "historique": 3},
                     {"adresse": "b2", "classe": "kitty", "historique": 0},
                     {"adresse": "c3", "classe": "Dolphin", "historique": 1}]
        self.assertEqual(self.appeler("fenetres", DOLPHIN, toplevels), ["c3", "a1"])
        self.assertEqual(self.appeler("fenetres", DISCORD, toplevels), [])

    def test_commandes(self):
        attendu = 'hl.dsp.focus({ window = "address:0x564b9643c830" })'
        self.assertEqual(self.appeler("commandeFocus", "564b9643c830"), attendu)
        self.assertEqual(self.appeler("commandeFocus", "0x564b9643c830"), attendu)
        self.assertEqual(self.appeler("commandeLancement", DOLPHIN), ["uwsm", "app", "--", "org.kde.dolphin.desktop"])


if __name__ == "__main__":
    unittest.main()
