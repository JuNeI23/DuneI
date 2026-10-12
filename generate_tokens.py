#!/usr/bin/env python3
"""
Générateur des tokens de design.

Lit tokens.toml — la source de vérité unique — résout le thème, et produit
les fichiers consommés par chaque sous-système.

    python3 generate_tokens.py [--src tokens.toml] [--out ./build] [--hue 40]

L'option --hue simule un autre thème machine sans toucher au fichier source :
utile pour vérifier qu'un thème ne casse rien avant de le déployer.
"""

from __future__ import annotations

import argparse
import json
import sys
import math
import re
import tomllib
from pathlib import Path


def oklch(l: float, c: float, h: float, ceiling: float) -> str:
    c = min(c, ceiling)
    return f"oklch({l:.3f} {c:.4f} {h:g})"


def to_srgb255(css: str) -> tuple[int, int, int]:
    """oklch(L C H) -> (R, G, B) sur 0-255, rabattu dans le gamut sRGB."""
    m = re.match(r"oklch\(([\d.]+) ([\d.]+) ([-\d.]+)\)", css)
    L, C, H = float(m.group(1)), float(m.group(2)), float(m.group(3))
    h = math.radians(H)
    a, b = C * math.cos(h), C * math.sin(h)
    l3 = (L + 0.3963377774 * a + 0.2158037573 * b) ** 3
    m3 = (L - 0.1055613458 * a - 0.0638541728 * b) ** 3
    s3 = (L - 0.0894841775 * a - 1.2914855480 * b) ** 3
    lin = (4.0767416621 * l3 - 3.3077115913 * m3 + 0.2309699292 * s3,
           -1.2684380046 * l3 + 2.6097574011 * m3 - 0.3413193965 * s3,
           -0.0041960863 * l3 - 0.7034186147 * m3 + 1.7076147010 * s3)
    out = []
    for c in lin:
        c = max(0.0, min(1.0, c))
        c = 12.92 * c if c <= 0.0031308 else 1.055 * c ** (1 / 2.4) - 0.055
        out.append(round(c * 255))
    return tuple(out)


def to_hex(css: str) -> str:
    return "#%02x%02x%02x" % to_srgb255(css)


def resolve(data: dict, hue_override: float | None) -> dict:
    th = dict(data["theme"])
    if hue_override is not None:
        th["hue"] = hue_override % 360

    hue = th["hue"]
    ceiling = th["chroma_ceiling"]
    scale = th["chroma_scale"]
    steps = data["lightness"]["steps"]

    # Neutres : chroma majoré sous L 0.45, la perception y est plus faible.
    ramp = []
    for l in steps:
        c = th["neutral_chroma"] * scale
        if l < 0.45:
            c *= th["dark_chroma_boost"]
        ramp.append(oklch(l, c, hue, ceiling))

    roles = {name: ramp[i] for name, i in data["roles"].items()}

    accent_l = steps[data["categorical"]["lightness_step"] - 2]
    accent = oklch(accent_l, th["accent_chroma"] * scale, hue, ceiling)
    on_accent = oklch(steps[0], 0.020, hue, ceiling)

    cat = data["categorical"]
    categorical = [
        oklch(steps[cat["lightness_step"]], cat["chroma"] * scale, (hue + off) % 360, ceiling)
        for off in cat["hue_offsets"]
    ]

    # La section [semantic] peut contenir des clés
    # scalaires : on ne garde que les définitions de couleur.
    semantic = {
        k: oklch(v["l"], v["c"], v["h"], ceiling)
        for k, v in data["semantic"].items()
        if isinstance(v, dict)
    }

    return {
        "hue": hue,
        "ramp": ramp,
        "roles": roles,
        "accent": accent,
        "on_accent": on_accent,
        "categorical": categorical,
        "semantic": semantic,
        "raw": data,
    }


def check(model: dict) -> list[str]:
    """Vérifications que l'outil fait à notre place, pour qu'aucune ne repose
    sur la vigilance de quelqu'un."""
    warn = []
    raw = model["raw"]

    ceiling = raw["theme"]["chroma_ceiling"]
    if raw["theme"]["accent_chroma"] > ceiling:
        warn.append("le chroma d'accent dépasse le plafond de gamut")

    sep = raw["categorical"]["min_angular_separation"]
    offs = sorted(o % 360 for o in raw["categorical"]["hue_offsets"])
    for a, b in zip(offs, offs[1:]):
        if b - a < sep:
            warn.append(f"teintes catégorielles trop proches : {a}° et {b}°")

    for name, d in raw["density"].items():
        for key in ("control_height", "row_height"):
            if d[key] % 2:
                warn.append(
                    f"densité « {name} » : {key} = {d[key]}px est impair — "
                    "risque de demi-pixel en échelle fractionnaire"
                )

    if raw["surface_material"]["sheen_max_height"] > 120:
        warn.append("sheen autorisé sur une trop grande hauteur : banding probable")

    return warn


