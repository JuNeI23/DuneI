#!/usr/bin/env python3
"""Extracteur de teinte — point d'entrée. La logique vit dans dunei_theme.hue.

    python3 extract_hue.py image.jpg [--src tokens.toml] [--json]
    python3 extract_hue.py --wal [colors.json] [--src tokens.toml] [--json]

Codes de retour (lus par le futur panneau de thème) :
    0  teinte extraite
    1  erreur : source, image ou palette illisible, dépendance absente
    2  usage incorrect (argparse)
    3  source achromatique : la teinte de repli est PROPOSÉE, l'utilisateur choisit
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from dunei_theme.hue import categorical, decide, from_image, from_wal
from dunei_theme.model import load

EXIT_OK, EXIT_ERROR, EXIT_ACHROMATIC = 0, 1, 3


def main() -> int:
    """Extraction de la teinte d'une image ou de la palette wal.

    Entrées : arguments image | --wal [chemin], --src, --json.
    Sortie : code de retour EXIT_OK, EXIT_ERROR ou EXIT_ACHROMATIC (voir en-tête).
             --json : {"hue", "achromatic", "pivot"} sur stdout.
    Erreurs : message « erreur : … » sur stderr si la lecture échoue.
    Dépendances : dunei_theme (hue, model) ; Pillow et numpy pour une image.
    """
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    src = ap.add_mutually_exclusive_group(required=True)
    src.add_argument("image", nargs="?", type=Path, help="image à analyser")
    src.add_argument("--wal", nargs="?", const="", metavar="COLORS_JSON", help="palette wal (défaut ~/.cache/wal/colors.json)")
    ap.add_argument("--src", default=Path("tokens.toml"), type=Path)
    ap.add_argument("--json", action="store_true", help="sortie machine")
    args = ap.parse_args()

    try:
        data = load(args.src)
        ex = data["extraction"]
        samples = from_image(args.image, ex) if args.image else from_wal(args.wal or None, ex)
    except Exception as e:  # toute lecture ratée a la même issue : on le dit et on sort
        print(f"erreur : {e}", file=sys.stderr)
        return EXIT_ERROR

    res = decide(samples, data)
    code = EXIT_ACHROMATIC if res.achromatic else EXIT_OK
    if args.json:
        print(json.dumps(res._asdict()))
        return code

    print(f"source        : {args.image or 'wal'}")
    if res.achromatic:
        print("verdict       : image ACHROMATIQUE, aucune teinte n'en est tirée")
        print(f"teinte PROPOSÉE (repli) : {res.hue}°")
        print(f"pour en choisir une autre : python3 generate_tokens.py --hue N  (0–360, pas de {data['extraction']['hue_step']}°)")
    else:
        p = res.pivot
        print(f"couleur pivot : rgb{tuple(p['rgb'])}  L={p['l']:.3f}  C={p['c']:.3f}  H={p['h']:.1f}°")
        print(f"TEINTE RETENUE: {res.hue}°")
    print("catégorielles :", " · ".join(f"{h}°" for h in categorical(res.hue, data["categorical"]["hue_offsets"])))
    print("\nLa teinte extraite n'est qu'un défaut : elle se règle ensuite dans le panneau de thème.")
    return code


if __name__ == "__main__":
    raise SystemExit(main())
