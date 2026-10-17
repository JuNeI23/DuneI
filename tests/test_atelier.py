"""Atelier — lecture de atelier.toml et réglage de mémoire du projet."""

import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from atelier import lire_atelier

ROOT = Path(__file__).resolve().parent.parent


class LectureTest(unittest.TestCase):
    """Lecture de atelier.toml : valeurs du dépôt, erreurs nommées, absence de secret."""

    def _lire_texte(self, texte: str):
        """Écrit texte dans un atelier.toml temporaire, le fait lire et rend (données, erreurs)."""
        with tempfile.TemporaryDirectory() as tmp:
            chemin = Path(tmp) / "atelier.toml"
            chemin.write_text(texte, encoding="utf-8")
            with mock.patch.dict(os.environ, {"DUNEI_ATELIER_TOML": str(chemin)}):
                return lire_atelier(ROOT)

    def _texte_depot(self) -> str:
        """Rend le texte de l'atelier.toml du dépôt."""
        return (ROOT / "atelier.toml").read_text(encoding="utf-8")

    def test_lit_le_depot(self):
        donnees, erreurs = lire_atelier(ROOT)
        self.assertEqual(erreurs, [])
        self.assertEqual(donnees["rtk"]["version"], "1.0.1")
        self.assertEqual(donnees["atelier"]["clone"], Path.home() / "dunei-atelier")
        self.assertEqual(len(donnees["atelier"]["liens"]), 5)

    def test_memoire_du_projet_dans_le_clone(self):
        donnees, _ = lire_atelier(ROOT)
        reglage = json.loads((ROOT / ".claude/settings.json").read_text(encoding="utf-8"))
        self.assertEqual(Path(reglage["autoMemoryDirectory"]).expanduser(),
                         donnees["atelier"]["clone"] / "memoire")

    def test_cle_manquante(self):
        texte = "\n".join(l for l in self._texte_depot().splitlines() if not l.startswith("sha256_binaire"))
        _, erreurs = self._lire_texte(texte)
        self.assertTrue(any("sha256_binaire" in e for e in erreurs), erreurs)

    def test_somme_mal_formee(self):
        texte = self._texte_depot().replace(
            "2e7508fe33f5fa336df8784158fafffa9bca09d060de22f7b4c6246ede96c4c4", "abc123")
        _, erreurs = self._lire_texte(texte)
        self.assertTrue(any("sha256_binaire" in e and "64" in e for e in erreurs), erreurs)

    def test_aucun_secret_dans_les_liens(self):
        donnees, _ = lire_atelier(ROOT)
        for destination in donnees["atelier"]["liens"].values():
            self.assertFalse(str(destination).endswith(".credentials.json"))

    def test_git_ignore_le_reste_de_claude(self):
        def ignore(chemin):
            return subprocess.run(["git", "check-ignore", "-q", chemin], cwd=ROOT).returncode == 0
        self.assertTrue(ignore(".claude/settings.local.json"))
        self.assertFalse(ignore(".claude/settings.json"))


if __name__ == "__main__":
    unittest.main()
