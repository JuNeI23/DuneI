#!/usr/bin/env python3
"""Mesure des planchers de contraste — point d'entrée. La logique vit dans dunei_theme.checks.

    python3 mesure_planchers.py [--src tokens.toml]

Imprime la table [meta.planchers] : pour chaque clé de checks.mesures, le plus petit Lc de la nuit de la famille par défaut
(la thématisée) aux teintes 0, 55, 200 et 265, arrondi à l'entier inférieur. Code de retour 0.
"""

from __future__ import annotations

import argparse
from pathlib import Path

from dunei_theme.checks import mesures
from dunei_theme.model import defaut, load, resolve, theme_data

HUES = (0, 55, 200, 265)


def main() -> int:
    """Impression de la table des planchers.

    Entrée : argument --src (tokens.toml par défaut).
    Sortie : code de retour 0 ; la table TOML sur stdout.
    Erreurs : FileNotFoundError si la source manque ; KeyError si elle est incomplète.
    Dépendances : dunei_theme (model, checks). Les planchers propres au jour (knob-off, on-accent-muted, jour
    thématisé) se relèvent à la main : ce script ne mesure que la nuit.
    """
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--src", default=Path("tokens.toml"), type=Path)
    data = load(ap.parse_args().src)
    nuit = theme_data(data, defaut(data)[0], "nuit")
    par_teinte = [mesures(resolve(nuit, h)) for h in HUES]
    print("[meta.planchers]")
    for cle in par_teinte[0]:
        print(f'"{cle}" = {int(min(m[cle] for m in par_teinte))}')
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
