"""Résolution de l'échelle d'inactivité — energie.toml → paliers ordonnés par alimentation."""

from __future__ import annotations

import tomllib
from pathlib import Path

from .checks import ALIMENTATIONS, ORDRE


def load(src: Path) -> dict:
    """Lecture de la source de l'échelle d'inactivité.

    Entrée : src — chemin d'energie.toml.
    Sortie : dictionnaire brut du TOML.
    Erreurs : FileNotFoundError si absent, tomllib.TOMLDecodeError si invalide.
    Dépendances : tomllib.
    """
    with src.open("rb") as fh:
        return tomllib.load(fh)


def resolve(raw: dict) -> dict:
    """Résolution d'une source déjà validée par checks.errors.

    Entrée : raw — sortie de load.
    Sortie : {verrouiller, verrouilleur, niveau, paliers : {alimentation : [(palier, délai), …]}},
             paliers dans l'ordre ORDRE, sans ceux qui manquent pour l'alimentation.
    Erreurs : KeyError si raw n'a pas été validé. Dépendances : ORDRE, ALIMENTATIONS.
    """
    p = raw["paliers"]
    return {**raw["commandes"], "niveau": raw["attenuation"]["niveau"],
            "paliers": {a: [(n, p[n][a]) for n in ORDRE if a in p.get(n, {})] for a in ALIMENTATIONS}}
