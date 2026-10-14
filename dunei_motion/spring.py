"""Ressort physique — même modèle que Hyprland (hyprutils) et que le banc proto/motion.

Progression normalisée de 0 à 1, masse m, raideur k, amortissement c, temps en
secondes. Les durées sont mesurées par simulation, jamais par une formule approchée.
"""

from __future__ import annotations

import math

STEP = 0.001          # Pas d'intégration en secondes, identique à proto/motion/physics.js.
EPSILON = 0.001       # Seuil d'arrêt de hyprutils, appliqué à l'écart et à la vitesse.
SETTLE = 0.01         # Tolérance de la durée de stabilisation perçue (±1 %).
CRITICAL_WT = 6.638   # Solution de (1 + ωt)·e^(−ωt) = 0,01, reprise du banc.


def spring(mass: float, stiffness: float, dampening: float) -> dict:
    """Ressort arrondi — forme commune à toutes les cibles.

    Entrées : mass, stiffness, dampening.
    Sortie : {mass, stiffness, dampening}, arrondis au centième, au dixième et au centième.
    Erreurs : aucune. Dépendances : aucune.
    """
    return {"mass": round(mass, 2), "stiffness": round(stiffness, 1), "dampening": round(dampening, 2)}


def zeta(s: dict) -> float:
    """Rapport d'amortissement ζ = c / (2·√(k·m)) ; un ressort dépasse sa cible si ζ < 1.

    Entrée : s — ressort aux valeurs strictement positives.
    Sortie : ζ, non arrondi. Erreurs : ValueError si k·m est négatif. Dépendances : math.
    """
    return s["dampening"] / (2 * math.sqrt(s["stiffness"] * s["mass"]))


def simulate(s: dict) -> tuple[int, float]:
    """Réponse indicielle de 0 à 1, intégrée par Euler semi-implicite comme dans le banc.

    Entrée : s — ressort aux valeurs strictement positives.
    Sortie : (durée en ms après laquelle l'écart reste sous 1 %, dépassement maximal en %).
    Erreurs : ZeroDivisionError si la masse est nulle ; la simulation s'arrête à 10 s.
    Dépendances : STEP, EPSILON, SETTLE.
    """
    m, k, c = s["mass"], s["stiffness"], s["dampening"]
    x = v = peak = 0.0
    settle = 0
    for i in range(1, round(10 / STEP) + 1):
        v += (-k * (x - 1) - c * v) / m * STEP
        x += v * STEP
        peak = max(peak, x)
        if abs(x - 1) >= SETTLE:
            settle = i
        if abs(x - 1) < EPSILON and abs(v) < EPSILON:
            break
    return round(settle * STEP * 1000), round(max(0.0, peak - 1) * 100, 2)


def unit_mass(s: dict) -> dict:
    """Même ressort ramené à une masse de 1 : k ÷ m et c ÷ m décrivent exactement le même mouvement.

    Hyprland 0.56.2 refuse une masse inférieure ou égale à 0,5 ; le banc, lui, en autorise.
    Entrée : s — ressort à la masse strictement positive.
    Sortie : ressort arrondi de masse 1. Erreurs : ZeroDivisionError si la masse est nulle.
    Dépendances : spring.
    """
    return spring(1, s["stiffness"] / s["mass"], s["dampening"] / s["mass"])


def exit_spring(s: dict, ratio: float) -> dict:
    """Ressort de sortie — le même mouvement, accéléré d'un facteur 1/ratio.

    k ÷ ratio² et c ÷ ratio, masse inchangée : ζ est conservé, les durées sont multipliées par ratio.
    Entrées : s — ressort d'entrée ; ratio — exit_ratio, strictement positif.
    Sortie : ressort arrondi. Erreurs : ZeroDivisionError si ratio est nul. Dépendances : spring.
    """
    return spring(s["mass"], s["stiffness"] / ratio**2, s["dampening"] / ratio)


def critical_spring(ms: float) -> dict:
    """Ressort critique (masse 1, ζ = 1) qui se stabilise à ±1 % en ms millisecondes.

    Entrée : ms — durée visée, strictement positive.
    Sortie : ressort arrondi. Erreurs : ZeroDivisionError si ms est nul.
    Dépendances : CRITICAL_WT, spring.
    """
    w = CRITICAL_WT / (ms / 1000)
    return spring(1, w * w, 2 * w)
