"""Couleurs OKLCH et leur conversion vers sRGB."""

from __future__ import annotations

import math
from typing import NamedTuple


class Oklch(NamedTuple):
    """Couleur OKLCH — valeur manipulée par toute la chaîne.

    Champs : l (0–1), c (chroma ≥ 0), h (teinte en degrés).
    Les valeurs sont arrondies à la création (L 3 décimales, C 4) : ce sont
    celles écrites dans les fichiers générés, donc celles qu'on convertit.
    """
    l: float
    c: float
    h: float

    def css(self) -> str:
        """Notation CSS — `oklch(L C H)`.

        Sortie : chaîne CSS. Erreurs : aucune. Dépendances : aucune.
        """
        return f"oklch({self.l:.3f} {self.c:.4f} {self.h:g})"


def oklch(l: float, c: float, h: float, ceiling: float) -> Oklch:
    """Construction d'une couleur — plafonne le chroma au plafond de gamut.

    Entrées : l, c, h — composantes ; ceiling — chroma maximal.
    Sortie : Oklch arrondie. Erreurs : aucune. Dépendances : Oklch.
    """
    return Oklch(round(l, 3), round(min(c, ceiling), 4), h)


def to_linear_srgb(col: Oklch) -> tuple[float, float, float]:
    """OKLCH → sRGB linéaire, sans rabattement (valeurs possiblement hors [0, 1]).

    Entrée : col. Sortie : (r, g, b) linéaires. Erreurs : aucune.
    Dépendances : math. Matrices : Björn Ottosson, « A perceptual color space ».
    """
    h = math.radians(col.h)
    a, b = col.c * math.cos(h), col.c * math.sin(h)
    l3 = (col.l + 0.3963377774 * a + 0.2158037573 * b) ** 3
    m3 = (col.l - 0.1055613458 * a - 0.0638541728 * b) ** 3
    s3 = (col.l - 0.0894841775 * a - 1.2914855480 * b) ** 3
    return (4.0767416621 * l3 - 3.3077115913 * m3 + 0.2309699292 * s3,
            -1.2684380046 * l3 + 2.6097574011 * m3 - 0.3413193965 * s3,
            -0.0041960863 * l3 - 0.7034186147 * m3 + 1.7076147010 * s3)


def to_srgb255(col: Oklch) -> tuple[int, int, int]:
    """OKLCH → sRGB 8 bits, écrêté canal par canal.

    Entrée : col. Sortie : (R, G, B) sur 0–255. Erreurs : aucune.
    Dépendances : to_linear_srgb.
    """
    out = []
    for c in to_linear_srgb(col):
        c = max(0.0, min(1.0, c))
        c = 12.92 * c if c <= 0.0031308 else 1.055 * c ** (1 / 2.4) - 0.055
        out.append(round(c * 255))
    return tuple(out)


def to_hex(col: Oklch) -> str:
    """OKLCH → `#rrggbb`.

    Entrée : col. Sortie : chaîne hexadécimale. Erreurs : aucune.
    Dépendances : to_srgb255.
    """
    return "#%02x%02x%02x" % to_srgb255(col)


def to_rgb_csv(col: Oklch) -> str:
    """OKLCH → `R,G,B` décimal, format des schémas de couleurs KDE.

    Entrée : col. Sortie : chaîne `R,G,B`. Erreurs : aucune.
    Dépendances : to_srgb255.
    """
    return ",".join(str(v) for v in to_srgb255(col))
