"""Générateur de l'échelle d'inactivité — generate_energie.py sur la vraie source et sur une source fautive."""

import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from dunei_energie.emitters import lua as lua_target

ROOT = Path(__file__).resolve().parent.parent
SCRIPTS = '"${XDG_CONFIG_HOME:-$HOME/.config}/hypr/scripts'
LUA = shutil.which("lua") or shutil.which("luajit")


def run(src: Path, out: Path) -> subprocess.CompletedProcess:
    """Lance generate_energie.py sur une source et un dossier de sortie."""
    return subprocess.run([sys.executable, str(ROOT / "generate_energie.py"), "--src", str(src), "--out", str(out)],
                          capture_output=True, text=True, cwd=ROOT)


class GenerateTest(unittest.TestCase):
    """Contenu exact de hypridle.conf et refus d'une source fautive."""

    def generate(self) -> str:
        """Génère depuis energie.toml et rend le texte de hypridle.conf."""
        with tempfile.TemporaryDirectory() as tmp:
            res = run(ROOT / "energie.toml", Path(tmp))
            self.assertEqual(res.returncode, 0, res.stderr)
            return (Path(tmp) / "hypridle.conf").read_text(encoding="utf-8")

    def test_mark_on_second_line(self):
        self.assertIn("GÉNÉRÉ depuis energie.toml", self.generate().splitlines()[1])

    def test_general(self):
        text = self.generate()
        for line in (f"    lock_cmd = {SCRIPTS}/dunei-verrou\"",
                     "    before_sleep_cmd = loginctl lock-session",
                     "    after_sleep_cmd = hyprctl dispatch 'hl.dsp.dpms({ action = \"on\" })'",
                     "    inhibit_sleep = 3", "    ignore_dbus_inhibit = false",
                     "    ignore_systemd_inhibit = false", "    ignore_wayland_inhibit = false"):
            self.assertIn(line + "\n", text)

    def test_dpms_strings_are_exact(self):
        # Une valeur inconnue fait basculer l'écran : seules « on » et « off » sont admises.
        import re
        self.assertEqual(set(re.findall(r'action = "(\w+)"', self.generate())), {"on", "off"})

    def test_listeners(self):
        text = self.generate()
        self.assertEqual(text.count("listener {"), 7)
        self.assertEqual(text.count(f"    condition_cmd = {SCRIPTS}/dunei-sur-batterie\"\n"), 4)
        self.assertEqual(text.count(f"    condition_cmd = ! {SCRIPTS}/dunei-sur-batterie\"\n"), 3)
        self.assertEqual(text.count("    condition_retry = 5\n"), 7)
        self.assertIn(f"    on-timeout = {SCRIPTS}/dunei-attenuer\" 10\n", text)
        self.assertIn(f"    on-resume = {SCRIPTS}/dunei-attenuer\" --restaurer\n", text)
        self.assertEqual(text.count("    on-timeout = systemctl suspend\n"), 1)
        for t in (150, 300, 330, 900, 600, 630):
            self.assertIn(f"    timeout = {t}\n", text)

    def test_no_hash_in_values(self):
        # « # » ouvre un commentaire en hyprlang : il couperait une commande.
        for line in self.generate().splitlines():
            if "=" in line:
                self.assertNotIn("#", line)

    def test_faulty_source_writes_nothing(self):
        with tempfile.TemporaryDirectory() as tmp:
            src, out = Path(tmp) / "energie.toml", Path(tmp) / "out"
            src.write_text((ROOT / "energie.toml").read_text(encoding="utf-8").replace("batterie = 330", "batterie = 200"),
                           encoding="utf-8")
            res = run(src, out)
            self.assertEqual(res.returncode, 1)
            self.assertIn("palier ecran, batterie", res.stderr)
            self.assertFalse(out.exists())

    def test_missing_source(self):
        with tempfile.TemporaryDirectory() as tmp:
            res = run(Path(tmp) / "absent.toml", Path(tmp))
            self.assertEqual(res.returncode, 1)
            self.assertIn("source illisible", res.stderr)


class CoqueTargetTest(unittest.TestCase):
    """generated/energie.json porte les seuils d'alerte de la batterie lus par la coque (L2-13)."""

    def test_seuils(self):
        with tempfile.TemporaryDirectory() as tmp:
            res = run(ROOT / "energie.toml", Path(tmp))
            self.assertEqual(res.returncode, 0, res.stderr)
            data = json.loads((Path(tmp) / "energie.json").read_text(encoding="utf-8"))
        self.assertEqual(data["alerte"], {"faible": 20, "critique": 5})
        self.assertIn("GÉNÉRÉ depuis energie.toml", data["_generated"])
        self.assertEqual(data["version"], "0.2.0")


