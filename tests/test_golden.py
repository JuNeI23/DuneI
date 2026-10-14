"""Non-régression — chaque cible doit reproduire exactement l'instantané de référence.

Un changement VOULU d'une sortie se fait en régénérant les instantanés
(`make golden`) : le diff de tests/golden/ montre alors ce qui change réellement.
"""

import unittest
from pathlib import Path

from dunei_theme.emitters import TARGETS
from dunei_theme.model import load, resolve
from dunei_motion.emitters import TARGETS as MOTION_TARGETS
from dunei_motion.model import load as load_motion, resolve as resolve_motion

ROOT = Path(__file__).resolve().parent.parent
GOLDEN = ROOT / "tests" / "golden"


class GoldenTest(unittest.TestCase):
    """Compare chaque cible du thème, pour chaque teinte d'instantané, et chaque cible du mouvement, à sa référence."""

    def test_targets_match_golden(self):
        data = load(ROOT / "tokens.toml")
        for hue_dir in sorted(GOLDEN.glob("hue-*")):
            model = resolve(data, float(hue_dir.name.removeprefix("hue-")))
            for filename, emitter in TARGETS.items():
                with self.subTest(hue=hue_dir.name, target=filename):
                    self.assertEqual(emitter(model), (hue_dir / filename).read_text(encoding="utf-8"))

    def test_motion_matches_golden(self):
        model = resolve_motion(load_motion(ROOT / "motion.toml"))
        for filename, emitter in MOTION_TARGETS.items():
            with self.subTest(target=filename):
                self.assertEqual(emitter(model), (GOLDEN / "motion" / filename).read_text(encoding="utf-8"))


if __name__ == "__main__":
    unittest.main()
