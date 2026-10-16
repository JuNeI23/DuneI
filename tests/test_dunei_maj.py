"""Mise à jour — dunei-maj exécuté avec de faux informant, sudo, pacman, pacdiff et uname dans le PATH."""

import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCRIPT = ROOT / "config" / "bin" / "dunei-maj"
# Chaque faux outil consigne son appel dans $FAKE_LOG. informant répond $FAKE_NEWS à « list », pacdiff
# répond $FAKE_PACNEW, pacman sort avec $FAKE_PACMAN (0 par défaut), uname rend « 1.0 ». sudo consigne puis
# exécute la commande qu'il reçoit, qui est donc l'un des autres faux.
FAKES = {
    "informant": 'echo "informant $*" >> "$FAKE_LOG"\n[ "$1" = list ] && printf "%s" "${FAKE_NEWS:-}"\nexit 0\n',
    "sudo": 'echo "sudo $*" >> "$FAKE_LOG"\nexec "$@"\n',
    "pacman": 'echo "pacman $*" >> "$FAKE_LOG"\nexit "${FAKE_PACMAN:-0}"\n',
    "pacdiff": 'echo "pacdiff $*" >> "$FAKE_LOG"\nprintf "%s" "${FAKE_PACNEW:-}"\n',
    "uname": 'echo 1.0\n',
}


class DuneiMajTest(unittest.TestCase):
    """Les quatre étapes dans l'ordre, et l'arrêt au premier échec."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        t = Path(self.tmp.name)
        (t / "bin").mkdir()
        (t / "sys").mkdir()
        for name, body in FAKES.items():
            (t / "bin" / name).write_text("#!/bin/sh\n" + body, encoding="utf-8")
            (t / "bin" / name).chmod(0o755)
        # Strict nécessaire : l'interpréteur du script et env pour sa première ligne ; rien d'autre.
        for name in ("bash", "env"):
            (t / "sys" / name).symlink_to(shutil.which(name))
        self.log = t / "log"
        (t / "root" / "usr" / "lib" / "modules").mkdir(parents=True)
        self.modules = t / "root" / "usr" / "lib" / "modules"
        self.env = {"PATH": f"{t / 'bin'}:{t / 'sys'}", "FAKE_LOG": str(self.log), "DUNEI_SYSROOT": str(t / "root")}

    def tearDown(self):
        self.tmp.cleanup()

    def run_script(self) -> subprocess.CompletedProcess:
        """Lance le script avec les faux outils, sans rien d'autre dans le PATH."""
        return subprocess.run([str(SCRIPT)], capture_output=True, text=True, env=self.env)

    def calls(self) -> list[str]:
        """Appels consignés, dans l'ordre."""
        return self.log.read_text().splitlines() if self.log.exists() else []

    def test_sans_actualite(self):
        (self.modules / "1.0").mkdir()
        res = self.run_script()
        self.assertEqual(res.returncode, 0, res.stderr)
        self.assertNotIn("informant read", " ".join(self.calls()))
        self.assertIn("sudo pacman -Syu", self.calls())

    def test_actualite_lue_d_abord(self):
        self.env["FAKE_NEWS"] = "0: Intervention manuelle\n"
        res = self.run_script()
        self.assertEqual(res.returncode, 0, res.stderr)
        calls = self.calls()
        self.assertLess(calls.index("informant read"), calls.index("pacman -Syu"))

    def test_pacnew_liste(self):
        self.env["FAKE_PACNEW"] = "/etc/a.pacnew\n"
        res = self.run_script()
        self.assertIn("/etc/a.pacnew", res.stdout)
        self.assertIn("sudo pacdiff", res.stdout)

    def test_noyau_change(self):
        res = self.run_script()
        self.assertIn("redémarre", res.stdout)

    def test_noyau_inchange(self):
        (self.modules / "1.0").mkdir()
        res = self.run_script()
        self.assertNotIn("redémarre", res.stdout)

    def test_echec_pacman(self):
        self.env["FAKE_PACMAN"] = "1"
        res = self.run_script()
        self.assertEqual(res.returncode, 1)
        self.assertNotIn("pacdiff -o", self.calls())
        self.assertTrue(res.stderr)


if __name__ == "__main__":
    unittest.main()
