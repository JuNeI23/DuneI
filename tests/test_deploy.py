"""Déploiement — deploy.py dans un dossier de configuration temporaire, jamais dans celui de la session."""

import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from deploy import config_home, plan

ROOT = Path(__file__).resolve().parent.parent
GENERIC = "-- Configuration générique de test.\n"
FOREIGN = "<?xml version=\"1.0\"?>\n<fontconfig/>\n"
OLD_OWN = "<?xml version=\"1.0\"?>\n<!-- GÉNÉRÉ depuis tokens.toml — NE PAS MODIFIER À LA MAIN -->\n<fontconfig/>\n"


def run(cfg: Path, *args: str) -> subprocess.CompletedProcess:
    """Lance deploy.py avec XDG_CONFIG_HOME pointant sur un dossier temporaire."""
    env = {**os.environ, "XDG_CONFIG_HOME": str(cfg)}
    return subprocess.run([sys.executable, str(ROOT / "deploy.py"), *args],
                          capture_output=True, text=True, cwd=ROOT, env=env)


def snapshot(d: Path) -> dict:
    """État d'un dossier sans suivre les liens : chemin relatif → cible du lien, contenu ou « dossier »."""
    out = {}
    for root, dirs, files in os.walk(d):
        for name in dirs + files:
            p = Path(root) / name
            out[str(p.relative_to(d))] = (("lien", os.readlink(p)) if p.is_symlink()
                                          else ("dossier",) if p.is_dir() else ("fichier", p.read_bytes()))
    return out


