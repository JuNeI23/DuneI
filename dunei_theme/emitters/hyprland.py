"""Cible Hyprland 0.56 — module Lua de géométrie et de bordures (couche 1, tuilage).

Le module RETOURNE une table d'options, sans appeler `hl.config` lui-même :
    hl.config(require("generated.hyprland-tokens"))
Données pures, sans effet de bord au chargement : la configuration choisit quand
et comment l'appliquer, un fragment machine peut la surcharger ensuite, et le
fichier se vérifie avec un interpréteur Lua nu, sans Hyprland.
"""

from __future__ import annotations

from ..color import to_hex


def emit(model: dict) -> str:
    """Module Lua des options `general` et `decoration` de Hyprland.

    Entrée : model — sortie de model.resolve.
    Sortie : contenu de hyprland-tokens.lua (une table Lua retournée).
    Erreurs : KeyError si le TOML brut ou le rôle border-subtle manque.
    Dépendances : color.to_hex (Hyprland accepte « #rrggbb »).
    """
    raw = model["raw"]
    d = raw["density"]["comfortable"]
    return "\n".join([
        "-- GÉNÉRÉ depuis tokens.toml — NE PAS MODIFIER À LA MAIN",
        "-- Usage : hl.config(require(\"generated.hyprland-tokens\"))",
        f"-- thème : teinte {model['hue']}°",
        "return {",
        "    general = {",
        # Hyprland applique gaps_in de chaque côté : deux voisines donnent la gouttière entière.
        f"        gaps_in     = {d['tiling_gutter'] // 2},",
        f"        gaps_out    = {d['tiling_margin']},",
        # La bordure active EST l'anneau de focus de la fenêtre : même épaisseur.
        f"        border_size = {raw['states']['focus']['ring_width']},",
        "        col = {",
        f"            active_border   = \"{to_hex(model['accent'])}\",",
        # Inactive : neutre, comme la sélection inactive (échelon du liseré discret).
        f"            inactive_border = \"{to_hex(model['roles']['border-subtle'])}\",",
        "        },",
        "    },",
        "    decoration = {",
        f"        rounding = {raw['radii']['window']},",
        # Couche 1 = E1 : aucune ombre.
        f"        shadow   = {{ enabled = {str(raw['elevation']['e1']['shadow']).lower()} }},",
        "    },",
        "}",
    ]) + "\n"
