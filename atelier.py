#!/usr/bin/env python3
"""Atelier — lit atelier.toml, qui épingle rtk et cartographie les liens de dunei-atelier.

Deux destinations de deploy.py s'appuient sur ce module :

- rtk : l'archive de la version épinglée est téléchargée, ses sommes sont vérifiées, puis le binaire
  est posé dans $XDG_BIN_HOME. Aucune initialisation de rtk n'est lancée.
- atelier : le dépôt privé dunei-atelier est cloné, puis chaque fichier du clone est lié à sa
  destination sous le dossier personnel ; le fichier gitconfig est inclus, jamais lié.

atelier.toml est la seule source de ces valeurs.
"""

from __future__ import annotations

import os
import re
import tomllib
from pathlib import Path

ATELIER = "atelier.toml"                      # Fichier déclaratif de l'atelier, à la racine du dépôt.
CLES_RTK = ("version", "archive", "url", "sha256_archive", "sha256_binaire")
CLES_ATELIER = ("depot", "clone", "gitconfig")
SOMMES = ("sha256_archive", "sha256_binaire")  # Clés de rtk qui portent une somme SHA-256.


def lire_atelier(repo: Path) -> tuple[dict, list[str]]:
    """Lecture de atelier.toml — rend les sections rtk et atelier validées.

    Entrées : repo, racine du dépôt ; la variable DUNEI_ATELIER_TOML, réservée aux tests, remplace
        le chemin du fichier.
    Sortie : (données, erreurs). Les données ont les clés rtk (version, archive, url, sha256_archive,
        sha256_binaire) et atelier (depot, clone et gitconfig, liens : chemin relatif au clone →
        destination) ; clone et destinations sont développés par expanduser.
    Erreurs : fichier illisible, clé manquante ou somme qui n'a pas 64 chiffres hexadécimaux, chacun
        rendu comme message ; aucune exception.
    Dépendances : tomllib, os, re, pathlib.
    """
    chemin = Path(os.environ.get("DUNEI_ATELIER_TOML") or repo / ATELIER)
    try:
        brut = tomllib.loads(chemin.read_text(encoding="utf-8"))
    except (OSError, tomllib.TOMLDecodeError) as e:
        return {}, [f"{chemin} illisible : {e}"]
    erreurs: list[str] = []
    rtk, atelier = brut.get("rtk", {}), brut.get("atelier", {})
    for section, cles, valeurs in (("rtk", CLES_RTK, rtk), ("atelier", CLES_ATELIER, atelier)):
        erreurs += [f"{ATELIER} : clé manquante [{section}] {c}" for c in cles if not isinstance(valeurs.get(c), str)]
    for cle in SOMMES:
        if isinstance(rtk.get(cle), str) and not re.fullmatch(r"[0-9a-f]{64}", rtk[cle]):
            erreurs.append(f"{ATELIER} : [rtk] {cle} doit avoir 64 chiffres hexadécimaux")
    liens = atelier.get("liens")
    if not isinstance(liens, dict) or not liens:
        erreurs.append(f"{ATELIER} : clé manquante [atelier.liens]")
        liens = {}
    if erreurs:
        return {}, erreurs
    atelier = {**atelier, "clone": Path(atelier["clone"]).expanduser(),
               "liens": {k: Path(v).expanduser() for k, v in liens.items()}}
    return {"rtk": rtk, "atelier": atelier}, []
