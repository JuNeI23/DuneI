"""Scripts shell — chaque script de config/hypr/scripts/ passe shellcheck sans aucun avertissement."""

import shutil
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SHELLCHECK = shutil.which("shellcheck")
SCRIPTS = sorted((ROOT / "config" / "hypr" / "scripts").iterdir())


@unittest.skipUnless(SHELLCHECK, "shellcheck absent : pacman -S shellcheck")
class ShellcheckTest(unittest.TestCase):
    """Analyse statique de chaque script, au niveau de sévérité le plus strict."""

    def test_scripts(self):
        for script in SCRIPTS:
            with self.subTest(script=script.name):
                res = subprocess.run([SHELLCHECK, "--severity=style", str(script)], capture_output=True, text=True)
                self.assertEqual(res.returncode, 0, res.stdout)


if __name__ == "__main__":
    unittest.main()
