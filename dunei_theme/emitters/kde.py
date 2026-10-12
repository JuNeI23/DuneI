"""Cible Qt — schéma de couleurs KDE (kdeglobals).

Consommé par Breeze (Qt) et, via kde-gtk-config, par Breeze-GTK (GTK 3).
Se recharge à chaud : changer de thème ne demande aucun redémarrage.

La correspondance est une DÉCISION DE DESIGN, pas une conversion mécanique.
Elle projette le modèle d'élévation (niveaux lus dans [elevation]) sur les
jeux de couleurs KDE :
    View   = ce qui reçoit du contenu  → s'enfonce  → E0
    Window = corps de fenêtre                        → E1
    Header = barres et en-têtes                      → E2
    Button = ce qui s'élève                          → E3
"""

from __future__ import annotations

from ..color import to_rgb_csv


def emit(model: dict) -> str:
    """Schéma de couleurs KDE.

    Entrée : model — sortie de model.resolve.
    Sortie : contenu de kdeglobals, une seule section [General].
    Erreurs : KeyError si un rôle, un niveau d'élévation ou une clé du TOML manque.
    Dépendances : color.to_rgb_csv.
    """
    r, e, raw, sem = model["roles"], model["elevation"], model["raw"], model["semantic"]
    accent, on_accent = model["accent"], model["on_accent"]

    def common(fg_normal, fg_inactive):
        """Jeu de premiers plans commun à tous les jeux de couleurs.

        Entrées : fg_normal, fg_inactive — Oklch du texte normal et inactif.
        Sortie : {clé KDE: Oklch}. Les sémantiques restent INVARIANTES.
        Erreurs : KeyError si un rôle manque. Dépendances : aucune.
        """
        return {
            "ForegroundNormal": fg_normal,
            "ForegroundInactive": fg_inactive,
            "ForegroundActive": accent,
            "ForegroundLink": accent,
            "ForegroundVisited": r["text-disabled"],
            "ForegroundNegative": sem["error"],
            "ForegroundNeutral": sem["warning"],
            "ForegroundPositive": sem["success"],
            "DecorationFocus": accent,
            "DecorationHover": accent,
        }

    text = common(r["text-primary"], r["text-tertiary"])
    sets = {
        "Colors:View": dict(BackgroundNormal=e["e0"], BackgroundAlternate=e["e1"], **text),
        "Colors:Window": dict(BackgroundNormal=e["e1"], BackgroundAlternate=e["e2"], **text),
        "Colors:Header": dict(BackgroundNormal=e["e2"], BackgroundAlternate=e["e3"], **text),
        "Colors:Button": dict(BackgroundNormal=e["e3"], BackgroundAlternate=e["e2"], **text),
        "Colors:Tooltip": dict(BackgroundNormal=e["e3"], BackgroundAlternate=e["e2"], **text),
        "Colors:Selection": dict(BackgroundNormal=accent, BackgroundAlternate=accent, **common(on_accent, on_accent)),
        "Colors:Complementary": dict(BackgroundNormal=e["e2"], BackgroundAlternate=e["e3"], **text),
    }

    t, name = raw["type"], raw["meta"]["name"]
    out = [
        "# GÉNÉRÉ depuis tokens.toml — NE PAS MODIFIER À LA MAIN",
        "# Destination : ~/.config/kdeglobals  (et ~/.local/share/color-schemes/*.colors)",
        "# kde-gtk-config répercute ensuite vers Breeze-GTK, sans redémarrage.",
        "",
        "[General]",
        f"ColorScheme={name}",
        f"Name=Theme machine (teinte {model['hue']}°)",
        "shadeSortColumn=true",
        f"font={t['interface']},{t['base_size']},-1,5,{t['weight_regular']},0,0,0,0,0",
        f"fixed={t['mono']},{t['base_size']},-1,5,{t['weight_regular']},0,0,0,0,0",
        "",
    ]
    for section, colors in sets.items():
        out.append(f"[{section}]")
        out += [f"{key}={to_rgb_csv(col)}" for key, col in colors.items()]
        out.append("")

    out += [
        "[KDE]",
        "widgetStyle=Breeze",
        "",
        "[Icons]",
        f"Theme={raw['icons']['xdg_theme']}",
        "",
    ]
    return "\n".join(out) + "\n"
