"""Extraction de teinte — les règles de la bible (ch. 2) sur des images synthétiques."""

import tempfile
import unittest
from pathlib import Path

import numpy as np
from PIL import Image

from dunei_theme.hue import decide, from_image, quantize
from dunei_theme.model import load

ROOT = Path(__file__).resolve().parent.parent
DATA = load(ROOT / "tokens.toml")
EX = DATA["extraction"]


def extract(pixels: np.ndarray):
    """Extraction d'une image en mémoire.

    Entrée : pixels — tableau (h, w, 3) uint8.
    Sortie : HueResult. Erreurs : aucune. Dépendances : Pillow, numpy, dunei_theme.hue.
    """
    with tempfile.TemporaryDirectory() as d:
        path = Path(d) / "img.png"
        Image.fromarray(pixels.astype(np.uint8)).save(path)
        return decide(from_image(path, EX), DATA)


def plain(rgb, size=100):
    """Image unie. Entrées : rgb, size. Sortie : tableau (size, size, 3). Dépendances : numpy."""
    return np.full((size, size, 3), rgb, dtype=np.uint8)


class HueTest(unittest.TestCase):

    def test_saturated_blue(self):
        res = extract(plain((0, 0, 255)))
        self.assertFalse(res.achromatic)
        self.assertEqual(res.hue, 265)

    def test_grey_is_achromatic(self):
        res = extract(plain((128, 128, 128)))
        self.assertTrue(res.achromatic)
        self.assertEqual(res.hue, DATA["theme"]["fallback_hue"])
        self.assertIsNone(res.pivot)

    def test_small_vivid_zone_beats_dominant(self):
        img = plain((120, 125, 135))       # gris légèrement bleuté, 90 % de la surface
        img[:10] = (220, 40, 40)           # bande rouge vive, 10 %
        res = extract(img)
        self.assertFalse(res.achromatic)
        self.assertEqual(res.hue, quantize(res.pivot["h"], EX["hue_step"]))
        self.assertLess(abs((res.hue - 25 + 180) % 360 - 180), 15)

    def test_quantize_never_360(self):
        self.assertEqual(quantize(358, EX["hue_step"]), 0)
        self.assertEqual(quantize(359.9, EX["hue_step"]), 0)
        self.assertEqual(quantize(357, EX["hue_step"]), 355)

    def test_stability(self):
        rng = np.random.default_rng(0)
        base = plain((40, 90, 200)).astype(int)
        noisy = np.clip(base + rng.integers(-3, 4, base.shape), 0, 255)
        self.assertEqual(extract(base).hue, extract(noisy).hue)


if __name__ == "__main__":
    unittest.main()
