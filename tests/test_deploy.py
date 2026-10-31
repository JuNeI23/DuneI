"""Déploiement — deploy.py dans un dossier de configuration temporaire, jamais dans celui de la session."""

import contextlib
import hashlib
import io
import os
import pwd
import subprocess
import sys
import tarfile
import tempfile
import unittest
from pathlib import Path
from unittest import mock

import deploy
from deploy import COPIES, config_home, lire_session, plan

ROOT = Path(__file__).resolve().parent.parent
# core.hooksPath déjà effectif par l'environnement : le déploiement n'écrit jamais dans la configuration du vrai dépôt.
CROCHETS_POSES = {"GIT_CONFIG_COUNT": "1", "GIT_CONFIG_KEY_0": "core.hooksPath", "GIT_CONFIG_VALUE_0": ".githooks"}
GENERIC = "-- Configuration générique de test.\n"
FOREIGN = "<?xml version=\"1.0\"?>\n<fontconfig/>\n"
# Faux sudo et faux systemctl : chaque appel est consigné dans $FAKE_LOG. sudo exécute la commande telle
# quelle, sauf si $FAKE_SUDO_FAIL est posé ; systemctl répond à is-enabled par $FAKE_ENABLED et à
# is-active par $FAKE_ACTIVE (« active » par défaut). gh (non connecté), hyprlock, greetd, tuigreet, kitty, checkupdates,
# paccache, pacdiff et informant sont de faux exécutables vides.
FAKES = {
    "sudo": '#!/bin/sh\necho "sudo $*" >> "$FAKE_LOG"\n[ -z "$FAKE_SUDO_FAIL" ] || exit 1\nexec "$@"\n',
    "systemctl": ('#!/bin/sh\necho "systemctl $*" >> "$FAKE_LOG"\n'
                  'case "$*" in *is-enabled*) echo "$FAKE_ENABLED"; [ "$FAKE_ENABLED" = enabled ] ;;\n'
                  '*is-active*) [ "${FAKE_ACTIVE:-active}" = active ] ;; esac\n'),
    "gh": "#!/bin/sh\nexit 1\n",  # Non connecté : la destination atelier se contente de sa note.
    # gsettings : get répond toujours 'Adwaita' ; set est consigné dans $FAKE_LOG.gsettings, jamais exécuté pour de bon.
    "gsettings": '#!/bin/sh\n[ "$1" = get ] && echo "\'Adwaita\'" || echo "gsettings $*" >> "$FAKE_LOG.gsettings"\n',
    "hyprlock": "#!/bin/sh\n",
    "greetd": "#!/bin/sh\n",
    "tuigreet": "#!/bin/sh\n",
    "kitty": "#!/bin/sh\n",
    "checkupdates": "#!/bin/sh\n",
    "fakeroot": "#!/bin/sh\n",
    "paccache": "#!/bin/sh\n",
    "pacdiff": "#!/bin/sh\n",
    "informant": "#!/bin/sh\n",
}
MASQUE = Path("systemd/user/wayland-session-xdg-autostart@.target")
LOGIND = Path("etc/systemd/logind.conf.d/10-dunei.conf")
GREETD = Path("etc/greetd/dunei.toml")
GREETD_DROPIN = Path("etc/systemd/system/greetd.service.d/10-dunei.conf")
DM = Path("etc/systemd/system/display-manager.service")
OLD_OWN = "<?xml version=\"1.0\"?>\n<!-- GÉNÉRÉ depuis tokens.toml — NE PAS MODIFIER À LA MAIN -->\n<fontconfig/>\n"


def faux_atelier(t: Path, somme_archive: str | None = None) -> Path:
    """Prépare un atelier de test : archive rtk factice, atelier.toml pointant dessus par file://.

    Entrées : t — dossier temporaire ; somme_archive — somme épinglée, celle de l'archive si absente.
    Sortie : chemin du atelier.toml. Le binaire factice est déjà posé dans t/local-bin avec la somme
    épinglée : par défaut, aucun test n'agit sur rtk. Erreurs : OSError. Dépendances : tarfile, hashlib.
    """
    binaire, archive, toml = b"#!/bin/sh\n", t / "source" / "rtk-test.tar.gz", t / "atelier.toml"
    archive.parent.mkdir(parents=True, exist_ok=True)
    with tarfile.open(archive, "w:gz") as tar:
        info = tarfile.TarInfo("rtk")
        info.size = len(binaire)
        tar.addfile(info, io.BytesIO(binaire))
    somme = lambda b: hashlib.sha256(b).hexdigest()
    toml.write_text(
        f'[rtk]\nversion = "9.9.9"\narchive = "rtk-test.tar.gz"\nurl = "file://{archive}"\n'
        f'sha256_archive = "{somme_archive or somme(archive.read_bytes())}"\nsha256_binaire = "{somme(binaire)}"\n'
        '[atelier]\ndepot = "x/y"\nclone = "~/c"\ngitconfig = "g"\n[atelier.liens]\n"a" = "~/a"\n', encoding="utf-8")
    (t / "local-bin").mkdir(exist_ok=True)
    (t / "local-bin" / "rtk").write_bytes(binaire)
    return toml


