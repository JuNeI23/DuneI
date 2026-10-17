"""Atelier — lecture de atelier.toml et réglage de mémoire du projet."""

import hashlib
import io
import json
import os
import subprocess
import tarfile
import tempfile
import unittest
from pathlib import Path
from unittest import mock

import atelier
from atelier import appliquer, lire_atelier, plan_rtk, sha256

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


class RtkTest(unittest.TestCase):
    """Destination rtk : archive factice, cache et binaire temporaires, adresse file://, aucun réseau."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        t = Path(self.tmp.name)
        self.bin, self.cache, self.source = t / "bin", t / "cache", t / "source"
        self.source.mkdir()
        self.binaire = b"#!/bin/sh\necho rtk factice\n"
        self.archive = self._archive(self.binaire)
        self.toml = t / "atelier.toml"
        self._ecrire_toml(sha256(self.archive))
        self.env = mock.patch.dict(os.environ, {"DUNEI_ATELIER_TOML": str(self.toml), "XDG_BIN_HOME": str(self.bin),
                                                "XDG_CACHE_HOME": str(t / "cache-racine")})
        self.env.start()
        self.cache = t / "cache-racine" / "dunei"

    def tearDown(self):
        self.env.stop()
        self.tmp.cleanup()

    def _archive(self, binaire: bytes) -> Path:
        """Construit rtk-test.tar.gz (rtk et LICENSE) dans source et rend son chemin."""
        chemin = self.source / "rtk-test.tar.gz"
        with tarfile.open(chemin, "w:gz") as tar:
            for nom, contenu in (("rtk", binaire), ("LICENSE", b"licence\n")):
                info = tarfile.TarInfo(nom)
                info.size = len(contenu)
                tar.addfile(info, io.BytesIO(contenu))
        return chemin

    def _ecrire_toml(self, somme_archive: str):
        """Écrit atelier.toml : adresse file:// de l'archive factice, somme d'archive et de binaire donnés."""
        self.toml.write_text(
            f'[rtk]\nversion = "9.9.9"\narchive = "rtk-test.tar.gz"\nurl = "file://{self.archive}"\n'
            f'sha256_archive = "{somme_archive}"\n'
            f'sha256_binaire = "{hashlib.sha256(self.binaire).hexdigest()}"\n'
            '[atelier]\ndepot = "x/y"\nclone = "~/c"\ngitconfig = "g"\n[atelier.liens]\n"a" = "~/a"\n',
            encoding="utf-8")

    def _poser_binaire(self, contenu: bytes):
        """Place un binaire rtk dans XDG_BIN_HOME."""
        self.bin.mkdir(exist_ok=True)
        (self.bin / "rtk").write_bytes(contenu)

    def test_binaire_conforme_rien_a_faire(self):
        self._poser_binaire(self.binaire)
        with mock.patch.object(atelier, "telecharger", side_effect=AssertionError("réseau")):
            self.assertEqual(plan_rtk(ROOT, Path(self.tmp.name)), ([], []))

    def test_binaire_absent_telecharge_a_l_inspection(self):
        actions, erreurs = plan_rtk(ROOT, Path(self.tmp.name))
        self.assertEqual(erreurs, [])
        self.assertEqual(actions, [("rtk-pose", self.cache / "rtk-test.tar.gz", sha256_de(self.binaire), self.bin / "rtk")])
        self.assertTrue((self.cache / "rtk-test.tar.gz").is_file())
        self.assertFalse(self.bin.exists())

    def test_somme_d_archive_fausse(self):
        fausse = "0" * 64
        self._ecrire_toml(fausse)
        actions, erreurs = plan_rtk(ROOT, Path(self.tmp.name))
        self.assertEqual(actions, [])
        self.assertTrue(any(fausse in e and sha256(self.archive) in e for e in erreurs), erreurs)
        self.assertFalse(self.bin.exists())

    def test_cache_corrompu_retelecharge_une_fois(self):
        self.cache.mkdir(parents=True)
        (self.cache / "rtk-test.tar.gz").write_bytes(b"corrompu")
        reel = atelier.telecharger
        with mock.patch.object(atelier, "telecharger", side_effect=reel) as appels:
            actions, erreurs = plan_rtk(ROOT, Path(self.tmp.name))
            self.assertEqual((len(actions), erreurs, appels.call_count), (1, [], 1))
        (self.cache / "rtk-test.tar.gz").write_bytes(b"corrompu")
        self._ecrire_toml("0" * 64)
        with mock.patch.object(atelier, "telecharger", side_effect=reel) as appels:
            actions, erreurs = plan_rtk(ROOT, Path(self.tmp.name))
            self.assertEqual((actions, len(erreurs), appels.call_count), ([], 1, 1))

    def test_hors_ligne(self):
        with mock.patch.object(atelier, "telecharger", side_effect=OSError("réseau coupé")):
            actions, erreurs = plan_rtk(ROOT, Path(self.tmp.name))
        self.assertEqual(actions, [])
        self.assertTrue(any(f"file://{self.archive}" in e for e in erreurs), erreurs)

    def test_autre_version_remplacee(self):
        self._poser_binaire(b"ancien")
        actions, erreurs = plan_rtk(ROOT, Path(self.tmp.name))
        self.assertEqual(erreurs, [])
        self.assertEqual([a[0] for a in actions], ["rtk-pose", "rtk-remplace"])
        self.assertEqual(actions[1], ("rtk-remplace", self.bin / "rtk", "9.9.9"))

    def test_pose(self):
        dest = self.bin / "rtk"
        self.assertTrue(appliquer(("rtk-pose", self.archive, sha256_de(self.binaire), dest)))
        self.assertEqual(dest.read_bytes(), self.binaire)
        self.assertEqual(dest.stat().st_mode & 0o777, 0o755)

    def test_pose_binaire_faux(self):
        self._poser_binaire(b"ancien")
        with self.assertRaises(OSError):
            appliquer(("rtk-pose", self.archive, "0" * 64, self.bin / "rtk"))
        self.assertEqual((self.bin / "rtk").read_bytes(), b"ancien")
        self.assertEqual(sorted(p.name for p in self.bin.iterdir()), ["rtk"])

    def test_action_etrangere(self):
        self.assertFalse(appliquer(("link", Path("a"), Path("b"))))


def sha256_de(octets: bytes) -> str:
    """Somme SHA-256 d'un contenu en mémoire."""
    return hashlib.sha256(octets).hexdigest()


if __name__ == "__main__":
    unittest.main()
