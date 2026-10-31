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


def accent_muet(model: dict) -> Oklch:
    """Fond de l'accent muet (sélection inactive d'un groupe qui a perdu le focus).

    Rôle : chroma de l'accent multiplié par states.container_inactive.accent_chroma_multiplier, à la luminosité
      states.container_inactive.fill_lightness quand le thème la donne (le jour), celle de l'accent sinon.
    Entrée : model — sortie de resolve.
    Sortie : Oklch rabattu dans le gamut. Erreurs : KeyError si states.container_inactive manque.
    Dépendances : color.oklch.
    """
    raw, acc = model["raw"], model["accent"]
    ci = raw["states"]["container_inactive"]
    return oklch(ci.get("fill_lightness", acc.l), acc.c * ci["accent_chroma_multiplier"], acc.h, raw["theme"]["chroma_ceiling"])


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
    """Données d'un thème : la base, puis les surcharges du moment, puis celles de la famille, puis la surcharge
    croisée [familles.<famille>.moments.<moment>], propre à ce couple.

    Entrées : data — TOML brut (jamais modifié) ; famille, moment — noms des tables de surcharge.
    Sortie : copie profonde de data, fusionnée, que resolve() sait résoudre ; la table [moments] n'y reçoit pas
             les surcharges croisées.
    Erreurs : KeyError « famille inconnue : <f> » ou « moment inconnu : <m> », y compris pour un moment nommé par
              une surcharge croisée de la famille.
    Dépendances : copy.
    """
    for table, nom, libelle in (("familles", famille, "famille"), ("moments", moment, "moment")):
        if nom not in data.get(table, {}):
            raise KeyError(f"{libelle} inconnu{'e' if libelle == 'famille' else ''} : {nom}")
    fam = dict(data["familles"][famille])
    croisees = fam.pop("moments", {})
    for nom in croisees:
        if nom not in data["moments"]:
            raise KeyError(f"moment inconnu : {nom}")
    out = copy.deepcopy(data)
    for surcharge in (data["moments"][moment], fam, croisees.get(moment, {})):
        _fusion(out, surcharge)
    return out


def bureaux(raw: dict) -> int:
    """Nombre de bureaux virtuels, validé.

    Entrée : raw — TOML brut du modèle.
    Sortie : bureaux_virtuels.nombre, entier de 1 à 10.
    Erreurs : ValueError si la valeur est absente, non entière (un booléen est refusé) ou hors de 1 à 10
              (la touche 0 mène au bureau 10, il n'y a pas de onzième touche).
    Dépendances : aucune.
    """
    n = raw.get("bureaux_virtuels", {}).get("nombre")
    if type(n) is not int or not 1 <= n <= 10:
        raise ValueError(f"bureaux_virtuels.nombre = {n!r} : entier de 1 à 10 attendu")
    return n


def resolve(data: dict, hue_override: float | None = None) -> dict:
    """Résolution — applique les deux variables du thème à l'échelle invariante.

    Entrées : data — TOML brut ; hue_override — teinte simulée (sans toucher la source).
    Sortie : modèle {hue, ramp, roles, elevation, accent, accent_standalone, accent_discret, on_accent,
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
    # neutral_profile (facultatif) remplace ce facteur échelon par échelon ; il doit avoir autant de facteurs que
    # d'échelons, sinon zip(strict=True) lève ValueError.
    profil = data["lightness"].get("neutral_profile") or [th["dark_chroma_boost"] if l < 0.45 else 1 for l in steps]
    ramp = [oklch(l, th["neutral_chroma"] * scale * f, hue, ceiling) for l, f in zip(steps, profil, strict=True)]

    def accent(step, lightness=None, chroma_ratio=1.0):
        """Accent à un échelon de l'échelle de luminosité, ou à une luminosité explicite.

        Entrées : step — index d'échelon ; lightness — luminosité qui l'emporte si elle est donnée ;
                  chroma_ratio — facteur appliqué à la chroma d'accent, 1,0 par défaut.
        Sortie : Oklch à la teinte du thème.
        Erreurs : IndexError si l'échelon n'existe pas. Dépendances : color.oklch.
        """
        return oklch(steps[step] if lightness is None else lightness,
                     th["accent_chroma"] * scale * chroma_ratio, hue, ceiling)

    roles = {name: ramp[i] for name, i in data["roles"].items()}
    kn = data["knob"]
    # Une luminosité explicite l'emporte sur le rôle : un moment surcharge ainsi le rôle de la base sans pouvoir le retirer.
    knob = oklch(kn["lightness"], 0, hue, ceiling) if "lightness" in kn else roles[kn["role"]]

    return {
        "hue": hue,
        "ramp": ramp,
        "roles": roles,
        "elevation": {name: ramp[lvl["step"]] for name, lvl in data["elevation"].items()},
        "accent": accent(acc["fill_step"], acc.get("fill_lightness")),
        "accent_standalone": accent(acc["standalone_step"], acc.get("standalone_lightness")),
        "accent_discret": accent(acc["standalone_step"], acc["discret_lightness"], acc["discret_chroma_ratio"]),
        "knob": knob,
        "on_accent": oklch(acc["on_lightness"], acc["on_chroma"], hue, ceiling),
        "categorical": [oklch(cat.get("lightness", steps[cat["lightness_step"]]), cat["chroma"] * scale, (hue + off) % 360, ceiling)
                        for off in cat["hue_offsets"]],
        # Hors moteur de thème : ni teinte, ni chroma_scale, ni plafond. Le rabattement
        # dans le gamut se fait à la conversion. On ne garde que les couleurs.
        "semantic": {k: Oklch(**v) for k, v in data["semantic"].items() if isinstance(v, dict)},
        "raw": data,
    }
