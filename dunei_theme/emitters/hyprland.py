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
    Erreurs : ValueError si un jeton n'est pas un entier (un booléen est refusé), si la portée de
              l'ombre flottante sort de 1 à 100 (bornes de Hyprland, 0 éteindrait l'ombre), si la portée
              ou le décalage n'est pas un multiple de la base (bible, ch. 3), si render_power sort de 1
              à 4 (bornes de Hyprland), si border_width ou radii.fullscreen est négatif, ou si
              window.resize_step n'appartient pas à spacing.scale (le pas de redimensionnement reste
              sur l'échelle des espacements).
    Dépendances : aucune.
    """
    s, base = raw["window"]["floating_shadow"], raw["scaling"]["height_multiple"]
    tokens = {f"window.floating_shadow.{k}": s[k] for k in ("range", "offset_y", "render_power")}
    tokens |= {"window.border_width": raw["window"]["border_width"], "radii.fullscreen": raw["radii"]["fullscreen"]}
    tokens["window.resize_step"] = raw["window"]["resize_step"]
    for name, val in tokens.items():
        if type(val) is not int:
            raise ValueError(f"{name} = {val!r} : entier attendu")
    if not 1 <= s["range"] <= 100:
        raise ValueError(f"window.floating_shadow.range = {s['range']} hors des bornes de Hyprland (1 à 100)")
    for key in ("range", "offset_y"):
        if s[key] % base:
            raise ValueError(f"window.floating_shadow.{key} = {s[key]} n'est pas un multiple de {base}")
    if not 1 <= s["render_power"] <= 4:
        raise ValueError(f"window.floating_shadow.render_power = {s['render_power']} hors des bornes de Hyprland (1 à 4)")
    for name in ("window.border_width", "radii.fullscreen"):
        if tokens[name] < 0:
            raise ValueError(f"{name} = {tokens[name]} : entier positif ou nul attendu")
    if tokens["window.resize_step"] not in raw["spacing"]["scale"]:
        raise ValueError(f"window.resize_step = {tokens['window.resize_step']} n'appartient pas à "
                         f"spacing.scale {raw['spacing']['scale']}")


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


def emit_rules(model: dict) -> str:
    """Module Lua des règles de fenêtre d'apparence, dérivées des jetons.

    Entrée : model — sortie de model.resolve.
    Sortie : contenu de hyprland-rules.lua (une liste Lua retournée, appliquée par modules/regles.lua).
             La règle de la couche 1 n'existe que si E1 n'a pas d'ombre. Le plein écran vise l'état
             interne 2 seul : une fenêtre agrandie (état 1) garde ses gouttières et ses coins, comme
             une tuile (D31, suite du 2026-10-15). Le plein écran vient en
             dernier, pour qu'une règle de plein écran l'emporte sur toute règle plus générale qui
             poserait une valeur contraire (aujourd'hui, les deux retirent l'ombre).
    Erreurs : KeyError si le TOML brut manque ; ValueError transmise par _validate.
    Dépendances : _validate.
    """
    raw = model["raw"]
    _validate(raw)
    rules = [] if raw["elevation"]["e1"]["shadow"] else [
        '    { name = "couche-1-sans-ombre", match = { float = false }, no_shadow = true },']
    rules.append('    { name = "plein-ecran-nu", match = { fullscreen_state_internal = 2 }, no_shadow = true, '
                 f'rounding = {raw["radii"]["fullscreen"]} }},')
    return "\n".join([
        "-- GÉNÉRÉ depuis tokens.toml — NE PAS MODIFIER À LA MAIN",
        "-- Usage : for _, r in ipairs(require(\"generated.hyprland-rules\")) do hl.window_rule(r) end",
        "return {",
        *rules,
        "}",
    ]) + "\n"


def emit_binds(model: dict) -> str:
    """Module Lua des valeurs lues par les raccourcis.

    Entrée : model — sortie de model.resolve.
    Sortie : contenu de hyprland-binds.lua (une table Lua retournée, lue par modules/clavier.lua).
    Erreurs : KeyError si le TOML brut manque ; ValueError transmise par _validate.
    Dépendances : _validate.
    """
    raw = model["raw"]
    _validate(raw)
    return "\n".join([
        "-- GÉNÉRÉ depuis tokens.toml — NE PAS MODIFIER À LA MAIN",
        "-- Usage : local pas = require(\"generated.hyprland-binds\").resize_step",
        "return {",
        f"    resize_step = {raw['window']['resize_step']},",
        "}",
    ]) + "\n"
