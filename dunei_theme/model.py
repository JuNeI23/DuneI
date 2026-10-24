"""Résolution du thème — tokens.toml + teinte → couleurs nommées."""

from __future__ import annotations

import tomllib
from pathlib import Path

from .color import Oklch, oklch


def load(src: Path) -> dict:
    """Lecture de la source de vérité.

    Entrée : src — chemin de tokens.toml.
    Sortie : dictionnaire brut du TOML.
    Erreurs : FileNotFoundError si absent, tomllib.TOMLDecodeError si invalide.
    Dépendances : tomllib.
    """
    with src.open("rb") as fh:
        return tomllib.load(fh)


def role_text(data: dict, role: str) -> str:
    """Rôle du texte posé sur un rôle de fond, dans ses états sans accent.

    Entrées : data — TOML brut ; role — nom du rôle de fond, par exemple control-raised.
    Sortie : le rôle de texte que nomme [role_text], sinon text-primary.
    Erreurs : aucune ; une table [role_text] absente laisse text-primary partout. Dépendances : aucune.
    """
    return data.get("role_text", {}).get(role, "text-primary")


def resolve(data: dict, hue_override: float | None = None) -> dict:
    """Résolution — applique les deux variables du thème à l'échelle invariante.

    Entrées : data — TOML brut ; hue_override — teinte simulée (sans toucher la source).
    Sortie : modèle {hue, ramp, roles, elevation, accent, accent_standalone, on_accent,
             categorical, semantic, raw}, couleurs de type Oklch.
    Erreurs : KeyError si une section attendue manque dans le TOML ;
              IndexError si un échelon dépasse l'échelle de luminosité.
    Dépendances : color.Oklch, color.oklch.
    """
    th = dict(data["theme"])
    if hue_override is not None:
        th["hue"] = hue_override % 360

    hue, ceiling, scale = th["hue"], th["chroma_ceiling"], th["chroma_scale"]
    steps, acc, cat = data["lightness"]["steps"], data["accent"], data["categorical"]

    # Neutres : chroma majoré sous L 0.45, la perception y est plus faible.
    ramp = [oklch(l, th["neutral_chroma"] * scale * (th["dark_chroma_boost"] if l < 0.45 else 1), hue, ceiling)
            for l in steps]

    def accent(step):
        """Accent à un échelon de l'échelle de luminosité.

        Entrée : step — index d'échelon. Sortie : Oklch à la teinte du thème.
        Erreurs : IndexError si l'échelon n'existe pas. Dépendances : color.oklch.
        """
        return oklch(steps[step], th["accent_chroma"] * scale, hue, ceiling)

    return {
        "hue": hue,
        "ramp": ramp,
        "roles": {name: ramp[i] for name, i in data["roles"].items()},
        "elevation": {name: ramp[lvl["step"]] for name, lvl in data["elevation"].items()},
        "accent": accent(acc["fill_step"]),
        "accent_standalone": accent(acc["standalone_step"]),
        "on_accent": oklch(acc["on_lightness"], acc["on_chroma"], hue, ceiling),
        "categorical": [oklch(steps[cat["lightness_step"]], cat["chroma"] * scale, (hue + off) % 360, ceiling)
                        for off in cat["hue_offsets"]],
        # Hors moteur de thème : ni teinte, ni chroma_scale, ni plafond. Le rabattement
        # dans le gamut se fait à la conversion. On ne garde que les couleurs.
        "semantic": {k: Oklch(**v) for k, v in data["semantic"].items() if isinstance(v, dict)},
        "raw": data,
    }
