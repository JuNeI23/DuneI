#!/usr/bin/env python3
"""Générateur du mouvement — point d'entrée.

Lit motion.toml, vérifie les règles du chapitre 6 de la bible et l'API d'animation
de Hyprland, puis produit les fichiers consommés par le compositeur et la coque.
La logique vit dans le paquet dunei_motion.

    python3 generate_motion.py [--src motion.toml] [--out generated]
"""

from __future__ import annotations

import argparse
import sys
import tomllib
from pathlib import Path

from dunei_motion.checks import errors, warnings
from dunei_motion.emitters import TARGETS
from dunei_motion.model import load, resolve


def main() -> int:
    """Génération de toutes les cibles du mouvement.

    Entrées : arguments de ligne de commande --src et --out.
    Sortie : code de retour 0 si succès, 1 si la source est absente, illisible ou non conforme.
    Erreurs : messages sur la sortie d'erreur ; aucun fichier n'est écrit en cas d'erreur.
    Dépendances : dunei_motion (model, checks, emitters).
    """
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--src", default=Path("motion.toml"), type=Path)
    ap.add_argument("--out", default=Path("generated"), type=Path)
    args = ap.parse_args()

    try:
        raw = load(args.src)
    except (OSError, tomllib.TOMLDecodeError) as e:
        print(f"source illisible : {args.src} ({e})", file=sys.stderr)
        return 1

    if errs := errors(raw):
        for e in errs:
            print(f"  erreur : {e}", file=sys.stderr)
        print(f"\n{len(errs)} erreur(s) : aucun fichier écrit.", file=sys.stderr)
        return 1

    model = resolve(raw)
    for w in warnings(model):
        print(f"  avertissement : {w}", file=sys.stderr)

    args.out.mkdir(parents=True, exist_ok=True)
    for filename, emitter in TARGETS.items():
        (args.out / filename).write_text(emitter(model), encoding="utf-8")
        print(f"  écrit {args.out / filename}")

    print(f"\nMouvement généré : {len(model['transitions'])} transitions vers {len(TARGETS)} cibles.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
