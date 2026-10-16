"""Cible Lua — les commandes de l'échelle d'inactivité dont la configuration Hyprland a besoin (L1-10).

Données pures : require("generated.energie") rend une table, sans effet de bord au chargement.
"""

from __future__ import annotations

import json


def emit(model: dict) -> str:
    """Texte complet de energie.lua.

    Entrée : model — sortie de dunei_energie.model.resolve (seule la clé verrouilleur est lue).
    Sortie : module Lua qui rend { verrouilleur = "…" }. Les chaînes JSON sont des chaînes Lua valides
             pour tout texte sans caractère de contrôle ; checks refuse déjà une commande vide.
    Erreurs : KeyError si model est incomplet. Dépendances : json.
    """
    return "\n".join([
        "-- GÉNÉRÉ depuis energie.toml par generate_energie.py — NE PAS MODIFIER À LA MAIN",
        "-- Usage : require(\"generated.energie\").verrouilleur — verrou initial (modules/demarrage.lua, L1-10).",
        "return {",
        f"    verrouilleur = {json.dumps(model['verrouilleur'], ensure_ascii=False)},",
        "}",
    ]) + "\n"
