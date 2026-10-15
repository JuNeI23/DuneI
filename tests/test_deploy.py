"""Déploiement — deploy.py dans un dossier de configuration temporaire, jamais dans celui de la session."""

import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from deploy import COPIES, config_home, plan

ROOT = Path(__file__).resolve().parent.parent
GENERIC = "-- Configuration générique de test.\n"
FOREIGN = "<?xml version=\"1.0\"?>\n<fontconfig/>\n"
# Faux sudo et faux systemctl : chaque appel est consigné dans $FAKE_LOG. sudo exécute la commande telle
# quelle, sauf si $FAKE_SUDO_FAIL est posé ; systemctl répond à is-enabled par $FAKE_ENABLED.
FAKES = {
    "sudo": '#!/bin/sh\necho "sudo $*" >> "$FAKE_LOG"\n[ -z "$FAKE_SUDO_FAIL" ] || exit 1\nexec "$@"\n',
    "systemctl": ('#!/bin/sh\necho "systemctl $*" >> "$FAKE_LOG"\n'
                  'case "$*" in *is-enabled*) echo "$FAKE_ENABLED"; [ "$FAKE_ENABLED" = enabled ] ;; esac\n'),
}
LOGIND = Path("etc/systemd/logind.conf.d/10-dunei.conf")
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
        t = Path(self.tmp.name)
        self.root, self.log, fake = t / "racine", t / "journal", t / "bin"
        fake.mkdir()
        for name, body in FAKES.items():
            (fake / name).write_text(body, encoding="utf-8")
            (fake / name).chmod(0o755)
        self.env = mock.patch.dict(os.environ, {"DUNEI_SYSROOT": str(self.root), "FAKE_LOG": str(self.log),
                                                "FAKE_ENABLED": "enabled", "PATH": f"{fake}:{os.environ['PATH']}"})
        self.env.start()

    def tearDown(self):
        self.env.stop()
        self.tmp.cleanup()

    def journal(self) -> list[str]:
        """Appels consignés par les faux sudo et systemctl."""
        return self.log.read_text().splitlines() if self.log.exists() else []

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
        self.assertEqual(os.readlink(self.hypr / "donnees"), str(ROOT / "config" / "hypr" / "donnees"))
        for name in COPIES:
            self.assertEqual((self.hypr / "generated" / name).read_bytes(), (ROOT / "generated" / name).read_bytes())
        self.assertEqual(self.fc.read_bytes(), (ROOT / "generated" / "fonts.conf").read_bytes())
        self.assertEqual((self.hypr / "hypridle.conf").read_bytes(), (ROOT / "generated" / "hypridle.conf").read_bytes())
        self.assertEqual(os.readlink(self.hypr / "hyprlock.conf"), str(ROOT / "config" / "hypr" / "hyprlock.conf"))
        self.assertEqual(os.readlink(self.hypr / "scripts"), str(ROOT / "config" / "hypr" / "scripts"))

    def test_copies_hyprland_files(self):
        """Hyprland lit ces quatre fichiers générés : un oubli dans COPIES casserait tout le point d'entrée."""
        self.assertEqual(set(COPIES), {"hyprland-tokens.lua", "hyprland-rules.lua", "hyprland-binds.lua", "motion.lua"})

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
                         ["donnees", "generated", "generique.lua", "hypridle.conf", "hyprland.lua", "hyprlock.conf", "machines",
                          "modules", "scripts"])
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

    def test_installs_system_file_with_sudo(self):
        res = run(self.cfg)
        self.assertEqual(res.returncode, 0, res.stderr)
        self.assertEqual((self.root / LOGIND).read_bytes(), (ROOT / "systeme" / LOGIND).read_bytes())
        self.assertIn("sudo systemctl reload systemd-logind", self.journal())

    def test_no_sudo_when_system_file_is_identical(self):
        run(self.cfg)
        self.log.unlink()
        res = run(self.cfg)
        self.assertEqual(res.returncode, 0, res.stderr)
        self.assertFalse([l for l in self.journal() if l.startswith("sudo")])

    def test_replaces_own_system_file(self):
        (self.root / LOGIND).parent.mkdir(parents=True)
        (self.root / LOGIND).write_text("# ancien\n# Posé par DuneI depuis systeme/\n[Login]\n", encoding="utf-8")
        self.assertEqual(run(self.cfg).returncode, 0)
        self.assertEqual((self.root / LOGIND).read_bytes(), (ROOT / "systeme" / LOGIND).read_bytes())

    def test_refuses_foreign_system_file(self):
        (self.root / LOGIND).parent.mkdir(parents=True)
        (self.root / LOGIND).write_text("[Login]\nHandlePowerKey=poweroff\n", encoding="utf-8")
        res = run(self.cfg)
        self.assertEqual(res.returncode, 1)
        self.assertIn("10-dunei.conf", res.stderr)
        self.assertEqual((self.root / LOGIND).read_text(), "[Login]\nHandlePowerKey=poweroff\n")
        self.assertFalse(any(l.startswith("sudo") for l in self.journal()))

    def test_sudo_failure_is_reported(self):
        with mock.patch.dict(os.environ, {"FAKE_SUDO_FAIL": "1"}):
            res = run(self.cfg)
        self.assertEqual(res.returncode, 1)
        self.assertIn("déploiement interrompu", res.stderr)
        self.assertNotIn("Traceback", res.stderr)

    def test_deploys_idle_files(self):
        self.assertEqual(run(self.cfg).returncode, 0)
        self.assertEqual((self.hypr / "hypridle.conf").read_bytes(), (ROOT / "generated" / "hypridle.conf").read_bytes())
        self.assertEqual(os.readlink(self.hypr / "hyprlock.conf"), str(ROOT / "config" / "hypr" / "hyprlock.conf"))
        self.assertEqual(os.readlink(self.hypr / "scripts"), str(ROOT / "config" / "hypr" / "scripts"))

    def test_refuses_foreign_hypridle_conf(self):
        self.hypr.mkdir(parents=True)
        (self.hypr / "hypridle.conf").write_text("general {\n}\n", encoding="utf-8")
        self.assert_refused("hypridle.conf")

    def test_enables_hypridle_when_disabled(self):
        with mock.patch.dict(os.environ, {"FAKE_ENABLED": "disabled"}):
            self.assertEqual(run(self.cfg).returncode, 0)
        self.assertIn("systemctl --user enable --now hypridle.service", self.journal())

    def test_restarts_hypridle_only_when_its_file_changes(self):
        run(self.cfg)
        self.assertIn("systemctl --user restart hypridle.service", self.journal())
        self.log.unlink()
        run(self.cfg)
        self.assertNotIn("systemctl --user restart hypridle.service", self.journal())

    def test_refuses_without_hypridle(self):
        before = snapshot(self.cfg)
        with mock.patch.dict(os.environ, {"FAKE_ENABLED": "not-found"}):
            res = run(self.cfg)
        self.assertEqual(res.returncode, 1)
        self.assertIn("pacman -S hypridle", res.stderr)
        self.assertEqual(snapshot(self.cfg), before)


if __name__ == "__main__":
    unittest.main()
