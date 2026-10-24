"""Vérifications automatiques — étage 1 de la recette.

Tout ce qui peut être vérifié par un programme l'est, plutôt que de reposer
sur la vigilance de quelqu'un.
"""

from __future__ import annotations

from .color import apca_lc
from .model import accent_muet, role_text

# Fonds dont le corps de texte est contrôlé en APCA, chacun avec le texte que lui donne model.role_text.
BODY_SURFACES = ("surface-window", "surface-panel", "surface-raised", "control-raised")


def contrast(model: dict) -> list[str]:
    """Contrôle APCA — corps de texte sur les surfaces, texte sur l'accent.

    Entrée : model — sortie de model.resolve.
    Sortie : avertissements ; corps de texte sous le plancher, ou sous la cible ;
             on_accent sur accent sous le plancher.
    Erreurs : KeyError si un rôle ou raw["meta"] (contrast_floor,
              contrast_target_body) manque.
    Dépendances : color.apca_lc, model.role_text, BODY_SURFACES.
    """
    meta, roles, warn = model["raw"]["meta"], model["roles"], []
    floor, target = meta["contrast_floor"], meta["contrast_target_body"]
    for text, bg in ((role_text(model["raw"], bg), bg) for bg in BODY_SURFACES):
        lc = int(abs(apca_lc(roles[text], roles[bg])) * 10) / 10  # tronqué : jamais « Lc 75.0 sous le plancher 75 »
        if lc < floor:
            warn.append(f"contraste APCA {text} sur {bg} : Lc {lc} sous le plancher Lc {floor}")
        elif lc < target:
            warn.append(f"contraste APCA {text} sur {bg} : Lc {lc} sous la cible Lc {target}")
    lc = int(abs(apca_lc(model["on_accent"], model["accent"])) * 10) / 10
    if lc < floor:
        warn.append(f"contraste APCA on_accent sur accent : Lc {lc} sous le plancher Lc {floor}")
    return warn


# Les trois surfaces sur lesquelles se mesurent les rôles de texte, de bordure et de couleur.
SURFACES = ("surface-window", "surface-panel", "surface-raised")
# Rôles de texte, du plus faible au plus fort, et rôles de bordure.
TEXTES = ("text-disabled", "text-tertiary", "text-secondary", "text-primary")
BORDURES = ("border-subtle", "border-default", "border-strong")


def _lc(a, b) -> float:
    """Contraste APCA absolu d'un texte sur un fond.

    Entrées : a — couleur du texte ; b — couleur du fond (Oklch).
    Sortie : |Lc|.
    Erreurs : aucune. Dépendances : color.apca_lc.
    """
    return abs(apca_lc(a, b))


def mesures(model: dict) -> dict[str, float]:
    """Mesures de contraste — pour chaque clé, le plus petit |Lc| sur ses fonds.

    Entrée : model — sortie de model.resolve.
    Sortie : {clé: Lc minimal}. Clés : chaque rôle text-* et border-* sur les trois surfaces ;
             control-raised-text (role_text sur control-raised) ; accent-standalone, error, warning, success,
             info et categorical (toutes les catégorielles) sur les trois surfaces ; knob-accent (knob sur accent) ;
             knob-off (knob sur la piste éteinte, rôle control-off) ; on-accent-muted (on_accent sur l'accent muet).
    Erreurs : KeyError si un rôle, une sémantique ou raw["role_text"] manque.
    Dépendances : _lc, model.role_text, model.accent_muet, SURFACES.
    """
    roles, out = model["roles"], {}
    for name in (n for n in roles if n.startswith(("text-", "border-"))):
        out[name] = min(_lc(roles[name], roles[bg]) for bg in SURFACES)
    out["control-raised-text"] = _lc(roles[role_text(model["raw"], "control-raised")], roles["control-raised"])
    couleurs = {"accent-standalone": [model["accent_standalone"]], "categorical": model["categorical"],
                **{k: [model["semantic"][k]] for k in ("error", "warning", "success", "info")}}
    for name, cs in couleurs.items():
        out[name] = min(_lc(c, roles[bg]) for c in cs for bg in SURFACES)
    out["knob-accent"] = _lc(model["knob"], model["accent"])
    out["knob-off"] = _lc(model["knob"], roles["control-off"])
    out["on-accent-muted"] = _lc(model["on_accent"], accent_muet(model))
    return out


