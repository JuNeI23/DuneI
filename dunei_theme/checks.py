"""Vérifications automatiques — étage 1 de la recette.

Tout ce qui peut être vérifié par un programme l'est, plutôt que de reposer
sur la vigilance de quelqu'un.
"""

from __future__ import annotations


def check(model: dict) -> list[str]:
    """Contrôle du modèle résolu.

    Entrée : model — sortie de model.resolve.
    Sortie : liste d'avertissements, vide si tout est conforme.
    Erreurs : KeyError si le TOML brut est incomplet.
    Dépendances : aucune.
    """
    warn = []
    raw = model["raw"]

    if raw["theme"]["accent_chroma"] > raw["theme"]["chroma_ceiling"]:
        warn.append("le chroma d'accent dépasse le plafond de gamut")

    sep = raw["categorical"]["min_angular_separation"]
    offs = sorted(o % 360 for o in raw["categorical"]["hue_offsets"])
    warn += [f"teintes catégorielles trop proches : {a}° et {b}°" for a, b in zip(offs, offs[1:]) if b - a < sep]

    for name, d in raw["density"].items():
        warn += [f"densité « {name} » : {key} = {d[key]}px est impair — risque de demi-pixel en échelle fractionnaire"
                 for key in ("control_height", "row_height") if d[key] % 2]

    if raw["surface_material"]["sheen_max_height"] > 120:
        warn.append("sheen autorisé sur une trop grande hauteur : banding probable")

    return warn
