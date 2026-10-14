"""Générateur — cibles produites, et refus sans écriture quand la source est invalide."""

import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def run(src: Path, out: Path) -> subprocess.CompletedProcess:
    """Lance generate_motion.py sur une source et un dossier de sortie."""
    return subprocess.run([sys.executable, str(ROOT / "generate_motion.py"), "--src", str(src), "--out", str(out)],
                          capture_output=True, text=True, cwd=ROOT)


class GenerateTest(unittest.TestCase):
    """Comportement de la ligne de commande."""

    def test_writes_both_targets(self):
        with tempfile.TemporaryDirectory() as tmp:
            res = run(ROOT / "motion.toml", Path(tmp))
            self.assertEqual(res.returncode, 0, res.stderr)
            data = json.loads((Path(tmp) / "motion.json").read_text(encoding="utf-8"))
            self.assertEqual(data["transitions"]["navigate"]["in"]["settle_ms"], 186)
            lua = (Path(tmp) / "motion.lua").read_text(encoding="utf-8")
            self.assertIn('["dunei-state-out"] = { type = "spring", mass = 0.5, stiffness = 2244.9, dampening = 71.43 },', lua)
            self.assertIn('{ leaf = "borderangle", enabled = false },', lua)

    def test_errors_write_nothing(self):
        with tempfile.TemporaryDirectory() as tmp:
            src, out = Path(tmp) / "motion.toml", Path(tmp) / "out"
            src.write_text((ROOT / "motion.toml").read_text(encoding="utf-8").replace('version = "0.1.0"', 'version = "9"'),
                           encoding="utf-8")
            out.mkdir()
            (out / "motion.lua").write_text("ancien", encoding="utf-8")
            res = run(src, out)
            self.assertEqual(res.returncode, 1)
            self.assertIn("version 9 inconnue", res.stderr)
            self.assertEqual([p.name for p in out.iterdir()], ["motion.lua"])
            self.assertEqual((out / "motion.lua").read_text(encoding="utf-8"), "ancien")

    def test_unreadable_source(self):
        with tempfile.TemporaryDirectory() as tmp:
            src = Path(tmp) / "motion.toml"
            src.write_text("version = \n", encoding="utf-8")
            res = run(src, Path(tmp) / "out")
            self.assertEqual(res.returncode, 1)
            self.assertIn("source illisible", res.stderr)
            self.assertNotIn("Traceback", res.stderr)
            self.assertFalse((Path(tmp) / "out").exists())


if __name__ == "__main__":
    unittest.main()
