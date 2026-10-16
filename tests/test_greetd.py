"""Fichiers de greetd — une seule commande de session, une surcharge qui désigne le fichier de DuneI."""

import shlex
import tomllib
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CONF = ROOT / "systeme" / "etc" / "greetd" / "dunei.toml"
SESSIONS = ROOT / "systeme" / "etc" / "greetd" / "sessions"
DROPIN = ROOT / "systeme" / "etc" / "systemd" / "system" / "greetd.service.d" / "10-dunei.conf"
SESSION = "uwsm start -e -D Hyprland hyprland.desktop"


class GreetdTest(unittest.TestCase):
    """Connexion automatique et écran de connexion lancent la même session uwsm."""

    def setUp(self):
        self.conf = tomllib.loads(CONF.read_text(encoding="utf-8"))

    def test_marked(self):
        for f in (CONF, DROPIN):
            with self.subTest(fichier=f.name):
                self.assertIn("Posé par DuneI", f.read_text(encoding="utf-8").splitlines()[1])

    def test_same_session_twice(self):
        greeter = shlex.split(self.conf["default_session"]["command"])
        self.assertEqual(greeter[0], "tuigreet")
        self.assertEqual(greeter[greeter.index("--cmd") + 1], SESSION)
        self.assertEqual(self.conf["initial_session"]["command"], SESSION)

    def test_session_menu_offers_only_dunei(self):
        greeter = shlex.split(self.conf["default_session"]["command"])
        self.assertEqual(greeter[greeter.index("--sessions") + 1], "/etc/greetd/sessions")
        # Aucune session X11 : --xsessions désigne un dossier que DuneI ne pose pas.
        self.assertEqual(greeter[greeter.index("--xsessions") + 1], "/etc/greetd/xsessions")
        self.assertFalse((ROOT / "systeme" / "etc" / "greetd" / "xsessions").exists())
        # Aucun fichier de configuration de tuigreet de la machine ne change l'écran (règle 5).
        self.assertIn("--no-config", greeter)
        self.assertEqual([p.name for p in SESSIONS.iterdir()], ["dunei.desktop"])
        entry = SESSIONS / "dunei.desktop"
        lines = entry.read_text(encoding="utf-8").splitlines()
        self.assertIn("Posé par DuneI", lines[1])
        self.assertIn(f"Exec={SESSION}", lines)

    def test_users(self):
        self.assertEqual(self.conf["initial_session"]["user"], "{utilisateur}")
        self.assertEqual(self.conf["default_session"]["user"], "greeter")
        self.assertEqual(self.conf["terminal"]["vt"], 1)

    def test_dropin_points_to_dunei_toml(self):
        lines = DROPIN.read_text(encoding="utf-8").splitlines()
        self.assertEqual([l for l in lines if l.startswith("ExecStart")],
                         ["ExecStart=", "ExecStart=/usr/bin/greetd --config /etc/greetd/dunei.toml"])


if __name__ == "__main__":
    unittest.main()