def run(cfg: Path, *args: str) -> subprocess.CompletedProcess:
    """Lance deploy.py avec des dossiers temporaires : XDG_CONFIG_HOME, XDG_BIN_HOME, XDG_DATA_HOME, XDG_CACHE_HOME, HOME,
    GIT_CONFIG_GLOBAL et GIT_CONFIG_SYSTEM (git ignore la configuration réelle), CROCHETS_POSES et un atelier.toml de test (DUNEI_ATELIER_TOML) — ni le réseau ni le vrai ~ ne sont touchés."""
    t = cfg.parent
    env = {**os.environ, "XDG_CONFIG_HOME": str(cfg), "XDG_BIN_HOME": str(t / "local-bin"),
           "XDG_DATA_HOME": str(t / "data"), "XDG_CACHE_HOME": str(t / "cache"), "HOME": str(t / "home"), "DUNEI_ATELIER_TOML": str(t / "atelier.toml"),
           "GIT_CONFIG_GLOBAL": "/dev/null", "GIT_CONFIG_SYSTEM": "/dev/null", **CROCHETS_POSES}
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
        self.kitty = self.cfg / "kitty" / "kitty.conf"
        self.bin = Path(self.tmp.name) / "local-bin"
        t = Path(self.tmp.name)
        self.root, self.log, fake = t / "racine", t / "journal", t / "bin"
        fake.mkdir()
        for name, body in FAKES.items():
            (fake / name).write_text(body, encoding="utf-8")
            (fake / name).chmod(0o755)
        self.fake = fake
        faux_atelier(t)
        self.env = mock.patch.dict(os.environ, {"DUNEI_SYSROOT": str(self.root), "XDG_BIN_HOME": str(self.bin), "FAKE_LOG": str(self.log),
                                                "XDG_DATA_HOME": str(t / "data"),
                                                "XDG_CACHE_HOME": str(t / "cache"), "HOME": str(t / "home"),
                                                "DUNEI_ATELIER_TOML": str(t / "atelier.toml"),
                                                "FAKE_ENABLED": "enabled", "PATH": f"{fake}:{os.environ['PATH']}", **CROCHETS_POSES})
        self.env.start()
        (self.root / DM).parent.mkdir(parents=True)
        (self.root / DM).symlink_to("/usr/lib/systemd/system/greetd.service")
        (self.root / "etc/ufw").mkdir(parents=True)
        (self.root / "etc/ufw/ufw.conf").write_text("ENABLED=yes\n", encoding="utf-8")  # Pare-feu déjà allumé : socle sans action ufw.

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
        self.assertEqual(os.readlink(self.kitty), str(ROOT / "config" / "kitty" / "kitty.conf"))

    def test_copies_hyprland_files(self):
        """Hyprland lit ces cinq fichiers générés : un oubli dans COPIES casserait tout le point d'entrée."""
        self.assertEqual(set(COPIES), {"hyprland-tokens.lua", "hyprland-rules.lua", "hyprland-layers.lua", "hyprland-binds.lua", "motion.lua", "energie.lua"})
        # Les fichiers que requiert un module lié (energie.lua, hyprland-layers.lua par regles.lua) passent avant
        # ceux dont la copie déclenche une recharge de Hyprland.
        self.assertEqual(COPIES[:2], ("energie.lua", "hyprland-layers.lua"))

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
        self.assertNotIn("fait : lier", res.stdout)

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

    def test_refuses_script_not_executable(self):
        script = ROOT / "config" / "hypr" / "scripts" / "dunei-verrou-initial"
        real, err = os.access, io.StringIO()
        before = snapshot(self.cfg)
        with (mock.patch("deploy.os.access", lambda p, m: real(p, m) and Path(p) != script),
              mock.patch.dict(os.environ, {"XDG_CONFIG_HOME": str(self.cfg)}),
              mock.patch.object(sys, "argv", ["deploy.py"]), contextlib.redirect_stderr(err)):
            self.assertEqual(deploy.main(), 1)
        self.assertIn(f"{script} n'est pas exécutable : chmod 755 {script}", err.getvalue())
        self.assertEqual(snapshot(self.cfg), before)
        self.assertFalse([l for l in self.journal() if l.startswith("sudo")])

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

    def test_keeps_other_kitty_files(self):
        self.kitty.parent.mkdir(parents=True)
        theme = self.kitty.parent / "theme.conf"
        theme.write_text("# perso\n", encoding="utf-8")
        self.assertEqual(run(self.cfg).returncode, 0)
        self.assertEqual(theme.read_text(encoding="utf-8"), "# perso\n")
        self.assert_deployed()

    def test_refuses_foreign_kitty_file(self):
        self.kitty.parent.mkdir(parents=True)
        self.kitty.write_text("font_size 14\n", encoding="utf-8")
        self.assert_refused("kitty.conf")

    def test_refuses_foreign_kitty_link(self):
        self.kitty.parent.mkdir(parents=True)
        self.kitty.symlink_to(Path(self.tmp.name))
        self.assert_refused("kitty.conf")

    def test_refuses_kitty_not_a_dir(self):
        self.cfg.mkdir()
        (self.cfg / "kitty").symlink_to(Path(self.tmp.name))
        self.assert_refused("kitty")

    def test_refuses_kitty_file(self):
        self.cfg.mkdir()
        (self.cfg / "kitty").write_text("", encoding="utf-8")
        self.assert_refused("kitty")

    def test_refuses_without_kitty(self):
        (self.fake / "kitty").unlink()
        before = snapshot(self.cfg)
        res = self.deploy_with_path(f"{self.fake}:/nonexistent")
        self.assertEqual(res.returncode, 1)
        self.assertIn("kitty introuvable", res.stderr)
        self.assertEqual(snapshot(self.cfg), before)

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
        self.assertIn("seuls les fichiers système restent à poser", res.stderr)
        self.assertIn("systemctl --user restart hypridle.service", self.journal())

    def test_deploys_idle_files(self):
        self.assertEqual(run(self.cfg).returncode, 0)
        self.assertEqual((self.hypr / "hypridle.conf").read_bytes(), (ROOT / "generated" / "hypridle.conf").read_bytes())
        self.assertEqual(os.readlink(self.hypr / "hyprlock.conf"), str(ROOT / "config" / "hypr" / "hyprlock.conf"))
        self.assertEqual(os.readlink(self.hypr / "scripts"), str(ROOT / "config" / "hypr" / "scripts"))

    def test_refuses_foreign_hypridle_conf(self):
        self.hypr.mkdir(parents=True)
        (self.hypr / "hypridle.conf").write_text("general {\n}\n", encoding="utf-8")
        self.assert_refused("hypridle.conf")

    def test_bin_lie_dunei_maj(self):
        self.assertEqual(run(self.cfg).returncode, 0)
        self.assertEqual(os.readlink(self.bin / "dunei-maj"), str(ROOT / "config" / "bin" / "dunei-maj"))

    def test_bin_fichier_etranger_refuse(self):
        self.bin.mkdir(exist_ok=True)
        (self.bin / "dunei-maj").write_text("#!/bin/sh\n", encoding="utf-8")
        before = snapshot(self.bin)
        res = run(self.cfg)
        self.assertEqual(res.returncode, 1, res.stdout)
        self.assertIn("dunei-maj", res.stderr)
        self.assertEqual(snapshot(self.bin), before)
        self.assertFalse(self.cfg.exists())

    def test_bin_hors_du_path_avertit_sans_bloquer(self):
        res = run(self.cfg, "--dry-run")
        self.assertEqual(res.returncode, 0, res.stderr)
        self.assertIn(f"attention : {self.bin} n'est pas encore dans le PATH de cette session", res.stdout)
        self.assertIn("dunei-bin.sh l'y met", res.stdout)

    def test_bin_dans_le_path_sans_avertissement(self):
        with mock.patch.dict(os.environ, {"PATH": f"{self.bin}{os.pathsep}{os.environ['PATH']}"}):
            res = run(self.cfg, "--dry-run")
        self.assertEqual(res.returncode, 0, res.stderr)
        self.assertNotIn("n'est pas encore dans le PATH", res.stdout)

    def test_bin_non_executable_refuse(self):
        repo = Path(self.tmp.name) / "depot"
        (repo / "config" / "bin").mkdir(parents=True)
        script = repo / "config" / "bin" / "dunei-maj"
        script.write_text("#!/bin/sh\n", encoding="utf-8")
        script.chmod(0o644)
        actions, err = deploy.plan_bin(repo, self.cfg)
        self.assertEqual(len(err), 1)
        self.assertIn("n'est pas exécutable", err[0])
        self.assertIn(str(script), err[0])

    def test_maj_outil_absent(self):
        (self.fake / "pacdiff").unlink()
        res = self.deploy_with_path(f"{self.fake}:/nonexistent")
        self.assertEqual(res.returncode, 1, res.stdout)
        self.assertIn("pacdiff introuvable", res.stderr)
        self.assertIn("pacman-contrib", res.stderr)

    def test_maj_active_le_minuteur(self):
        with mock.patch.dict(os.environ, {"FAKE_ENABLED": "disabled"}):
            self.assertEqual(run(self.cfg).returncode, 0)
        self.assertIn("sudo systemctl enable --now dunei-precharge.timer", self.journal())

    def test_maj_minuteur_deja_actif(self):
        self.assertEqual(run(self.cfg).returncode, 0)
        self.assertNotIn("sudo systemctl enable --now dunei-precharge.timer", self.journal())

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

    def test_dropin_deployed_then_reload_precedes_restart(self):
        self.assertEqual(run(self.cfg).returncode, 0)
        dropin = self.cfg / "systemd/user/hypridle.service.d/10-dunei.conf"
        self.assertIn("ExecStart=/usr/bin/hypridle --quiet", dropin.read_text(encoding="utf-8"))
        calls = [l for l in self.journal() if l.startswith("systemctl --user") and "is-" not in l]
        self.assertEqual(calls, ["systemctl --user daemon-reload", "systemctl --user restart hypridle.service",
                                 "systemctl --user restart nm-applet.service",
                                 "systemctl --user restart dunei-coque.service"])
        self.log.unlink()
        self.assertEqual(run(self.cfg).returncode, 0)
        self.assertEqual([l for l in self.journal() if "is-" not in l], [])

    def write_session(self, body: str) -> Path:
        """Dépôt factice : copie du dépôt réel limitée à session.toml, pour lire_session."""
        repo = Path(self.tmp.name) / "depot"
        repo.mkdir(exist_ok=True)
        (repo / "session.toml").write_text(body, encoding="utf-8")
        return repo

    def test_session_real_list(self):
        self.assertEqual(lire_session(ROOT), (["hypridle.service", "nm-applet.service", "dunei-coque.service"], []))

    def test_session_refusals(self):
        for body, word in (('version = "0.1.0"\n[demarrage]\nservices = []\n', "non vide"),
                           ('version = "0.1.0"\n[demarrage]\nservices = ["nm-applet"]\n', "nm-applet"),
                           ('version = "0.1.0"\n[demarrage]\nservices = ["a.service", "a.service"]\n', "deux fois"),
                           ('version = "9"\n[demarrage]\nservices = ["a.service"]\n', "version"),
                           ("services = [\n", "illisible")):
            with self.subTest(attendu=word):
                services, err = lire_session(self.write_session(body))
                self.assertEqual(services, [])
                self.assertTrue(any(word in e for e in err), err)

    def test_masks_xdg_autostart_once(self):
        self.assertEqual(run(self.cfg).returncode, 0)
        self.assertEqual(os.readlink(self.cfg / MASQUE), "/dev/null")
        self.log.unlink()
        self.assertEqual(run(self.cfg).returncode, 0)
        self.assertNotIn("systemctl --user daemon-reload", self.journal())

    def test_refuses_foreign_mask_path(self):
        (self.cfg / MASQUE).parent.mkdir(parents=True)
        (self.cfg / MASQUE).write_text("[Unit]\n", encoding="utf-8")
        self.assert_refused("autostart")

    def test_deploys_and_enables_nm_applet(self):
        with mock.patch.dict(os.environ, {"FAKE_ENABLED": "disabled"}):
            self.assertEqual(run(self.cfg).returncode, 0)
        unit = self.cfg / "systemd/user/nm-applet.service"
        self.assertEqual(unit.read_bytes(), (ROOT / "config/systemd/user/nm-applet.service").read_bytes())
        calls = [l for l in self.journal() if l.startswith("systemctl --user") and "is-" not in l]
        self.assertEqual(calls[0], "systemctl --user daemon-reload")
        self.assertIn("systemctl --user enable --now nm-applet.service", calls)

    def test_reports_unit_outside_list(self):
        wants = self.cfg / "systemd/user/graphical-session.target.wants"
        wants.mkdir(parents=True)
        (wants / "waybar.service").symlink_to("/usr/lib/systemd/user/waybar.service")
        res = run(self.cfg)
        self.assertEqual(res.returncode, 0, res.stderr)
        self.assertIn("attention", res.stdout)
        self.assertIn("waybar.service", res.stdout)
        self.assertTrue((wants / "waybar.service").is_symlink())

    def test_dropin_change_triggers_reload_and_restart(self):
        run(self.cfg)
        dropin = self.cfg / "systemd/user/hypridle.service.d/10-dunei.conf"
        dropin.write_text("# a\n# Posé par DuneI\n", encoding="utf-8")
        self.log.unlink()
        run(self.cfg)
        self.assertEqual([l for l in self.journal() if "is-" not in l],
                         ["systemctl --user daemon-reload", "systemctl --user restart hypridle.service"])

    def test_refuses_foreign_dropin(self):
        d = self.cfg / "systemd/user/hypridle.service.d"
        d.mkdir(parents=True)
        (d / "10-dunei.conf").write_text("[Service]\nExecStart=\n", encoding="utf-8")
        self.assert_refused("10-dunei.conf")

    def test_refuses_without_hyprlock(self):
        (self.fake / "hyprlock").unlink()
        before = snapshot(self.cfg)
        with mock.patch.dict(os.environ, {"PATH": f"{self.fake}:/nonexistent"}):
            res = subprocess.run(["/usr/bin/python3", str(ROOT / "deploy.py")], capture_output=True, text=True,
                                 cwd=ROOT, env={**os.environ, "XDG_CONFIG_HOME": str(self.cfg)})
        self.assertEqual(res.returncode, 1)
        self.assertIn("hyprlock", res.stderr)
        self.assertEqual(snapshot(self.cfg), before)

    def test_starts_hypridle_when_enabled_but_inactive(self):
        run(self.cfg)
        self.log.unlink()
        with mock.patch.dict(os.environ, {"FAKE_ACTIVE": "inactive"}):
            self.assertEqual(run(self.cfg).returncode, 0)
        self.assertIn("systemctl --user start hypridle.service", self.journal())

    def test_refuses_without_hypridle(self):
        before = snapshot(self.cfg)
        with mock.patch.dict(os.environ, {"FAKE_ENABLED": "not-found"}):
            res = run(self.cfg)
        self.assertEqual(res.returncode, 1)
        self.assertIn("hypridle.service introuvable", res.stderr)
        self.assertEqual(snapshot(self.cfg), before)

    def deploy_with_path(self, path: str) -> subprocess.CompletedProcess:
        """Lance deploy.py avec un PATH imposé, par l'interpréteur système (python3 hors du PATH)."""
        with mock.patch.dict(os.environ, {"PATH": path}):
            return subprocess.run(["/usr/bin/python3", str(ROOT / "deploy.py")], capture_output=True, text=True,
                                  cwd=ROOT, env={**os.environ, "XDG_CONFIG_HOME": str(self.cfg)})

    def test_greetd_file_names_the_user(self):
        self.assertEqual(run(self.cfg).returncode, 0)
        text = (self.root / GREETD).read_text(encoding="utf-8")
        self.assertIn(f'user = "{pwd.getpwuid(os.getuid()).pw_name}"', text)
        self.assertNotIn("{utilisateur}", text)
        self.assertIn("sudo systemctl daemon-reload", self.journal())

    def test_filled_file_is_compared_filled(self):
        run(self.cfg)
        self.log.unlink()
        self.assertEqual(run(self.cfg).returncode, 0)
        self.assertFalse([l for l in self.journal() if l.startswith("sudo")])

    def test_switches_from_sddm(self):
        (self.root / DM).unlink()
        (self.root / DM).symlink_to("/usr/lib/systemd/system/sddm.service")
        self.assertEqual(run(self.cfg).returncode, 0)
        sudo = [l for l in self.journal() if l.startswith("sudo systemctl")]
        self.assertEqual(sudo[-1], "sudo systemctl enable --force greetd.service")
        self.assertFalse([l for l in self.journal() if "disable" in l])
        copies = [i for i, l in enumerate(self.journal()) if l.startswith("sudo install")]
        self.assertLess(max(copies), self.journal().index("sudo systemctl enable --force greetd.service"))

    def test_no_switch_when_greetd_is_active(self):
        self.assertEqual(run(self.cfg).returncode, 0)
        self.assertFalse([l for l in self.journal() if "enable greetd" in l or "disable" in l])

    def test_enables_greetd_without_previous_manager(self):
        (self.root / DM).unlink()
        self.assertEqual(run(self.cfg).returncode, 0)
        self.assertIn("sudo systemctl enable --force greetd.service", self.journal())
        self.assertFalse([l for l in self.journal() if "disable" in l])

    def test_refuses_without_greetd(self):
        (self.fake / "greetd").unlink()
        before = snapshot(self.cfg)
        res = self.deploy_with_path(f"{self.fake}:/nonexistent")
        self.assertEqual(res.returncode, 1)
        self.assertIn("pacman -S --needed greetd greetd-tuigreet", res.stderr)
        self.assertEqual(snapshot(self.cfg), before)

    def test_refuses_without_tuigreet(self):
        (self.fake / "tuigreet").unlink()
        res = self.deploy_with_path(f"{self.fake}:/nonexistent")
        self.assertEqual(res.returncode, 1)
        self.assertIn("tuigreet", res.stderr)

    def test_refuses_foreign_greetd_file(self):
        (self.root / GREETD).parent.mkdir(parents=True)
        (self.root / GREETD).write_text("[terminal]\nvt = 1\n", encoding="utf-8")
        res = run(self.cfg)
        self.assertEqual(res.returncode, 1)
        self.assertIn("dunei.toml", res.stderr)

    def test_refuses_masked_display_manager(self):
        (self.root / DM).unlink()
        (self.root / DM).symlink_to("/dev/null")
        res = run(self.cfg)
        self.assertEqual(res.returncode, 1)
        self.assertIn("display-manager.service", res.stderr)
        self.assertFalse([l for l in self.journal() if l.startswith("sudo")])

    def test_install_pose_rtk(self):
        (self.bin / "rtk").unlink()
        res = run(self.cfg)
        self.assertEqual(res.returncode, 0, res.stderr)
        self.assertTrue(os.access(self.bin / "rtk", os.X_OK))

    def test_install_refuse_archive_fausse(self):
        faux_atelier(Path(self.tmp.name), somme_archive="0" * 64)
        (self.bin / "rtk").unlink()
        before = snapshot(self.cfg)
        res = run(self.cfg)
        self.assertEqual(res.returncode, 1, res.stdout)
        self.assertIn("rien n'a été modifié", res.stderr)
        self.assertFalse((self.bin / "rtk").exists())
        self.assertEqual(snapshot(self.cfg), before)

    def test_ligne_atelier_du_bilan(self):
        sortie = io.StringIO()
        with mock.patch.dict(os.environ, {"XDG_CONFIG_HOME": str(self.cfg)}), \
                mock.patch.object(sys, "argv", ["deploy.py", "--dry-run"]), \
                mock.patch.object(deploy.atelier, "etat_atelier", return_value=["2 fichier(s) à envoyer"]), \
                contextlib.redirect_stdout(sortie):
            self.assertEqual(deploy.main(), 0)
        self.assertIn("  atelier : 2 fichier(s) à envoyer", sortie.getvalue())

    def test_interruption_affiche_les_notes_appliquees(self):
        erreur = io.StringIO()
        deploy.atelier.NOTES_APPLIQUEES[:] = [("atelier-repris", Path("/x/y"))]
        self.addCleanup(deploy.atelier.NOTES_APPLIQUEES.clear)
        with mock.patch.dict(os.environ, {"XDG_CONFIG_HOME": str(self.cfg)}), \
                mock.patch.object(sys, "argv", ["deploy.py"]), \
                mock.patch.object(deploy, "apply", side_effect=OSError("disque plein")), \
                contextlib.redirect_stderr(erreur):
            self.assertEqual(deploy.main(), 1)
        self.assertIn("/x/y", erreur.getvalue())

    def test_refuses_root(self):
        with mock.patch("os.getuid", return_value=0):
            actions, err = plan(ROOT, self.cfg)
        self.assertTrue(any("root" in e for e in err))


