"""Cible de la coque — les seuils d'alerte de la batterie, lus par EtatEnergie (L2-13).

Copiée par make install vers ~/.config/dunei/energie.json, à côté de motion.json.
"""

from __future__ import annotations

import json


def emit(model: dict) -> str:
    """Texte complet de energie.json.

    Entrée : model — sortie de dunei_energie.model.resolve (clés version et alerte lues).
    Sortie : JSON {_generated, version, alerte : {faible, critique}}, la marque de DuneI sur la deuxième ligne.
    Erreurs : KeyError si model est incomplet. Dépendances : json.
    """
    return json.dumps({"_generated": "GÉNÉRÉ depuis energie.toml par generate_energie.py. Ne pas modifier à la main.",
                       "version": model["version"], "alerte": model["alerte"]}, ensure_ascii=False, indent=2) + "\n"
