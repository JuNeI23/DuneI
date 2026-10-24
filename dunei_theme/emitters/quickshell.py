"""Cible Quickshell — `coque-tokens.json`, toutes les valeurs de design de la coque en QML.

Le QML ne porte aucune valeur de design : il lit ce fichier. Les couleurs y sont
déjà en sRGB (`#rrggbb`, ou `#AArrggbb` pour les translucides, ordre de Qt), les
clés en camelCase, les tailles inchangées.
"""

from __future__ import annotations

import json
import re

from ..color import Oklch, oklch, to_hex
from ..model import defaut, resolve, role_text, theme_data, themes

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


def _eteint(model: dict, col: Oklch, fond: Oklch) -> Oklch:
    """Couleur désactivée — luminosité rapprochée de celle du fond, chroma atténué.

    Entrées : model — sortie de model.resolve ; col — couleur à éteindre ; fond — couleur dont on se rapproche.
    Sortie : Oklch rabattu dans le gamut. Erreurs : KeyError si `states.disabled` manque au TOML.
    Dépendances : color.oklch.
    """
    d = model["raw"]["states"]["disabled"]
    return oklch(col.l + (fond.l - col.l) * d["lightness_toward_background"], col.c * d["chroma_multiplier"], col.h,
                 model["raw"]["theme"]["chroma_ceiling"])


def _states(model: dict) -> dict:
    """Combinaisons d'états précalculées — rôle, sélection, interaction vers fond et texte.

    Règles de la bible (ch. 7), appliquées dans l'ordre base, sélection, survol, pression,
    désactivé. Le QML n'a ainsi aucune règle de couleur à porter. Le texte des sélections sans
    accent est celui du rôle de fond ([role_text], text-primary par défaut).

    Entrée : model — sortie de model.resolve.
    Sortie : dict states[rôle][sélection][interaction] = {"fill": "#rrggbb", "text": "#rrggbb"},
             soit 4 × 4 × 4 entrées. Erreurs : KeyError si une section du TOML manque.
    Dépendances : color.oklch, color.to_hex, model.role_text.
    """
    raw, roles = model["raw"], model["roles"]
    ceiling, st = raw["theme"]["chroma_ceiling"], raw["states"]
    acc = model["accent"]
    muet = st["container_inactive"]["accent_chroma_multiplier"]

    def decale(col, dl=0.0, dc=1.0):
        """Couleur dont la luminosité est décalée et le chroma multiplié, rabattue dans le gamut.

        Entrées : col — couleur ; dl — décalage de luminosité ; dc — facteur de chroma.
        Sortie : Oklch. Erreurs : aucune. Dépendances : color.oklch.
        """
        return oklch(col.l + dl, col.c * dc, col.h, ceiling)

    def eteint(col, fond):
        """Couleur désactivée de ce thème.

        Entrées : col — couleur à éteindre ; fond — couleur dont on se rapproche.
        Sortie : Oklch. Erreurs : aucune. Dépendances : _eteint.
        """
        return _eteint(model, col, fond)

    def combinaisons(nom, selection):
        """Les quatre interactions d'une sélection sur un rôle de surface.

        Entrées : nom — nom du rôle ; selection — none, active, inactive ou activeMuted.
        Sortie : dict interaction vers {"fill", "text"}. Erreurs : aucune.
        Dépendances : decale, eteint, color.to_hex, model.role_text.
        """
        role, texte = roles[nom], roles[role_text(raw, nom)]
        fond, txt = {"none": (role, texte), "active": (acc, model["on_accent"]),
                     "inactive": (model["ramp"][st["selected_inactive"]["lightness_step"]], texte),
                     "activeMuted": (decale(acc, 0, muet), model["on_accent"])}[selection]
        fond_off = eteint(fond, role)
        cols = {"rest": (fond, txt), "hover": (decale(fond, st["hover"]["lightness_delta"]), txt),
                "pressed": (decale(fond, st["pressed"]["lightness_delta"]), txt),
                "disabled": (fond_off, eteint(txt, fond_off))}
        return {k: {"fill": to_hex(f), "text": to_hex(t)} for k, (f, t) in cols.items()}

    return {_camel(r): {s: combinaisons(r, s) for s in ("none", "active", "inactive", "activeMuted")}
            for r in ("surface-window", "surface-panel", "surface-raised", "control-raised")}


def _focus(model: dict) -> dict:
    """Anneau de focus — couleurs lisibles sur fond sombre, épaisseur et décalages.

    Entrée : model — sortie de model.resolve.
    Sortie : dict {color, colorMuted, width, offset, rowOffset}.
    Erreurs : KeyError si `states.focus` manque au TOML. Dépendances : color.oklch, color.to_hex.
    """
    f, acc = model["raw"]["states"]["focus"], model["accent_standalone"]
    muet = model["raw"]["states"]["container_inactive"]["accent_chroma_multiplier"]
    return {"color": to_hex(acc),
            "colorMuted": to_hex(oklch(acc.l, acc.c * muet, acc.h, model["raw"]["theme"]["chroma_ceiling"])),
            "width": f["ring_width"], "offset": f["ring_offset"], "rowOffset": f["ring_offset_row"]}