def emit_css(model: dict) -> str:
    raw = model["raw"]
    out = ["/* GÉNÉRÉ depuis tokens.toml — NE PAS MODIFIER À LA MAIN */", ":root {"]

    out.append(f"  /* thème : teinte {model['hue']}° */")
    for i, v in enumerate(model["ramp"]):
        out.append(f"  --l-{i}: {v};")
    out.append("")
    for name, v in model["roles"].items():
        out.append(f"  --{name}: {v};")
    out.append("")
    out.append(f"  --accent: {model['accent']};")
    out.append(f"  --on-accent: {model['on_accent']};")
    out.append("")
    for i, v in enumerate(model["categorical"]):
        out.append(f"  --cat-{i}: {v};")
    out.append("")
    out.append("  /* hors moteur de thème : ne recolorent jamais */")
    for name, v in model["semantic"].items():
        out.append(f"  --{name}: {v};")
    out.append("")

    d = raw["density"]["comfortable"]
    for key, val in d.items():
        if key != "multiplier":
            out.append(f"  --{key.replace('_', '-')}: {val}px;")
    for key, val in raw["radii"].items():
        out.append(f"  --radius-{key}: {val}px;")
    for key, val in raw["layout"].items():
        unit = "" if key == "reading_measure_max" else "px"
        out.append(f"  --{key.replace('_', '-')}: {val}{unit};")
    for i, val in enumerate(raw["spacing"]["scale"]):
        out.append(f"  --space-{i}: {val}px;")
    out.append("")

    t = raw["type"]
    out.append(f"  --font-interface: '{t['interface']}', sans-serif;")
    out.append(f"  --font-mono: '{t['mono']}', monospace;")
    out.append(f"  --text-base: {t['base_size']}px;")
    for size in t["scale"]:
        out.append(f"  --text-{size}: {size}px;")
    out.append(f"  --weight-regular: {t['weight_regular']};")
    out.append(f"  --weight-medium: {t['weight_medium']};")
    out.append("}")

    bp = raw["breakpoints"]
    out += [
        "",
        "/* Seuils sur la largeur du CONTENEUR, jamais de l'écran. */",
        ".pane { container-type: inline-size; }",
        f"@container (max-width: {bp['compact'] - 1}px) {{ .sidebar {{ --sidebar-mode: compact; }} }}",
        f"@container (min-width: {bp['extended']}px) {{ .inspector {{ --inspector-visible: 1; }} }}",
    ]
    return "\n".join(out) + "\n"


def emit_json(model: dict) -> str:
    m = {k: v for k, v in model.items() if k != "raw"}
    return json.dumps(m, indent=2, ensure_ascii=False) + "\n"




