"""Crochet pre-commit et make generes — de vrais commits dans une copie jetable du dépôt (L1-21).

La copie a son propre dépôt git et sa propre configuration : le vrai dépôt, ses crochets et la
configuration git de l'utilisateur ne sont jamais touchés.
"""

import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
IGNORE = shutil.ignore_patterns(".git", ".superpowers", "docs", "proto", "tests", "__pycache__", ".claude")
GIT = ["git", "-c", "user.name=essai", "-c", "user.email=essai@dunei.invalid"]


class CrochetTest(unittest.TestCase):
    """Chaque scénario : propre, retouché, source ou shader sans régénération, hors de l'index, orphelin, partiel, génération en échec."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.repo = Path(self.tmp.name) / "depot"
        # Liens copiés tels quels : coque/Theme/essai/Theme pointe vers son parent et ne se suit pas.
        shutil.copytree(ROOT, self.repo, symlinks=True, ignore=IGNORE)
        self.env = {**os.environ, "GIT_CONFIG_GLOBAL": "/dev/null", "GIT_CONFIG_SYSTEM": "/dev/null"}
        for args in (["init", "-q"], ["add", "-A"], ["commit", "-q", "--no-verify", "-m", "départ"],
                     ["config", "core.hooksPath", ".githooks"]):
            self.git(*args, check=True)

    def tearDown(self):
        self.tmp.cleanup()

    def git(self, *args: str, check: bool = False) -> subprocess.CompletedProcess:
        """Lance git dans la copie, sans configuration globale ni système."""
        return subprocess.run([*GIT, *args], cwd=self.repo, env=self.env, capture_output=True, text=True, check=check)

    def commit_autre(self) -> subprocess.CompletedProcess:
        """Indexe un fichier hors de generated/ et tente le commit."""
        (self.repo / "autre.txt").write_text("autre\n", encoding="utf-8")
        self.git("add", "autre.txt", check=True)
        return self.git("commit", "-q", "-m", "essai")

    def test_commit_propre_accepte(self):
        res = self.commit_autre()
        self.assertEqual(res.returncode, 0, res.stderr)

    def test_generated_retouche_refuse(self):
        with (self.repo / "generated/tokens.css").open("a", encoding="utf-8") as f:
            f.write("/* retouche */\n")
        self.git("add", "generated/tokens.css", check=True)
        res = self.git("commit", "-q", "-m", "essai")
        self.assertNotEqual(res.returncode, 0)
        self.assertIn("generated/", res.stderr)

    def test_source_sans_regeneration_refuse(self):
        src = self.repo / "tokens.toml"
        src.write_text(src.read_text(encoding="utf-8").replace("hue = 55 ", "hue = 60 ", 1), encoding="utf-8")
        self.git("add", "tokens.toml", check=True)
        self.assertNotEqual(self.git("commit", "-q", "-m", "essai").returncode, 0)
        subprocess.run(["make", "-s", "tokens", "motion", "energie"], cwd=self.repo, env=self.env, capture_output=True, check=True)
        self.git("add", "generated/", check=True)
        res = self.git("commit", "-q", "-m", "essai")
        self.assertEqual(res.returncode, 0, res.stderr)

    def test_fichier_genere_hors_index_refuse(self):
        self.git("rm", "-q", "--cached", "generated/tokens.css", check=True)
        res = self.git("commit", "-q", "-m", "essai")
        self.assertNotEqual(res.returncode, 0)
        self.assertIn("generated/tokens.css", res.stderr)

    def changer_teinte(self):
        """Change la teinte de tokens.toml dans l'arbre de travail, sans l'indexer."""
        src = self.repo / "tokens.toml"
        src.write_text(src.read_text(encoding="utf-8").replace("hue = 55 ", "hue = 60 ", 1), encoding="utf-8")

    def test_commit_partiel_coherent_accepte(self):
        self.changer_teinte()
        res = self.commit_autre()
        self.assertEqual(res.returncode, 0, res.stderr)

    def test_source_indexee_copie_restauree_refuse(self):
        self.changer_teinte()
        self.git("add", "tokens.toml", check=True)
        (self.repo / "tokens.toml").write_bytes(self.git("show", "HEAD:tokens.toml").stdout.encode())
        self.assertNotEqual(self.git("commit", "-q", "-m", "essai").returncode, 0)

    def test_orphelin_indexe_refuse(self):
        (self.repo / "generated/orphelin.txt").write_text("orphelin\n", encoding="utf-8")
        self.git("add", "generated/orphelin.txt", check=True)
        self.assertNotEqual(self.git("commit", "-q", "-m", "essai").returncode, 0)

    def test_arbre_de_travail_intact(self):
        with (self.repo / "generated/tokens.css").open("a", encoding="utf-8") as f:
            f.write("/* retouche */\n")
        self.git("add", "generated/tokens.css", check=True)
        self.git("commit", "-q", "-m", "essai")
        self.assertIn("/* retouche */", (self.repo / "generated/tokens.css").read_text(encoding="utf-8"))

    def test_commit_propre_silencieux(self):
        res = self.commit_autre()
        self.assertNotIn("écrit generated", res.stdout + res.stderr)

    def test_generation_en_echec_message(self):
        (self.repo / "tokens.toml").write_text("[[ invalide\n", encoding="utf-8")
        self.git("add", "tokens.toml", check=True)
        res = self.git("commit", "-q", "-m", "essai")
        self.assertNotEqual(res.returncode, 0)
        self.assertIn("la génération échoue", res.stderr)

    def test_shader_sans_recompilation_refuse(self):
        src = self.repo / "coque/Theme/materiau.frag"
        src.write_text(src.read_text(encoding="utf-8").replace("/ 255.0", "/ 128.0", 1), encoding="utf-8")
        self.git("add", "coque/Theme/materiau.frag", check=True)
        res = self.git("commit", "-q", "-m", "essai")
        self.assertNotEqual(res.returncode, 0)
        self.assertIn("materiau.frag.qsb", res.stderr)

    def test_make_generes(self):
        make = lambda: subprocess.run(["make", "-s", "generes"], cwd=self.repo, env=self.env, capture_output=True)
        (self.repo / "generated/materiau.frag.qsb").unlink()
        self.assertEqual(make().returncode, 0)
        (self.repo / "generated/nouveau.txt").write_text("nouveau\n", encoding="utf-8")
        self.assertNotEqual(make().returncode, 0)


if __name__ == "__main__":
    unittest.main()
