"""Cibles GTK — libadwaita (GTK 4) et adw-gtk3 (GTK 3).

libadwaita n'accepte PAS de thème : sa géométrie est figée. Mais la
RECOLORATION est officiellement prévue, par couleurs nommées et variables CSS.
Le modèle d'élévation s'y projette à l'identique :
    view                   = ce qui reçoit du contenu  → E0
    window                 = corps de fenêtre          → E1
    headerbar / sidebar    = barres                    → E2
    card / popover / dialog = flottant                 → E3

adw-gtk3 donne aux applications GTK 3 l'apparence de libadwaita avec les mêmes
noms : une application qui migre de GTK 3 à GTK 4 ne change pas d'apparence.
"""

from __future__ import annotations

from ..color import oklch, to_hex

_ALPHA = {
    "shade_color": "rgba(0,0,0,0.36)",
    "scrollbar_outline_color": "rgba(0,0,0,0.5)",
    "headerbar_shade_color": "rgba(0,0,0,0.36)",
    "sidebar_shade_color": "rgba(0,0,0,0.36)",
    "secondary_sidebar_shade_color": "rgba(0,0,0,0.36)",
    "card_shade_color": "rgba(0,0,0,0.36)",
    "popover_shade_color": "rgba(0,0,0,0.36)",
}


def palette(model: dict) -> dict:
    """Couleurs nommées libadwaita.

    Entrée : model — sortie de model.resolve.
    Sortie : {nom libadwaita: Oklch}.
    Erreurs : KeyError si le TOML brut est incomplet.
    Dépendances : color.oklch.
    """
    r, ramp, sem, raw = model["roles"], model["ramp"], model["semantic"], model["raw"]
    th, steps = raw["theme"], raw["lightness"]["steps"]

    # Accent « autonome » : pour du TEXTE accentué sur fond sombre, donc bien
    # plus clair que l'accent de remplissage, sinon illisible.
    accent_standalone = oklch(steps[9], th["accent_chroma"] * th["chroma_scale"], model["hue"], th["chroma_ceiling"])
    fg, dark = r["text-primary"], ramp[0]

    return {
        "accent_color": accent_standalone,
        "accent_bg_color": model["accent"],
        "accent_fg_color": model["on_accent"],
        # sémantiques — INVARIANTES, hors moteur de thème
        "destructive_color": sem["error"], "destructive_bg_color": sem["error"], "destructive_fg_color": dark,
        "error_color": sem["error"], "error_bg_color": sem["error"], "error_fg_color": dark,
        "warning_color": sem["warning"], "warning_bg_color": sem["warning"], "warning_fg_color": dark,
        "success_color": sem["success"], "success_bg_color": sem["success"], "success_fg_color": dark,
        # E0 — ce qui reçoit du contenu s'enfonce
        "view_bg_color": ramp[0], "view_fg_color": fg,
        # E1 — corps de fenêtre
        "window_bg_color": ramp[1], "window_fg_color": fg,
        # E2 — barres et panneaux
        "headerbar_bg_color": ramp[2], "headerbar_fg_color": fg,
        "headerbar_border_color": ramp[4], "headerbar_backdrop_color": ramp[1],
        "sidebar_bg_color": ramp[2], "sidebar_fg_color": fg,
        "sidebar_border_color": ramp[4], "sidebar_backdrop_color": ramp[1],
        "secondary_sidebar_bg_color": ramp[2], "secondary_sidebar_fg_color": fg,
        "secondary_sidebar_border_color": ramp[4], "secondary_sidebar_backdrop_color": ramp[1],
        # E3 — ce qui flotte s'élève
        "card_bg_color": ramp[3], "card_fg_color": fg,
        "dialog_bg_color": ramp[3], "dialog_fg_color": fg,
        "popover_bg_color": ramp[3], "popover_fg_color": fg,
        "thumbnail_bg_color": ramp[3], "thumbnail_fg_color": fg,
    }


def _header(model: dict) -> list[str]:
    """En-tête commun — avertissement « généré » et teinte.

    Entrée : model. Sortie : lignes d'en-tête. Erreurs : aucune. Dépendances : aucune.
    """
    return ["/* GÉNÉRÉ depuis tokens.toml — NE PAS MODIFIER À LA MAIN */", f"/* thème machine : teinte {model['hue']}° */", ""]


def _define_colors(pal: dict) -> list[str]:
    """Couleurs nommées au format `@define-color`, seul format de GTK 3.

    Entrée : pal — sortie de palette. Sortie : lignes CSS. Erreurs : aucune.
    Dépendances : color.to_hex.
    """
    return [f"@define-color {n} {to_hex(c)};" for n, c in pal.items()] + [f"@define-color {n} {v};" for n, v in _ALPHA.items()]


def emit_gtk3(model: dict) -> str:
    """~/.config/gtk-3.0/gtk.css — consommé par adw-gtk3.

    Entrée : model. Sortie : contenu CSS. Erreurs : KeyError si TOML incomplet.
    Dépendances : palette, _define_colors.
    """
    return "\n".join(_header(model) + _define_colors(palette(model))) + "\n"


def emit_gtk4(model: dict) -> str:
    """~/.config/gtk-4.0/gtk.css — consommé par libadwaita.

    Écrit les DEUX formes : variables CSS (1.6+) et couleurs nommées (compatibilité).
    La surcharge CSS donne la teinte EXACTE, là où le portail n'en fournit
    qu'une approximation parmi neuf.

    Entrée : model. Sortie : contenu CSS. Erreurs : KeyError si TOML incomplet.
    Dépendances : palette, _define_colors, color.to_hex.
    """
    raw, pal = model["raw"], palette(model)
    out = _header(model) + [":root {"]
    out += [f"  --{n.replace('_', '-')}: {to_hex(c)};" for n, c in pal.items()]
    out += [f"  --{n.replace('_', '-')}: {v};" for n, v in _ALPHA.items()]
    out += [
        "",
        "  /* seule convergence géométrique avec le shell : le coin de fenêtre */",
        f"  --window-radius: {raw['radii']['window']}px;",
        f"  --disabled-opacity: {raw['states']['disabled']['chroma_multiplier'] + 0.35:.2f};",
        "}",
        "",
        "/* compatibilité avec les versions antérieures à 1.6 */",
    ]
    return "\n".join(out + _define_colors(pal)) + "\n"