def _theme(model: dict) -> dict:
    """Branche d'un thème — couleurs, états, focus, désactivé, élévation, matière et rendu.

    Entrée : model — sortie de model.resolve sur les données d'un thème (model.theme_data).
    Sortie : dict {color, states, focus, disabled, elevation, material, render}, `color.knob` et `knob` compris.
    Erreurs : KeyError si une section du TOML manque.
    Dépendances : _camel, _argb, _states, _focus, _eteint, color.oklch, color.to_hex.
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

    # Le désactivé du knob suit celui de control-raised sans sélection, dont il se rapproche.
    fond_off = _eteint(model, model["roles"]["control-raised"], model["roles"]["control-raised"])
    out = {
        "color": {
            **{_camel(k): to_hex(v) for k, v in model["roles"].items()},
            "accent": to_hex(model["accent"]),
            "accentStandalone": to_hex(model["accent_standalone"]),
            "onAccent": to_hex(model["on_accent"]),
            "knob": to_hex(model["knob"]),
            **{k: to_hex(sem[k]) for k in ("error", "warning", "success", "info")},
            "categorical": [to_hex(c) for c in model["categorical"]],
        },
        "states": _states(model),
        "focus": _focus(model),
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
                   "neverAnimateBlurRadius": raw["render"]["never_animate_blur_radius"],
                   "hairlinePhysical": raw["scaling"]["hairlines_in_physical_pixels"]},
        "knob": {"rest": to_hex(model["knob"]), "disabled": to_hex(_eteint(model, model["knob"], fond_off))},
    }
    return out


def _pastilles(model: dict) -> dict:
    """Couleurs des pastilles de fenêtre, indépendantes du thème.

    Le glyphe est le fond de base du thème par défaut ; les variantes de survol et de pression des teintes
    sémantiques montent ou descendent la luminosité des écarts de la section pastilles, en OKLCH, sans plafond de
    chroma, que la teinte de base ne subit pas non plus.

    Entrée : model — sortie de model.resolve sur le thème par défaut.
    Sortie : dict {glyph, error, errorHover, errorPressed, warning, …, success, …}.
    Erreurs : KeyError si une section du TOML manque. Dépendances : color.Oklch, color.to_hex.
    """
    sem, p = model["semantic"], model["raw"]["pastilles"]
    return {"glyph": to_hex(model["roles"]["surface-base"]),
            **{f"{k}{suf}": to_hex(sem[k] if not suf else Oklch(round(sem[k].l + p[cle], 3), sem[k].c, sem[k].h))
               for k in ("error", "warning", "success")
               for suf, cle in (("", None), ("Hover", "hover_lightness_delta"), ("Pressed", "pressed_lightness_delta"))}}


def emit(model: dict) -> str:
    """Fichier `coque-tokens.json` : les quatre thèmes, les pastilles et les cotes partagées.

    Entrée : model — sortie de model.resolve ; seuls `raw` et `hue` servent, chaque thème étant résolu ici.
    Sortie : contenu du fichier JSON. Erreurs : KeyError si une section du TOML manque.
    Dépendances : json, _camel_keys, _theme, _pastilles, model.themes, model.defaut, model.theme_data, model.resolve.
    """
    raw, hue = model["raw"], model["hue"]
    resolus = {(f, m): resolve(theme_data(raw, f, m), hue) for f, m in themes(raw)}
    fam, mom = defaut(raw)
    out = {
        "_generated": "GÉNÉRÉ depuis tokens.toml — NE PAS MODIFIER À LA MAIN",
        "hue": hue,
        "space": _camel_keys(raw["spacing"]),
        "density": _camel_keys(raw["density"]),
        "radius": _camel_keys(raw["radii"]),
        "window": _camel_keys(raw["window"]),
        "layout": _camel_keys(raw["layout"]),
        "breakpoints": _camel_keys(raw["breakpoints"]),
        "typo": _camel_keys({k: v for k, v in raw["type"].items() if k != "fallback_chain" and not isinstance(v, dict)}),
        "icons": {**{k: raw["icons"][k] for k in ("source", "variants", "grid", "stroke", "sizes")},
                  "xdgTheme": raw["icons"]["xdg_theme"]},
        "familles": list(raw["familles"]),
        "moments": list(raw["moments"]),
        "defaut": {"famille": fam, "moment": mom},
        "themes": {f: {m: _theme(resolus[(f, m)]) for g, m in resolus if g == f} for f in raw["familles"]},
        "pastilles": _pastilles(resolus[(fam, mom)]),
    }
    return json.dumps(out, indent=2, ensure_ascii=False) + "\n"