class DeployTest(unittest.TestCase):
    """Comportement de la ligne de commande et de l'inspection."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.cfg = Path(self.tmp.name) / "cfg"
        self.hypr = self.cfg / "hypr"
        self.fc = self.cfg / "fontconfig" / "conf.d" / "50-dunei.conf"

    def tearDown(self):
        self.tmp.cleanup()

    def generic_machine(self):
        """Prépare une machine qui n'a que la configuration générique."""
        self.hypr.mkdir(parents=True)
        (self.hypr / "hyprland.lua").write_text(GENERIC, encoding="utf-8")

    def assert_refused(self, *words: str):
        """Vérifie un refus : code 1, mots attendus dans le message, destination intacte."""
        before = snapshot(self.cfg)
        res = run(self.cfg)
        self.assertEqual(res.returncode, 1, res.stdout)
        for w in words:
            self.assertIn(w, res.stderr)
        self.assertEqual(snapshot(self.cfg), before)

    def assert_deployed(self):
        """Vérifie les liens et les copies attendus."""
        self.assertEqual(os.readlink(self.hypr / "hyprland.lua"), str(ROOT / "config" / "hypr" / "hyprland.lua"))
        self.assertEqual(os.readlink(self.hypr / "modules"), str(ROOT / "config" / "hypr" / "modules"))
        self.assertEqual(os.readlink(self.hypr / "machines"), str(ROOT / "config" / "hypr" / "machines"))
        for name in ("hyprland-tokens.lua", "motion.lua"):
            self.assertEqual((self.hypr / "generated" / name).read_bytes(), (ROOT / "generated" / name).read_bytes())
        self.assertEqual(self.fc.read_bytes(), (ROOT / "generated" / "fonts.conf").read_bytes())

    def test_config_home(self):
        self.assertEqual(config_home({"XDG_CONFIG_HOME": "/x", "HOME": "/h"}), Path("/x"))
        self.assertEqual(config_home({"XDG_CONFIG_HOME": "", "HOME": "/h"}), Path("/h/.config"))
        self.assertEqual(config_home({"HOME": "/h"}), Path("/h/.config"))

    def test_fresh_machine(self):
        res = run(self.cfg)
        self.assertEqual(res.returncode, 0, res.stderr)
        self.assert_deployed()
        self.assertFalse((self.hypr / "generique.lua").exists())

    def test_switch(self):
        self.generic_machine()
        inode = (self.hypr / "hyprland.lua").stat().st_ino
        res = run(self.cfg)
        self.assertEqual(res.returncode, 0, res.stderr)
        self.assert_deployed()
        self.assertEqual((self.hypr / "generique.lua").read_text(encoding="utf-8"), GENERIC)
        self.assertEqual((self.hypr / "generique.lua").stat().st_ino, inode)
        self.assertEqual(sorted(p.name for p in self.hypr.iterdir()),
                         ["generated", "generique.lua", "hyprland.lua", "machines", "modules"])
        self.assertIn("hyprctl reload", res.stdout)

    def test_second_run_changes_nothing(self):
        self.generic_machine()
        run(self.cfg)
        before = snapshot(self.cfg)
        res = run(self.cfg)
        self.assertEqual(res.returncode, 0, res.stderr)
        self.assertEqual(snapshot(self.cfg), before)
        self.assertNotIn("lier", res.stdout)

    def test_leftover_temporary_link(self):
        self.generic_machine()
        (self.hypr / ".hyprland.lua.dunei").symlink_to("/inexistant")
        res = run(self.cfg)
        self.assertEqual(res.returncode, 0, res.stderr)
        self.assert_deployed()
        self.assertFalse((self.hypr / ".hyprland.lua.dunei").is_symlink())

    def test_refuses_real_modules_dir(self):
        self.generic_machine()
        (self.hypr / "modules").mkdir()
        self.assert_refused("modules")

    def test_refuses_real_machines_dir(self):
        self.generic_machine()
        (self.hypr / "machines").mkdir()
        self.assert_refused("machines")

    def test_refuses_foreign_machines_link(self):
        self.generic_machine()
        (self.hypr / "machines").symlink_to(Path(self.tmp.name) / "ailleurs")
        self.assert_refused("machines", "ailleurs")

    def test_refuses_foreign_link(self):
        self.hypr.mkdir(parents=True)
        (self.hypr / "hyprland.lua").symlink_to(Path(self.tmp.name) / "ailleurs.lua")
        self.assert_refused("hyprland.lua", "ailleurs.lua")

    def test_refuses_both_files(self):
        self.generic_machine()
        (self.hypr / "generique.lua").write_text(GENERIC, encoding="utf-8")
        self.assert_refused("generique.lua")

    def test_refuses_generated_link(self):
        self.generic_machine()
        (self.hypr / "generated").symlink_to(ROOT / "generated")
        self.assert_refused("generated")

    def test_refuses_legacy_conf(self):
        self.hypr.mkdir(parents=True)
        (self.hypr / "hyprland.conf").write_text("# Ancienne configuration hyprlang.\n", encoding="utf-8")
        self.assert_refused("hyprland.conf")

    def test_refuses_linked_worktree(self):
        repo = Path(self.tmp.name) / "arbre"
        repo.mkdir()
        (repo / ".git").write_text("gitdir: /ailleurs/.git/worktrees/arbre\n", encoding="utf-8")
        actions, err = plan(repo, self.cfg)
        self.assertTrue(any("arbre de travail" in e for e in err), err)

    def test_dry_run_changes_nothing(self):
        self.generic_machine()
        before = snapshot(self.cfg)
        res = run(self.cfg, "--dry-run")
        self.assertEqual(res.returncode, 0, res.stderr)
        self.assertIn("prévu", res.stdout)
        self.assertEqual(snapshot(self.cfg), before)

    def test_missing_source(self):
        actions, err = plan(Path(self.tmp.name) / "depot-vide", self.cfg)
        self.assertTrue(any("make tokens motion" in e for e in err), err)
        self.assertTrue(any("fonts.conf" in e for e in err), err)

    def test_replaces_own_file(self):
        self.fc.parent.mkdir(parents=True)
        self.fc.write_text(OLD_OWN, encoding="utf-8")
        res = run(self.cfg)
        self.assertEqual(res.returncode, 0, res.stderr)
        self.assert_deployed()

    def test_keeps_user_fontconfig_files(self):
        self.fc.parent.mkdir(parents=True)
        user = {self.cfg / "fontconfig" / "fonts.conf": FOREIGN, self.fc.parent / "99-perso.conf": FOREIGN}
        for p, text in user.items():
            p.write_text(text, encoding="utf-8")
        res = run(self.cfg)
        self.assertEqual(res.returncode, 0, res.stderr)
        for p, text in user.items():
            self.assertEqual(p.read_text(encoding="utf-8"), text)

    def test_refuses_foreign_fontconfig_file(self):
        self.fc.parent.mkdir(parents=True)
        self.fc.write_text(FOREIGN, encoding="utf-8")
        self.assert_refused("50-dunei.conf")

    def test_refuses_fontconfig_link(self):
        self.fc.parent.mkdir(parents=True)
        self.fc.symlink_to(ROOT / "generated" / "fonts.conf")
        self.assert_refused("50-dunei.conf")

    def test_refuses_fontconfig_not_a_dir(self):
        self.cfg.mkdir()
        (self.cfg / "fontconfig").write_text("", encoding="utf-8")
        self.assert_refused("fontconfig")

    def test_refuses_conf_d_not_a_dir(self):
        (self.cfg / "fontconfig").mkdir(parents=True)
        (self.cfg / "fontconfig" / "conf.d").write_text("", encoding="utf-8")
        self.assert_refused("conf.d")

    def test_refuses_conf_d_link(self):
        (self.cfg / "fontconfig").mkdir(parents=True)
        (self.cfg / "fontconfig" / "conf.d").symlink_to(Path(self.tmp.name))
        self.assert_refused("conf.d")

    def test_fontconfig_refusal_blocks_hypr(self):
        self.generic_machine()
        self.fc.parent.mkdir(parents=True)
        self.fc.write_text(FOREIGN, encoding="utf-8")
        self.assert_refused("50-dunei.conf")
        self.assertEqual((self.hypr / "hyprland.lua").read_text(encoding="utf-8"), GENERIC)

    def test_hypr_refusal_blocks_fontconfig(self):
        self.generic_machine()
        (self.hypr / "modules").mkdir()
        self.assert_refused("modules")
        self.assertFalse((self.cfg / "fontconfig").exists())


if __name__ == "__main__":
    unittest.main()
