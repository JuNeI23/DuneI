"""setup/vm.sh — refus sans aucune création quand l'ISO donnée est introuvable."""

import os
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


class VmTest(unittest.TestCase):
    """Le refus tombe avant le dossier d'état, donc sans qemu ni swtpm installés."""

    def test_iso_introuvable(self):
        with tempfile.TemporaryDirectory() as tmp:
            env = {**os.environ, "XDG_CACHE_HOME": tmp}
            res = subprocess.run([str(ROOT / "setup/vm.sh"), tmp + "/absente.iso"], env=env, capture_output=True, text=True)
            self.assertEqual(res.returncode, 1)
            self.assertIn("ISO introuvable", res.stderr)
            self.assertEqual(list(Path(tmp).iterdir()), [])


if __name__ == "__main__":
    unittest.main()
