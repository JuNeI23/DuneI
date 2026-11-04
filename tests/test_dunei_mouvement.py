"""Mouvement réduit — dunei-mouvement exécuté dans un dossier temporaire désigné par DUNEI_TOKENS_DIR.

Hyprland n'est jamais joint : un faux hyprctl, placé en tête du PATH, enregistre ses appels dans un fichier.
"""

import json
import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCRIPT = ROOT / "config" / "bin" / "dunei-mouvement"


class DuneiMouvementTest(unittest.TestCase):
    """Lecture de l'état, écriture atomique de la préférence, rechargement de Hyprland et refus des arguments inconnus."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.dir = Path(self.tmp.name) / "dunei"
        self.dir.mkdir()
        self.choix = self.dir / "mouvement.json"
        self.appels = Path(self.tmp.name) / "hyprctl.log"
        faux = Path(self.tmp.name) / "faux"
        faux.mkdir()
        (faux / "hyprctl").write_text(f'#!/bin/sh\necho "$@" >> "{self.appels}"\n')
        (faux / "hyprctl").chmod(0o755)
        self.faux = faux

    def tearDown(self):
        self.tmp.cleanup()

    def lance(self, *args: str, hyprland: bool = False) -> subprocess.CompletedProcess:
        """Lance dunei-mouvement avec le dossier d'essai et le faux hyprctl ; HOME reste dans le dossier temporaire.

        Entrées : args — arguments de la commande ; hyprland — vrai pour simuler une session Hyprland en cours.
        Sortie : le processus terminé. Erreurs : aucune. Dépendances : SCRIPT.
        """
        env = {**os.environ, "DUNEI_TOKENS_DIR": str(self.dir), "HOME": str(Path(self.tmp.name) / "home"),
               "PATH": f"{self.faux}:{os.environ['PATH']}"}
        env.pop("XDG_CONFIG_HOME", None)
        env.pop("HYPRLAND_INSTANCE_SIGNATURE", None)
        if hyprland:
            env["HYPRLAND_INSTANCE_SIGNATURE"] = "essai"
        return subprocess.run([str(SCRIPT), *args], capture_output=True, text=True, env=env)

    def test_etat_par_defaut(self):
        res = self.lance()
        self.assertEqual((res.returncode, res.stdout), (0, "normal\n"))
        self.assertFalse(self.choix.exists())

    def test_reduit_puis_normal(self):
        self.assertEqual(self.lance("reduit").stdout, "reduit\n")
        self.assertEqual(json.loads(self.choix.read_text()), {"reduit": True})
        self.assertEqual(self.lance().stdout, "reduit\n")
        self.assertEqual(self.lance("normal").stdout, "normal\n")
        self.assertEqual(json.loads(self.choix.read_text()), {"reduit": False})

    def test_bascule_aller_retour(self):
        self.assertEqual(self.lance("bascule").stdout, "reduit\n")
        self.assertEqual(self.lance("bascule").stdout, "normal\n")

    def test_fichier_invalide_vaut_normal(self):
        for texte in ("pas du json", '{"reduit": "oui"}', "{}"):
            self.choix.write_text(texte)
            self.assertEqual(self.lance().stdout, "normal\n", texte)

    def test_argument_inconnu(self):
        self.lance("reduit")
        avant = self.choix.read_text()
        for args in (("rapide",), ("reduit", "normal"), ("bascule", "x")):
            res = self.lance(*args)
            self.assertEqual(res.returncode, 2, args)
            self.assertIn("Usage", res.stderr)
        self.assertEqual(self.choix.read_text(), avant)

    def test_ecriture_atomique(self):
        self.lance("reduit")
        self.assertEqual([p.name for p in self.dir.iterdir()], ["mouvement.json"])

    def test_jq_manquant(self):
        # Sans jq dans le PATH, le script refuse d'agir : code 1, message explicite, aucune préférence écrite.
        sain = Path(self.tmp.name) / "sain"
        sain.mkdir()
        for outil in ("sh", "bash", "env", "mktemp", "mv", "rm", "dirname", "cat"):
            if chemin := shutil.which(outil):
                (sain / outil).symlink_to(chemin)
        env = {**os.environ, "DUNEI_TOKENS_DIR": str(self.dir), "PATH": str(sain)}
        res = subprocess.run([str(SCRIPT), "reduit"], capture_output=True, text=True, env=env)
        self.assertEqual(res.returncode, 1)
        self.assertIn("jq", res.stderr)
        self.assertFalse(self.choix.exists())

    def test_recharge_hyprland_si_il_tourne(self):
        self.lance("reduit", hyprland=True)
        self.assertEqual(self.appels.read_text(), "reload\n")

    def test_aucun_rechargement_hors_hyprland(self):
        self.lance("reduit")
        self.assertFalse(self.appels.exists())
        self.lance(hyprland=True)
        self.assertFalse(self.appels.exists())


if __name__ == "__main__":
    unittest.main()
