"""Cibles GTK — libadwaita (GTK 4) et adw-gtk3 (GTK 3).

libadwaita n'accepte PAS de thème : sa géométrie est figée. Mais la
RECOLORATION est officiellement prévue, par couleurs nommées et variables CSS.
Le modèle d'élévation s'y projette à l'identique (niveaux lus dans [elevation]) :
    view                   = ce qui reçoit du contenu  → E0
    window                 = corps de fenêtre          → E1
    headerbar / sidebar    = barres                    → E2
    card / popover / dialog = flottant                 → E3

adw-gtk3 donne aux applications GTK 3 l'apparence de libadwaita avec les mêmes
noms : une application qui migre de GTK 3 à GTK 4 ne change pas d'apparence.
"""

from __future__ import annotations

from ..color import Oklch, to_hex, to_srgb255


def _rgba(col: Oklch, alpha: float) -> str:
    """Couleur translucide au format CSS `rgba(R,G,B,A)`.

    Entrées : col — couleur ; alpha — opacité 0–1.
    Sortie : chaîne CSS. Erreurs : aucune. Dépendances : color.to_srgb255.
    """
    return "rgba({},{},{},{:g})".format(*to_srgb255(col), alpha)


def alphas(model: dict) -> dict:
    """Couleurs translucides libadwaita — ombrages et contour superposé.

    Entrée : model — sortie de model.resolve.
    Sortie : {nom libadwaita: chaîne rgba}.
    Erreurs : KeyError si [surface_material] est incomplet.
    Dépendances : _rgba, color.Oklch.
    """
    mat = model["raw"]["surface_material"]
    shadow = Oklch(**mat["shadow_color"])
    shade = _rgba(shadow, mat["shade_opacity"])
    return {
        "shade_color": shade,
        "scrollbar_outline_color": _rgba(shadow, mat["overlay_outline_opacity"]),
        **{f"{n}_shade_color": shade for n in ("headerbar", "sidebar", "secondary_sidebar", "card", "popover")},
    }


def palette(model: dict) -> dict:
    """Couleurs nommées libadwaita.

    Entrée : model — sortie de model.resolve.
    Sortie : {nom libadwaita: Oklch}.
    Erreurs : KeyError si un rôle ou un niveau d'élévation manque.
    Dépendances : aucune (couleurs déjà résolues par model.resolve).
    """
    r, e, sem = model["roles"], model["elevation"], model["semantic"]
    fg, dark, border = r["text-primary"], r["surface-base"], r["border-subtle"]

    return {
        # Accent autonome pour le texte, accent de remplissage pour les fonds.
        "accent_color": model["accent_standalone"],
        "accent_bg_color": model["accent"],
        "accent_fg_color": model["on_accent"],
        # sémantiques — INVARIANTES, hors moteur de thème
        "destructive_color": sem["error"], "destructive_bg_color": sem["error"], "destructive_fg_color": dark,
        "error_color": sem["error"], "error_bg_color": sem["error"], "error_fg_color": dark,
        "warning_color": sem["warning"], "warning_bg_color": sem["warning"], "warning_fg_color": dark,
        "success_color": sem["success"], "success_bg_color": sem["success"], "success_fg_color": dark,
        # E0 — ce qui reçoit du contenu s'enfonce
        "view_bg_color": e["e0"], "view_fg_color": fg,
        # E1 — corps de fenêtre
        "window_bg_color": e["e1"], "window_fg_color": fg,
        # E2 — barres et panneaux
        "headerbar_bg_color": e["e2"], "headerbar_fg_color": fg,
        "headerbar_border_color": border, "headerbar_backdrop_color": e["e1"],
        "sidebar_bg_color": e["e2"], "sidebar_fg_color": fg,
        "sidebar_border_color": border, "sidebar_backdrop_color": e["e1"],
        "secondary_sidebar_bg_color": e["e2"], "secondary_sidebar_fg_color": fg,
        "secondary_sidebar_border_color": border, "secondary_sidebar_backdrop_color": e["e1"],
        # E3 — ce qui flotte s'élève
        "card_bg_color": e["e3"], "card_fg_color": fg,
        "dialog_bg_color": e["e3"], "dialog_fg_color": fg,
        "popover_bg_color": e["e3"], "popover_fg_color": fg,
        "thumbnail_bg_color": e["e3"], "thumbnail_fg_color": fg,
    }


def _header(model: dict) -> list[str]:
    """En-tête commun — avertissement « généré » et teinte.

    Entrée : model. Sortie : lignes d'en-tête. Erreurs : aucune. Dépendances : aucune.
    """
    return ["/* GÉNÉRÉ depuis tokens.toml — NE PAS MODIFIER À LA MAIN */", f"/* thème machine : teinte {model['hue']}° */", ""]


def _define_colors(model: dict) -> list[str]:
    """Couleurs nommées au format `@define-color`, seul format de GTK 3.

    Entrée : model. Sortie : lignes CSS. Erreurs : KeyError si TOML incomplet.
    Dépendances : palette, alphas, color.to_hex.
    """
    return ([f"@define-color {n} {to_hex(c)};" for n, c in palette(model).items()]
            + [f"@define-color {n} {v};" for n, v in alphas(model).items()])


def emit_gtk3(model: dict) -> str:
    """~/.config/gtk-3.0/gtk.css — consommé par adw-gtk3.

    Entrée : model. Sortie : contenu CSS. Erreurs : KeyError si TOML incomplet.
    Dépendances : _header, _define_colors.
    """
    return "\n".join(_header(model) + _define_colors(model)) + "\n"


def emit_gtk4(model: dict) -> str:
    """~/.config/gtk-4.0/gtk.css — consommé par libadwaita.

    Écrit les DEUX formes : variables CSS (1.6+) et couleurs nommées (compatibilité).
    La surcharge CSS donne la teinte EXACTE, là où le portail n'en fournit
    qu'une approximation parmi neuf.

    Entrée : model. Sortie : contenu CSS. Erreurs : KeyError si TOML incomplet.
    Dépendances : palette, alphas, _header, _define_colors, color.to_hex.
    """
    raw = model["raw"]
    out = _header(model) + [":root {"]
    out += [f"  --{n.replace('_', '-')}: {to_hex(c)};" for n, c in palette(model).items()]
    out += [f"  --{n.replace('_', '-')}: {v};" for n, v in alphas(model).items()]
    out += [
        "",
        "  /* seule convergence géométrique avec le shell : le coin de fenêtre */",
        f"  --window-radius: {raw['radii']['window']}px;",
        f"  --disabled-opacity: {raw['states']['disabled']['opacity']:.2f};",
        "}",
        "",
        "/* compatibilité avec les versions antérieures à 1.6 */",
    ]
    return "\n".join(out + _define_colors(model)) + "\n"