class SocleTest(unittest.TestCase):
    """Services système de services.toml : activation et pare-feu (L1-25), état de systemd simulé."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.env = mock.patch.dict(os.environ, {"DUNEI_SYSROOT": str(self.root)})
        self.env.start()
        self.repo = self.root / "depot"
        self.repo.mkdir()
        self.ecrire(deploy.SOCLE_VERSION, ["ufw.service", "fstrim.timer", "cups.socket"])
        self.ufw("yes")

    def tearDown(self):
        self.env.stop()
        self.tmp.cleanup()

    def ecrire(self, version, unites):
        """Écrit services.toml dans le dépôt factice."""
        liste = ", ".join(f'"{u}"' for u in unites)
        (self.repo / deploy.SOCLE).write_text(f'version = "{version}"\n[systeme]\nunites = [{liste}]\n', encoding="utf-8")

    def ufw(self, valeur):
        """Écrit etc/ufw/ufw.conf sous la racine factice."""
        conf = self.root / "etc/ufw/ufw.conf"
        conf.parent.mkdir(parents=True, exist_ok=True)
        conf.write_text(f"ENABLED={valeur}\n", encoding="utf-8")

    def plan(self, etat):
        """Planifie avec _etat_systeme simulé, qui répond etat pour toute unité."""
        with mock.patch("deploy._etat_systeme", return_value=etat):
            return deploy.plan_socle(self.repo, self.root)

    def test_active_unite_inactive(self):
        actions, err = self.plan(("disabled", False))
        self.assertEqual(err, [])
        self.assertIn(("sudo-enable", "fstrim.timer"), actions)

    def test_unite_active_rien(self):
        self.assertEqual(self.plan(("enabled", True)), ([], []))

    def test_unite_introuvable(self):
        actions, err = self.plan(("not-found", False))
        self.assertTrue(any("fstrim.timer" in e and "paquets.toml" in e for e in err))

    def test_pare_feu_eteint(self):
        self.ufw("no")
        actions, err = self.plan(("disabled", False))
        self.assertIn(("sudo-ufw",), actions)
        self.assertLess(actions.index(("sudo-enable", "ufw.service")), actions.index(("sudo-ufw",)))

    def test_liste_fautive(self):
        for version, unites in (("9.9.9", ["ufw.service"]), (deploy.SOCLE_VERSION, []),
                                (deploy.SOCLE_VERSION, ["ufw"]), (deploy.SOCLE_VERSION, ["ufw.service", "ufw.service"])):
            with self.subTest(version=version, unites=unites):
                self.ecrire(version, unites)
                actions, err = self.plan(("disabled", False))
                self.assertEqual((actions, len(err)), ([], 1))


class ProfilBinTest(unittest.TestCase):
    """Le fichier profile.d de DuneI ajoute ~/.local/bin au PATH, une seule fois, en fin de liste."""

    def chemin(self, **env):
        """Source deux fois dunei-bin.sh sous sh avec un environnement maîtrisé. Entrées : variables à poser en plus de HOME et PATH. Sortie : le PATH obtenu. Erreurs : échec du test si sh échoue. Dépendances : sh."""
        script = ROOT / "systeme/etc/profile.d/dunei-bin.sh"
        res = subprocess.run(["sh", "-c", f'. {script}; . {script}; echo "$PATH"'], capture_output=True, text=True,
                             env={"HOME": "/h", "PATH": "/usr/bin", **env})
        self.assertEqual(res.returncode, 0, res.stderr)
        return res.stdout.strip()

    def test_profil_bin(self):
        self.assertEqual(self.chemin(), "/usr/bin:/h/.local/bin")
        self.assertEqual(self.chemin(XDG_BIN_HOME="/x"), "/usr/bin:/x")


class CrochetsTest(unittest.TestCase):
    """make install active les crochets du dépôt : core.hooksPath posé, laissé, ou valeur étrangère refusée."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.repo = Path(self.tmp.name)
        self.env = mock.patch.dict(os.environ, {"GIT_CONFIG_GLOBAL": "/dev/null", "GIT_CONFIG_SYSTEM": "/dev/null"})
        self.env.start()
        subprocess.run(["git", "init", "-q", str(self.repo)], check=True)

    def tearDown(self):
        self.env.stop()
        self.tmp.cleanup()

    def poser(self, valeur: str):
        """Écrit core.hooksPath dans la configuration locale du dépôt jetable."""
        subprocess.run(["git", "-C", str(self.repo), "config", "--local", "core.hooksPath", valeur], check=True)

    def test_absent_pose(self):
        actions, err = deploy.plan_crochets(self.repo, self.repo)
        self.assertEqual((actions, err), ([("crochets", self.repo)], []))
        deploy.apply(actions)
        lu = subprocess.run(["git", "-C", str(self.repo), "config", "--local", "core.hooksPath"], capture_output=True, text=True)
        self.assertEqual(lu.stdout.strip(), ".githooks")

    def test_deja_pose_rien(self):
        self.poser(".githooks")
        self.assertEqual(deploy.plan_crochets(self.repo, self.repo), ([], []))

    def test_valeur_etrangere_refusee(self):
        self.poser("/ailleurs")
        actions, err = deploy.plan_crochets(self.repo, self.repo)
        self.assertEqual((actions, len(err)), ([], 1))
        self.assertIn("/ailleurs", err[0])
        self.assertIn("core.hooksPath", err[0])

    def test_describe(self):
        self.assertIn(".githooks", deploy.describe(("crochets", self.repo)))

    def test_git_absent_message(self):
        with mock.patch("deploy.shutil.which", return_value=None):
            self.assertEqual(deploy.plan_crochets(self.repo, self.repo), ([], ["git introuvable : pacman -S git"]))


