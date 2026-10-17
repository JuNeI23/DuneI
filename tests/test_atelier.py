"""Atelier — lecture de atelier.toml et réglage de mémoire du projet."""

import hashlib
import http.client
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
from atelier import appliquer, etat_atelier, lire_atelier, plan_atelier, plan_rtk, sha256

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

    def test_cache_valide_sans_telechargement(self):
        self.cache.mkdir(parents=True)
        (self.cache / "rtk-test.tar.gz").write_bytes(self.archive.read_bytes())
        with mock.patch.object(atelier, "telecharger", side_effect=AssertionError("réseau")):
            actions, erreurs = plan_rtk(ROOT, Path(self.tmp.name))
        self.assertEqual((len(actions), erreurs), (1, []))

    def test_erreurs_http_et_valeur_du_telechargement(self):
        for exc in (http.client.HTTPException("réponse tronquée"), ValueError("adresse inconnue")):
            with mock.patch.object(atelier, "telecharger", side_effect=exc):
                actions, erreurs = plan_rtk(ROOT, Path(self.tmp.name))
            self.assertEqual((actions, len(erreurs)), ([], 1), exc)
            self.assertIn("non téléchargeable", erreurs[0])
        self.assertFalse(self.bin.exists())

    def test_archive_sans_membre_rtk(self):
        sans = self.source / "sans.tar.gz"
        with tarfile.open(sans, "w:gz") as tar:
            info = tarfile.TarInfo("LICENSE")
            tar.addfile(info, io.BytesIO(b""))
        self._poser_binaire(b"ancien")
        with self.assertRaises(OSError):
            appliquer(("rtk-pose", sans, sha256_de(self.binaire), self.bin / "rtk"))
        self.assertEqual(sorted(p.name for p in self.bin.iterdir()), ["rtk"])
        self.assertEqual((self.bin / "rtk").read_bytes(), b"ancien")

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


# Faux gh : auth status et repo view répondent par $FAKE_GH_AUTH (0 ou 1) ; repo clone <depot> <dest> clone
# le dépôt nu $FAKE_ATELIER_NU, puis donne à origin l'adresse GitHub du dépôt demandé.
FAUX_GH = ('#!/bin/sh\ncase "$1 $2" in\n"auth status"|"repo view") exit "${FAKE_GH_AUTH:-0}" ;;\n'
           '"repo clone") [ -z "$FAKE_GH_CLONE_FAIL" ] || exit 1; git clone -q "$FAKE_ATELIER_NU" "$4" && git -C "$4" remote set-url origin "https://github.com/$3.git" ;;\n'
           'esac\n')
FAUX_CLAUDE = """#!/bin/sh
echo "$*" >> "$FAKE_CLAUDE_LOG"
[ "$1 $2" = "plugin list" ] && echo "$FAKE_PLUGINS"
exit 0
"""
LIENS = {"claude/settings.json": ".claude/settings.json", "claude/CLAUDE.md": ".claude/CLAUDE.md",
         "claude/RTK.md": ".claude/RTK.md", "maison/CLAUDE.md": "CLAUDE.md", "rtk/config.toml": ".config/rtk/config.toml"}


