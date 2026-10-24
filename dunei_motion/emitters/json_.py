"""Cible JSON — ressorts du mouvement pour la future coque Quickshell."""

from __future__ import annotations

import json


def emit(model: dict) -> str:
    """Ressorts d'entrée, de sortie et réduit, avec leurs grandeurs indicatives, puis délais et périodes.

    JSON n'a pas de commentaires : l'avertissement « généré » est la clé `_generated`, placée en tête.
    Entrée : model — sortie de model.resolve.
    Sortie : contenu de motion.json. Erreurs : KeyError si le modèle est incomplet. Dépendances : json.
    """
    out = {
        "_generated": "GÉNÉRÉ depuis motion.toml par generate_motion.py. Ne pas modifier à la main.",
        "version": model["version"],
        "rules": model["rules"],
        "delays": model["delays"],
        "periods": model["periods"],
        "transitions": model["transitions"],
        "reduced": model["reduced"],
    }
    return json.dumps(out, indent=2, ensure_ascii=False) + "\n"
