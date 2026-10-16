"""Fichiers système des mises à jour — règle de cache de pacman, service et minuteur de préchargement."""

import shutil
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
HOOK = ROOT / "systeme" / "etc" / "pacman.d" / "hooks" / "dunei-cache.hook"
SERVICE = ROOT / "systeme" / "etc" / "systemd" / "system" / "dunei-precharge.service"
TIMER = ROOT / "systeme" / "etc" / "systemd" / "system" / "dunei-precharge.timer"


def lignes(f):
    """Lit un fichier d'unité ; sortie : ses lignes, commentaires exclus."""
    return [l for l in f.read_text(encoding="utf-8").splitlines() if l and not l.startswith("#")]


class SystemeMajTest(unittest.TestCase):
    """Le cache est borné après chaque transaction ; les mises à jour sont préchargées sans être installées."""

    def test_marque(self):
        for f in (HOOK, SERVICE, TIMER):
            with self.subTest(fichier=f.name):
                self.assertIn("Posé par DuneI", f.read_text(encoding="utf-8").splitlines()[1])

    def test_hook(self):
        l = lignes(HOOK)
        self.assertIn("When = PostTransaction", l)
        self.assertIn("Depends = pacman-contrib", l)
        exe = next(x for x in l if x.startswith("Exec = "))
        self.assertTrue(exe.startswith("Exec = /usr/bin/sh -c "))
        self.assertIn("paccache -rk3", exe)
        self.assertIn("paccache -ruk0", exe)

    def test_minuteur(self):
        l = lignes(TIMER)
        for x in ("OnCalendar=daily", "Persistent=true", "RandomizedDelaySec=1h", "WantedBy=timers.target"):
            self.assertIn(x, l)

    def test_service(self):
        l = lignes(SERVICE)
        for x in ("ExecStart=/usr/bin/checkupdates -d", "Nice=19", "IOSchedulingClass=idle",
                  "After=network-online.target"):
            self.assertIn(x, l)
        cond = next(x for x in l if x.startswith("ExecCondition="))
        self.assertIn("Metered", cond)
        self.assertIn("$$", cond)

    @unittest.skipUnless(shutil.which("systemd-analyze") and Path("/usr/bin/checkupdates").exists(),
                         "systemd-analyze et /usr/bin/checkupdates requis")
    def test_unites_valides(self):
        r = subprocess.run(["systemd-analyze", "verify", str(SERVICE), str(TIMER)], capture_output=True, text=True)
        self.assertEqual(r.returncode, 0, r.stderr)


if __name__ == "__main__":
    unittest.main()
