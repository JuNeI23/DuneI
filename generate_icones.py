#!/usr/bin/env python3
"""Générateur du thème d'icônes XDG DuneI.

Lit la table icones/correspondances.toml (une entrée « base+pastille » compose deux glyphes en un SVG) et les SVG Phosphor versionnés, puis écrit sous generated/icons/<thème>/
un index.theme et, pour chaque nom freedesktop, les variantes symbolic/<nom>-symbolic.svg (graisse de la table)
et symbolic/<nom>-fill-symbolic.svg (variante pleine). Le nom du thème et son héritage viennent de
tokens.toml [icons]. Aucun accès au réseau.

    python3 generate_icones.py [--out generated]
"""

from __future__ import annotations

import argparse
import re
import shutil
import sys
import tomllib
from pathlib import Path

from phosphor import DEST, TABLE, charger, glyphes, nom_fichier

# Couleur de repli du texte, reprise par la feuille de style que GTK remplace par la couleur du thème.
COULEUR_REPLI = "#bebebe"


def index_theme(nom: str, herite: list[str]) -> str:
    """Contenu du fichier index.theme.

    Entrées : nom — nom du thème ; herite — thèmes parents, par ordre de priorité.
    Sortie : texte du fichier, avec un unique répertoire « symbolic » de type Scalable.
    Erreurs : aucune. Dépendances : aucune.
    """
    return (
        "[Icon Theme]\n"
        f"Name={nom}\n"
        "Comment=Pictogrammes Phosphor du thème DuneI\n"
        f"Inherits={','.join(herite)}\n"
        "Directories=symbolic\n"
        "\n"
        "[symbolic]\n"
        "Size=16\nMinSize=8\nMaxSize=512\nType=Scalable\n"
    )


def recolorable(svg: str) -> str:
    """Rend un SVG recolorable par GTK selon la convention ColorScheme-Text.

    Entrée : svg — texte d'un SVG Phosphor.
    Sortie : le SVG dont la racine porte fill="currentColor" et class="ColorScheme-Text", avec en premier enfant
             la feuille <style>.ColorScheme-Text{color:#bebebe}</style> ; tout le reste est conservé.
    Erreurs : ValueError si aucune racine <svg> n'est trouvée. Dépendances : re.
    """
    m = re.search(r"<svg\b([^>]*?)(/?)>", svg)
    if not m:
        raise ValueError("racine <svg> introuvable")
    attrs = re.sub(r'\s(?:fill|class)="[^"]*"', "", m.group(1))
    racine = f'<svg{attrs} fill="currentColor" class="ColorScheme-Text">'
    style = f"<style>.ColorScheme-Text{{color:{COULEUR_REPLI}}}</style>"
    if m.group(2):  # racine auto-fermante : on la rouvre pour loger la feuille.
        return svg[: m.start()] + racine + style + "</svg>" + svg[m.end():]
    return svg[: m.start()] + racine + style + svg[m.end():]


# Composition d'une pastille (voir composer) : échelle de la pastille, position de son coin en haut à gauche,
# épaisseur de trait ajoutée (dans le repère de la pastille), centre et rayon de l'évidement de la base.
# Le cercle de la pastille touche le coin bas droit du cadre de 256 ; l'évidement laisse un liseré d'environ 8.
PASTILLE = {"echelle": 0.45, "decalage": 146.2, "trait": 16, "centre": 203.8, "evidement": 60}


def contenu(svg: str) -> str:
    """Corps d'un SVG Phosphor.

    Entrée : svg — texte d'un SVG à une racine non auto-fermante. Sortie : ce qui est entre <svg …> et </svg>.
    Erreurs : ValueError si la racine est introuvable. Dépendances : re.
    """
    m = re.search(r"<svg\b[^>]*>(.*)</svg>", svg, re.S)
    if not m:
        raise ValueError("racine <svg> introuvable")
    return m.group(1)


