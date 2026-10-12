"""Cible JSON — modèle résolu, pour les outils qui ne lisent pas le CSS."""

from __future__ import annotations

import json

from ..color import Oklch


def _serial(v):
    """Sérialisation — Oklch en notation CSS, conteneurs parcourus récursivement.

    Entrée : v — valeur du modèle. Sortie : valeur sérialisable en JSON.
    Erreurs : aucune. Dépendances : Oklch.
    """
    if isinstance(v, Oklch):
        return v.css()
    if isinstance(v, dict):
        return {k: _serial(x) for k, x in v.items()}
    if isinstance(v, list):
        return [_serial(x) for x in v]
    return v


def emit(model: dict) -> str:
    """Modèle résolu, sans le TOML brut.

    Entrée : model — sortie de model.resolve.
    Sortie : contenu de tokens.json. Erreurs : aucune. Dépendances : json.
    """
    return json.dumps(_serial({k: v for k, v in model.items() if k != "raw"}), indent=2, ensure_ascii=False) + "\n"
