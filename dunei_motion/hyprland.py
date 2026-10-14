"""Hyprland 0.56.2 — éléments d'animation et styles acceptés.

Relevé sur la version installée (`hyprctl animations -j`) et dans la source de
CHyprAnimationManager::styleValidInConfigVar. Ces tables sont à revérifier à chaque
mise à jour de Hyprland : tests/test_motion_hyprland.py compare NODES à la version
en cours d'exécution.
"""

from __future__ import annotations

# Tous les éléments publics de l'arbre d'animation, hors __internal_fadeCTM.
NODES = frozenset({
    "global", "windows", "windowsIn", "windowsOut", "windowsMove",
    "layers", "layersIn", "layersOut",
    "fade", "fadeIn", "fadeOut", "fadeSwitch", "fadeShadow", "fadeGlow", "fadeDim",
    "fadeLayers", "fadeLayersIn", "fadeLayersOut", "fadePopups", "fadePopupsIn", "fadePopupsOut", "fadeDpms",
    "border", "borderangle", "shadowangle", "glowangle",
    "workspaces", "workspacesIn", "workspacesOut", "specialWorkspace", "specialWorkspaceIn", "specialWorkspaceOut",
    "zoomFactor", "monitorAdded",
})

# Les parents intermédiaires ne sont pas déclarés, puisque chacun de leurs enfants l'est.
PARENTS = frozenset({"windows", "layers", "fade", "fadeLayers", "fadePopups", "workspaces", "specialWorkspace"})

# Les 26 éléments terminaux, plus global, qui sert de valeur par défaut aux éléments futurs.
REQUIRED = NODES - PARENTS

# Styles qui ne déplacent pas l'élément et ne changent pas son échelle.
STILL = ("", "fade", "loop", "once")

# Éléments dont le style vide vaut un mouvement : popin pour les fenêtres, slide pour les bureaux.
MOVING_DEFAULT = ("windows", "workspaces", "specialWorkspace")


def _percent(style: str) -> bool:
    """Pourcentage final d'un style, par exemple « popin 90% ».

    Entrée : style. Sortie : vrai si le dernier mot, après une espace, est un entier suivi de « % ».
    Erreurs : aucune. Dépendances : aucune.
    """
    head, _, tail = style.rpartition(" ")
    return bool(head) and tail.endswith("%") and tail[:-1].isdigit()


def still(leaf: str, style: str) -> bool:
    """Absence de mouvement d'un style, compte tenu du style par défaut de Hyprland.

    Entrées : leaf — nom de l'élément ; style — style demandé, vide s'il n'y en a pas.
    Sortie : vrai si l'élément ne se déplace pas et ne change pas d'échelle.
    Erreurs : aucune. Dépendances : STILL, MOVING_DEFAULT.
    """
    return style in STILL and not (style == "" and leaf.startswith(MOVING_DEFAULT))


def style_error(leaf: str, style: str) -> str:
    """Validité d'un style pour un élément, selon la règle de Hyprland 0.56.2.

    Entrées : leaf — nom de l'élément ; style — style demandé, vide s'il n'y en a pas.
    Sortie : chaîne vide si le style est accepté, sinon la raison du refus.
    Erreurs : aucune. Dépendances : _percent.
    """
    if not style:
        return ""
    if leaf.startswith("window"):
        if style.startswith("slide") or style in ("gnome", "gnomed"):
            return ""
        if style.startswith("popin"):
            return "" if "%" not in style or _percent(style) else "pourcentage invalide"
        return "style inconnu"
    if leaf.startswith(("workspaces", "specialWorkspace")):
        if style in ("slide", "slidevert", "fade"):
            return ""
        if style.startswith("slide"):
            return "" if "%" not in style or _percent(style) else "pourcentage invalide"
        return "style inconnu"
    if leaf.endswith("angle"):
        return "" if style in ("loop", "once") else "style inconnu"
    if leaf.startswith("layers"):
        if style == "fade" or style.startswith("slide"):
            return ""
        if style.startswith("popin"):
            return "" if "%" not in style or _percent(style) else "pourcentage invalide"
        return "style inconnu"
    return "cet élément n'accepte aucun style"
