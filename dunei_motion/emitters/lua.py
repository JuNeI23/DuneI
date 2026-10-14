"""Cible Hyprland 0.56 — module Lua des ressorts et des animations.

Le module RETOURNE une table, sans appeler hl.curve ni hl.animation lui-même :
config/hypr/modules/motion.lua l'applique, en mode normal ou réduit. Le fichier
se vérifie donc avec un interpréteur Lua nu, sans Hyprland.
"""

from __future__ import annotations

import json


def value(v) -> str:
    """Littéral Lua d'une valeur simple.

    Entrée : v — booléen, nombre ou chaîne.
    Sortie : texte Lua ; les nombres sont écrits sans zéro superflu (1100, 0.5, 2244.9).
    Erreurs : aucune. Dépendances : json, pour l'échappement des chaînes.
    """
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return f"{v:.10g}"
    return json.dumps(v, ensure_ascii=False)


def table(d: dict) -> str:
    """Table Lua sur une ligne, dans l'ordre des clés.

    Entrée : d — dictionnaire de valeurs simples.
    Sortie : texte « { clé = valeur, … } ». Erreurs : aucune. Dépendances : value.
    """
    return "{ " + ", ".join(f"{k} = {value(v)}" for k, v in d.items()) + " }"


def emit(model: dict) -> str:
    """Module Lua des courbes et des deux jeux d'animations.

    Entrée : model — sortie de model.resolve.
    Sortie : contenu de motion.lua (une table Lua retournée).
    Erreurs : KeyError si le modèle est incomplet. Dépendances : table.
    """
    return "\n".join([
        "-- GÉNÉRÉ depuis motion.toml par generate_motion.py. Ne pas modifier à la main.",
        '-- Usage : require("modules.motion").apply(false)',
        "return {",
        "    -- Courbes : un ressort d'entrée et un ressort de sortie par transition, plus le fondu réduit.",
        "    curves = {",
        *(f'        ["{name}"] = {table({"type": "spring", **s})},' for name, s in model["curves"].items()),
        "    },",
        "    -- Animations du mode normal, une entrée par élément de Hyprland, global en premier.",
        "    animations = {",
        *(f"        {table(a)}," for a in model["animations"]),
        "    },",
        "    -- Animations du mouvement réduit : mêmes éléments, fondu court, sans déplacement ni changement d'échelle.",
        "    reduced = {",
        *(f"        {table(a)}," for a in model["reduced_animations"]),
        "    },",
        "}",
    ]) + "\n"