class CoqueTest(unittest.TestCase):
    """Les tokens et le shader de la coque sont copiés sous <config>/dunei/, où la coque les lit (L2-34, L2-04)."""

    def setUp(self):
        """Prépare un dépôt et un dossier de configuration jetables, avec les fichiers générés de COQUE. Entrées : aucune. Sortie : aucune. Erreurs : aucune. Dépendances : tempfile."""
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.repo, self.cfg = Path(self.tmp.name) / "repo", Path(self.tmp.name) / "cfg"
        (self.repo / "generated").mkdir(parents=True)
        self.cfg.mkdir()
        for nom, marque, _ in deploy.COQUE:
            (self.repo / "generated" / nom).write_text(f'{{\n  "_generated": "{marque}",\n  "bureau": {{"fond": "#0f0703"}}\n}}\n', encoding="utf-8")
        (self.repo / "coque").mkdir()
        self.copies = [("copy", self.repo / "generated" / nom, self.cfg / "dunei" / nom) for nom, _, _ in deploy.COQUE]
        self.bureau = self.cfg / "dunei" / "bureau.json"
        self.ecrire = ("ecrire", self.bureau, '{"origine": "theme", "fond": "#0f0703"}\n')
        self.lien = [("mkdir", self.cfg / "quickshell"), ("link", self.repo / "coque", self.cfg / "quickshell" / "dunei")]

    def poser_bureau(self, texte):
        """Pose un bureau.json sous dunei/ (créé au besoin). Entrée : texte brut. Sortie : aucune. Erreurs : aucune. Dépendances : pathlib."""
        self.bureau.parent.mkdir(exist_ok=True)
        self.bureau.write_text(texte, encoding="utf-8")

    def actions(self):
        """Actions de plan_coque après le dossier dunei/ et les copies. Entrée : aucune. Sortie : liste d'actions. Erreurs : aucune. Dépendances : plan_coque."""
        return deploy.plan_coque(self.repo, self.cfg)[0][len(self.copies):]

    def test_coque_premier_passage(self):
        """Le dossier dunei est créé, puis chaque fichier de COQUE est copié."""
        self.assertEqual(deploy.plan_coque(self.repo, self.cfg),
                         ([("mkdir", self.cfg / "dunei")] + self.copies + [self.ecrire] + self.lien, []))

    def test_coque_deja_pose(self):
        """Un dossier dunei existant et des fichiers à nous donnent les seules copies, sans mkdir."""
        (self.cfg / "dunei").mkdir()
        for nom, _, _ in deploy.COQUE:
            (self.cfg / "dunei" / nom).write_text((self.repo / "generated" / nom).read_text(encoding="utf-8"), encoding="utf-8")
        self.assertEqual(deploy.plan_coque(self.repo, self.cfg), (self.copies + [self.ecrire] + self.lien, []))

    def test_coque_source_absente(self):
        """Une source manquante est signalée avec la commande qui la génère."""
        (self.repo / "generated" / "motion.json").unlink()
        err = deploy.plan_coque(self.repo, self.cfg)[1]
        self.assertEqual(len(err), 1)
        self.assertIn("make motion", err[0])

    def test_coque_fichier_etranger(self):
        """Un motion.json sans marque DuneI est refusé."""
        (self.cfg / "dunei").mkdir()
        (self.cfg / "dunei" / "motion.json").write_text("{}\n", encoding="utf-8")
        err = deploy.plan_coque(self.repo, self.cfg)[1]
        self.assertEqual(len(err), 1)
        self.assertIn("motion.json", err[0])

    def test_coque_shader_absent(self):
        """Un shader compilé manquant est signalé avec make shaders."""
        (self.repo / "generated" / "materiau.frag.qsb").unlink()
        err = deploy.plan_coque(self.repo, self.cfg)[1]
        self.assertEqual(len(err), 1)
        self.assertIn("make shaders", err[0])

    def test_coque_shader_binaire_remplace(self):
        """Le shader compilé déjà posé, binaire et sans marque, est remplacé sans refus."""
        (self.cfg / "dunei").mkdir()
        (self.cfg / "dunei" / "materiau.frag.qsb").write_bytes(b"\x00\xff qsb")
        self.assertEqual(deploy.plan_coque(self.repo, self.cfg)[1], [])

    def test_coque_shader_lien(self):
        """Un lien à la place du shader compilé est refusé."""
        (self.cfg / "dunei").mkdir()
        (self.cfg / "dunei" / "materiau.frag.qsb").symlink_to(self.tmp.name)
        err = deploy.plan_coque(self.repo, self.cfg)[1]
        self.assertEqual(len(err), 1)
        self.assertIn("materiau.frag.qsb", err[0])

    def test_coque_dossier_lien(self):
        """Un dossier dunei qui est un lien est refusé, sans action."""
        (self.cfg / "dunei").symlink_to(self.tmp.name)
        actions, err = deploy.plan_coque(self.repo, self.cfg)
        self.assertEqual((actions, len(err)), ([], 1))

    def test_bureau_cree(self):
        """Un bureau.json absent est écrit avec l'origine « theme » et le fond des tokens."""
        (self.cfg / "dunei").mkdir()
        self.assertEqual(self.actions()[0], self.ecrire)

    def test_bureau_suit_le_theme(self):
        """Un bureau.json d'origine « theme » au fond périmé est réécrit."""
        self.poser_bureau('{"origine": "theme", "fond": "#000000"}')
        self.assertEqual(self.actions()[0], self.ecrire)

    def test_bureau_inchange(self):
        """Un bureau.json identique ne donne aucune action d'écriture."""
        self.poser_bureau(self.ecrire[2])
        self.assertEqual(self.actions(), self.lien)

    def test_bureau_fond_preserve(self):
        """Un bureau.json d'origine « fond » est préservé, quel que soit son fond."""
        self.poser_bureau('{"origine": "fond", "fond": "#123456"}')
        self.assertEqual(self.actions(), self.lien)

    def test_bureau_illisible_refuse(self):
        """Un JSON invalide, non-objet ou d'origine inconnue est refusé, sans écriture."""
        for texte in ("pas du json", "[1]", '{"origine": "autre"}', "{}"):
            with self.subTest(texte=texte):
                self.poser_bureau(texte)
                actions, err = deploy.plan_coque(self.repo, self.cfg)
                self.assertEqual(len(err), 1)
                self.assertIn("bureau.json", err[0])
                self.assertNotIn("ecrire", [a[0] for a in actions])

    def test_bureau_sans_fond_dans_les_tokens(self):
        """Des tokens sans bureau.fond sont une erreur de plan."""
        (self.repo / "generated" / "coque-tokens.json").write_text('{\n  "_generated": "GÉNÉRÉ depuis tokens.toml"\n}\n', encoding="utf-8")
        err = deploy.plan_coque(self.repo, self.cfg)[1]
        self.assertEqual(len(err), 1)
        self.assertIn("bureau.fond", err[0])

    def test_lien_coque(self):
        """Le lien quickshell/dunei est créé, avec quickshell/ au besoin ; déjà correct, il ne donne rien."""
        self.assertEqual(self.actions()[-2:], self.lien)
        (self.cfg / "quickshell").mkdir()
        (self.cfg / "quickshell" / "dunei").symlink_to(self.repo / "coque")
        self.assertNotIn("link", [a[0] for a in self.actions()])
        self.assertEqual(deploy.plan_coque(self.repo, self.cfg)[1], [])

    def test_lien_coque_etranger(self):
        """Un lien étranger ou un dossier réel à la place du lien est refusé."""
        (self.cfg / "quickshell").mkdir()
        lien = self.cfg / "quickshell" / "dunei"
        lien.symlink_to(self.tmp.name)
        self.assertEqual(len(deploy.plan_coque(self.repo, self.cfg)[1]), 1)
        lien.unlink()
        lien.mkdir()
        err = deploy.plan_coque(self.repo, self.cfg)[1]
        self.assertEqual(len(err), 1)
        self.assertIn("quickshell/dunei", err[0])

    def test_ecrire_applique_et_decrit(self):
        """L'action ecrire pose le texte de façon atomique et se décrit."""
        (self.cfg / "dunei").mkdir()
        deploy.apply([self.ecrire])
        self.assertEqual(self.bureau.read_text(encoding="utf-8"), self.ecrire[2])
        self.assertEqual(list((self.cfg / "dunei").iterdir()), [self.bureau])
        self.assertIn("bureau.json", deploy.describe(self.ecrire))


