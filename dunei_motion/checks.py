"""Contrôles du mouvement — règles du chapitre 6 de la bible et API de Hyprland 0.56.2.

Une erreur bloque la génération : aucun fichier n'est écrit. Un avertissement est
seulement affiché. errors travaille sur le TOML brut et ne lève jamais d'exception,
afin que chaque défaut soit signalé par un message plutôt que par une trace Python.
Les clés et les types de chaque table sont vérifiés avant toute autre règle.
"""

from __future__ import annotations

from .hyprland import MOVING_LEAVES, NODES, REQUIRED, SPRING_MIN, still, style_error
from .model import reduced_animation
from .spring import critical_spring, exit_spring, spring, unit_mass, zeta

VERSION = "0.1.0"
SECTIONS = ("meta", "rules", "transitions", "hyprland", "hyprland_reduced")
REDUCED_FLOOR_MS = 100   # Plancher du fondu réduit fixé par la bible.

# Types acceptés, désignés par leur nom dans les messages d'erreur.
KINDS = {
    "nombre": lambda v: isinstance(v, (int, float)) and not isinstance(v, bool),
    "texte": lambda v: isinstance(v, str),
    "booléen": lambda v: isinstance(v, bool),
    "liste de textes": lambda v: isinstance(v, list) and all(isinstance(x, str) for x in v),
}

# Clés autorisées dans chaque table, avec leur type ; toute autre clé est refusée.
META_KEYS = {"name": "texte", "prefix": "texte"}
RULE_KEYS = {"exit_ratio": "nombre", "exit_tolerance": "nombre", "overshoot_allowed": "liste de textes",
             "stagger_allowed": "liste de textes", "stagger_cap": "nombre", "reduced_fade_ms": "nombre"}
TRANSITION_KEYS = {"usage": "texte", "mass": "nombre", "stiffness": "nombre", "dampening": "nombre",
                   "exit_ratio": "nombre", "overshoot": "booléen", "symmetric": "booléen", "stagger_ms": "nombre"}
HYPRLAND_KEYS = {"use": "texte", "phase": "texte", "style": "texte", "enabled": "booléen"}
REDUCED_KEYS = {"style": "texte", "enabled": "booléen"}
SPRING_KEYS = ("usage", "mass", "stiffness", "dampening")


def _table(p: str, t, schema: dict) -> list[str]:
    """Contrôle de forme d'une table : clés connues et valeurs du bon type.

    Entrées : p — chemin affiché dans les messages ; t — valeur lue dans le TOML ; schema — clé → type.
    Sortie : liste d'erreurs. Erreurs : aucune exception. Dépendances : KINDS.
    """
    if not isinstance(t, dict):
        return [f"{p} : doit être une table, par exemple {{ use = \"state\" }}"]
    return [f"{p} : clé « {k} » inconnue" if k not in schema else f"{p} : « {k} » doit être de type {schema[k]}"
            for k, v in t.items() if k not in schema or not KINDS[schema[k]](v)]


def _bounds(p: str, s: dict) -> list[str]:
    """Contrôle d'une courbe émise contre la borne de hl.curve dans Hyprland 0.56.2.

    Entrées : p — chemin et phase affichés ; s — ressort tel qu'il sera écrit.
    Sortie : liste d'erreurs. Erreurs : aucune exception. Dépendances : hyprland.SPRING_MIN.
    """
    return [f"{p} : {k} {v} refusé par Hyprland, qui exige une valeur supérieure à {SPRING_MIN}"
            for k, v in s.items() if v <= SPRING_MIN]


def _transitions(raw: dict) -> list[str]:
    """Contrôle des transitions : clés, valeurs positives, bornes de Hyprland, dépassement, sortie et cascade.

    Entrée : raw — TOML brut dont les clés et les types ont été vérifiés.
    Sortie : liste d'erreurs. Erreurs : aucune exception.
    Dépendances : spring, unit_mass, exit_spring, zeta, _bounds.
    """
    rules, err = raw["rules"], []
    lo = round(rules["exit_ratio"] - rules["exit_tolerance"], 6)
    hi = round(rules["exit_ratio"] + rules["exit_tolerance"], 6)
    for name, t in raw["transitions"].items():
        p = f"transitions.{name}"
        needed = SPRING_KEYS + (() if t.get("symmetric") else ("exit_ratio",))
        missing = [k for k in needed if k not in t]
        err += [f"{p} : clé « {k} » manquante" for k in missing]
        if missing:
            continue
        s = spring(t["mass"], t["stiffness"], t["dampening"])
        nonpositive = [k for k, v in s.items() if v <= 0]
        err += [f"{p} : {k} doit être strictement positif, après arrondi" for k in nonpositive]
        if nonpositive:
            continue
        s_in = unit_mass(s)
        err += _bounds(f"{p} (entrée, masse ramenée à 1)", s_in)
        allowed = name in rules["overshoot_allowed"]
        if (z := zeta(s)) < 1 and not allowed:
            err.append(f"{p} : ζ {z:.2f} < 1, dépassement interdit par la bible")
        if t.get("overshoot") and not allowed:
            err.append(f"{p} : overshoot réservé à {', '.join(rules['overshoot_allowed'])}")
        if t.get("symmetric") and "exit_ratio" in t:
            err.append(f"{p} : transition symétrique, exit_ratio interdit")
        elif not t.get("symmetric"):
            if t["exit_ratio"] <= 0 or not lo <= t["exit_ratio"] <= hi:
                err.append(f"{p} : exit_ratio {t['exit_ratio']} hors de l'intervalle {lo}–{hi}")
            else:
                err += _bounds(f"{p} (sortie, masse ramenée à 1)", exit_spring(s_in, t["exit_ratio"]))
        if "stagger_ms" in t and name not in rules["stagger_allowed"]:
            err.append(f"{p} : cascade interdite, réservée à {', '.join(rules['stagger_allowed'])}")
    return err


