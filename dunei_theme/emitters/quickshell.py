"""Cible Quickshell — `coque-tokens.json`, toutes les valeurs de design de la coque en QML.

Le QML ne porte aucune valeur de design : il lit ce fichier. Les couleurs y sont
déjà en sRGB (`#rrggbb`, ou `#AArrggbb` pour les translucides, ordre de Qt), les
clés en camelCase, les tailles inchangées.
"""

from __future__ import annotations

import json
import re

from ..color import Oklch, oklch, to_hex

_BLANC = Oklch(1, 0, 0)


def _camel(name: str) -> str:
    """Nom en camelCase — `surface-raised` donne `surfaceRaised`.

    Entrée : name — nom en tirets ou en soulignés. Sortie : nom en camelCase.
    Erreurs : aucune. Dépendances : re.
    """
    return re.sub(r"[-_]+(.)", lambda m: m[1].upper(), name)


def _camel_keys(v):
    """Copie d'une valeur dont toutes les clés de dictionnaire sont en camelCase.

    Entrée : v — valeur issue du TOML. Sortie : valeur de même forme.
    Erreurs : aucune. Dépendances : _camel.
    """
    if isinstance(v, dict):
        return {_camel(k): _camel_keys(x) for k, x in v.items()}
    return v


def _argb(col: Oklch, alpha: float) -> str:
    """Couleur translucide au format `#AArrggbb`, ordre de QML.

    Entrées : col — couleur ; alpha — opacité 0–1, arrondie sur 0–255.
    Sortie : chaîne hexadécimale en minuscules. Erreurs : aucune.
    Dépendances : color.to_hex.
    """
    return f"#{round(alpha * 255):02x}{to_hex(col)[1:]}"


def emit(model: dict) -> str:
    """Fichier `coque-tokens.json`, hors combinaisons d'états.

    Entrée : model — sortie de model.resolve.
    Sortie : contenu du fichier JSON. Erreurs : KeyError si une section du TOML manque.
    Dépendances : json, _camel, _camel_keys, _argb, color.oklch, color.to_hex.
    """
    raw, sem = model["raw"], model["semantic"]
    mat, ceiling = raw["surface_material"], raw["theme"]["chroma_ceiling"]
    shadow = Oklch(**mat["shadow_color"])

    def sheen_top(name, fill):
        """Haut du dégradé d'un niveau d'élévation, ou None sans lustre.

        Entrées : name — niveau ; fill — son remplissage. Sortie : `#rrggbb` ou None.
        Erreurs : aucune. Dépendances : color.oklch, color.to_hex.
        """
        if not raw["elevation"][name].get("sheen"):
            return None
        return to_hex(oklch(fill.l + mat["sheen_delta"], fill.c, fill.h, ceiling))

    levels = {
        n: {"fill": to_hex(f), "sheen": raw["elevation"][n]["sheen"], "sheenTop": sheen_top(n, f),
            "edgeLight": raw["elevation"][n]["edge_light"], "shadow": raw["elevation"][n]["shadow"]}
        for n, f in model["elevation"].items() if n != "field"
    }
    levels["field"] = {"fill": to_hex(model["elevation"]["field"]),
                       "insetShadow": raw["elevation"]["field"]["inset_shadow"]}

    out = {
        "_generated": "GÉNÉRÉ depuis tokens.toml — NE PAS MODIFIER À LA MAIN",
        "hue": model["hue"],
        "color": {
            **{_camel(k): to_hex(v) for k, v in model["roles"].items()},
            "accent": to_hex(model["accent"]),
            "accentStandalone": to_hex(model["accent_standalone"]),
            "onAccent": to_hex(model["on_accent"]),
            **{k: to_hex(sem[k]) for k in ("error", "warning", "success", "info")},
            "categorical": [to_hex(c) for c in model["categorical"]],
        },
        "disabled": {k: raw["states"]["disabled"][k] for k in ("opacity", "shadow")},
        "elevation": levels,
        "material": {
            "dither": mat["dither"],
            "sheenMaxHeight": mat["sheen_max_height"],
            "edgeLight": _argb(_BLANC, mat["edge_light_opacity"]),
            "edgeShadow": _argb(shadow, mat["edge_shadow_opacity"]),
            "shade": _argb(shadow, mat["shade_opacity"]),
            "overlayOutline": _argb(shadow, mat["overlay_outline_opacity"]),
        },
        "render": {"scrim": _argb(shadow, raw["render"]["scrim_opacity"]),
                   "neverAnimateBlurRadius": raw["render"]["never_animate_blur_radius"]},
        "space": _camel_keys(raw["spacing"]),
        "density": _camel_keys(raw["density"]),
        "radius": _camel_keys(raw["radii"]),
        "window": _camel_keys(raw["window"]),
        "layout": _camel_keys(raw["layout"]),
        "breakpoints": _camel_keys(raw["breakpoints"]),
        "typo": _camel_keys({k: v for k, v in raw["type"].items() if k != "fallback_chain" and not isinstance(v, dict)}),
        "icons": {**{k: raw["icons"][k] for k in ("source", "variants", "grid", "stroke", "sizes")},
                  "xdgTheme": raw["icons"]["xdg_theme"]},
    }
    return json.dumps(out, indent=2, ensure_ascii=False) + "\n"
