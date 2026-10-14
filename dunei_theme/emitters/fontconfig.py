"""Cible fontconfig — indirection des noms de polices, chaîne de repli et rendu.

Les jetons nomment les polices par leur nom canonique ; les paquets les installent sous
d'autres noms, et une famille introuvable retombe silencieusement sur la police système.
Ce fichier fait la correspondance une seule fois, pour toutes les applications qui passent
par fontconfig.

fontconfig applique les règles dans l'ordre, chacune voyant le résultat des précédentes.
Les familles génériques sont donc redirigées vers les noms canoniques avant que ceux-ci
le soient vers les familles installées : une seule passe suffit.

Déployé dans $XDG_CONFIG_HOME/fontconfig/conf.d/50-dunei.conf, lu avant les préférences
d'Arch (60-*.conf).
"""

from __future__ import annotations

from xml.sax.saxutils import escape

HINTSTYLES = ("hintnone", "hintslight", "hintmedium", "hintfull")
RGBA = ("none", "rgb", "bgr", "vrgb", "vbgr", "unknown")
GENERICS = {"sans-serif": "interface", "monospace": "mono"}  # Famille générique → rôle de [type].


def check_rendering(rendering: dict) -> None:
    """Contrôle des valeurs de rendu, avant toute écriture.

    Entrée : rendering — table [type.rendering] du TOML.
    Sortie : aucune.
    Erreurs : ValueError, qui nomme la clé fautive, si antialias n'est pas un booléen ou si
              hintstyle ou rgba n'est pas une constante de fontconfig ; KeyError si une clé manque.
    Dépendances : HINTSTYLES, RGBA.
    """
    if not isinstance(rendering["antialias"], bool):
        raise ValueError(f"[type.rendering] antialias : booléen attendu, reçu {rendering['antialias']!r}")
    for key, allowed in (("hintstyle", HINTSTYLES), ("rgba", RGBA)):
        if rendering[key] not in allowed:
            raise ValueError(f"[type.rendering] {key} : {rendering[key]!r} n'est pas l'une de {', '.join(allowed)}")


def alias(family: str, prefer: list[str]) -> str:
    """Bloc <alias> : les familles de prefer sont insérées, dans l'ordre, devant family.

    Entrées : family — famille demandée ; prefer — familles à lui préférer.
    Sortie : texte XML indenté. La liaison « same » reprend la force de la demande d'origine.
    Erreurs : aucune. Dépendances : xml.sax.saxutils.escape.
    """
    fams = "".join(f"<family>{escape(f)}</family>" for f in prefer)
    return f'  <alias binding="same">\n    <family>{escape(family)}</family>\n    <prefer>{fams}</prefer>\n  </alias>\n'


def emit(model: dict) -> str:
    """Configuration fontconfig de DuneI.

    Entrée : model — sortie de model.resolve.
    Sortie : contenu de fonts.conf : rendu, familles génériques, noms canoniques.
    Erreurs : ValueError si une valeur de rendu est refusée (check_rendering) ; KeyError si une
              clé de [type], [type.installed] ou [type.rendering] manque.
    Dépendances : check_rendering, alias, GENERICS.
    """
    t = model["raw"]["type"]
    r = t["rendering"]
    check_rendering(r)
    out = [
        '<?xml version="1.0"?>\n',
        "<!-- GÉNÉRÉ depuis tokens.toml — NE PAS MODIFIER À LA MAIN -->\n",
        '<!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">\n',
        "<fontconfig>\n",
        "  <!-- Rendu : écran dense, niveaux de gris, hinting léger. -->\n",
        '  <match target="font">\n',
        f'    <edit name="antialias" mode="assign"><bool>{str(r["antialias"]).lower()}</bool></edit>\n',
        f'    <edit name="hintstyle" mode="assign"><const>{r["hintstyle"]}</const></edit>\n',
        f'    <edit name="rgba" mode="assign"><const>{r["rgba"]}</const></edit>\n',
        "  </match>\n",
        "  <!-- Familles génériques vers les noms canoniques. -->\n",
        *(alias(g, [t[role]]) for g, role in GENERICS.items()),
        "  <!-- Noms canoniques vers les familles installées, puis la chaîne de repli. -->\n",
        *(alias(t[role], [t["installed"][role], *t["fallback_chain"]]) for role in GENERICS.values()),
        "</fontconfig>\n",
    ]
    return "".join(out)
