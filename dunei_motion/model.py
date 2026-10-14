"""Résolution du mouvement — motion.toml → ressorts d'entrée, de sortie et réduit, puis animations Hyprland."""

from __future__ import annotations

import tomllib
from pathlib import Path

from .spring import critical_spring, exit_spring, simulate, spring, zeta


def load(src: Path) -> dict:
    """Lecture de la source de vérité du mouvement.

    Entrée : src — chemin de motion.toml.
    Sortie : dictionnaire brut du TOML, dans l'ordre du fichier.
    Erreurs : FileNotFoundError si absent, tomllib.TOMLDecodeError si invalide.
    Dépendances : tomllib.
    """
    with src.open("rb") as fh:
        return tomllib.load(fh)


def describe(s: dict) -> dict:
    """Ressort accompagné de ses grandeurs indicatives.

    Entrée : s — ressort arrondi.
    Sortie : {mass, stiffness, dampening, zeta, settle_ms}.
    Erreurs : aucune pour un ressort aux valeurs positives. Dépendances : spring.zeta, spring.simulate.
    """
    return {**s, "zeta": round(zeta(s), 2), "settle_ms": simulate(s)[0]}


def _animation(leaf: str, entry: dict, prefix: str) -> dict:
    """Animation du mode normal pour un élément de Hyprland.

    Entrées : leaf — élément ; entry — sa table dans [hyprland] ; prefix — préfixe des courbes.
    Sortie : entrée prête pour hl.animation. Erreurs : KeyError si `use` manque sur un élément actif.
    Dépendances : aucune.
    """
    if entry.get("enabled", True) is False:
        return {"leaf": leaf, "enabled": False}
    a = {"leaf": leaf, "enabled": True, "speed": 1, "spring": f"{prefix}-{entry['use']}-{entry.get('phase', 'in')}"}
    return a | ({"style": entry["style"]} if "style" in entry else {})


def _reduced_animation(leaf: str, entry: dict, override: dict, prefix: str) -> dict:
    """Animation du mouvement réduit pour un élément de Hyprland.

    Entrées : leaf — élément ; entry — sa table dans [hyprland] ;
              override — sa table dans [hyprland_reduced], vide s'il n'y figure pas ; prefix — préfixe.
    Sortie : entrée prête pour hl.animation, sur le ressort réduit et sans autre style que celui de override.
    Erreurs : aucune. Dépendances : aucune.
    """
    if entry.get("enabled", True) is False or override.get("enabled", True) is False:
        return {"leaf": leaf, "enabled": False}
    a = {"leaf": leaf, "enabled": True, "speed": 1, "spring": f"{prefix}-reduced"}
    return a | ({"style": override["style"]} if "style" in override else {})


def resolve(raw: dict) -> dict:
    """Résolution complète d'un motion.toml déjà validé par checks.errors.

    Entrée : raw — sortie de load.
    Sortie : {version, prefix, rules, transitions, reduced, curves, animations, reduced_animations}
             (le détail est donné dans le plan, tâche 3).
    Erreurs : KeyError si raw n'a pas été validé et qu'une clé manque.
    Dépendances : spring, describe, _animation, _reduced_animation.
    """
    prefix, rules = raw["meta"]["prefix"], raw["rules"]
    transitions, curves = {}, {}
    for name, t in raw["transitions"].items():
        s_in = spring(t["mass"], t["stiffness"], t["dampening"])
        s_out = s_in if t.get("symmetric") else exit_spring(s_in, t["exit_ratio"])
        transitions[name] = {"usage": t["usage"], "in": describe(s_in), "out": describe(s_out),
                             "overshoot": t.get("overshoot", False), "symmetric": t.get("symmetric", False)}
        if "stagger_ms" in t:
            transitions[name]["stagger"] = {"ms": t["stagger_ms"], "cap": rules["stagger_cap"]}
        curves[f"{prefix}-{name}-in"], curves[f"{prefix}-{name}-out"] = s_in, s_out
    reduced = critical_spring(rules["reduced_fade_ms"])
    curves[f"{prefix}-reduced"] = reduced
    hyp, overrides = raw["hyprland"], raw["hyprland_reduced"]
    return {
        "version": raw["version"], "prefix": prefix, "rules": rules,
        "transitions": transitions, "reduced": describe(reduced),
        "curves": dict(sorted(curves.items())),
        "animations": [_animation(leaf, e, prefix) for leaf, e in hyp.items()],
        "reduced_animations": [_reduced_animation(leaf, e, overrides.get(leaf, {}), prefix) for leaf, e in hyp.items()],
    }
