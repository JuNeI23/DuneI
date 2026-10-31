#!/usr/bin/env python3
"""Sources Phosphor : lecture de la table de correspondance et rafraîchissement des SVG versionnés.

Lit icones/correspondances.toml, télécharge l'archive npm épinglée, vérifie sa somme sha256, puis
n'extrait que les SVG nommés par la table (graisse choisie et variante pleine) et la licence.
Seule cette commande, lancée à la main, touche au réseau.

    python3 phosphor.py
"""

from __future__ import annotations

import hashlib
import io
import shutil
import sys
import tarfile
import tomllib
import urllib.request
from pathlib import Path

TABLE = Path("icones/correspondances.toml")
DEST = Path("icones/phosphor")


def charger(chemin: Path) -> tuple[dict, dict[str, str]]:
    """Lecture de la table de correspondance.

    Entrée : chemin — fichier TOML avec une section [source] et des groupes nom freedesktop → nom Phosphor.
    Sortie : (section source, dictionnaire fusionné de tous les autres groupes).
    Erreurs : ValueError si un nom freedesktop figure dans deux groupes, ou si la section [source] manque ;
              OSError si le fichier est illisible.
    Dépendances : tomllib.
    """
    brut = tomllib.loads(chemin.read_text(encoding="utf-8"))
    if "source" not in brut:
        raise ValueError(f"{chemin} : section [source] absente")
    noms: dict[str, str] = {}
    for groupe, table in brut.items():
        if groupe == "source":
            continue
        for nom, phosphor in table.items():
            if nom in noms:
                raise ValueError(f"{chemin} : le nom « {nom} » figure dans deux groupes")
            noms[nom] = phosphor
    return brut["source"], noms


def nom_fichier(nom: str, graisse: str) -> str:
    """Nom de fichier d'une icône Phosphor dans l'archive.

    Entrées : nom — nom Phosphor ; graisse — graisse ou « fill ».
    Sortie : « nom.svg » pour regular, « nom-<graisse>.svg » sinon.
    Erreurs : aucune. Dépendances : aucune.
    """
    return f"{nom}.svg" if graisse == "regular" else f"{nom}-{graisse}.svg"


def rafraichir(repo: Path) -> list[str]:
    """Téléchargement vérifié et extraction des SVG de la table.

    Entrée : repo — racine du dépôt.
    Sortie : liste des chemins écrits, relatifs au dépôt.
    Erreurs : ValueError si la somme sha256 diffère (la somme réelle est indiquée) ou si un SVG manque
              dans l'archive ; OSError, urllib.error.URLError en cas d'échec de lecture ou de réseau.
    Dépendances : charger, nom_fichier, urllib, tarfile, hashlib.
    """
    source, noms = charger(repo / TABLE)
    with urllib.request.urlopen(source["url"], timeout=60) as r:
        donnees = r.read()
    somme = hashlib.sha256(donnees).hexdigest()
    if somme != source.get("sha256"):
        raise ValueError(f"somme sha256 inattendue : {somme} (table : {source.get('sha256') or 'vide'})")
    graisse = source["graisse"]
    voulus = {"LICENSE": "LICENSE"}
    for phosphor in sorted(set(noms.values())):
        for g in (graisse, "fill"):
            f = nom_fichier(phosphor, g)
            voulus[f"assets/{g}/{f}"] = f"{g}/{f}"
    dest = repo / DEST
    for g in (graisse, "fill"):
        shutil.rmtree(dest / g, ignore_errors=True)
        (dest / g).mkdir(parents=True)
    ecrits: list[str] = []
    with tarfile.open(fileobj=io.BytesIO(donnees), mode="r:gz") as tar:
        for src, cible in voulus.items():
            try:
                contenu = tar.extractfile(f"package/{src}").read()
            except (KeyError, AttributeError):
                raise ValueError(f"fichier absent de l'archive : {src}") from None
            (dest / cible).write_bytes(contenu)
            ecrits.append(str(DEST / cible))
    return ecrits


def main() -> int:
    """Point d'entrée de `make phosphor`.

    Entrée : aucune (exécuté depuis la racine du dépôt). Sortie : 0 si succès, 1 sinon.
    Erreurs : message sur la sortie d'erreur. Dépendances : rafraichir.
    """
    try:
        ecrits = rafraichir(Path(__file__).resolve().parent)
    except (OSError, ValueError) as e:
        print(f"phosphor : {e}", file=sys.stderr)
        return 1
    print(f"{len(ecrits)} fichiers écrits sous {DEST}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
