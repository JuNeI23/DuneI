"""Résolution du thème — tokens.toml + teinte → couleurs nommées."""

from __future__ import annotations

import copy
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


def themes(data: dict) -> list[tuple[str, str]]:
    """Liste des thèmes composables.

    Entrée : data — TOML brut.
    Sortie : couples (famille, moment), familles puis moments dans l'ordre du TOML.
    Erreurs : KeyError si [familles] ou [moments] manque. Dépendances : aucune.
    """
    return [(f, m) for f in data["familles"] for m in data["moments"]]


def defaut(data: dict) -> tuple[str, str]:
    """Thème par défaut.

    Entrée : data — TOML brut.
    Sortie : le couple (famille, moment) de [theme.defaut].
    Erreurs : KeyError si [theme.defaut] ou l'une de ses clés manque. Dépendances : aucune.
    """
    d = data["theme"]["defaut"]
    return d["famille"], d["moment"]


def _fusion(base: dict, surcharge: dict) -> None:
    """Fusion récursive en place : un dictionnaire se fusionne clé à clé, toute autre valeur remplace.

    Entrées : base — dictionnaire modifié ; surcharge — valeurs prioritaires.
    Sortie : aucune. Erreurs : aucune. Dépendances : copy.
    """
    for k, v in surcharge.items():
        if isinstance(v, dict) and isinstance(base.get(k), dict):
            _fusion(base[k], v)
        else:
            base[k] = copy.deepcopy(v)


def theme_data(data: dict, famille: str, moment: str) -> dict:
    """Données d'un thème : la base, puis les surcharges du moment, puis celles de la famille.

    Entrées : data — TOML brut (jamais modifié) ; famille, moment — noms des tables de surcharge.
    Sortie : copie profonde de data, fusionnée, que resolve() sait résoudre.
    Erreurs : KeyError « famille inconnue : <f> » ou « moment inconnu : <m> ».
    Dépendances : copy.
    """
    for table, nom, libelle in (("familles", famille, "famille"), ("moments", moment, "moment")):
        if nom not in data.get(table, {}):
            raise KeyError(f"{libelle} inconnu{'e' if libelle == 'famille' else ''} : {nom}")
    out = copy.deepcopy(data)
    _fusion(out, data["moments"][moment])
    _fusion(out, data["familles"][famille])
    return out


def resolve(data: dict, hue_override: float | None = None) -> dict:
    """Résolution — applique les deux variables du thème à l'échelle invariante.

    Entrées : data — TOML brut ; hue_override — teinte simulée (sans toucher la source).
    Sortie : modèle {hue, ramp, roles, elevation, accent, accent_standalone, on_accent,
             categorical, semantic, knob, raw}, couleurs de type Oklch.
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
    # neutral_profile (facultatif) remplace ce facteur échelon par échelon.
    profil = data["lightness"].get("neutral_profile") or [th["dark_chroma_boost"] if l < 0.45 else 1 for l in steps]
    ramp = [oklch(l, th["neutral_chroma"] * scale * f, hue, ceiling) for l, f in zip(steps, profil)]

    def accent(step, lightness=None):
        """Accent à un échelon de l'échelle de luminosité, ou à une luminosité explicite.

        Entrées : step — index d'échelon ; lightness — luminosité qui l'emporte si elle est donnée.
        Sortie : Oklch à la teinte du thème.
        Erreurs : IndexError si l'échelon n'existe pas. Dépendances : color.oklch.
        """
        return oklch(steps[step] if lightness is None else lightness, th["accent_chroma"] * scale, hue, ceiling)

    roles = {name: ramp[i] for name, i in data["roles"].items()}
    kn = data["knob"]
    knob = roles[kn["role"]] if "role" in kn else oklch(kn["lightness"], 0, hue, ceiling)

    return {
        "hue": hue,
        "ramp": ramp,
        "roles": roles,
        "elevation": {name: ramp[lvl["step"]] for name, lvl in data["elevation"].items()},
        "accent": accent(acc["fill_step"], acc.get("fill_lightness")),
        "accent_standalone": accent(acc["standalone_step"], acc.get("standalone_lightness")),
        "knob": knob,
        "on_accent": oklch(acc["on_lightness"], acc["on_chroma"], hue, ceiling),
        "categorical": [oklch(cat.get("lightness", steps[cat["lightness_step"]]), cat["chroma"] * scale, (hue + off) % 360, ceiling)
                        for off in cat["hue_offsets"]],
        # Hors moteur de thème : ni teinte, ni chroma_scale, ni plafond. Le rabattement
        # dans le gamut se fait à la conversion. On ne garde que les couleurs.
        "semantic": {k: Oklch(**v) for k, v in data["semantic"].items() if isinstance(v, dict)},
        "raw": data,
    }
