"""Non-régression — chaque cible doit reproduire exactement l'instantané de référence.

Un changement VOULU d'une sortie se fait en régénérant les instantanés
(`make golden`) : le diff de tests/golden/ montre alors ce qui change réellement.
"""

import unittest
from pathlib import Path

from dunei_theme.emitters import TARGETS
from dunei_theme.model import load, resolve

ROOT = Path(__file__).resolve().parent.parent
GOLDEN = ROOT / "tests" / "golden"


class GoldenTest(unittest.TestCase):
    """Compare chaque cible, pour chaque teinte d'instantané, à sa référence."""

    def test_targets_match_golden(self):
        data = load(ROOT / "tokens.toml")
        for hue_dir in sorted(GOLDEN.iterdir()):
            model = resolve(data, float(hue_dir.name.removeprefix("hue-")))
            for filename, emitter in TARGETS.items():
                with self.subTest(hue=hue_dir.name, target=filename):
                    self.assertEqual(emitter(model), (hue_dir / filename).read_text(encoding="utf-8"))


if __name__ == "__main__":
    unittest.main()
