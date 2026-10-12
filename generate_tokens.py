#!/usr/bin/env python3
"""Générateur des tokens de design — point d'entrée.

Lit tokens.toml, résout le thème, et produit les fichiers consommés par chaque
sous-système. La logique vit dans le paquet dunei_theme.

    python3 generate_tokens.py [--src tokens.toml] [--out generated] [--hue 40]

L'option --hue simule un autre thème machine sans toucher au fichier source.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from dunei_theme.checks import check
from dunei_theme.emitters import TARGETS
from dunei_theme.model import load, resolve


def main() -> int:
    """Génération de toutes les cibles.

    Entrées : arguments de ligne de commande --src, --out, --hue.
    Sortie : code de retour 0 si succès, 1 si la source est introuvable.
    Erreurs : « source introuvable » sur stderr ; avertissements de check sur stderr.
    Dépendances : dunei_theme (model, checks, emitters).
    """
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--src", default=Path("tokens.toml"), type=Path)
    ap.add_argument("--out", default=Path("generated"), type=Path)
    ap.add_argument("--hue", type=float, default=None, help="simuler une autre teinte machine")
    args = ap.parse_args()

    if not args.src.exists():
        print(f"source introuvable : {args.src}", file=sys.stderr)
        return 1

    model = resolve(load(args.src), args.hue)
    for w in check(model):
        print(f"  avertissement : {w}", file=sys.stderr)

    args.out.mkdir(parents=True, exist_ok=True)
    for filename, emitter in TARGETS.items():
        (args.out / filename).write_text(emitter(model), encoding="utf-8")
        print(f"  écrit {args.out / filename}")

    print(f"\nThème teinte {model['hue']}° généré vers {len(TARGETS)} cibles.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