def _hyprland(raw: dict) -> list[str]:
    """Contrôle de [hyprland] : éléments connus et complets, transition, phase et style valides.

    Entrée : raw — TOML brut dont les clés et les types ont été vérifiés.
    Sortie : liste d'erreurs. Erreurs : aucune exception.
    Dépendances : hyprland.NODES, hyprland.REQUIRED, hyprland.style_error.
    """
    hyp, names = raw["hyprland"], set(raw["transitions"])
    err = [f"hyprland : élément « {leaf} » non déclaré" for leaf in sorted(REQUIRED - set(hyp))]
    for leaf, e in hyp.items():
        p = f"hyprland.{leaf}"
        if leaf not in NODES:
            err.append(f"{p} : élément Hyprland inconnu")
        elif e.get("enabled", True):
            if "use" not in e:
                err.append(f"{p} : clé « use » manquante")
            elif e["use"] not in names:
                err.append(f"{p} : transition « {e['use']} » inconnue")
            if e.get("phase", "in") not in ("in", "out"):
                err.append(f"{p} : phase « {e['phase']} » invalide, in ou out attendu")
            if why := style_error(leaf, e.get("style", "")):
                err.append(f"{p} : style « {e['style']} » invalide ({why})")
    return err


def _reduced(raw: dict) -> list[str]:
    """Contrôle de [hyprland_reduced] : éléments déclarés, styles valides, aucun mouvement résiduel.

    L'immobilité est vérifiée sur l'animation réduite telle qu'elle sera émise, pas seulement sur la source.
    Entrée : raw — TOML brut dont les clés et les types ont été vérifiés.
    Sortie : liste d'erreurs. Erreurs : aucune exception.
    Dépendances : hyprland.MOVING_LEAVES, hyprland.still, hyprland.style_error, model.reduced_animation.
    """
    hyp, red, err = raw["hyprland"], raw["hyprland_reduced"], []
    for leaf, o in red.items():
        p = f"hyprland_reduced.{leaf}"
        if leaf not in hyp:
            err.append(f"{p} : élément absent de [hyprland]")
        elif why := style_error(leaf, o.get("style", "")):
            err.append(f"{p} : style « {o['style']} » invalide ({why})")
    for leaf, e in hyp.items():
        a = reduced_animation(leaf, e, red.get(leaf, {}), "")
        if not a["enabled"] or still(leaf, style := a.get("style", "")):
            continue
        if leaf in MOVING_LEAVES:
            err.append(f"hyprland_reduced : {leaf} déplace ou agrandit quel que soit son style ; "
                       "il doit être désactivé (enabled = false)")
        elif leaf in red:
            shown = f"le style « {style} »" if style else "le style par défaut de Hyprland"
            err.append(f"hyprland_reduced.{leaf} : {shown} déplace encore l'élément en mouvement réduit")
        else:
            shown = f"le style « {e['style']} »" if e.get("style") else "le style par défaut de Hyprland"
            err.append(f"hyprland_reduced : {leaf} doit remplacer {shown}, qui déplace l'élément")
    return err


def errors(raw: dict) -> list[str]:
    """Contrôles bloquants d'un motion.toml brut.

    Entrée : raw — sortie de model.load.
    Sortie : liste d'erreurs, vide si la source est conforme.
    Erreurs : aucune exception ; chaque défaut devient un message.
    Dépendances : _table, _bounds, _transitions, _hyprland, _reduced.
    """
    if raw.get("version") != VERSION:
        return [f"version {raw.get('version')} inconnue (attendue : {VERSION})"]
    err = [f"section [{s}] manquante" for s in SECTIONS if not isinstance(raw.get(s), dict)]
    if err:
        return err
    err += _table("meta", raw["meta"], META_KEYS) + _table("rules", raw["rules"], RULE_KEYS)
    err += [f"meta : clé « {k} » manquante" for k in META_KEYS if k not in raw["meta"]]
    err += [f"rules : clé « {k} » manquante" for k in RULE_KEYS if k not in raw["rules"]]
    for section, schema in (("transitions", TRANSITION_KEYS), ("hyprland", HYPRLAND_KEYS),
                            ("hyprland_reduced", REDUCED_KEYS)):
        for name, t in raw[section].items():
            err += _table(f"{section}.{name}", t, schema)
    if err:
        return err
    if raw["rules"]["reduced_fade_ms"] <= 0:
        err.append("rules : reduced_fade_ms doit être strictement positif")
    else:
        err += _bounds("rules : ressort réduit", critical_spring(raw["rules"]["reduced_fade_ms"]))
    return err + _transitions(raw) + _hyprland(raw) + _reduced(raw)


def warnings(model: dict) -> list[str]:
    """Contrôles non bloquants du modèle résolu.

    Entrée : model — sortie de model.resolve.
    Sortie : liste d'avertissements, vide si tout est conforme.
    Erreurs : KeyError si le modèle est incomplet. Dépendances : REDUCED_FLOOR_MS.
    """
    ms = model["rules"]["reduced_fade_ms"]
    return [f"reduced_fade_ms = {ms} ms, sous le plancher de {REDUCED_FLOOR_MS} ms fixé par la bible"] \
        if ms < REDUCED_FLOOR_MS else []
