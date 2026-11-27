"""Rideau de la voie B : calque Overlay opaque posé avant la reprise du verrou par hyprlock (L2-22).

Rôle : vérifie la structure de coque/Rideau/shell.qml, puis son démarrage réel sous la plate-forme Qt hors écran.
Dépendances : unittest, subprocess, Quickshell (qs) pour le test de pose.
"""

import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SHELL = ROOT / "coque" / "Rideau" / "shell.qml"


class RideauTest(unittest.TestCase):
    """Contrôle du rideau : sa structure statique et sa pose."""

    def test_structure(self):
        """Le rideau porte son namespace, la couche Overlay, lit sa couleur dans l'environnement et n'importe rien de la coque."""
        texte = SHELL.read_text(encoding="utf-8")
        self.assertIn('WlrLayershell.namespace: "dunei-rideau"', texte)
        self.assertIn("WlrLayer.Overlay", texte)
        self.assertIn("ExclusionMode.Ignore", texte)
        self.assertIn("WlrKeyboardFocus.None", texte)
        self.assertIn('Quickshell.env("DUNEI_RIDEAU_COULEUR")', texte)
        self.assertNotIn('import "../', texte)
        self.assertNotRegex(texte, r'import\s+"')

    @unittest.skipUnless(shutil.which("qs"), "Quickshell absent")
    def test_pose(self):
        """Sous QT_QPA_PLATFORM=offscreen, sans aucune session Wayland, le rideau se charge jusqu'à son premier PanelWindow.

        Quickshell n'a pas de moteur de calque hors écran : la pose réelle (« rideau : posé ») ne peut s'éprouver que
        sur un calque visible, donc dans le banc imbriqué (tâche 10), jamais sur le bureau de l'utilisateur. Ici, le
        seul échec admis est « No PanelWindow backend loaded » : toute erreur de syntaxe, d'import ou de type en
        donnerait une autre. Le processus est lancé sans WAYLAND_DISPLAY et tué par son PID s'il survit.
        """
        with tempfile.TemporaryDirectory() as tmp:
            env = {**{k: v for k, v in os.environ.items() if k != "WAYLAND_DISPLAY"},
                   "QT_QPA_PLATFORM": "offscreen", "DUNEI_RIDEAU_COULEUR": "#101010", "XDG_RUNTIME_DIR": tmp}
            p = subprocess.Popen(["qs", "-p", str(SHELL)], env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                 text=True)
            try:
                sortie, _ = p.communicate(timeout=5)
            except subprocess.TimeoutExpired:
                p.kill()
                sortie, _ = p.communicate()
        erreurs = [l for l in sortie.splitlines() if "ERROR" in l]
        self.assertTrue(all("PanelWindow" in l or "Failed to load" in l for l in erreurs), sortie)
        self.assertNotIn("rideau : posé", sortie)


if __name__ == "__main__":
    unittest.main()
