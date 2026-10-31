#!/usr/bin/env python3
"""Générateur du thème d'icônes XDG DuneI.

Lit la table icones/correspondances.toml et les SVG Phosphor versionnés, puis écrit sous generated/icons/<thème>/
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

from phosphor import DEST, TABLE, charger, nom_fichier

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


def generer(repo: Path, sortie: Path) -> list[Path]:
    """Écrit le thème d'icônes sous sortie/<nom du thème>.

    Entrées : repo — racine du dépôt (tokens.toml, table et SVG) ; sortie — dossier parent des thèmes.
    Sortie : chemins des fichiers écrits, index.theme en tête puis les SVG dans l'ordre alphabétique des noms.
    Erreurs : FileNotFoundError dont le message nomme le SVG source manquant ; OSError, ValueError (table,
              tokens.toml) en cas de lecture impossible. Dépendances : phosphor.charger, phosphor.nom_fichier.
    """
    icones = tomllib.loads((repo / "tokens.toml").read_text(encoding="utf-8"))["icons"]
    nom = icones["xdg_theme"]
    source, noms = charger(repo / TABLE)
    graisse = source["graisse"]
    # Lecture complète avant toute écriture : un SVG manquant ne laisse pas un thème à moitié écrit.
    contenus: dict[str, str] = {}
    for freedesktop, phosphor in sorted(noms.items()):
        for g, suffixe in ((graisse, ""), ("fill", "-fill")):
            chemin = repo / DEST / g / nom_fichier(phosphor, g)
            if not chemin.is_file():
                raise FileNotFoundError(f"SVG Phosphor manquant : {chemin}")
            contenus[f"{freedesktop}{suffixe}-symbolic.svg"] = recolorable(chemin.read_text(encoding="utf-8"))
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