def planchers(model: dict) -> list[str]:
    """Planchers par rôle — compare chaque mesure à raw["meta"]["planchers"].

    Entrée : model — sortie de model.resolve.
    Sortie : un avertissement par clé dont la mesure, tronquée au dixième, est sous son plancher.
    Erreurs : KeyError si un plancher manque pour une clé mesurée.
    Dépendances : mesures.
    """
    floors = model["raw"]["meta"]["planchers"]
    return [f"plancher {k} : Lc {int(v * 10) / 10} sous le plancher Lc {floors[k]}"
            for k, v in mesures(model).items() if int(v * 10) / 10 < floors[k]]


def ordre(model: dict) -> list[str]:
    """Ordre des rôles — sur chaque surface, la hiérarchie du texte et des bordures.

    Entrée : model — sortie de model.resolve.
    Sortie : un avertissement par surface où les Lc ne croissent pas strictement de text-disabled à text-primary,
             où text-emphasis est sous text-primary, ou où le plus faible texte ne dépasse pas la plus forte bordure.
    Erreurs : KeyError si un rôle manque.
    Dépendances : _lc, SURFACES, TEXTES, BORDURES.
    """
    roles, warn = model["roles"], []
    for bg in SURFACES:
        lc = {n: _lc(roles[n], roles[bg]) for n in (*TEXTES, "text-emphasis", *BORDURES)}
        suite = [lc[n] for n in TEXTES]
        if any(a >= b for a, b in zip(suite, suite[1:])):
            warn.append(f"ordre des textes sur {bg} : les Lc ne croissent pas strictement de text-disabled à text-primary")
        if lc["text-emphasis"] < lc["text-primary"]:
            warn.append(f"ordre des textes sur {bg} : text-emphasis est sous text-primary")
        forte = max(BORDURES, key=lambda n: (lc[n], BORDURES.index(n)))  # à égalité, la plus forte
        if lc["text-disabled"] <= lc[forte]:
            warn.append(f"ordre sur {bg} : text-disabled ne dépasse pas {forte}")
    return warn


def check(model: dict) -> list[str]:
    """Contrôle du modèle résolu.

    Entrée : model — sortie de model.resolve.
    Sortie : liste d'avertissements, vide si tout est conforme.
    Erreurs : KeyError si le TOML brut est incomplet.
    Dépendances : contrast, planchers, ordre.
    """
    warn = []
    raw = model["raw"]

    if raw["theme"]["accent_chroma"] > raw["theme"]["chroma_ceiling"]:
        warn.append("le chroma d'accent dépasse le plafond de gamut")

    # Écart angulaire, bouclage 360° compris : le dernier décalage est comparé au premier + 360.
    sep = raw["categorical"]["min_angular_separation"]
    offs = sorted(o % 360 for o in raw["categorical"]["hue_offsets"])
    wrap = offs[1:] + [offs[0] + 360] if len(offs) > 1 else []
    warn += [f"teintes catégorielles trop proches : {a}° et {b % 360}°" for a, b in zip(offs, wrap) if b - a < sep]

    mult = raw["scaling"]["height_multiple"]
    for name, d in raw["density"].items():
        warn += [f"densité « {name} » : {key} = {d[key]}px n'est pas multiple de {mult} — risque de demi-pixel en échelle fractionnaire"
                 for key in ("control_height", "row_height") if d[key] % mult]

    if raw["surface_material"]["sheen_max_height"] > 120:
        warn.append("sheen autorisé sur une trop grande hauteur : banding probable")

    return warn + contrast(model) + planchers(model) + ordre(model)
