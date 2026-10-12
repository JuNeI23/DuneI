"""Cible Qt — schéma de couleurs KDE (kdeglobals).

Consommé par Breeze (Qt) et, via kde-gtk-config, par Breeze-GTK (GTK 3).
Se recharge à chaud : changer de thème ne demande aucun redémarrage.

La correspondance est une DÉCISION DE DESIGN, pas une conversion mécanique.
Elle projette le modèle d'élévation sur les jeux de couleurs KDE :
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
    Sortie : contenu de kdeglobals.
    Erreurs : KeyError si le TOML brut est incomplet.
    Dépendances : color.to_rgb_csv.
    """
    r, raw, ramp, sem = model["roles"], model["raw"], model["ramp"], model["semantic"]
    accent, on_accent = model["accent"], model["on_accent"]

    def common(fg_normal, fg_inactive):
        """Jeu commun — les sémantiques restent INVARIANTES (liste d'invariants de la bible)."""
        return {
            "ForegroundNormal": fg_normal,
            "ForegroundInactive": fg_inactive,
            "ForegroundActive": accent,
            "ForegroundLink": accent,
            "ForegroundVisited": ramp[7],
            "ForegroundNegative": sem["error"],
            "ForegroundNeutral": sem["warning"],
            "ForegroundPositive": sem["success"],
            "DecorationFocus": accent,
            "DecorationHover": accent,
        }

    text = common(r["text-primary"], r["text-tertiary"])
    sets = {
        "Colors:View": dict(BackgroundNormal=ramp[0], BackgroundAlternate=ramp[1], **text),
        "Colors:Window": dict(BackgroundNormal=ramp[1], BackgroundAlternate=ramp[2], **text),
        "Colors:Header": dict(BackgroundNormal=ramp[2], BackgroundAlternate=ramp[3], **text),
        "Colors:Button": dict(BackgroundNormal=ramp[3], BackgroundAlternate=ramp[2], **text),
        "Colors:Tooltip": dict(BackgroundNormal=ramp[3], BackgroundAlternate=ramp[2], **text),
        "Colors:Selection": dict(BackgroundNormal=accent, BackgroundAlternate=accent, **common(on_accent, on_accent)),
        "Colors:Complementary": dict(BackgroundNormal=ramp[2], BackgroundAlternate=ramp[3], **text),
    }

    out = [
        "# GÉNÉRÉ depuis tokens.toml — NE PAS MODIFIER À LA MAIN",
        "# Destination : ~/.config/kdeglobals  (et ~/.local/share/color-schemes/*.colors)",
        "# kde-gtk-config répercute ensuite vers Breeze-GTK, sans redémarrage.",
        "",
        "[General]",
        "ColorScheme=SystemeTheme",
        f"Name=Theme machine (teinte {model['hue']}°)",
        "shadeSortColumn=true",
        "",
    ]
    for section, colors in sets.items():
        out.append(f"[{section}]")
        out += [f"{key}={to_rgb_csv(col)}" for key, col in colors.items()]
        out.append("")

    t = raw["type"]
    out += [
        "[General]",
        f"font={t['interface']},{t['base_size']},-1,5,{t['weight_regular']},0,0,0,0,0",
        f"fixed={t['mono']},{t['base_size']},-1,5,{t['weight_regular']},0,0,0,0,0",
        "",
        "[KDE]",
        "widgetStyle=Breeze",
        "",
        "[Icons]",
        f"Theme={raw['icons'].get('xdg_theme', 'Adwaita')}",
        "",
    ]
    return "\n".join(out) + "\n"
