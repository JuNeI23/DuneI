"""Cible portail d'apparence freedesktop — repli pour les applications en bac à sable.

Elles suivront au moins le mode sombre et une teinte proche : libadwaita
choisit la plus proche parmi neuf, en Oklch. L'accent exact vient du gtk.css.
Le câblage dépend du backend de portail (lot 3).
"""

from __future__ import annotations

from ..color import to_hex, to_srgb255

# Valeurs du protocole org.freedesktop.appearance color-scheme (0 = sans préférence).
_SCHEME = {"dark": 1, "light": 2}


def emit(model: dict) -> str:
    """Réglages org.freedesktop.appearance.

    Entrée : model — sortie de model.resolve.
    Sortie : contenu de appearance-portal.conf.
    Erreurs : KeyError si meta.mode n'est ni « dark » ni « light ».
    Dépendances : color.to_srgb255, color.to_hex.
    """
    r, g, b = to_srgb255(model["accent"])
    mode = model["raw"]["meta"]["mode"]
    return "\n".join([
        "# GÉNÉRÉ depuis tokens.toml",
        "# org.freedesktop.appearance",
        "",
        f"color-scheme={_SCHEME[mode]}                 # préférence : {mode}",
        f"accent-color=({r/255:.4f}, {g/255:.4f}, {b/255:.4f})",
        "",
        f"# teinte {model['hue']}° — accent exact : {to_hex(model['accent'])}",
        "# Approximation attendue côté libadwaita : la plus proche des neuf.",
    ]) + "\n"
