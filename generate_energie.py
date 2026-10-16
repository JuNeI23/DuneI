#!/usr/bin/env python3
"""Générateur de l'échelle d'inactivité — point d'entrée.

Lit energie.toml, vérifie l'ordre des paliers, puis produit la configuration de hypridle.
La logique vit dans le paquet dunei_energie.

    python3 generate_energie.py [--src energie.toml] [--out generated]
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from dunei_energie.checks import errors
from dunei_energie.emitters import TARGETS
from dunei_energie.model import load, resolve


def main() -> int:
    """Génération de toutes les cibles de l'échelle d'inactivité.

    Entrées : arguments de ligne de commande --src et --out.
    Sortie : code de retour 0 si succès, 1 si la source est absente, illisible ou fautive.
    Erreurs : messages sur la sortie d'erreur ; aucun fichier n'est écrit en cas d'erreur.
    Dépendances : dunei_energie (model, checks, emitters).
    """
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--src", default=Path("energie.toml"), type=Path)
    ap.add_argument("--out", default=Path("generated"), type=Path)
    args = ap.parse_args()

    try:
        raw = load(args.src)
    except (OSError, ValueError) as e:   # ValueError couvre la syntaxe TOML et l'encodage.
        print(f"source illisible : {args.src} ({e})", file=sys.stderr)
        return 1

    if errs := errors(raw):
        for e in errs:
            print(f"  erreur : {e}", file=sys.stderr)
        print(f"\n{len(errs)} erreur(s) : aucun fichier écrit.", file=sys.stderr)
        return 1

    model = resolve(raw)
    args.out.mkdir(parents=True, exist_ok=True)
    for filename, emitter in TARGETS.items():
        (args.out / filename).write_text(emitter(model), encoding="utf-8")
        print(f"  écrit {args.out / filename}")
    print(f"\nÉchelle générée : {sum(map(len, model['paliers'].values()))} paliers vers {len(TARGETS)} cible(s).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
