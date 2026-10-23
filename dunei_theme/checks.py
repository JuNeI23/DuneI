"""Vérifications automatiques — étage 1 de la recette.

Tout ce qui peut être vérifié par un programme l'est, plutôt que de reposer
sur la vigilance de quelqu'un.
"""

from __future__ import annotations

from .color import apca_lc

# Paires (texte, fond) contrôlées en APCA ; noms de rôles du modèle, ou clés de premier niveau.
BODY_PAIRS = [("text-primary", bg) for bg in ("surface-window", "surface-panel", "surface-raised", "control-raised")]


def contrast(model: dict) -> list[str]:
    """Contrôle APCA — corps de texte sur les surfaces, texte sur l'accent.

    Entrée : model — sortie de model.resolve.
    Sortie : avertissements ; corps de texte sous le plancher, ou sous la cible ;
             on_accent sur accent sous le plancher.
    Erreurs : KeyError si un rôle ou raw["meta"] (contrast_floor,
              contrast_target_body) manque.
    Dépendances : color.apca_lc.
    """
    meta, roles, warn = model["raw"]["meta"], model["roles"], []
    floor, target = meta["contrast_floor"], meta["contrast_target_body"]
    for text, bg in BODY_PAIRS:
        lc = int(abs(apca_lc(roles[text], roles[bg])) * 10) / 10  # tronqué : jamais « Lc 75.0 sous le plancher 75 »
        if lc < floor:
            warn.append(f"contraste APCA {text} sur {bg} : Lc {lc} sous le plancher Lc {floor}")
        elif lc < target:
            warn.append(f"contraste APCA {text} sur {bg} : Lc {lc} sous la cible Lc {target}")
    lc = int(abs(apca_lc(model["on_accent"], model["accent"])) * 10) / 10
    if lc < floor:
        warn.append(f"contraste APCA on_accent sur accent : Lc {lc} sous le plancher Lc {floor}")
    return warn


def check(model: dict) -> list[str]:
    """Contrôle du modèle résolu.

    Entrée : model — sortie de model.resolve.
    Sortie : liste d'avertissements, vide si tout est conforme.
    Erreurs : KeyError si le TOML brut est incomplet.
    Dépendances : contrast.
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

    return warn + contrast(model)
