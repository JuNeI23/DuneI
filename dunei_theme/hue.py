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

from .color import from_srgb255



class HueResult(NamedTuple):
    """Résultat d'extraction.

    Champs : hue — teinte retenue, ou teinte de repli si achromatique ;
             achromatic — vrai si aucune couleur n'a passé les règles ;
             pivot — couleur retenue {rgb, l, c, h}, None si achromatique.
    """
    hue: int
    achromatic: bool
    pivot: dict | None


def score(L: float, C: float, weight: float, ex: dict) -> float:
    """Règles 1 et 2 — chroma pondéré par la surface, extrêmes de luminosité pénalisés.

    Entrées : L, C — luminosité et chroma OKLCH ; weight — surface relative ;
              ex — section [extraction] de tokens.toml.
    Sortie : score ≥ 0, nul pour un quasi-neutre. Erreurs : KeyError si ex incomplet.
    Dépendances : aucune.
    """
    if C < ex["neutral_chroma_max"]:
        return 0.0
    pivot = ex["pivot_lightness"]
    return C * weight * max(0.0, 1.0 - abs(L - pivot) / pivot) ** ex["penalty_exponent"]


def quantize(h: float, step: int) -> int:
    """Règle 4 — teinte arrondie au pas, dans [0, 360) : 358° donne 0, jamais 360.

    Entrées : h — teinte en degrés ; step — pas. Sortie : teinte entière.
    Erreurs : aucune. Dépendances : aucune.
    """
    return round(h / step) * step % 360


def decide(samples: list[tuple[int, int, int, float]], data: dict) -> HueResult:
    """Choix de la teinte parmi des échantillons pondérés.

    Entrées : samples — liste de (r, g, b, poids) ; data — tokens.toml
              (theme.fallback_hue, [extraction]).
    Sortie : HueResult ; achromatic=True et hue=theme.fallback_hue si rien ne passe la règle 2.
    Erreurs : KeyError si data incomplet. Dépendances : color.from_srgb255, score, quantize.
    """
    ex = data["extraction"]
    best = max(((score(lch.l, lch.c, w, ex), lch, (r, g, b)) for r, g, b, w in samples
                for lch in [from_srgb255(r, g, b)]), default=(0.0, None, None))
    if best[0] <= 0:                 # règle 3 : jamais de teinte tirée du bruit
        return HueResult(data["theme"]["fallback_hue"], True, None)
    _, (L, C, H), rgb = best
    return HueResult(quantize(H, ex["hue_step"]), False, {"rgb": list(rgb), "l": L, "c": C, "h": H})


def from_image(path: Path, ex: dict) -> list[tuple[int, int, int, float]]:
    """Échantillons d'une image — groupes de couleurs pondérés par leur surface.

    Entrées : path — chemin de l'image ; ex — section [extraction] (image_max_side,
              image_bucket, image_top_colors).
    Sortie : liste de (r, g, b, part de surface), les image_top_colors plus fréquents.
    Erreurs : FileNotFoundError, PIL.UnidentifiedImageError, ImportError si Pillow/numpy absents.
    Dépendances : Pillow (python-pillow), numpy (python-numpy).
    """
    from PIL import Image
    import numpy as np
    im = Image.open(path).convert("RGB")
    im.thumbnail((ex["image_max_side"],) * 2)
    counts = Counter(map(tuple, (np.asarray(im).reshape(-1, 3) // ex["image_bucket"] * ex["image_bucket"]).tolist()))
    n = sum(counts.values())
    return [(r, g, b, c / n) for (r, g, b), c in counts.most_common(ex["image_top_colors"])]


def from_wal(path: Path | None, ex: dict) -> list[tuple[int, int, int, float]]:
    """Échantillons de la palette wal (colors.json).

    wal ne fournit pas de surface : ses seize couleurs pèsent à égalité, sauf
    les extrêmes de fond et d'avant-plan (wal_extreme_indices : color0, color7,
    color8, color15), ramenés à wal_extreme_weight.

    Entrées : path — colors.json, défaut ex["wal_cache"] ; ex — section [extraction].
    Sortie : liste de (r, g, b, poids).
    Erreurs : FileNotFoundError, json.JSONDecodeError, KeyError si palette incomplète.
    Dépendances : json.
    """
    d = json.loads(Path(path or ex["wal_cache"]).expanduser().read_text(encoding="utf-8"))
    return [(*(int(d["colors"][f"color{i}"].lstrip("#")[j:j + 2], 16) for j in (0, 2, 4)),
             ex["wal_extreme_weight"] if i in ex["wal_extreme_indices"] else 1.0) for i in range(16)]


def categorical(hue: int, offsets: list[int]) -> list[int]:
    """Teintes catégorielles dérivées — décalages fixes de [categorical].hue_offsets.

    Entrées : hue — teinte du thème ; offsets — décalages en degrés.
    Sortie : teintes dans [0, 360). Erreurs : aucune. Dépendances : aucune.
    """
    return [(hue + o) % 360 for o in offsets]
