#!/usr/bin/env python3
"""
Extracteur de teinte — applique les cinq règles de la bible.

Deux modes :
    python3 extract_hue.py --wal            lit ~/.cache/wal/colors.json
    python3 extract_hue.py image.jpg        analyse directement une image

Dans les deux cas, la sortie est LA MÊME : une teinte, quantifiée par pas de 5°.
Ni luminosité ni chroma ne sont repris — ils sont imposés par notre échelle.
"""
import json, math, sys
from collections import Counter


def srgb_to_oklch(r, g, b):
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
    C = math.hypot(a, bb)
    H = math.degrees(math.atan2(bb, a)) % 360
    return L, C, H


def score(L, C, weight):
    """Règle 1 : pondérer le chroma par la surface, pénaliser les luminosités
    extrêmes. Une couleur très sombre ou très claire ne fait pas une identité."""
    if C < 0.03:                      # Règle 2 : rejet des quasi-neutres
        return 0.0
    penalty = 1.0 - abs(L - 0.55) / 0.55
    return C * weight * max(0.0, penalty) ** 1.5


def decide(samples, fallback_hue=255):
    """samples : liste de (r, g, b, poids)."""
    best, total_c = [], 0.0
    for r, g, b, w in samples:
        L, C, H = srgb_to_oklch(r, g, b)
        s = score(L, C, w)
        total_c += C * w
        if s > 0:
            best.append((s, L, C, H, (r, g, b)))
    if not best:                      # Règle 3 : fond achromatique → repli
        return fallback_hue, None, True
    best.sort(reverse=True)
    s, L, C, H, rgb = best[0]
    return round(H / 5) * 5, (L, C, H, rgb), False   # Règle 4 : pas de 5°


def from_image(path, max_side=400):
    from PIL import Image
    import numpy as np
    im = Image.open(path).convert("RGB")
    im.thumbnail((max_side, max_side))
    a = np.array(im).reshape(-1, 3)
    q = (a // 16 * 16).astype(int)
    counts = Counter(map(tuple, q))
    n = sum(counts.values())
    return [(r, g, b, c / n) for (r, g, b), c in counts.most_common(64)]


def from_wal(path=None):
    import os
    path = path or os.path.expanduser("~/.cache/wal/colors.json")
    d = json.load(open(path))
    out = []
    for i in range(16):
        h = d["colors"][f"color{i}"].lstrip("#")
        r, g, b = (int(h[j:j + 2], 16) for j in (0, 2, 4))
        # wal ne fournit pas de surface : on pondère à égalité, sauf color0 et
        # color15 qui sont des extrêmes de fond et d'avant-plan.
        out.append((r, g, b, 0.2 if i in (0, 7, 8, 15) else 1.0))
    return out


if __name__ == "__main__":
    args = sys.argv[1:]
    if args and args[0] == "--wal":
        samples = from_wal(args[1] if len(args) > 1 else None)
        src = "wal"
    else:
        samples = from_image(args[0])
        src = args[0]

    hue, detail, fell_back = decide(samples)
    print(f"source        : {src}")
    if fell_back:
        print("verdict       : source achromatique → repli sur la teinte par défaut")
    else:
        L, C, H, rgb = detail
        print(f"couleur pivot : rgb{rgb}  L={L:.3f}  C={C:.3f}  H={H:.1f}°")
    print(f"TEINTE RETENUE: {hue}°")

    # Palette catégorielle telle que la générerait le moteur
    offs = [0, 40, 95, 160, -60]
    print("catégorielles :", " · ".join(f"{(hue + o) % 360}°" for o in offs))

    print()
    print("La teinte extraite n'est qu'un défaut : elle se règle ensuite dans")
    print("le panneau de thème, sans repasser par ce script.")