class AtelierTest(unittest.TestCase):
    """Destination atelier : dépôt nu local pour dunei-atelier, faux gh dans le PATH, HOME temporaire."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        t = Path(self.tmp.name)
        self.home, self.clone = t / "home", t / "home" / "dunei-atelier"
        self.home.mkdir()
        git = {"HOME": str(self.home), "GIT_CONFIG_GLOBAL": "/dev/null", "GIT_CONFIG_SYSTEM": "/dev/null",
               "GIT_AUTHOR_NAME": "t", "GIT_AUTHOR_EMAIL": "t@t", "GIT_COMMITTER_NAME": "t", "GIT_COMMITTER_EMAIL": "t@t"}
        self.nu, graine = t / "nu.git", t / "graine"
        for args in (["init", "-q", "--bare", "-b", "main", str(self.nu)], ["init", "-q", "-b", "main", str(graine)]):
            subprocess.run(["git", *args], check=True, cwd=t, env={**os.environ, **git})
        for rel in LIENS:
            (graine / rel).parent.mkdir(parents=True, exist_ok=True)
            (graine / rel).write_text("{}\n" if rel.endswith(".json") else f"atelier {rel}\n", encoding="utf-8")
        for args in (["add", "."], ["commit", "-qm", "graine"], ["push", "-q", str(self.nu), "main"]):
            subprocess.run(["git", "-C", str(graine), *args], check=True, env={**os.environ, **git})
        fake = t / "bin"
        fake.mkdir()
        (fake / "gh").write_text(FAUX_GH, encoding="utf-8")
        (fake / "gh").chmod(0o755)
        (fake / "claude").write_text(FAUX_CLAUDE, encoding="utf-8")
        (fake / "claude").chmod(0o755)
        self.fake, self.log = fake, t / "claude.log"
        liens = "".join(f'"{k}" = "~/{v}"\n' for k, v in LIENS.items())
        toml = t / "atelier.toml"
        toml.write_text('[rtk]\nversion = "1"\narchive = "a"\nurl = "file:///a"\n' + f'sha256_archive = "{"0" * 64}"\nsha256_binaire = "{"0" * 64}"\n'
                        '[atelier]\ndepot = "JuNeI23/dunei-atelier"\nclone = "~/dunei-atelier"\ngitconfig = "git/gitconfig"\n[atelier.liens]\n' + liens,
                        encoding="utf-8")
        git["GIT_CONFIG_GLOBAL"] = str(self.home / ".gitconfig")
        self.env = mock.patch.dict(os.environ, {**git, "FAKE_CLAUDE_LOG": str(self.log), "FAKE_PLUGINS": "[]", "DUNEI_ATELIER_TOML": str(toml), "FAKE_ATELIER_NU": str(self.nu),
                                                "FAKE_GH_AUTH": "0", "PATH": f"{fake}:{os.environ['PATH']}"})
        self.env.start()
        atelier.NOTES_APPLIQUEES.clear()
        atelier._SAUTE = False

    def tearDown(self):
        self.env.stop()
        self.tmp.cleanup()

    def _git(self, *args: str) -> str:
        """Lance git dans le clone et rend sa sortie standard."""
        return subprocess.run(["git", "-C", str(self.clone), *args], check=True, capture_output=True, text=True).stdout

    def _plan(self):
        """Inspecte la destination atelier."""
        return plan_atelier(ROOT, Path(self.tmp.name))

    def _tout_poser(self):
        """Inspecte puis applique toutes les actions ; rend la liste des actions."""
        actions, erreurs = self._plan()
        self.assertEqual(erreurs, [])
        for a in actions:
            if a[0] != "atelier-saute":
                self.assertTrue(appliquer(a), a)
        return actions

    def _dst(self, rel: str) -> Path:
        """Destination sous HOME du lien dont le chemin dans le clone est rel."""
        return self.home / LIENS[rel]

    def test_gh_deconnecte_saute(self):
        with mock.patch.dict(os.environ, {"FAKE_GH_AUTH": "1"}):
            actions, erreurs = self._plan()
        self.assertEqual((len(actions), actions[0][0], erreurs), (1, "atelier-saute", []))
        self.assertIn("gh auth login", actions[0][1])

    def test_machine_neuve(self):
        actions = self._tout_poser()
        self.assertEqual(actions[0], ("atelier-clone", "JuNeI23/dunei-atelier", self.clone))
        for rel in LIENS:
            self.assertEqual(self._dst(rel).resolve(), (self.clone / rel).resolve())
            self.assertTrue(self._dst(rel).is_symlink())
        self.assertEqual(atelier.NOTES_APPLIQUEES, [])

    def test_neuf_garde_le_fichier_par_defaut(self):
        dst = self._dst("claude/settings.json")
        dst.parent.mkdir(parents=True)
        dst.write_text("defaut\n", encoding="utf-8")
        self._tout_poser()
        self.assertTrue(dst.is_symlink())
        self.assertEqual(dst.with_name("settings.json.avant-dunei").read_text(encoding="utf-8"), "defaut\n")
        self.assertEqual(atelier.NOTES_APPLIQUEES, [("atelier-garde", dst, dst.with_name("settings.json.avant-dunei"))])

    def test_ancienne_garde_jamais_ecrasee(self):
        dst = self._dst("claude/settings.json")
        dst.parent.mkdir(parents=True)
        dst.write_text("nouveau\n", encoding="utf-8")
        ancienne = dst.with_name("settings.json.avant-dunei")
        ancienne.write_text("ancien\n", encoding="utf-8")
        self._tout_poser()
        self.assertEqual(ancienne.read_text(encoding="utf-8"), "ancien\n")
        suivante = dst.with_name("settings.json.avant-dunei.1")
        self.assertEqual(suivante.read_text(encoding="utf-8"), "nouveau\n")
        self.assertEqual(atelier.NOTES_APPLIQUEES, [("atelier-garde", dst, suivante)])

    def test_reprise_d_un_lien_remplace(self):
        self._tout_poser()
        dst = self._dst("claude/settings.json")
        dst.unlink()
        dst.write_text("réécrit par claude\n", encoding="utf-8")
        actions, erreurs = self._plan()
        self.assertEqual((erreurs, [a[0] for a in actions]), ([], ["atelier-lien"]))
        self.assertFalse(actions[0][3])
        self.assertTrue(appliquer(actions[0]))
        self.assertTrue(dst.is_symlink())
        self.assertEqual((self.clone / "claude/settings.json").read_text(encoding="utf-8"), "réécrit par claude\n")
        self.assertEqual(atelier.NOTES_APPLIQUEES, [("atelier-repris", dst)])
        self.assertIn("claude/settings.json", self._git("status", "--porcelain"))

    def test_fichier_identique_devient_lien(self):
        self._tout_poser()
        dst = self._dst("rtk/config.toml")
        dst.unlink()
        dst.write_text("atelier rtk/config.toml\n", encoding="utf-8")
        for a in self._plan()[0]:
            appliquer(a)
        self.assertTrue(dst.is_symlink())
        self.assertEqual(atelier.NOTES_APPLIQUEES, [])
        self.assertEqual(self._git("status", "--porcelain"), "")

    def test_deuxieme_passage_rien(self):
        self._tout_poser()
        self.assertEqual(self._plan(), ([], []))

    def test_lien_etranger_refuse(self):
        self._tout_poser()
        dst = self._dst("claude/RTK.md")
        dst.unlink()
        dst.symlink_to(self.home / "ailleurs")
        actions, erreurs = self._plan()
        self.assertEqual(len(erreurs), 1)
        self.assertIn(str(dst), erreurs[0])

    def test_clone_qui_n_est_pas_git_saute(self):
        self.clone.mkdir()
        actions, erreurs = self._plan()
        self.assertEqual(erreurs, [])
        self.assertEqual([a[0] for a in actions], ["atelier-saute"])
        self.assertIn("avant-dunei", actions[0][1])
        self.assertIn("ne pas le supprimer", actions[0][1])

    def test_autre_origine_refusee(self):
        self._tout_poser()
        self._git("remote", "set-url", "origin", "https://github.com/JuNeI23/autre.git")
        erreurs = self._plan()[1]
        self.assertEqual(len(erreurs), 1)
        self.assertIn(str(self.clone), erreurs[0])

    def test_origine_ssh_acceptee(self):
        self._tout_poser()
        self._git("remote", "set-url", "origin", "git@github.com:JuNeI23/dunei-atelier.git")
        self.assertEqual(self._plan(), ([], []))

    def test_dossier_a_la_place_refuse(self):
        dst = self._dst("maison/CLAUDE.md")
        dst.mkdir(parents=True)
        erreurs = self._plan()[1]
        self.assertEqual(len(erreurs), 1)
        self.assertIn(str(dst), erreurs[0])

    def test_clone_en_echec_saute_tout(self):
        actions, _ = self._plan()
        with mock.patch.dict(os.environ, {"FAKE_GH_CLONE_FAIL": "1"}):
            for a in actions:
                self.assertTrue(appliquer(a), a)
        self.assertEqual([n[0] for n in atelier.NOTES_APPLIQUEES], ["atelier-saute"])
        self.assertFalse(any(self._dst(rel).exists() or self._dst(rel).is_symlink() for rel in LIENS))
        self.assertEqual(list(self.home.rglob("*.avant-dunei*")), [])
        self.assertFalse((self.home / ".gitconfig").exists())

    def test_reprise_garde_une_modification_non_validee(self):
        self._tout_poser()
        src, dst = self.clone / "claude/settings.json", self._dst("claude/settings.json")
        src.write_text('{"travail": "en cours"}\n', encoding="utf-8")
        dst.unlink()
        dst.write_text("réécrit par claude\n", encoding="utf-8")
        for a in self._plan()[0]:
            appliquer(a)
        atelier.NOTES_APPLIQUEES[:] = [n for n in atelier.NOTES_APPLIQUEES if n[0] != "atelier-plugins-echec"]
        garde = src.with_name("settings.json.avant-dunei")
        self.assertEqual(src.read_text(encoding="utf-8"), "réécrit par claude\n")
        self.assertEqual(garde.read_text(encoding="utf-8"), '{"travail": "en cours"}\n')
        self.assertEqual(atelier.NOTES_APPLIQUEES, [("atelier-repris-garde", src, garde), ("atelier-repris", dst)])
        self.assertEqual(list(src.parent.glob(".*dunei-tmp")), [])

    def test_reprise_garde_src_si_git_echoue(self):
        self._tout_poser()
        src, dst = self.clone / "claude/settings.json", self._dst("claude/settings.json")
        src.write_text('{"travail": "en cours"}\n', encoding="utf-8")
        dst.unlink()
        dst.write_text("réécrit par claude\n", encoding="utf-8")
        actions = self._plan()[0]
        with mock.patch.dict(os.environ, {"GIT_DIR": str(self.home / "inexistant")}):
            for a in actions:
                appliquer(a)
        self.assertEqual(src.with_name("settings.json.avant-dunei").read_text(encoding="utf-8"), '{"travail": "en cours"}\n')

    def test_settings_invalide_sur_clone_existant_planifie_les_plugins(self):
        self._tout_poser()
        self._regler("pas du json")
        actions, erreurs = self._plan()
        self.assertEqual((erreurs, [a[0] for a in actions]), ([], ["atelier-plugins"]))

    def test_delai_de_gh_est_un_echec(self):
        with mock.patch.object(atelier.subprocess, "run", side_effect=subprocess.TimeoutExpired("gh", 30)):
            self.assertIn("gh auth login", atelier.gh_accessible("x/y"))

    def test_delai_de_claude_est_un_etat_inconnu(self):
        self._tout_poser()
        with mock.patch.object(atelier.subprocess, "run", side_effect=subprocess.TimeoutExpired("claude", 30)):
            self.assertIsNone(atelier._plugins_a_poser(self.clone))

    def _plugins(self, installes: list[str], voulus: dict) -> list[str]:
        """Pose un settings.json voulant `voulus`, simule `installes` et rend les appels faits à claude."""
        reglages = self.clone / "claude" / "settings.json"
        reglages.parent.mkdir(parents=True, exist_ok=True)
        reglages.write_text(json.dumps({"enabledPlugins": voulus}), encoding="utf-8")
        liste = json.dumps([{"id": i, "version": "1", "scope": "user", "enabled": True} for i in installes])
        with mock.patch.dict(os.environ, {"FAKE_PLUGINS": liste}):
            self.assertTrue(appliquer(("atelier-plugins", self.clone)))
        return self.log.read_text(encoding="utf-8").splitlines() if self.log.exists() else []

    def test_installe_les_plugins_manquants(self):
        appels = self._plugins(["context7@claude-plugins-official"],
                               {"context7@claude-plugins-official": True, "superpowers@claude-plugins-official": True, "off@x": False})
        self.assertEqual(appels, ["plugin list --json", "plugin install superpowers@claude-plugins-official"])

    def test_plugins_tous_presents_rien(self):
        appels = self._plugins(["a@m"], {"a@m": True})
        self.assertEqual(appels, ["plugin list --json"])

    def test_sans_claude_signale(self):
        (self.fake / "claude").unlink()
        sous_path = {"PATH": str(self.fake)}
        with mock.patch.dict(os.environ, sous_path):
            self.assertTrue(appliquer(("atelier-plugins", self.clone)))
        self.assertEqual(atelier.NOTES_APPLIQUEES, [("atelier-sans-claude",)])

    def _faux_claude(self, corps: str):
        """Remplace le faux claude par un script au corps donné."""
        (self.fake / "claude").write_text("#!/bin/sh\n" + corps + "\n", encoding="utf-8")

    def _regler(self, texte: str):
        """Écrit le settings.json du clone."""
        (self.clone / "claude").mkdir(parents=True, exist_ok=True)
        (self.clone / "claude" / "settings.json").write_text(texte, encoding="utf-8")

    def test_liste_en_echec_a_l_inspection_planifie(self):
        self._tout_poser()
        self._regler('{"enabledPlugins": {"a@m": true}}')
        self._faux_claude("exit 1")
        actions, erreurs = self._plan()
        self.assertEqual((erreurs, [a[0] for a in actions]), ([], ["atelier-plugins"]))

    def test_liste_en_echec_a_l_application_note(self):
        self._regler('{"enabledPlugins": {"a@m": true}}')
        self._faux_claude("echo pas json")
        self.assertTrue(appliquer(("atelier-plugins", self.clone)))
        self.assertEqual([n[0] for n in atelier.NOTES_APPLIQUEES], ["atelier-plugins-echec"])

    def test_installation_en_echec_note(self):
        self._regler('{"enabledPlugins": {"a@m": true}}')
        self._faux_claude('[ "$2" = list ] && echo "[]" && exit 0\nexit 1')
        self.assertTrue(appliquer(("atelier-plugins", self.clone)))
        self.assertEqual([n[0] for n in atelier.NOTES_APPLIQUEES], ["atelier-plugins-echec"])

    def test_settings_invalide_note(self):
        for texte in ("pas du json", '{"enabledPlugins": ["a"]}'):
            atelier.NOTES_APPLIQUEES.clear()
            self._regler(texte)
            self.assertTrue(appliquer(("atelier-plugins", self.clone)))
            self.assertEqual([n[0] for n in atelier.NOTES_APPLIQUEES], ["atelier-plugins-echec"], texte)

    def test_gitconfig_absent_cree_avec_inclusion(self):
        self._tout_poser()
        inclusion = str(self.clone / "git/gitconfig")
        self.assertEqual(self._git_global("--get-all", "include.path"), inclusion + "\n")
        self.assertEqual((self.home / ".gitconfig").read_text(encoding="utf-8").count("["), 1)

    def test_gitconfig_de_gh_garde(self):
        gh = '[credential "https://github.com"]\n\thelper = !/usr/bin/gh auth git-credential\n'
        (self.home / ".gitconfig").write_text(gh, encoding="utf-8")
        self._tout_poser()
        texte = (self.home / ".gitconfig").read_text(encoding="utf-8")
        self.assertTrue(texte.startswith(gh))
        self.assertEqual(texte.count("path = "), 1)
        self.assertNotIn("atelier-include", [a[0] for a in self._plan()[0]])

    def test_ordre(self):
        types = [a[0] for a in self._plan()[0]]
        self.assertEqual(types[:3], ["atelier-clone", "atelier-plugins", "atelier-include"])
        self.assertLess(types.index("atelier-include"), types.index("atelier-lien"))

    def _git_global(self, *args: str) -> str:
        """Lit la configuration git globale du HOME temporaire."""
        return subprocess.run(["git", "config", "--global", *args], check=True, capture_output=True, text=True).stdout

    def test_etat_sans_clone_vide(self):
        self.assertEqual(etat_atelier(ROOT), [])

    def test_etat_propre_vide(self):
        self._tout_poser()
        self.assertEqual(etat_atelier(ROOT), [])

    def test_etat_modifie(self):
        self._tout_poser()
        (self.clone / "claude" / "CLAUDE.md").write_text("changé\n", encoding="utf-8")
        (self.clone / "neuf.md").write_text("neuf\n", encoding="utf-8")
        etat = etat_atelier(ROOT)
        self.assertEqual(len(etat), 1, etat)
        self.assertIn("2 fichier(s)", etat[0])

    def test_etat_en_avance(self):
        self._tout_poser()
        (self.clone / "claude" / "CLAUDE.md").write_text("changé\n", encoding="utf-8")
        self._git("commit", "-qam", "avance")
        etat = etat_atelier(ROOT)
        self.assertEqual(len(etat), 1, etat)
        self.assertIn("1 commit(s)", etat[0])

    def test_etat_lien_devenu_fichier(self):
        self._tout_poser()
        dst = self._dst("claude/CLAUDE.md")
        dst.unlink()
        dst.write_text("fichier\n", encoding="utf-8")
        etat = etat_atelier(ROOT)
        self.assertEqual(len(etat), 1, etat)
        self.assertIn(str(dst), etat[0])

    def test_etat_ligne_de_commande(self):
        self._tout_poser()
        res = subprocess.run(["python3", str(ROOT / "atelier.py"), "--etat"], capture_output=True, text=True, env=os.environ)
        self.assertEqual((res.returncode, res.stdout), (0, ""), res.stderr)


def sha256_de(octets: bytes) -> str:
    """Somme SHA-256 d'un contenu en mémoire."""
    return hashlib.sha256(octets).hexdigest()


if __name__ == "__main__":
    unittest.main()
