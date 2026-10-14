"""Contrôles du mouvement — règles du chapitre 6 de la bible et API de Hyprland 0.56.2.

Une erreur bloque la génération : aucun fichier n'est écrit. Un avertissement est
seulement affiché. errors travaille sur le TOML brut et ne lève jamais d'exception,
afin que chaque défaut soit signalé par un message plutôt que par une trace Python.
"""

from __future__ import annotations

from .hyprland import NODES, REQUIRED, still, style_error
from .spring import spring, zeta

VERSION = "0.1.0"
SECTIONS = ("meta", "rules", "transitions", "hyprland", "hyprland_reduced")
META_KEYS = ("name", "prefix")
RULE_KEYS = ("exit_ratio", "exit_tolerance", "overshoot_allowed", "stagger_allowed", "stagger_cap", "reduced_fade_ms")
SPRING_KEYS = ("usage", "mass", "stiffness", "dampening")
REDUCED_FLOOR_MS = 100   # Plancher du fondu réduit fixé par la bible.


def _transitions(raw: dict) -> list[str]:
    """Contrôle des transitions : clés, valeurs positives, dépassement, sortie et cascade.

    Entrée : raw — TOML brut, sections et règles déjà présentes.
    Sortie : liste d'erreurs. Erreurs : aucune exception. Dépendances : spring, zeta.
    """
    rules, err = raw["rules"], []
    lo = round(rules["exit_ratio"] - rules["exit_tolerance"], 6)
    hi = round(rules["exit_ratio"] + rules["exit_tolerance"], 6)
    for name, t in raw["transitions"].items():
        p = f"transitions.{name}"
        if not isinstance(t, dict):
            err.append(f"{p} : doit être une table")
            continue
        needed = SPRING_KEYS + (() if t.get("symmetric") else ("exit_ratio",))
        missing = [k for k in needed if k not in t]
        err += [f"{p} : clé « {k} » manquante" for k in missing]
        nonpositive = [k for k in ("mass", "stiffness", "dampening") if k in t and t[k] <= 0]
        err += [f"{p} : {k} doit être strictement positif" for k in nonpositive]
        if missing or nonpositive:
            continue
        allowed = name in rules["overshoot_allowed"]
        z = zeta(spring(t["mass"], t["stiffness"], t["dampening"]))
        if z < 1 and not allowed:
            err.append(f"{p} : ζ {z:.2f} < 1, dépassement interdit par la bible")
        if t.get("overshoot") and not allowed:
            err.append(f"{p} : overshoot réservé à {', '.join(rules['overshoot_allowed'])}")
        if t.get("symmetric") and "exit_ratio" in t:
            err.append(f"{p} : transition symétrique, exit_ratio interdit")
        elif not t.get("symmetric") and not lo <= t["exit_ratio"] <= hi:
            err.append(f"{p} : exit_ratio {t['exit_ratio']} hors de l'intervalle {lo}–{hi}")
        if "stagger_ms" in t and name not in rules["stagger_allowed"]:
            err.append(f"{p} : cascade interdite, réservée à {', '.join(rules['stagger_allowed'])}")
    return err


def _hyprland(raw: dict) -> list[str]:
    """Contrôle de [hyprland] : éléments connus et complets, transition, phase et style valides.

    Entrée : raw — TOML brut, sections présentes.
    Sortie : liste d'erreurs. Erreurs : aucune exception.
    Dépendances : hyprland.NODES, hyprland.REQUIRED, hyprland.style_error.
    """
    hyp, names = raw["hyprland"], set(raw["transitions"])
    err = [f"hyprland : élément « {leaf} » non déclaré" for leaf in sorted(REQUIRED - set(hyp))]
    for leaf, e in hyp.items():
        p = f"hyprland.{leaf}"
        if leaf not in NODES:
            err.append(f"{p} : élément Hyprland inconnu")
        elif not isinstance(e, dict):
            err.append(f"{p} : doit être une table, par exemple {{ use = \"state\" }}")
        elif e.get("enabled", True) is not False:
            if e.get("use") not in names:
                err.append(f"{p} : transition « {e.get('use')} » inconnue")
            if e.get("phase", "in") not in ("in", "out"):
                err.append(f"{p} : phase « {e['phase']} » invalide, in ou out attendu")
            if why := style_error(leaf, e.get("style", "")):
                err.append(f"{p} : style « {e['style']} » invalide ({why})")
    return err


def _reduced(raw: dict) -> list[str]:
    """Contrôle de [hyprland_reduced] : éléments déclarés, styles valides, aucun mouvement résiduel.

    Entrée : raw — TOML brut, sections présentes.
    Sortie : liste d'erreurs. Erreurs : aucune exception.
    Dépendances : hyprland.still, hyprland.style_error.
    """
    hyp, red, err = raw["hyprland"], raw["hyprland_reduced"], []
    for leaf, o in red.items():
        p = f"hyprland_reduced.{leaf}"
        if leaf not in hyp:
            err.append(f"{p} : élément absent de [hyprland]")
        elif not isinstance(o, dict):
            err.append(f"{p} : doit être une table, par exemple {{ style = \"fade\" }}")
        elif why := style_error(leaf, o.get("style", "")):
            err.append(f"{p} : style « {o['style']} » invalide ({why})")
    for leaf, e in hyp.items():
        if isinstance(e, dict) and e.get("enabled", True) is not False and leaf not in red \
                and not still(leaf, style := e.get("style", "")):
            shown = f"le style « {style} »" if style else "le style par défaut de Hyprland"
            err.append(f"hyprland_reduced : {leaf} doit remplacer {shown}, qui déplace l'élément")
    return err


def errors(raw: dict) -> list[str]:
    """Contrôles bloquants d'un motion.toml brut.

    Entrée : raw — sortie de model.load.
    Sortie : liste d'erreurs, vide si la source est conforme.
    Erreurs : aucune exception ; chaque défaut devient un message.
    Dépendances : _transitions, _hyprland, _reduced.
    """
    if raw.get("version") != VERSION:
        return [f"version {raw.get('version')} inconnue (attendue : {VERSION})"]
    err = [f"section [{s}] manquante" for s in SECTIONS if not isinstance(raw.get(s), dict)]
    if err:
        return err
    err += [f"meta : clé « {k} » manquante" for k in META_KEYS if k not in raw["meta"]]
    err += [f"rules : clé « {k} » manquante" for k in RULE_KEYS if k not in raw["rules"]]
    if err:
        return err
    if raw["rules"]["reduced_fade_ms"] <= 0:
        err.append("rules : reduced_fade_ms doit être strictement positif")
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