class CheminDuVerrouilleurTest(unittest.TestCase):
    """Les commandes du verrouilleur, telles que hypridle et dunei-verrou-initial les exécutent par sh -c, désignent un
    exécutable existant une fois le dépôt lié comme le fait deploy.py (config/hypr/scripts sous hypr/scripts), avec ou
    sans XDG_CONFIG_HOME, et le PATH réduit aux dossiers système. Aucune commande n'est exécutée : sh développe
    seulement le premier mot, que command -v résout. Le lanceur ainsi lancé est reconnu par le motif de la coque."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        t = Path(self.tmp.name)
        res = run(ROOT / "energie.toml", t / "gen")
        self.assertEqual(res.returncode, 0, res.stderr)
        idle = (t / "gen" / "hypridle.conf").read_text(encoding="utf-8")
        lua = (t / "gen" / "energie.lua").read_text(encoding="utf-8")
        self.commandes = {"lock_cmd": re.search(r"^    lock_cmd = (.*)$", idle, re.M).group(1),
                          **{k: json.loads(re.search(rf"^    {k} = (.*),$", lua, re.M).group(1))
                             for k in ("verrouilleur", "verrouilleur_initial")}}
        # Banc qui remplace dunei-verrou-initial : même sh -c "$1", mais qui résout le premier mot au lieu de le lancer.
        self.banc = t / "banc"
        self.banc.write_text('#!/bin/sh\nexec sh -c "set -- $1; command -v \\"\\$1\\""\n', encoding="utf-8")
        self.banc.chmod(0o755)
        self.motif = re.compile(re.search(r'property string motifLanceur: "([^"]*)"',
                                          (ROOT / "coque/Verrou/Verrou.qml").read_text(encoding="utf-8")).group(1))

    def lier(self, config: Path) -> None:
        """Lie le dossier des scripts du dépôt sous config/hypr/scripts, comme deploy.py."""
        (config / "hypr").mkdir(parents=True)
        (config / "hypr" / "scripts").symlink_to(ROOT / "config" / "hypr" / "scripts")

    def resoudre(self, commande: str, env: dict, initial: bool) -> str:
        """Chemin de l'exécutable désigné par une commande, développée par sh -c (hypridle) ou par le banc du verrou
        initial, appelé comme Hyprland l'appelle depuis demarrage.lua (argument cité entre apostrophes)."""
        if initial:
            cite = "'" + commande.replace("'", "'\\''") + "'"
            argv = ["/bin/sh", "-c", f"{self.banc} {cite}"]
        else:
            argv = ["/bin/sh", "-c", f"set -- {commande}; command -v \"$1\""]
        res = subprocess.run(argv, capture_output=True, text=True, env=env, timeout=5)
        self.assertEqual(res.returncode, 0, f"{commande} : {res.stderr}")
        return res.stdout.strip()

    def verifier(self, env: dict, config: Path):
        """Chaque commande résout dunei-verrou sous config/hypr/scripts, exécutable et reconnu par la coque."""
        for nom, commande in self.commandes.items():
            for initial in ((False, True) if nom == "verrouilleur_initial" else (False,)):
                with self.subTest(commande=nom, initial=initial):
                    chemin = self.resoudre(commande, env, initial)
                    self.assertEqual(chemin, str(config / "hypr" / "scripts" / "dunei-verrou"))
                    self.assertTrue(os.access(chemin, os.X_OK))
                    self.assertTrue(self.motif.search(f"/bin/sh {chemin}" + (" --sec" if "--sec" in commande else "")))

    def test_sans_xdg_config_home(self):
        maison = Path(self.tmp.name) / "maison"
        self.lier(maison / ".config")
        self.verifier({"HOME": str(maison), "PATH": "/usr/bin:/bin"}, maison / ".config")

    def test_avec_xdg_config_home(self):
        config = Path(self.tmp.name) / "conf"
        self.lier(config)
        self.verifier({"HOME": str(Path(self.tmp.name) / "vide"), "XDG_CONFIG_HOME": str(config),
                       "PATH": "/usr/bin:/bin"}, config)


class LuaTargetTest(unittest.TestCase):
    """generated/energie.lua rend la commande du verrouilleur, intacte, en Lua valide."""

    def roundtrip(self, cmd: str) -> str:
        """Évalue le module émis pour une commande donnée et rend la valeur lue par Lua."""
        text = lua_target.emit({"verrouilleur": cmd, "verrouilleur_initial": cmd})
        res = subprocess.run([LUA, "-e", f"io.write((load([==[{text}]==])()).verrouilleur)"],
                             capture_output=True, text=True)
        self.assertEqual(res.returncode, 0, res.stderr)
        return res.stdout

    def test_marked_as_generated(self):
        self.assertIn("GÉNÉRÉ depuis energie.toml", lua_target.emit({"verrouilleur": "x", "verrouilleur_initial": "x"}).splitlines()[0])

    @unittest.skipUnless(LUA, "aucun interpréteur Lua")
    def test_real_command_roundtrips(self):
        cmd = "pidof hyprlock || hyprlock --no-fade-in --immediate-render"
        self.assertEqual(self.roundtrip(cmd), cmd)

    @unittest.skipUnless(LUA, "aucun interpréteur Lua")
    def test_initial_command_roundtrips(self):
        text = lua_target.emit({"verrouilleur": "a", "verrouilleur_initial": "a --sec"})
        res = subprocess.run([LUA, "-e", f"io.write((load([==[{text}]==])()).verrouilleur_initial)"],
                             capture_output=True, text=True)
        self.assertEqual((res.returncode, res.stdout), (0, "a --sec"))

    @unittest.skipUnless(LUA, "aucun interpréteur Lua")
    def test_quotes_and_backslashes_roundtrip(self):
        cmd = "verrou --texte \"l'écran\" --motif 'a\\b'"
        self.assertEqual(self.roundtrip(cmd), cmd)


if __name__ == "__main__":
    unittest.main()
