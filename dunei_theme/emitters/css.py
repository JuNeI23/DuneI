"""Cible CSS — variables consommées par la coque."""

from __future__ import annotations


def emit(model: dict) -> str:
    """Feuille de variables CSS.

    Entrée : model — sortie de model.resolve.
    Sortie : contenu de tokens.css.
    Erreurs : KeyError si le TOML brut est incomplet.
    Dépendances : color.Oklch.css.
    """
    raw = model["raw"]
    out = ["/* GÉNÉRÉ depuis tokens.toml — NE PAS MODIFIER À LA MAIN */", ":root {"]

    out.append(f"  /* thème : teinte {model['hue']}° */")
    out += [f"  --l-{i}: {v.css()};" for i, v in enumerate(model["ramp"])]
    out.append("")
    out += [f"  --{name}: {v.css()};" for name, v in model["roles"].items()]
    out.append("")
    out.append(f"  --accent: {model['accent'].css()};")
    out.append(f"  --accent-standalone: {model['accent_standalone'].css()};")
    out.append(f"  --on-accent: {model['on_accent'].css()};")
    out.append("")
    out += [f"  --cat-{i}: {v.css()};" for i, v in enumerate(model["categorical"])]
    out.append("")
    out.append("  /* hors moteur de thème : ne recolorent jamais */")
    out += [f"  --{name}: {v.css()};" for name, v in model["semantic"].items()]
    out.append("")

    out += [f"  --{key.replace('_', '-')}: {val}px;" for key, val in raw["density"]["comfortable"].items()
            if key != "multiplier"]
    out += [f"  --radius-{key}: {val}px;" for key, val in raw["radii"].items()]
    out += [f"  --{key.replace('_', '-')}: {val}{'' if key == 'reading_measure_max' else 'px'};"
            for key, val in raw["layout"].items()]
    out += [f"  --space-{i}: {val}px;" for i, val in enumerate(raw["spacing"]["scale"])]
    out.append("")

    t = raw["type"]
    out.append(f"  --font-interface: '{t['interface']}', sans-serif;")
    out.append(f"  --font-mono: '{t['mono']}', monospace;")
    out.append(f"  --text-base: {t['base_size']}px;")
    out += [f"  --text-{size}: {size}px;" for size in t["scale"]]
    out.append(f"  --weight-regular: {t['weight_regular']};")
    out.append(f"  --weight-medium: {t['weight_medium']};")
    out.append("")

    out.append("  /* seuils sur la largeur du CONTENEUR, jamais de l'écran */")
    out += [f"  --breakpoint-{key}: {val}px;" for key, val in raw["breakpoints"].items()]
    out.append("}")
    return "\n".join(out) + "\n"
