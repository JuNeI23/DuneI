#!/usr/bin/env python3
"""Paquets — aligne les paquets de la machine sur paquets.toml, qui déclare chaque paquet une fois.

paquets.toml est la seule source (L1-02, L1-05) : des groupes communs, des paquets provisoires reliés
au backlog, des listes choisies par le matériel détecté et des listes propres à une machine.

- détection : processeur et cartes graphiques sont lus sous une racine, le nom d'hôte dans etc/hostname.
- lecture : paquets.toml est lu et contrôlé (version, dépôts, noms, unicité) ; une seule erreur
  suffit à tout refuser.

    python3 paquets.py [--dry-run]
"""

from __future__ import annotations

import re
import tomllib
from collections.abc import Mapping
from pathlib import Path

FICHIER = "paquets.toml"                 # Source unique des paquets, à la racine du dépôt.
VERSION = "0.1.0"                        # Version du format de paquets.toml.
DEPOTS = ["core", "extra"]               # Dépôts admis, exacts.
HOTE = re.compile(r"[A-Za-z0-9-]+")      # Nom d'hôte accepté (D24).
CARTE = re.compile(r"card\d+")           # Une carte de /sys/class/drm, à l'exclusion de ses connecteurs.
PROCESSEURS = {"AuthenticAMD": "amd", "GenuineIntel": "intel"}            # vendor_id de cpuinfo → fabricant.
CARTES = {"0x1002": "amd", "0x8086": "intel", "0x10de": "nvidia"}         # vendor du pilote DRM → fabricant.


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


def sysroot(env: Mapping[str, str]) -> Path:
    """Racine du système à examiner.

    Entrée : env — environnement, os.environ en usage normal.
    Sortie : $DUNEI_SYSROOT, réservé aux tests, ou / si la variable est absente ou vide.
    Erreurs : aucune. Dépendances : aucune.
    """
    return Path(env.get("DUNEI_SYSROOT") or "/")


def nom_hote(root: Path) -> str | None:
    """Nom d'hôte de la machine.

    Entrée : root — racine du système.
    Sortie : contenu de etc/hostname sans blancs, ou None s'il est absent, illisible, vide ou refusé par HOTE.
    Erreurs : aucune exception. Dépendances : HOTE.
    """
    try:
        nom = (root / "etc/hostname").read_text(encoding="utf-8").strip()
    except (OSError, ValueError):
        return None
    return nom if HOTE.fullmatch(nom) else None


def detecter(root: Path) -> tuple[set[str], set[str]]:
    """Détection du matériel.

    Entrée : root — racine du système.
    Sortie : (processeurs, cartes), des ensembles de fabricants ; un fabricant absent des tables
             PROCESSEURS et CARTES devient « inconnu:<valeur> ».
    Erreurs : aucune exception ; un fichier absent ou illisible est ignoré. Dépendances : PROCESSEURS, CARTES, CARTE.
    """
    def lire_texte(chemin: Path) -> str:
        """Contenu du fichier, ou chaîne vide s'il est illisible."""
        try:
            return chemin.read_text(encoding="utf-8")
        except (OSError, ValueError):
            return ""

    vendeurs = {m.group(1) for m in re.finditer(r"^vendor_id\s*:\s*(\S+)", lire_texte(root / "proc/cpuinfo"), re.M)}
    drm = root / "sys/class/drm"
    cartes = {lire_texte(c / "device/vendor").strip()
              for c in (drm.iterdir() if drm.is_dir() else []) if CARTE.fullmatch(c.name)} - {""}
    return ({PROCESSEURS.get(v, f"inconnu:{v}") for v in vendeurs},
            {CARTES.get(v, f"inconnu:{v}") for v in cartes})


def voulus(modele: dict, hote: str | None, processeurs: set[str], cartes: set[str]) -> tuple[set[str], list[str]]:
    """Paquets voulus sur cette machine.

    Entrée : modele — sortie de lire ; hote — nom d'hôte ou None ; processeurs, cartes — sortie de detecter.
    Sortie : (paquets, avertissements) : groupes communs, paquets provisoires, listes des fabricants
             détectés et section de la machine si elle existe.
    Erreurs : aucune exception ; matériel inconnu, carte NVIDIA sans pilote décidé, carte absente, hôte
              absent ou sans section deviennent des avertissements. Dépendances : aucune.
    """
    mat, avert = modele["materiel"], []
    voulus_ = {p for l in modele["groupes"].values() for p in l} | set(modele["provisoire"])
    for genre, trouves in (("processeur", processeurs), ("graphique", cartes)):
        for f in sorted(trouves):
            if f in mat[genre]:
                voulus_ |= set(mat[genre][f])
                if genre == "graphique" and not mat[genre][f]:
                    avert.append(f"carte {f.upper()} détectée : aucun pilote décidé, voir le journal")
            else:
                avert.append(f"{genre} inconnu « {f} » : aucun paquet ajouté")
    if not cartes:
        avert.append("aucune carte graphique détectée : aucun pilote ajouté")
    if hote is None:
        avert.append("nom d'hôte absent ou invalide : aucune section de machine appliquée")
    elif hote in modele["machines"]:
        voulus_ |= set(modele["machines"][hote])
    else:
        avert.append(f"aucune section de machine pour « {hote} » : groupes communs seulement")
    return voulus_, avert
