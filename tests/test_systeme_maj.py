"""Fichiers système des mises à jour — règle de cache de pacman, service et minuteur de préchargement."""

import os
import shutil
import subprocess
import tempfile
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

    def test_type_et_code_de_sortie(self):
        l = lignes(SERVICE)
        self.assertIn("Type=oneshot", l)
        self.assertIn("SuccessExitStatus=2", l)

    def test_abstention_sur_connexion_mesuree(self):
        """Exécute l'ExecCondition avec un faux busctl : sortie 1 pour « u 1 » et « u 3 », 0 sinon."""
        cond = next(x for x in lignes(SERVICE) if x.startswith("ExecCondition=")).removeprefix("ExecCondition=")
        cond = cond.replace("$$", "$")
        with tempfile.TemporaryDirectory() as d:
            faux = Path(d) / "busctl"
            faux.write_text('#!/bin/sh\nprintf "%s" "$FAKE_METERED"\n', encoding="utf-8")
            faux.chmod(0o755)
            env = {**os.environ, "PATH": f"{d}{os.pathsep}{os.environ['PATH']}"}
            for rep, code in (("u 1", 1), ("u 3", 1), ("u 4", 0), ("u 2", 0), ("", 0), ("illisible", 0)):
                with self.subTest(reponse=rep):
                    r = subprocess.run(["/bin/sh", "-c", cond.removeprefix("/usr/bin/sh -c ").strip("'")],
                                       env={**env, "FAKE_METERED": rep})
                    self.assertEqual(r.returncode, code)

    @unittest.skipUnless(shutil.which("systemd-analyze") and Path("/usr/bin/checkupdates").exists(),
                         "systemd-analyze et /usr/bin/checkupdates requis")
    def test_unites_valides(self):
        r = subprocess.run(["systemd-analyze", "verify", str(SERVICE), str(TIMER)], capture_output=True, text=True)
        self.assertEqual(r.returncode, 0, r.stderr)


if __name__ == "__main__":
    unittest.main()
