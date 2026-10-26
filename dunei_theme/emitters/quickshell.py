"""Cible Quickshell — `coque-tokens.json`, toutes les valeurs de design de la coque en QML.

Le QML ne porte aucune valeur de design : il lit ce fichier. Les couleurs y sont
déjà en sRGB (`#rrggbb`, ou `#AArrggbb` pour les translucides, ordre de Qt), les
clés en camelCase, les tailles inchangées.
"""

from __future__ import annotations

import json
import re

from ..color import Oklch, oklch, to_hex
from ..model import accent_muet, defaut, resolve, role_text, theme_data, themes

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
    accent est celui du rôle de fond ([role_text], text-primary par défaut). L'accent muet (activeMuted) prend la
    luminosité de states.container_inactive.fill_lightness quand le thème la donne, celle de l'accent sinon.

    Entrée : model — sortie de model.resolve.
    Sortie : dict states[rôle][sélection][interaction] = {"fill": "#rrggbb", "text": "#rrggbb"},
             soit 5 × 4 × 4 entrées (controlOff : piste éteinte et rail d'onglets). Erreurs : KeyError si une section du TOML manque.
    Dépendances : color.oklch, color.to_hex, model.accent_muet, model.role_text.
    """
    raw, roles = model["raw"], model["roles"]
    ceiling, st = raw["theme"]["chroma_ceiling"], raw["states"]
    acc = model["accent"]

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

    muet_fond = accent_muet(model)

    def combinaisons(nom, selection):
        """Les quatre interactions d'une sélection sur un rôle de surface.

        Entrées : nom — nom du rôle ; selection — none, active, inactive ou activeMuted.
        Sortie : dict interaction vers {"fill", "text"}. Erreurs : aucune.
        Dépendances : decale, eteint, color.to_hex, model.role_text.
        """
        role, texte = roles[nom], roles[role_text(raw, nom)]
        fond, txt = {"none": (role, texte), "active": (acc, model["on_accent"]),
                     "inactive": (model["ramp"][st["selected_inactive"]["lightness_step"]], texte),
                     "activeMuted": (muet_fond, model["on_accent"])}[selection]
        fond_off = eteint(fond, role)
        cols = {"rest": (fond, txt), "hover": (decale(fond, st["hover"]["lightness_delta"]), txt),
                "pressed": (decale(fond, st["pressed"]["lightness_delta"]), txt),
                "disabled": (fond_off, eteint(txt, fond_off))}
        return {k: {"fill": to_hex(f), "text": to_hex(t)} for k, (f, t) in cols.items()}

    return {_camel(r): {s: combinaisons(r, s) for s in ("none", "active", "inactive", "activeMuted")}
            for r in ("surface-window", "surface-panel", "surface-raised", "control-raised", "control-off")}


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


def _controles(model: dict) -> dict:
    """Traitement des contrôles blancs : contour, piste éteinte et ombre (section [controls]).

    Entrée : model — sortie de model.resolve.
    Sortie : dict {outline, offTrack, shadow, shadowBlur, shadowOffsetY} ; outline est la couleur du rôle nommé
             par controls.outline, None si ce nom est vide ; shadow est la couleur des ombres (`#AArrggbb`) à
             l'opacité controls.shadow_opacity, None à l'opacité nulle.
    Erreurs : KeyError si [controls], [surface_material] ou le rôle nommé manque.
    Dépendances : _argb, color.Oklch, color.to_hex.
    """
    c = model["raw"]["controls"]
    ombre = Oklch(**model["raw"]["surface_material"]["shadow_color"])
    return {"outline": to_hex(model["roles"][c["outline"]]) if c["outline"] else None,
            "offTrack": c["off_track"],
            "shadow": _argb(ombre, c["shadow_opacity"]) if c["shadow_opacity"] else None,
            "shadowBlur": c["shadow_blur"], "shadowOffsetY": c["shadow_offset_y"]}


def _theme(model: dict) -> dict:
    """Branche d'un thème — couleurs, états, focus, désactivé, élévation, matière, verre et rendu.

    Entrée : model — sortie de model.resolve sur les données d'un thème (model.theme_data).
    Sortie : dict {color, states, focus, disabled, elevation, material, glass, render, knob, controls}, `color.knob` compris.
    Erreurs : KeyError si une section du TOML manque.
    Dépendances : _camel, _argb, _states, _focus, _eteint, _controles, color.oklch, color.to_hex.
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

    # Le désactivé du knob se rapproche du rôle `knob.disabled_toward`, lui-même éteint comme un fond désactivé.
    cible = model["roles"][raw["knob"]["disabled_toward"]]
    fond_off = _eteint(model, cible, cible)
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
            "insetShadow": _argb(shadow, mat["inset_shadow_opacity"]),
            "insetDepth": mat["inset_shadow_depth"],
            "shadowBlur": raw["window"]["floating_shadow"]["range"],
            "shadowOffsetY": raw["window"]["floating_shadow"]["offset_y"],
        },
        "glass": {"e2": raw["glass"]["e2_opacity"], "e3": raw["glass"]["e3_opacity"]},
        "render": {"scrim": _argb(shadow, raw["render"]["scrim_opacity"]),
                   "neverAnimateBlurRadius": raw["render"]["never_animate_blur_radius"],
                   "hairlinePhysical": raw["scaling"]["hairlines_in_physical_pixels"]},
        "knob": {"rest": to_hex(model["knob"]), "disabled": to_hex(_eteint(model, model["knob"], fond_off))},
        "controls": _controles(model),
    }
    return out