def emit_kde_colors(model: dict) -> str:
    """Schéma de couleurs KDE — consommé par Breeze (Qt) ET, via la
    synchronisation de kde-gtk-config, par Breeze-GTK (GTK 3).

    Une seule source pilote donc les deux boîtes à outils. Le fichier se
    recharge à chaud : changer de thème machine ne demande aucun redémarrage
    d'application.

    La correspondance ci-dessous est une DÉCISION DE DESIGN, pas une
    conversion mécanique. Elle projette notre modèle d'élévation sur les jeux
    de couleurs de KDE :
        View   = ce qui reçoit du contenu  → s'enfonce  → E0
        Window = corps de fenêtre                        → E1
        Header = barres et en-têtes                      → E2
        Button = ce qui s'élève                          → E3
    C'est exactement notre règle « ce qui reçoit se creuse, ce qui flotte
    s'élève », transposée telle quelle.
    """
    r = model["roles"]
    raw = model["raw"]
    ramp = model["ramp"]
    sem = model["semantic"]

    def rgb(css: str) -> str:
        return ",".join(str(v) for v in to_srgb255(css))

    accent, on_accent = model["accent"], model["on_accent"]

    # Jeu de couleurs commun à tous les ensembles : les couleurs sémantiques
    # restent INVARIANTES, conformément à la liste d'invariants de la bible.
    def common(fg_normal, fg_inactive):
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

    sets = {
        "Colors:View":     dict(BackgroundNormal=ramp[0], BackgroundAlternate=ramp[1],
                                **common(r["text-primary"], r["text-tertiary"])),
        "Colors:Window":   dict(BackgroundNormal=ramp[1], BackgroundAlternate=ramp[2],
                                **common(r["text-primary"], r["text-tertiary"])),
        "Colors:Header":   dict(BackgroundNormal=ramp[2], BackgroundAlternate=ramp[3],
                                **common(r["text-primary"], r["text-tertiary"])),
        "Colors:Button":   dict(BackgroundNormal=ramp[3], BackgroundAlternate=ramp[2],
                                **common(r["text-primary"], r["text-tertiary"])),
        "Colors:Tooltip":  dict(BackgroundNormal=ramp[3], BackgroundAlternate=ramp[2],
                                **common(r["text-primary"], r["text-tertiary"])),
        "Colors:Selection": dict(BackgroundNormal=accent, BackgroundAlternate=accent,
                                 **common(on_accent, on_accent)),
        "Colors:Complementary": dict(BackgroundNormal=ramp[2], BackgroundAlternate=ramp[3],
                                     **common(r["text-primary"], r["text-tertiary"])),
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
        for key, css in colors.items():
            out.append(f"{key}={rgb(css)}")
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



# ---------------------------------------------------------------------------
# GTK — libadwaita et adw-gtk3
# ---------------------------------------------------------------------------
# libadwaita n'accepte PAS de thème : sa géométrie est figée, c'est un choix
# assumé de GNOME. Mais la RECOLORATION est officiellement prévue, par
# couleurs nommées et variables CSS.
#
# Les couleurs nommées de libadwaita décrivent exactement le même modèle
# conceptuel que les jeux de couleurs de KDE. Notre échelle d'élévation se
# projette donc à l'identique sur les deux boîtes à outils :
#     view      = ce qui reçoit du contenu  → E0
#     window    = corps de fenêtre          → E1
#     headerbar / sidebar = barres          → E2
#     card / popover / dialog = flottant    → E3
#
# adw-gtk3 donne aux applications GTK 3 l'apparence de libadwaita et consomme
# les mêmes noms. Une application qui migre de GTK 3 vers GTK 4 ne change donc
# pas d'apparence — c'est la raison du choix.


def _adw_palette(model: dict) -> dict:
    r, ramp, sem = model["roles"], model["ramp"], model["semantic"]
    raw = model["raw"]
    th = raw["theme"]
    steps = raw["lightness"]["steps"]
    hue, scale, ceil = model["hue"], th["chroma_scale"], th["chroma_ceiling"]

    # Version « autonome » de l'accent : employée pour du TEXTE accentué, donc
    # posée sur un fond sombre. Elle doit être bien plus claire que l'accent
    # de remplissage, sinon elle est illisible.
    accent_standalone = oklch(steps[9], th["accent_chroma"] * scale, hue, ceil)
    accent_bg, accent_fg = model["accent"], model["on_accent"]
    dark = ramp[0]

    return {
        # accent
        "accent_color": accent_standalone,
        "accent_bg_color": accent_bg,
        "accent_fg_color": accent_fg,
        # sémantiques — INVARIANTES, hors moteur de thème
        "destructive_color": sem["error"], "destructive_bg_color": sem["error"], "destructive_fg_color": dark,
        "error_color": sem["error"], "error_bg_color": sem["error"], "error_fg_color": dark,
        "warning_color": sem["warning"], "warning_bg_color": sem["warning"], "warning_fg_color": dark,
        "success_color": sem["success"], "success_bg_color": sem["success"], "success_fg_color": dark,
        # E0 — ce qui reçoit du contenu s'enfonce
        "view_bg_color": ramp[0], "view_fg_color": r["text-primary"],
        # E1 — corps de fenêtre
        "window_bg_color": ramp[1], "window_fg_color": r["text-primary"],
        # E2 — barres et panneaux
        "headerbar_bg_color": ramp[2], "headerbar_fg_color": r["text-primary"],
        "headerbar_border_color": ramp[4], "headerbar_backdrop_color": ramp[1],
        "sidebar_bg_color": ramp[2], "sidebar_fg_color": r["text-primary"],
        "sidebar_border_color": ramp[4], "sidebar_backdrop_color": ramp[1],
        "secondary_sidebar_bg_color": ramp[2], "secondary_sidebar_fg_color": r["text-primary"],
        "secondary_sidebar_border_color": ramp[4], "secondary_sidebar_backdrop_color": ramp[1],
        # E3 — ce qui flotte s'élève
        "card_bg_color": ramp[3], "card_fg_color": r["text-primary"],
        "dialog_bg_color": ramp[3], "dialog_fg_color": r["text-primary"],
        "popover_bg_color": ramp[3], "popover_fg_color": r["text-primary"],
        "thumbnail_bg_color": ramp[3], "thumbnail_fg_color": r["text-primary"],
    }


_ADW_ALPHA = {
    "shade_color": "rgba(0,0,0,0.36)",
    "scrollbar_outline_color": "rgba(0,0,0,0.5)",
    "headerbar_shade_color": "rgba(0,0,0,0.36)",
    "sidebar_shade_color": "rgba(0,0,0,0.36)",
    "secondary_sidebar_shade_color": "rgba(0,0,0,0.36)",
    "card_shade_color": "rgba(0,0,0,0.36)",
    "popover_shade_color": "rgba(0,0,0,0.36)",
}


def _adw_header(model: dict) -> list[str]:
    return [
        "/* GÉNÉRÉ depuis tokens.toml — NE PAS MODIFIER À LA MAIN */",
        f"/* thème machine : teinte {model['hue']}° */",
        "",
    ]


def emit_gtk3(model: dict) -> str:
    """~/.config/gtk-3.0/gtk.css — consommé par adw-gtk3.
    GTK 3 ne connaît que @define-color, pas les variables CSS."""
    out = _adw_header(model)
    for name, css in _adw_palette(model).items():
        out.append(f"@define-color {name} {to_hex(css)};")
    for name, val in _ADW_ALPHA.items():
        out.append(f"@define-color {name} {val};")
    return "\n".join(out) + "\n"


def emit_gtk4(model: dict) -> str:
    """~/.config/gtk-4.0/gtk.css — consommé par libadwaita.
    On écrit les DEUX formes : les variables CSS (1.6+) et les couleurs
    nommées (compatibilité). La surcharge CSS donne la teinte EXACTE, là où
    le portail ne fournit qu'une approximation parmi neuf couleurs."""
    raw = model["raw"]
    out = _adw_header(model)
    pal = _adw_palette(model)

    out.append(":root {")
    for name, css in pal.items():
        out.append(f"  --{name.replace('_', '-')}: {to_hex(css)};")
    for name, val in _ADW_ALPHA.items():
        out.append(f"  --{name.replace('_', '-')}: {val};")
    out.append("")
    out.append("  /* seule convergence géométrique avec le shell : le coin de fenêtre */")
    out.append(f"  --window-radius: {raw['radii']['window']}px;")
    out.append(f"  --disabled-opacity: {raw['states']['disabled']['chroma_multiplier'] + 0.35:.2f};")
    out.append("}")
    out.append("")

    out.append("/* compatibilité avec les versions antérieures à 1.6 */")
    for name, css in pal.items():
        out.append(f"@define-color {name} {to_hex(css)};")
    for name, val in _ADW_ALPHA.items():
        out.append(f"@define-color {name} {val};")
    return "\n".join(out) + "\n"


def emit_portal(model: dict) -> str:
    """Réglages du portail d'apparence freedesktop.

    Sert de REPLI : les applications en bac à sable qui ne lisent pas nos
    fichiers de style suivront au moins le mode sombre et une teinte proche.
    libadwaita choisit la couleur la plus proche parmi neuf, dans l'espace
    Oklch — le nôtre. L'accent exact vient du gtk.css, pas d'ici.

    Le câblage dépend du backend de portail, non encore choisi.
    """
    r, g, b = to_srgb255(model["accent"])
    return "\n".join([
        "# GÉNÉRÉ depuis tokens.toml",
        "# org.freedesktop.appearance",
        "",
        "color-scheme=1                 # 1 = préférence sombre",
        f"accent-color=({r/255:.4f}, {g/255:.4f}, {b/255:.4f})",
        "",
        f"# teinte {model['hue']}° — accent exact : {to_hex(model['accent'])}",
        "# Approximation attendue côté libadwaita : la plus proche des neuf.",
    ]) + "\n"

TARGETS = {
    "tokens.css": emit_css,
    "tokens.json": emit_json,
    "kdeglobals": emit_kde_colors,          # Qt / Breeze
    "gtk-3.0-gtk.css": emit_gtk3,           # adw-gtk3
    "gtk-4.0-gtk.css": emit_gtk4,           # libadwaita
    "appearance-portal.conf": emit_portal,  # repli bac à sable
}


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--src", default=Path("tokens.toml"), type=Path)
    ap.add_argument("--out", default=Path("build"), type=Path)
    ap.add_argument("--hue", type=float, default=None, help="simuler une autre teinte machine")
    args = ap.parse_args()

    if not args.src.exists():
        print(f"source introuvable : {args.src}", file=sys.stderr)
        return 1

    with args.src.open("rb") as fh:
        data = tomllib.load(fh)

    model = resolve(data, args.hue)

    for w in check(model):
        print(f"  avertissement : {w}", file=sys.stderr)

    args.out.mkdir(parents=True, exist_ok=True)
    for filename, emitter in TARGETS.items():
        (args.out / filename).write_text(emitter(model), encoding="utf-8")
        print(f"  écrit {args.out / filename}")

    print(f"\nThème teinte {model['hue']}° généré vers {len(TARGETS)} cibles.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
