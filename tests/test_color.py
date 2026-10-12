"""Tests de color — rabattement de gamut à teinte préservée et contraste APCA."""

import unittest

from dunei_theme.color import Oklch, apca_lc, fit_gamut, in_gamut, to_hex, to_srgb255


def gray(v: int) -> Oklch:
    """Gris sRGB 8 bits v exprimé en OKLCH (achromatique : L = racine cubique de la luminance)."""
    c = v / 255
    lin = c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    return Oklch(lin ** (1 / 3), 0.0, 0.0)


class FitGamutTest(unittest.TestCase):
    """fit_gamut : couleur dans sRGB, teinte et clarté inchangées."""

    HUES = [5 * i for i in range(72)]

    def test_hue_preserved_and_in_gamut(self):
        for h in self.HUES:
            with self.subTest(h=h):
                col = Oklch(0.53, 0.15, h)
                fit = fit_gamut(col)
                self.assertTrue(in_gamut(fit))
                self.assertEqual((fit.l, fit.h), (col.l, col.h))
                self.assertLessEqual(fit.c, col.c)

    def test_chroma_is_maximal(self):
        """Le chroma rendu est le plus grand possible à 1e-4 près (pas de réduction excessive)."""
        for h in self.HUES:
            fit = fit_gamut(Oklch(0.53, 0.15, h))
            if fit.c < 0.15:
                with self.subTest(h=h):
                    self.assertFalse(in_gamut(fit._replace(c=fit.c + 2e-4)))

    def test_in_gamut_unchanged(self):
        col = Oklch(0.5, 0.02, 120)
        self.assertIs(fit_gamut(col), col)

    def test_some_hues_are_out_of_gamut(self):
        """Garde-fou : le jeu de test exerce bien le rabattement."""
        self.assertTrue(any(not in_gamut(Oklch(0.53, 0.15, h)) for h in self.HUES))

    def test_conversions_extremes(self):
        self.assertEqual(to_hex(Oklch(0, 0, 0)), "#000000")
        self.assertEqual(to_hex(Oklch(1, 0, 0)), "#ffffff")
        self.assertEqual(to_srgb255(gray(136)), (136, 136, 136))


class ApcaTest(unittest.TestCase):
    """apca_lc : paires de référence APCA 0.0.98G-4g."""

    def test_reference_pairs(self):
        black, white = Oklch(0, 0, 0), Oklch(1, 0, 0)
        for text, bg, ref in ((black, white, 106.04), (white, black, -107.88),
                              (gray(136), white, 63.06), (white, gray(136), -68.54)):
            with self.subTest(text=to_hex(text), bg=to_hex(bg)):
                self.assertAlmostEqual(apca_lc(text, bg), ref, delta=0.1)

    def test_same_color_is_zero(self):
        self.assertEqual(apca_lc(gray(100), gray(100)), 0.0)


if __name__ == "__main__":
    unittest.main()
