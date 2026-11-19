"""Tests du lanceur d'applications de la coque (L2-16).

Rôle : éprouve la logique pure de lanceur.js (recherche floue, actions visées, classement) dans un vrai Quickshell,
par l'IPC de la coque d'essai coque/Lanceur/essai/logique.
Entrées : aucune. Sorties : résultats unittest. Erreurs : échecs de test.
Dépendances : qs (Quickshell ≥ 0.3), tests.test_coque_theme (EssaiCoque).
"""
import json
import os
import subprocess
import unittest

from tests.test_coque_theme import DELAI, QS, ROOT, EssaiCoque


def res(cle: str, genre: str, pertinence: int, retrait: bool = False, app: str = "") -> dict:
    """Construit un résultat minimal du lanceur.

    Entrées : cle, genre, pertinence ; retrait, vrai pour une fenêtre rangée ; app, clé de son application.
    Sortie : le dictionnaire du résultat, titré par sa clé. Erreurs : aucune. Dépendances : aucune.
    """
    return {"cle": cle, "genre": genre, "titre": cle, "pertinence": pertinence, "retrait": retrait, "app": app}


@unittest.skipUnless(os.environ.get("WAYLAND_DISPLAY") and QS, "session Wayland et Quickshell requis")
class LogiqueTest(EssaiCoque, unittest.TestCase):
    """La logique du lanceur (lanceur.js), appelée par l'IPC d'une coque d'essai sans fenêtre."""

    essai = ROOT / "coque" / "Lanceur" / "essai" / "logique"
    teintes = ()

    def setUp(self):
        super().setUp()
        self.lancer(self.dir)
        self.attendre("essai : prêt")

    def appeler(self, fonction: str, *args):
        """Appelle une fonction de lanceur.js et rend sa valeur décodée.

        Entrées : fonction — nom exporté par lanceur.js ; args — ses arguments, transmis en JSON dans
        {"args": [...]}. Sortie : la valeur retournée, décodée du JSON. Erreurs : échec du test si la fonction lève ;
        CalledProcessError si l'appel IPC échoue. Dépendances : qs, lancer.
        """
        sortie = subprocess.run([QS, "ipc", "--pid", str(self.proc.pid), "call", "essai", "appeler", fonction,
                                 json.dumps({"args": list(args)})], check=True, capture_output=True, text=True,
                                timeout=DELAI).stdout.strip()
        self.assertFalse(sortie.startswith("erreur"), sortie)
        return json.loads(sortie)

    def test_score_ordre(self):
        self.assertEqual([self.appeler("score", t, "fire") for t in
                          ("Firefox", "Mozilla Firefox", "Campfire", "Ferme")], [4, 3, 2, 0])
        self.assertEqual(self.appeler("score", "Paramètres", "parametres"), 4)   # accents ignorés
        self.assertEqual(self.appeler("score", "LibreOffice Writer", "lowr"), 1)

    def test_action_visee(self):
        self.assertTrue(self.appeler("actionVisee", "Firefox", "Nouvelle fenêtre privée", "privée"))
        self.assertTrue(self.appeler("actionVisee", "Firefox", "Nouvelle fenêtre privée", "fire priv"))
        self.assertFalse(self.appeler("actionVisee", "Firefox", "Nouvelle fenêtre privée", "fire"))

    def test_classer_application_puis_fenetres(self):
        r = [res("fen:2", "fenetre", 3, retrait=True, app="app:ff"), res("app:kit", "application", 4),
             res("app:ff", "application", 4), res("cmd:x", "commande", 4), res("calc", "calcul", 0),
             res("fen:1", "fenetre", 3, retrait=True, app="app:ff")]
        cles = [x["cle"] for x in self.appeler("classer", r, {"app:ff": 9, "fen:1": 5, "fen:2": 1})]
        self.assertEqual(cles, ["calc", "app:ff", "fen:1", "fen:2", "app:kit", "cmd:x"])


if __name__ == "__main__":
    unittest.main()
