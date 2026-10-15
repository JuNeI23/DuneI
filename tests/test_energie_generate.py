"""Générateur de l'échelle d'inactivité — generate_energie.py sur la vraie source et sur une source fautive."""

import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCRIPTS = '"${XDG_CONFIG_HOME:-$HOME/.config}/hypr/scripts'


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
        for line in ("    lock_cmd = pidof hyprlock || hyprlock --no-fade-in",
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


if __name__ == "__main__":
    unittest.main()
