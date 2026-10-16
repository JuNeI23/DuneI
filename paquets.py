#!/usr/bin/env python3
"""Paquets — aligne les paquets de la machine sur paquets.toml, qui déclare chaque paquet une fois.

paquets.toml est la seule source (L1-02, L1-05) : des groupes communs, des paquets provisoires reliés
au backlog, des listes choisies par le matériel détecté et des listes propres à une machine.

- détection : processeur et cartes graphiques sont lus sous une racine, le nom d'hôte dans etc/hostname.
- contrôle et plan : dépôts et noms vérifiés, écart entre le voulu et l'installé en cinq catégories.
- exécution : installe le manquant, marque, propose de retirer l'excédent, sur confirmation.
- lecture : paquets.toml est lu et contrôlé (version, dépôts, noms, unicité) ; une seule erreur
  suffit à tout refuser.

    python3 paquets.py [--dry-run]
"""

from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys
import tomllib
from collections.abc import Mapping
from pathlib import Path

FICHIER = "paquets.toml"                 # Source unique des paquets, à la racine du dépôt.
VERSION = "0.1.0"                        # Version du format de paquets.toml.
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
              pas une chaîne, nom déclaré deux fois, liste matérielle qui répète un nom commun,
              provisoire sans élément de backlog deviennent des messages. Dépendances : tomllib, FICHIER, VERSION.
    """
    try:
        with (repo / FICHIER).open("rb") as fh:
            raw = tomllib.load(fh)
    except (OSError, ValueError) as e:   # ValueError couvre la syntaxe TOML et l'encodage.
        return {}, [f"{FICHIER} illisible ({e})"]
    err = []
    if raw.get("version") != VERSION:
        err.append(f"{FICHIER} : version « {raw.get('version')} », {VERSION} attendue")
    depots = raw.get("depots")
    if not (isinstance(depots, list) and depots and all(isinstance(d, str) and d.strip() for d in depots)):
        err.append(f"{FICHIER} : depots doit être une liste non vide de noms de dépôts")

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
    err += [f"{FICHIER} : provisoire.{nom} doit être l'élément du backlog qui remplacera le paquet (chaîne non vide)"
            for nom, item in provisoire.items() if not (isinstance(item, str) and item.strip())]
    listes = [liste for liste in (*groupes.values(), *machines.values(),
                                  *(v for m in materiel.values() for v in m.values()))
              if isinstance(liste, list)]
    err += [f"{FICHIER} : « {n} » n'est pas un nom de paquet" for liste in listes for n in liste
            if not (isinstance(n, str) and n.strip())]
    communs = [n for liste in (*groupes.values(), *machines.values()) if isinstance(liste, list)
               for n in liste] + list(provisoire)
    err += [f"{FICHIER} : « {n} » est déclaré deux fois" for n in sorted({n for n in communs if isinstance(n, str)})
            if communs.count(n) > 1]
    err += [f"{FICHIER} : « {n} » de {genre} répète un paquet commun" for genre, m in materiel.items()
            for liste in m.values() for n in sorted({x for x in liste if isinstance(x, str)} & set(communs))]
    modele = {"depots": depots, "groupes": groupes, "provisoire": provisoire,
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


def controler(modele: dict, depots_configures: list[str], noms_sync: set[str]) -> list[str]:
    """Contrôle des dépôts configurés et des noms déclarés.

    Entrée : modele — sortie de lire ; depots_configures — dépôts de pacman-conf ; noms_sync — noms
             connus des dépôts admis (pacman -Sl).
    Sortie : liste d'erreurs, vide si tout va bien. Les noms vérifiés sont tous les noms déclarés : groupes,
             provisoires, listes matérielles de tous les fabricants et sections de toutes les machines.
    Erreurs : aucune exception ; dépôt hors de modele["depots"], noms introuvables, ou base jamais
              synchronisée (noms_sync vide, une seule erreur) deviennent des messages. Dépendances : aucune.
    """
    err = [f"dépôt « {d} » non admis : retirer sa section de /etc/pacman.conf"
           for d in depots_configures if d not in modele["depots"]]
    if not noms_sync:
        return err + ["base de paquets non synchronisée : lancer sudo pacman -Syu"]
    listes = [*modele["groupes"].values(), *modele["machines"].values()]
    listes += [liste for par_fabricant in modele["materiel"].values() for liste in par_fabricant.values()]
    declares = {nom for liste in listes for nom in liste}
    inconnus = sorted((declares | set(modele["provisoire"])) - noms_sync)
    return err + ([f"introuvables dans {', '.join(modele['depots'])} : {', '.join(inconnus)} ; "
                    f"corriger ou retirer ces noms dans {FICHIER}"] if inconnus else [])


def calculer(voulus: set[str], installes: set[str], explicites: set[str], non_requis: set[str],
             orphelins: set[str]) -> dict[str, list[str]]:
    """Plan en cinq catégories (spec 3.4).

    Entrée : voulus — sortie de voulus ; installes — pacman -Qq ; explicites — pacman -Qqe ;
             non_requis — pacman -Qqett ; orphelins — pacman -Qqdt.
    Sortie : dict de listes triées : manquants (voulus non installés), a_expliciter (voulus installés comme
             dépendances), excedent_requis (explicites non voulus que quelque chose requiert),
             excedent_libre (explicites non voulus que rien ne requiert), orphelins (hors voulus).
    Erreurs : aucune. Dépendances : aucune.
    """
    exces = explicites - voulus
    return {"manquants": sorted(voulus - installes), "a_expliciter": sorted((voulus & installes) - explicites),
            "excedent_requis": sorted(exces - non_requis), "excedent_libre": sorted(exces & non_requis),
            "orphelins": sorted(orphelins - voulus)}


def etat(depots: list[str]) -> tuple[list[str], set[str], set[str], set[str], set[str], set[str]]:
    """État de pacman, seule fonction qui l'interroge.

    Entrée : depots — dépôts admis (modele["depots"]), interrogés par pacman -Sl.
    Sortie : (dépôts configurés, noms des dépôts admis, installés, explicites, explicites non requis,
             orphelins), lus par pacman-conf --repo-list, pacman -Sl, -Qq, -Qqe, -Qqett et -Qqdt.
    Erreurs : RuntimeError lisible (commande, code, message) si une commande échoue autrement que par le
              code 1 sans aucune sortie (ni stdout ni stderr), réponse de pacman quand rien ne correspond. Le programme appelant
              l'affiche au lieu d'une trace. Dépendances : pacman, pacman-conf, subprocess.
    """
    def lignes(*cmd: str) -> list[str]:
        """Lignes de sortie de la commande ; [] pour le code 1 sans aucune sortie."""
        r = subprocess.run(cmd, capture_output=True, text=True)
        if r.returncode and not (r.returncode == 1 and not r.stdout.strip() and not r.stderr.strip()):
            raise RuntimeError(f"{' '.join(cmd)} a échoué (code {r.returncode}) : {r.stderr.strip()}")
        return [ligne for ligne in r.stdout.splitlines() if ligne.strip()]

    sync = {ligne.split()[1] for ligne in lignes("pacman", "-Sl", *depots)}
    return (lignes("pacman-conf", "--repo-list"), sync, *(set(lignes("pacman", o)) for o in ("-Qq", "-Qqe", "-Qqett", "-Qqdt")))


def demander(question: str) -> bool:
    """Question oui/non, « non » par défaut.

    Entrée : question — texte affiché, terminé par « [o/N] ».
    Sortie : True seulement si l'entrée standard est un terminal et que la réponse, blancs et casse
             ignorés, est « o » ou « oui » ; False sinon, sans lire hors terminal.
    Erreurs : fin de fichier pendant la saisie vaut « non ». Dépendances : sys.stdin, input.
    """
    if not sys.stdin.isatty():
        return False
    try:
        return input(question).strip().lower() in ("o", "oui")
    except EOFError:
        return False


def agir(cmd: list[str]) -> int:
    """Lance une commande qui modifie le système, par sudo.

    Entrée : cmd — pacman et ses arguments, jamais vides de noms (l'appelant ne lance rien pour une liste vide).
    Sortie : 0 si elle réussit ; sinon son code de sortie (1 si sudo est introuvable), après un message
             sur la sortie d'erreur qui rappelle informant.
    Erreurs : aucune exception. Dépendances : sudo, subprocess.
    """
    try:
        code = subprocess.run(["sudo", *cmd]).returncode
    except OSError as e:
        print(f"erreur : sudo introuvable ({e})", file=sys.stderr)
        return 1
    if code:
        print(f"erreur : {' '.join(['sudo', *cmd])} a échoué (code {code}). "
              "Si informant a bloqué la transaction : informant read, puis relancer.", file=sys.stderr)
    return code


def main(argv: list[str] | None = None) -> int:
    """Aligne les paquets de la machine sur paquets.toml.

    Entrée : argv — arguments, sys.argv[1:] par défaut ; --dry-run affiche le plan et s'arrête.
    Sortie : 0 en cas de succès ou de --dry-run ; 1 si une vérification échoue (rien n'est modifié) ;
             sinon le code de la commande sudo pacman qui a échoué, sans autre question ensuite.
    Erreurs : messages sur la sortie d'erreur, sans trace Python. Dépendances : lire, sysroot, nom_hote,
              detecter, voulus, etat, controler, calculer, demander, agir.
    """
    ap = argparse.ArgumentParser(description="Aligne les paquets sur paquets.toml.")
    ap.add_argument("--dry-run", action="store_true", help="affiche le plan sans rien modifier")
    args = ap.parse_args(argv)
    modele, erreurs = lire(Path(__file__).resolve().parent)
    if erreurs:
        print("\n".join(f"erreur : {e}" for e in erreurs), file=sys.stderr)
        return 1
    root = sysroot(os.environ)
    processeurs, cartes = detecter(root)
    try:
        configures, noms, installes, explicites, non_requis, orphelins = etat(modele["depots"])
    except RuntimeError as e:
        print(f"erreur : {e}", file=sys.stderr)
        return 1
    erreurs = controler(modele, configures, noms)
    if erreurs:
        print("\n".join(f"erreur : {e}" for e in erreurs), file=sys.stderr)
        return 1
    veut, avertissements = voulus(modele, nom_hote(root), processeurs, cartes)
    plan = calculer(veut, installes, explicites, non_requis, orphelins)
    print(f"matériel : processeur {', '.join(sorted(processeurs)) or 'aucun'}, "
          f"graphique {', '.join(sorted(cartes)) or 'aucun'}")
    print("\n".join(f"avertissement : {a}" for a in avertissements))
    titres = {"manquants": "à installer", "a_expliciter": "à marquer explicites",
              "excedent_requis": "excédent requis par un autre paquet (marquable comme dépendance)",
              "excedent_libre": "excédent libre (retirable)", "orphelins": "orphelins (retirables)"}
    for cle, titre in titres.items():
        print(f"{titre} : {len(plan[cle])}" + (f" — {', '.join(plan[cle])}" if plan[cle] else ""))
    if args.dry_run:
        return 0
    for cmd in (["pacman", "-S", "--needed", *plan["manquants"]] if plan["manquants"] else None,
                ["pacman", "-D", "--asexplicit", *plan["a_expliciter"]] if plan["a_expliciter"] else None):
        if cmd and (code := agir(cmd)):
            return code
    retirables = sorted({*plan["excedent_libre"], *plan["orphelins"]})
    for noms_, question, cmd in (
            (plan["excedent_requis"], "Marquer ces {n} paquets comme dépendances ? [o/N] ", ["pacman", "-D", "--asdeps"]),
            (retirables, "Retirer ces {n} paquets ? [o/N] ", ["pacman", "-Rns"])):
        if noms_ and demander(question.format(n=len(noms_))) and (code := agir([*cmd, *noms_])):
            return code
    if modele["provisoire"]:
        print(f"{len(modele['provisoire'])} paquets provisoires : "
              + ", ".join(f"{p} → {item}" for p, item in sorted(modele["provisoire"].items())))
    return 0


if __name__ == "__main__":
    sys.exit(main())
