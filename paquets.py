#!/usr/bin/env python3
"""Paquets — aligne les paquets de la machine sur paquets.toml, qui déclare chaque paquet une fois.

paquets.toml est la seule source (L1-02, L1-05) : des groupes communs, des paquets provisoires reliés
au backlog, des listes choisies par le matériel détecté et des listes propres à une machine.

- lecture : paquets.toml est lu et contrôlé (version, dépôts, noms, unicité) ; une seule erreur
  suffit à tout refuser.

    python3 paquets.py [--dry-run]
"""

from __future__ import annotations

import tomllib
from pathlib import Path

FICHIER = "paquets.toml"                 # Source unique des paquets, à la racine du dépôt.
VERSION = "0.1.0"                        # Version du format de paquets.toml.
DEPOTS = ["core", "extra"]               # Dépôts admis, exacts.


def lire(repo: Path) -> tuple[dict, list[str]]:
    """Lecture et contrôle de paquets.toml.

    Entrée : repo — racine du dépôt.
    Sortie : (modèle, erreurs). Le modèle est {"depots", "groupes", "provisoire", "materiel":
             {"processeur", "graphique"}, "machines"}, les tables matérielles et de machines aplaties
             en dict[str, list[str]] ; il est vide ({}) dès qu'une erreur existe.
    Erreurs : aucune exception ; fichier illisible, version ou dépôts inattendus, nom vide ou qui n'est
              pas une chaîne, nom déclaré deux fois, liste matérielle qui répète un nom commun
              deviennent des messages. Dépendances : tomllib, FICHIER, VERSION, DEPOTS.
    """
    try:
        with (repo / FICHIER).open("rb") as fh:
            raw = tomllib.load(fh)
    except (OSError, ValueError) as e:   # ValueError couvre la syntaxe TOML et l'encodage.
        return {}, [f"{FICHIER} illisible ({e})"]
    err = []
    if raw.get("version") != VERSION:
        err.append(f"{FICHIER} : version « {raw.get('version')} », {VERSION} attendue")
    if raw.get("depots") != DEPOTS:
        err.append(f"{FICHIER} : depots doit valoir {DEPOTS}")

    def table(*cle: str) -> dict:
        """Descend de table en table selon cle ; {} si un maillon manque ou n'est pas une table."""
        t = raw
        for k in cle:
            t = t.get(k, {}) if isinstance(t, dict) else {}
        return t if isinstance(t, dict) else {}

    def aplatir(t: dict) -> dict[str, list]:
        """Réduit {nom: {paquets: [...]}} à {nom: [...]} ; une liste absente devient une erreur."""
        out = {}
        for nom, sec in t.items():
            liste = sec.get("paquets") if isinstance(sec, dict) else None
            if not isinstance(liste, list):
                err.append(f"{FICHIER} : {nom} doit contenir une liste « paquets »")
            out[nom] = liste if isinstance(liste, list) else []
        return out

    groupes = dict(table("groupes"))
    provisoire = dict(table("provisoire"))
    materiel = {k: aplatir(table("materiel", k)) for k in ("processeur", "graphique")}
    machines = aplatir(table("machines"))
    for nom, liste in groupes.items():
        if not isinstance(liste, list):
            err.append(f"{FICHIER} : groupes.{nom} doit être une liste")
    listes = [l for l in (*groupes.values(), *machines.values(), *(l for m in materiel.values() for l in m.values()))
              if isinstance(l, list)]
    err += [f"{FICHIER} : « {n} » n'est pas un nom de paquet" for l in listes for n in l
            if not (isinstance(n, str) and n.strip())]
    communs = [n for l in (*groupes.values(), *machines.values()) if isinstance(l, list) for n in l] + list(provisoire)
    err += [f"{FICHIER} : « {n} » est déclaré deux fois" for n in sorted({n for n in communs if isinstance(n, str)})
            if communs.count(n) > 1]
    err += [f"{FICHIER} : « {n} » de {genre} répète un paquet commun" for genre, m in materiel.items()
            for l in m.values() for n in sorted({x for x in l if isinstance(x, str)} & set(communs))]
    modele = {"depots": raw.get("depots"), "groupes": groupes, "provisoire": provisoire,
              "materiel": materiel, "machines": machines}
    return ({} if err else modele), err