class IconesTest(unittest.TestCase):
    """Déploiement du thème d'icônes : lien, settings.ini GTK et gsettings simulé (L4-12)."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        t = Path(self.tmp.name)
        self.repo, self.cfg, self.data = t / "depot", t / "cfg", t / "data"
        (self.repo / "generated" / "icons" / "DuneI").mkdir(parents=True)
        (self.repo / "tokens.toml").write_text('[icons]\nxdg_theme = "DuneI"\n', encoding="utf-8")
        for rel in deploy.GTK_SETTINGS:
            (self.cfg / rel).parent.mkdir(parents=True)
        self.valeur = "'Adwaita'"  # Valeur que rend le faux gsettings get.
        self.appels = []
        patches = [mock.patch.dict(os.environ, {"XDG_DATA_HOME": str(self.data)}),
                   mock.patch("deploy.shutil.which", lambda exe: "/faux/" + exe),
                   mock.patch("deploy.subprocess.run", self.faux_run)]
        for p in patches:
            p.start()
            self.addCleanup(p.stop)
        self.addCleanup(self.tmp.cleanup)

    def faux_run(self, cmd, **kw):
        """Faux subprocess.run de gsettings : get rend self.valeur, set la remplace. Entrées : cmd, kw. Sortie : CompletedProcess. Erreurs : AssertionError si la commande n'est pas gsettings. Dépendances : subprocess."""
        assert cmd[0] == "gsettings", cmd
        self.appels.append(cmd)
        if cmd[1] == "set":
            self.valeur = f"'{cmd[4]}'"
        return subprocess.CompletedProcess(cmd, 0, stdout=self.valeur + "\n")

    def plan(self):
        """plan_icones sur la maison temporaire. Entrée : aucune. Sortie : (actions, erreurs). Erreurs : aucune. Dépendances : plan_icones."""
        return deploy.plan_icones(self.repo, self.cfg)

    def test_icones_premier_passage(self):
        """Dossier icons/, lien, deux settings.ini marqués, puis gsettings."""
        actions, err = self.plan()
        self.assertEqual(err, [])
        texte = actions[2][2]
        self.assertEqual(actions, [("mkdir", self.data / "icons"),
                                   ("link", self.repo / "generated" / "icons" / "DuneI", self.data / "icons" / "DuneI"),
                                   ("ecrire", self.cfg / "gtk-3.0" / "settings.ini", texte),
                                   ("ecrire", self.cfg / "gtk-4.0" / "settings.ini", texte),
                                   ("gsettings", "org.gnome.desktop.interface", "icon-theme", "DuneI")])
        self.assertIn("[Settings]\ngtk-icon-theme-name=DuneI\n", texte)
        self.assertIn(deploy.MARK, texte.splitlines()[1])
        self.assertEqual(deploy.describe(actions[-1]), "régler org.gnome.desktop.interface icon-theme à DuneI")

    def test_icones_dossiers_gtk_manquants(self):
        """Un dossier gtk-3.0 absent est créé avant l'écriture de son settings.ini."""
        (self.cfg / "gtk-3.0").rmdir()
        actions = self.plan()[0]
        self.assertEqual(actions[2:4], [("mkdir", self.cfg / "gtk-3.0"), ("ecrire", self.cfg / "gtk-3.0" / "settings.ini", actions[3][2])])

    def test_icones_idempotent(self):
        """Une fois appliqué, le plan est vide, et gsettings n'a reçu qu'un seul set."""
        deploy.apply(self.plan()[0])
        self.assertEqual(self.plan(), ([], []))
        self.assertEqual([c[1] for c in self.appels].count("set"), 1)

    def test_icones_xdg_data_home(self):
        """Le lien va sous $XDG_DATA_HOME, pas sous ~/.local/share."""
        self.assertIn(self.data / "icons" / "DuneI", [a[2] for a in self.plan()[0] if a[0] == "link"])

    def test_icones_settings_etranger(self):
        """Un settings.ini sans la marque est refusé par un message qui le nomme, jamais écrasé."""
        ini = self.cfg / "gtk-3.0" / "settings.ini"
        ini.write_text("[Settings]\ngtk-theme-name=Autre\n", encoding="utf-8")
        actions, err = self.plan()
        self.assertEqual(len(err), 1)
        self.assertIn(str(ini), err[0])
        self.assertNotIn(ini, [a[1] for a in actions if a[0] == "ecrire"])

    def test_icones_lien_etranger(self):
        """Un dossier réel, ou un lien étranger, à la place du lien est refusé."""
        lien = self.data / "icons" / "DuneI"
        lien.mkdir(parents=True)
        err = self.plan()[1]
        self.assertEqual(len(err), 1)
        self.assertIn(str(lien), err[0])
        lien.rmdir()
        lien.symlink_to(self.tmp.name)
        self.assertEqual(len(self.plan()[1]), 1)

    def test_icones_sans_gsettings(self):
        """Sans gsettings, une note remplace le réglage et rien ne bloque."""
        with mock.patch("deploy.shutil.which", lambda exe: None):
            actions, err = self.plan()
        self.assertEqual((err, actions[-1]), ([], ("gsettings-absent", "DuneI")))
        self.assertIn("gsettings-absent", deploy.NOTES)
        self.assertIn("DuneI", deploy.describe(actions[-1]))


if __name__ == "__main__":
    unittest.main()
