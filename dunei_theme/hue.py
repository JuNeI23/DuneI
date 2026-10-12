"""Extraction de teinte — applique les cinq règles de la bible (ch. 2).

La sortie est une teinte quantifiée, et rien d'autre : luminosité et chroma
sont imposés par l'échelle. Une source achromatique n'est pas tranchée ici :
le résultat le signale, et le choix revient à l'utilisateur.
"""

from __future__ import annotations

import json
import math
from collections import Counter
from pathlib import Path
from typing import NamedTuple

# Paramètres d'extraction — à migrer dans tokens.toml (section [extraction]).
NEUTRAL_CHROMA_MAX = 0.03        # règle 2 : sous ce chroma, un pixel est neutre
HUE_STEP = 5                     # règle 4 : pas de quantification, en degrés
PIVOT_LIGHTNESS = 0.55           # règle 1 : luminosité sans pénalité
PENALTY_EXPONENT = 1.5           # règle 1 : raideur de la pénalité des extrêmes
WAL_EXTREME_INDICES = (0, 7, 8, 15)  # couleurs wal de fond et d'avant-plan
WAL_EXTREME_WEIGHT = 0.2         # leur poids, les autres valant 1
IMAGE_MAX_SIDE = 400             # px — réduction avant analyse
IMAGE_BUCKET = 16                # regroupement des canaux sRGB 8 bits
IMAGE_TOP_COLORS = 64            # nombre de groupes retenus
WAL_CACHE = "~/.cache/wal/colors.json"


class HueResult(NamedTuple):
    """Résultat d'extraction.

    Champs : hue — teinte retenue, ou teinte de repli si achromatique ;
             achromatic — vrai si aucune couleur n'a passé les règles ;
             pivot — couleur retenue {rgb, l, c, h}, None si achromatique.
    """
    hue: int
    achromatic: bool
    pivot: dict | None


def srgb_to_oklch(r: int, g: int, b: int) -> tuple[float, float, float]:
    """sRGB 8 bits → OKLCH.

    Entrées : r, g, b — canaux 0–255.
    Sortie : (L, C, H en degrés). Erreurs : aucune.
    Dépendances : math. Matrices : Björn Ottosson, « A perceptual color space ».
    """
    def lin(c):
        c /= 255.0
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    R, G, B = lin(r), lin(g), lin(b)
    l = (0.4122214708 * R + 0.5363325363 * G + 0.0514459929 * B) ** (1 / 3)
    m = (0.2119034982 * R + 0.6806995451 * G + 0.1073969566 * B) ** (1 / 3)
    s = (0.0883024619 * R + 0.2817188376 * G + 0.6299787005 * B) ** (1 / 3)
    L = 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s
    a = 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s
    bb = 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s
    return L, math.hypot(a, bb), math.degrees(math.atan2(bb, a)) % 360


def score(L: float, C: float, weight: float) -> float:
    """Règles 1 et 2 — chroma pondéré par la surface, extrêmes de luminosité pénalisés.

    Entrées : L, C — luminosité et chroma OKLCH ; weight — surface relative.
    Sortie : score ≥ 0, nul pour un quasi-neutre. Erreurs : aucune.
    Dépendances : constantes NEUTRAL_CHROMA_MAX, PIVOT_LIGHTNESS, PENALTY_EXPONENT.
    """
    if C < NEUTRAL_CHROMA_MAX:
        return 0.0
    return C * weight * max(0.0, 1.0 - abs(L - PIVOT_LIGHTNESS) / PIVOT_LIGHTNESS) ** PENALTY_EXPONENT


def quantize(h: float, step: int = HUE_STEP) -> int:
    """Règle 4 — teinte arrondie au pas, dans [0, 360) : 358° donne 0, jamais 360.

    Entrées : h — teinte en degrés ; step — pas. Sortie : teinte entière.
    Erreurs : aucune. Dépendances : aucune.
    """
    return round(h / step) * step % 360


def decide(samples: list[tuple[int, int, int, float]], fallback_hue: int) -> HueResult:
    """Choix de la teinte parmi des échantillons pondérés.

    Entrées : samples — liste de (r, g, b, poids) ; fallback_hue — teinte de repli (theme.fallback_hue).
    Sortie : HueResult ; achromatic=True et hue=fallback_hue si rien ne passe la règle 2.
    Erreurs : aucune. Dépendances : srgb_to_oklch, score, quantize.
    """
    best = max(((score(*lch[:2], w), lch, (r, g, b)) for r, g, b, w in samples
                for lch in [srgb_to_oklch(r, g, b)]), default=(0.0, None, None))
    if best[0] <= 0:                 # règle 3 : jamais de teinte tirée du bruit
        return HueResult(fallback_hue, True, None)
    _, (L, C, H), rgb = best
    return HueResult(quantize(H), False, {"rgb": list(rgb), "l": L, "c": C, "h": H})


def from_image(path: Path) -> list[tuple[int, int, int, float]]:
    """Échantillons d'une image — groupes de couleurs pondérés par leur surface.

    Entrée : path — chemin de l'image.
    Sortie : liste de (r, g, b, part de surface), les IMAGE_TOP_COLORS plus fréquents.
    Erreurs : FileNotFoundError, PIL.UnidentifiedImageError, ImportError si Pillow/numpy absents.
    Dépendances : Pillow (python-pillow), numpy (python-numpy).
    """
    from PIL import Image
    import numpy as np
    im = Image.open(path).convert("RGB")
    im.thumbnail((IMAGE_MAX_SIDE, IMAGE_MAX_SIDE))
    counts = Counter(map(tuple, (np.asarray(im).reshape(-1, 3) // IMAGE_BUCKET * IMAGE_BUCKET).tolist()))
    n = sum(counts.values())
    return [(r, g, b, c / n) for (r, g, b), c in counts.most_common(IMAGE_TOP_COLORS)]


def from_wal(path: Path | None = None) -> list[tuple[int, int, int, float]]:
    """Échantillons de la palette wal (colors.json).

    wal ne fournit pas de surface : ses seize couleurs pèsent à égalité, sauf
    les extrêmes de fond et d'avant-plan (WAL_EXTREME_INDICES : color0, color7,
    color8, color15), ramenés à WAL_EXTREME_WEIGHT.

    Entrée : path — colors.json, défaut WAL_CACHE.
    Sortie : liste de (r, g, b, poids).
    Erreurs : FileNotFoundError, json.JSONDecodeError, KeyError si palette incomplète.
    Dépendances : json.
    """
    d = json.loads(Path(path or WAL_CACHE).expanduser().read_text(encoding="utf-8"))
    return [(*(int(d["colors"][f"color{i}"].lstrip("#")[j:j + 2], 16) for j in (0, 2, 4)),
             WAL_EXTREME_WEIGHT if i in WAL_EXTREME_INDICES else 1.0) for i in range(16)]


def categorical(hue: int, offsets: list[int]) -> list[int]:
    """Teintes catégorielles dérivées — décalages fixes de [categorical].hue_offsets.

    Entrées : hue — teinte du thème ; offsets — décalages en degrés.
    Sortie : teintes dans [0, 360). Erreurs : aucune. Dépendances : aucune.
    """
    return [(hue + o) % 360 for o in offsets]
