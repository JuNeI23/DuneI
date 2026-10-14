"""Cible Hyprland 0.56 — modules Lua de géométrie, d'ombre et de règles de fenêtre.

Chaque module RETOURNE des données, sans appeler `hl` lui-même :
    hl.config(require("generated.hyprland-tokens"))
Données pures, sans effet de bord au chargement : la configuration choisit quand
et comment les appliquer, un fragment machine peut les surcharger ensuite, et le
fichier se vérifie avec un interpréteur Lua nu, sans Hyprland.
"""

from __future__ import annotations

from ..color import Oklch, to_srgb255


def _rgba(col: Oklch, alpha: float) -> str:
    """Couleur translucide au format Hyprland `rgba(rrggbbaa)`.

    Entrées : col — couleur ; alpha — opacité de 0 à 1.
    Sortie : chaîne hexadécimale. Erreurs : aucune. Dépendances : color.to_srgb255.
    """
    return "rgba({:02x}{:02x}{:02x}{:02x})".format(*to_srgb255(col), round(alpha * 255))


def _validate(raw: dict) -> None:
    """Contrôles bloquants des jetons de fenêtre.

    Entrée : raw — TOML brut du modèle.
    Sortie : aucune.
    Erreurs : ValueError si la portée ou le décalage de l'ombre flottante n'est pas un multiple de la
              base (bible, ch. 3), si render_power sort des bornes de Hyprland (1 à 4), ou si
              border_width ou radii.fullscreen est négatif.
    Dépendances : aucune.
    """
    s, base = raw["window"]["floating_shadow"], raw["scaling"]["height_multiple"]
    for key in ("range", "offset_y"):
        if s[key] % base:
            raise ValueError(f"window.floating_shadow.{key} = {s[key]} n'est pas un multiple de {base}")
    if not 1 <= s["render_power"] <= 4:
        raise ValueError(f"window.floating_shadow.render_power = {s['render_power']} hors des bornes de Hyprland (1 à 4)")
    for name, val in (("window.border_width", raw["window"]["border_width"]), ("radii.fullscreen", raw["radii"]["fullscreen"])):
        if val < 0:
            raise ValueError(f"{name} = {val} : entier positif ou nul attendu")


def emit(model: dict) -> str:
    """Module Lua des options `general` et `decoration` de Hyprland.

    Entrée : model — sortie de model.resolve.
    Sortie : contenu de hyprland-tokens.lua (une table Lua retournée).
    Erreurs : KeyError si le TOML brut manque ; ValueError transmise par _validate.
    Dépendances : _validate, _rgba, color.Oklch.
    """
    raw = model["raw"]
    _validate(raw)
    d, s, mat = raw["density"]["comfortable"], raw["window"]["floating_shadow"], raw["surface_material"]
    return "\n".join([
        "-- GÉNÉRÉ depuis tokens.toml — NE PAS MODIFIER À LA MAIN",
        "-- Usage : hl.config(require(\"generated.hyprland-tokens\"))",
        f"-- thème : teinte {model['hue']}°",
        "return {",
        "    general = {",
        # Hyprland applique gaps_in de chaque côté : deux voisines donnent la gouttière entière.
        f"        gaps_in     = {d['tiling_gutter'] // 2},",
        f"        gaps_out    = {d['tiling_margin']},",
        f"        border_size = {raw['window']['border_width']},",
        "    },",
        "    decoration = {",
        f"        rounding = {raw['radii']['window']},",
        # Ombre globale de la couche 2 ; hyprland-rules.lua la retire aux fenêtres tuilées.
        "        shadow = {",
        "            enabled      = true,",
        f"            range        = {s['range']},",
        f"            render_power = {s['render_power']},",
        f"            offset       = {{ 0, {s['offset_y']} }},",
        f"            color        = \"{_rgba(Oklch(**mat['shadow_color']), mat['shade_opacity'])}\",",
        "        },",
        "    },",
        "}",
    ]) + "\n"
