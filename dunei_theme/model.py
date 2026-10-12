"""Résolution du thème — tokens.toml + teinte → couleurs nommées."""

from __future__ import annotations

import tomllib
from pathlib import Path

from .color import oklch


def load(src: Path) -> dict:
    """Lecture de la source de vérité.

    Entrée : src — chemin de tokens.toml.
    Sortie : dictionnaire brut du TOML.
    Erreurs : FileNotFoundError si absent, tomllib.TOMLDecodeError si invalide.
    Dépendances : tomllib.
    """
    with src.open("rb") as fh:
        return tomllib.load(fh)


def resolve(data: dict, hue_override: float | None = None) -> dict:
    """Résolution — applique les deux variables du thème à l'échelle invariante.

    Entrées : data — TOML brut ; hue_override — teinte simulée (sans toucher la source).
    Sortie : modèle {hue, ramp, roles, accent, on_accent, categorical, semantic, raw},
             couleurs de type Oklch.
    Erreurs : KeyError si une section attendue manque dans le TOML.
    Dépendances : color.oklch.
    """
    th = dict(data["theme"])
    if hue_override is not None:
        th["hue"] = hue_override % 360

    hue, ceiling, scale = th["hue"], th["chroma_ceiling"], th["chroma_scale"]
    steps = data["lightness"]["steps"]

    # Neutres : chroma majoré sous L 0.45, la perception y est plus faible.
    ramp = [oklch(l, th["neutral_chroma"] * scale * (th["dark_chroma_boost"] if l < 0.45 else 1), hue, ceiling)
            for l in steps]

    cat = data["categorical"]
    return {
        "hue": hue,
        "ramp": ramp,
        "roles": {name: ramp[i] for name, i in data["roles"].items()},
        "accent": oklch(steps[cat["lightness_step"] - 2], th["accent_chroma"] * scale, hue, ceiling),
        "on_accent": oklch(steps[0], 0.020, hue, ceiling),
        "categorical": [oklch(steps[cat["lightness_step"]], cat["chroma"] * scale, (hue + off) % 360, ceiling)
                        for off in cat["hue_offsets"]],
        # La section [semantic] peut contenir des clés scalaires : on ne garde que les couleurs.
        "semantic": {k: oklch(v["l"], v["c"], v["h"], ceiling)
                     for k, v in data["semantic"].items() if isinstance(v, dict)},
        "raw": data,
    }