def _pastilles(model: dict) -> dict:
    """Couleurs des pastilles de fenêtre, indépendantes du thème.

    Le glyphe est le fond de base de la nuit de la famille par défaut ; les variantes de survol et de pression
    des teintes sémantiques montent ou descendent la luminosité des écarts de la section pastilles, en OKLCH, sans plafond de
    chroma, que la teinte de base ne subit pas non plus.

    Entrée : model — sortie de model.resolve sur la nuit de la famille par défaut.
    Sortie : dict {glyph, error, errorHover, errorPressed, warning, …, success, …}.
    Erreurs : KeyError si une section du TOML manque. Dépendances : color.Oklch, color.to_hex.
    """
    sem, p = model["semantic"], model["raw"]["pastilles"]
    return {"glyph": to_hex(model["roles"]["surface-base"]),
            **{f"{k}{suf}": to_hex(sem[k] if not suf else Oklch(round(sem[k].l + p[cle], 3), sem[k].c, sem[k].h))
               for k in ("error", "warning", "success")
               for suf, cle in (("", None), ("Hover", "hover_lightness_delta"), ("Pressed", "pressed_lightness_delta"))}}


def _bureau(model: dict) -> dict:
    """Jetons du bureau : fond du compositeur, couleurs de texte posé dessus, seuil de luminance et logo.

    Entrée : model — sortie de model.resolve (thème par défaut) ; `raw["bureau"]` fournit les valeurs.
    Sortie : dict {fond, texteClair, texteClairSurvol, texteFonce, texteFonceSurvol, seuil, logo} ; `fond` est
             `surface-base`, la valeur exacte de `misc.background_color` de Hyprland.
    Erreurs : KeyError si la table [bureau] ou une de ses clés manque. Dépendances : color.Oklch, color.to_hex.
    """
    b = model["raw"]["bureau"]
    return {"fond": to_hex(model["roles"]["surface-base"]),
            **{_camel(k): to_hex(Oklch(**b[k])) for k in ("texte_clair", "texte_clair_survol", "texte_fonce", "texte_fonce_survol")},
            "seuil": b["seuil"], "logo": b["logo"]}


def emit(model: dict) -> str:
    """Fichier `coque-tokens.json` : les quatre thèmes, les pastilles et les cotes partagées.

    Entrée : model — sortie de model.resolve ; `raw` et `hue` servent à résoudre chaque thème ici, `roles` à la clé
             `bureau` (via _bureau).
    Sortie : contenu du fichier JSON. Erreurs : KeyError si une section du TOML manque ou si le moment « nuit » n'existe pas
             (les pastilles en dérivent).
    Dépendances : json, _camel_keys, _theme, _pastilles, _bureau, model.themes, model.defaut, model.theme_data, model.resolve.
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
        "pastilles": _pastilles(resolus[(fam, "nuit")]),
        "bureau": _bureau(model),
    }
    return json.dumps(out, indent=2, ensure_ascii=False) + "\n"
