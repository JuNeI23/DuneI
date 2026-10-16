"""Verrou initial — dunei-verrou-initial exécuté avec de faux hyprctl, uwsm et logger dans le PATH."""

import os
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCRIPT = ROOT / "config" / "hypr" / "scripts" / "dunei-verrou-initial"
# Chaque faux outil consigne son appel dans $FAKE_LOG, une ligne par appel. hyprctl répond $FAKE_HYPRCTL
# (« ok » par défaut) ; uwsm sort avec le code $FAKE_UWSM (0 par défaut).
FAKES = {name: f'#!/bin/sh\necho "{name} $*" >> "$FAKE_LOG"\n' for name in ("hyprctl", "uwsm", "logger")}
FAKES["hyprctl"] += 'echo "${FAKE_HYPRCTL:-ok}"\n'
FAKES["uwsm"] += 'exit "${FAKE_UWSM:-0}"\n'
RESET = "hyprctl dispatch hl.dsp.submap(\"reset\")"


class VerrouInitialTest(unittest.TestCase):
    """Clavier rendu après un déverrouillage, relance après un échec, session fermée après trois."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        t = Path(self.tmp.name)
        (t / "bin").mkdir()
        for name, body in FAKES.items():
            (t / "bin" / name).write_text(body, encoding="utf-8")
            (t / "bin" / name).chmod(0o755)
        self.log, self.count = t / "log", t / "compte"
        self.env = {**os.environ, "PATH": f"{t / 'bin'}:{os.environ['PATH']}", "FAKE_LOG": str(self.log)}

    def tearDown(self):
        self.tmp.cleanup()

    def run_script(self, *args: str) -> subprocess.CompletedProcess:
        """Lance le script avec les faux outils."""
        return subprocess.run([str(SCRIPT), *args], capture_output=True, text=True, env=self.env)

    def calls(self) -> list[str]:
        """Appels consignés, dans l'ordre."""
        return self.log.read_text().splitlines() if self.log.exists() else []

    def test_unlock_gives_keyboard_back(self):
        res = self.run_script("true")
        self.assertEqual(res.returncode, 0, res.stderr)
        self.assertEqual(self.calls(), [RESET])

    def test_three_failures_close_the_session(self):
        res = self.run_script("false")
        self.assertEqual(res.returncode, 1)
        calls = self.calls()
        self.assertEqual(calls[-1], "uwsm stop")
        self.assertEqual(len([c for c in calls if c.startswith("logger")]), 4)
        self.assertNotIn(RESET, calls)

    def test_failure_then_success(self):
        cmd = f'n=$(cat "{self.count}" 2>/dev/null || echo 0); echo $((n + 1)) > "{self.count}"; [ "$n" -ge 1 ]'
        res = self.run_script(cmd)
        self.assertEqual(res.returncode, 0, res.stderr)
        self.assertEqual(self.count.read_text().strip(), "2")
        self.assertEqual([c for c in self.calls() if not c.startswith("logger")], [RESET])

    def test_refused_reset_is_logged(self):
        self.env["FAKE_HYPRCTL"] = "erreur"
        res = self.run_script("true")
        self.assertEqual(res.returncode, 0, res.stderr)
        calls = self.calls()
        self.assertEqual(calls[0], RESET)
        self.assertEqual(len([c for c in calls if c.startswith("logger")]), 1)

    def test_failed_stop_is_logged(self):
        self.env["FAKE_UWSM"] = "1"
        res = self.run_script("false")
        self.assertEqual(res.returncode, 1)
        self.assertTrue(self.calls()[-1].startswith("logger"))
        self.assertEqual(len([c for c in self.calls() if c.startswith("logger")]), 5)

    def test_usage(self):
        res = self.run_script()
        self.assertEqual(res.returncode, 2)
        self.assertIn("usage", res.stderr)
        self.assertEqual(self.calls(), [])


if __name__ == "__main__":
    unittest.main()