def composer(base: str, pastille: str) -> str:
    """Compose une icône à partir de deux glyphes : la base et une pastille en bas à droite.

    Entrées : base, pastille — textes de SVG Phosphor de même graisse (viewBox 256).
    Sortie : un SVG unique : la base évidée d'un disque autour de la pastille (masque), la pastille réduite et
             épaissie d'un trait de même couleur pour rester lisible à 17 px.
    Erreurs : ValueError si une racine <svg> manque. Dépendances : contenu, PASTILLE.
    """
    p = PASTILLE
    return (
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 256" fill="currentColor">'
        '<defs><mask id="evide"><rect width="256" height="256" fill="#fff"/>'
        f'<circle cx="{p["centre"]}" cy="{p["centre"]}" r="{p["evidement"]}" fill="#000"/></mask></defs>'
        f'<g mask="url(#evide)">{contenu(base)}</g>'
        f'<g transform="translate({p["decalage"]} {p["decalage"]}) scale({p["echelle"]})" stroke="currentColor" '
        f'stroke-width="{p["trait"]}" stroke-linejoin="round">{contenu(pastille)}</g></svg>'
    )


def generer(repo: Path, sortie: Path) -> list[Path]:
    """Écrit le thème d'icônes sous sortie/<nom du thème>.

    Entrées : repo — racine du dépôt (tokens.toml, table et SVG) ; sortie — dossier parent des thèmes.
    Sortie : chemins des fichiers écrits, index.theme en tête puis les SVG dans l'ordre alphabétique des noms.
    Erreurs : TypeError si une entrée compose plus de deux glyphes ; FileNotFoundError dont le message nomme le SVG source manquant ; OSError, ValueError (table,
              tokens.toml) en cas de lecture impossible. Dépendances : phosphor.charger, phosphor.nom_fichier.
    """
    icones = tomllib.loads((repo / "tokens.toml").read_text(encoding="utf-8")).get("icons", {})
    manquantes = [k for k in ("xdg_theme", "xdg_inherits") if k not in icones]
    if manquantes:
        raise ValueError(f"tokens.toml : section [icons] absente ou incomplète, clé(s) manquante(s) : {', '.join(manquantes)}")
    nom = icones["xdg_theme"]
    source, noms = charger(repo / TABLE)
    graisse = source["graisse"]
    # Lecture complète avant toute écriture : un SVG manquant ne laisse pas un thème à moitié écrit.
    contenus: dict[str, str] = {}
    for freedesktop, phosphor in sorted(noms.items()):
        for g, suffixe in ((graisse, ""), ("fill", "-fill")):
            textes = []
            for glyphe in glyphes(phosphor):
                chemin = repo / DEST / g / nom_fichier(glyphe, g)
                if not chemin.is_file():
                    raise FileNotFoundError(f"SVG Phosphor manquant : {chemin}")
                textes.append(chemin.read_text(encoding="utf-8"))
            contenus[f"{freedesktop}{suffixe}-symbolic.svg"] = recolorable(composer(*textes) if len(textes) == 2 else textes[0])
    racine = sortie / nom
    shutil.rmtree(racine, ignore_errors=True)
    (racine / "symbolic").mkdir(parents=True)
    ecrits = [racine / "index.theme"]
    ecrits[0].write_text(index_theme(nom, icones["xdg_inherits"]), encoding="utf-8")
    for fichier, texte in contenus.items():
        ecrits.append(racine / "symbolic" / fichier)
        ecrits[-1].write_text(texte, encoding="utf-8")
    return ecrits


def main() -> int:
    """Point d'entrée de `make icones`.

    Entrée : argument --out (dossier de sortie, « generated » par défaut ; le thème va sous <out>/icons).
    Sortie : 0 si succès, 1 sinon. Erreurs : message sur la sortie d'erreur. Dépendances : generer.
    """
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--out", default=Path("generated"), type=Path)
    args = ap.parse_args()
    try:
        ecrits = generer(Path(__file__).resolve().parent, args.out / "icons")
    except (OSError, ValueError, KeyError) as e:
        print(f"icones : {e}", file=sys.stderr)
        return 1
    print(f"  écrit {args.out / 'icons'} ({len(ecrits)} fichiers)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
