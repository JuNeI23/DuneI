"""Thèmes — dunei-theme exécuté dans un dossier temporaire désigné par DUNEI_TOKENS_DIR."""

import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCRIPT = ROOT / "config" / "bin" / "dunei-theme"


class DuneiThemeTest(unittest.TestCase):
    """Lecture de l'état, écriture atomique du choix et refus des noms inconnus."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.dir = Path(self.tmp.name)
        self.choix = self.dir / "theme.json"
        subprocess.run(["python3", "generate_tokens.py", "--out", str(self.dir), "--hue", "250"],
                       cwd=ROOT, check=True, capture_output=True)

    def tearDown(self):
        self.tmp.cleanup()

    def lance(self, *args: str, dossier: Path | None = None) -> subprocess.CompletedProcess:
        """Lance dunei-theme avec le dossier d'essai (ou celui donné) ; HOME reste dans le dossier temporaire."""
        env = {**os.environ, "DUNEI_TOKENS_DIR": str(dossier or self.dir), "HOME": str(self.dir / "home")}
        env.pop("XDG_CONFIG_HOME", None)
        return subprocess.run([str(SCRIPT), *args], capture_output=True, text=True, env=env)

    def test_etat_par_defaut(self):
        res = self.lance()
        self.assertEqual((res.returncode, res.stdout), (0, "thematisee nuit\n"))
        self.assertFalse(self.choix.exists())

    def test_jour_garde_la_famille(self):
        self.lance("famille", "dominante")
        res = self.lance("jour")
        self.assertEqual((res.returncode, res.stdout), (0, "dominante jour\n"))

    def test_bascule_aller_retour(self):
        self.assertEqual(self.lance("bascule").stdout, "thematisee jour\n")
        self.assertEqual(self.lance("bascule").stdout, "thematisee nuit\n")

    def test_famille(self):
        res = self.lance("famille", "dominante")
        self.assertEqual((res.returncode, res.stdout), (0, "dominante nuit\n"))
        self.assertEqual(json.loads(self.choix.read_text()), {"famille": "dominante", "moment": "nuit"})

    def test_nom_inconnu(self):
        self.lance("jour")
        avant = self.choix.read_text()
        for args in (("famille", "rose"), ("famille",), ("bbizarre",)):
            res = self.lance(*args)
            self.assertEqual(res.returncode, 2, args)
            self.assertIn("Usage", res.stderr)
        self.assertEqual(self.choix.read_text(), avant)

    def test_sans_tokens(self):
        vide = self.dir / "vide"
        vide.mkdir()
        res = self.lance("jour", dossier=vide)
        self.assertEqual(res.returncode, 1)
        self.assertIn("coque-tokens.json", res.stderr)
        self.assertEqual(list(vide.iterdir()), [])

    def test_ecriture_atomique(self):
        avant = set(self.dir.iterdir())
        self.lance("jour")
        self.assertEqual(set(self.dir.iterdir()) - avant, {self.choix})

    def test_json_valide(self):
        self.lance("jour")
        self.assertEqual(set(json.loads(self.choix.read_text())), {"famille", "moment"})


if __name__ == "__main__":
    unittest.main()
