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
import hashlib
import re
import shutil
import subprocess
import tarfile
import tomllib
import urllib.request
from collections.abc import Mapping
from pathlib import Path

ATELIER = "atelier.toml"                      # Fichier déclaratif de l'atelier, à la racine du dépôt.
CLES_RTK = ("version", "archive", "url", "sha256_archive", "sha256_binaire")
CLES_ATELIER = ("depot", "clone", "gitconfig")
NOTES_APPLIQUEES: list[tuple] = []             # Notes nées de l'application (atelier-repris, atelier-garde), lues par deploy.main.
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


def bin_home(env: Mapping[str, str]) -> Path:
    """Dossier des exécutables de l'utilisateur.

    Entrée : env — environnement, os.environ en usage normal.
    Sortie : $XDG_BIN_HOME, ou $HOME/.local/bin si la variable est absente ou vide.
    Erreurs : aucune. Dépendances : aucune.
    """
    return Path(env.get("XDG_BIN_HOME") or Path(env.get("HOME") or os.path.expanduser("~")) / ".local" / "bin")


def cache_home(env: Mapping[str, str]) -> Path:
    """Dossier de cache de DuneI.

    Entrée : env — environnement, os.environ en usage normal.
    Sortie : $XDG_CACHE_HOME/dunei, ou $HOME/.cache/dunei si la variable est absente ou vide.
    Erreurs : aucune. Dépendances : aucune.
    """
    return Path(env.get("XDG_CACHE_HOME") or Path(env.get("HOME") or os.path.expanduser("~")) / ".cache") / "dunei"


def telecharger(url: str, dest: Path) -> None:
    """Téléchargement d'une adresse vers un fichier ; seul point réseau du module.

    Entrées : url — adresse à lire ; dest — fichier à écrire.
    Sortie : aucune. Erreurs : OSError (dont URLError) si le téléchargement échoue.
    Dépendances : urllib.request.
    """
    urllib.request.urlretrieve(url, dest)


def sha256(path: Path) -> str:
    """Somme SHA-256 d'un fichier.

    Entrée : path — fichier à lire. Sortie : somme en hexadécimal minuscule.
    Erreurs : OSError si le fichier est illisible. Dépendances : hashlib.
    """
    return hashlib.sha256(path.read_bytes()).hexdigest()


def plan_rtk(repo: Path, home: Path) -> tuple[list[tuple], list[str]]:
    """Inspection de rtk — télécharge et vérifie l'archive épinglée si le binaire n'est pas conforme.

    Entrées : repo — racine du dépôt ; home — inutilisé, pour l'interface commune de DESTINATIONS.
    Sortie : (actions, erreurs). Rien à faire si le binaire de bin_home a la somme épinglée ; sinon
        ("rtk-pose", archive, somme du binaire attendue, destination), précédé de
        ("rtk-remplace", destination, version) quand un autre binaire est présent. Une archive en
        cache de mauvaise somme est supprimée puis retéléchargée une fois.
    Erreurs : atelier.toml invalide, téléchargement impossible (l'adresse est nommée) ou somme de
        l'archive fausse (somme attendue et somme lue), rendus comme messages.
    Dépendances : lire_atelier, bin_home, cache_home, telecharger, sha256.
    """
    donnees, erreurs = lire_atelier(repo)
    if erreurs:
        return [], erreurs
    rtk = donnees["rtk"]
    dest = bin_home(os.environ) / "rtk"
    if dest.is_file() and sha256(dest) == rtk["sha256_binaire"]:
        return [], []
    archive = cache_home(os.environ) / rtk["archive"]
    if archive.is_file() and sha256(archive) != rtk["sha256_archive"]:
        archive.unlink()
    if not archive.is_file():
        part = archive.with_name(archive.name + ".part")
        try:
            archive.parent.mkdir(parents=True, exist_ok=True)
            telecharger(rtk["url"], part)
            lue = sha256(part)
            if lue != rtk["sha256_archive"]:
                part.unlink()
                return [], [f"archive rtk de somme fausse : attendue {rtk['sha256_archive']}, lue {lue} ({rtk['url']})"]
            os.replace(part, archive)
        except OSError as e:
            return [], [f"rtk {rtk['version']} non téléchargeable depuis {rtk['url']} : {e}"]
    actions: list[tuple] = [("rtk-pose", archive, rtk["sha256_binaire"], dest)]
    if dest.exists():
        actions.append(("rtk-remplace", dest, rtk["version"]))
    return actions, []


def gh_accessible(depot: str) -> str:
    """Vérification de l'accès à dunei-atelier par gh.

    Entrée : depot — dépôt GitHub au format propriétaire/nom.
    Sortie : chaîne vide si gh auth status puis gh repo view réussissent, sinon la cause en une phrase
        avec la commande à lancer.
    Erreurs : aucune (gh absent compris). Dépendances : subprocess, gh.
    """
    causes = ((["gh", "auth", "status"], "gh n'est pas connecté : lancer gh auth login, puis relancer make install"),
              (["gh", "repo", "view", depot], f"gh n'a pas accès à {depot} : vérifier le compte (gh auth status), puis relancer make install"))
    for commande, cause in causes:
        try:
            if subprocess.run(commande, capture_output=True).returncode:
                return cause
        except OSError:
            return "gh est absent : installer github-cli et lancer gh auth login, puis relancer make install"
    return ""


def _origine_ok(clone: Path, depot: str) -> bool:
    """Vrai si l'adresse origin du clone désigne depot (formes https et ssh de GitHub, avec ou sans .git)."""
    sortie = subprocess.run(["git", "-C", str(clone), "remote", "get-url", "origin"], capture_output=True, text=True)
    forme = rf"(https://github\.com/|git@github\.com:|ssh://git@github\.com/){re.escape(depot)}(\.git)?/?"
    return sortie.returncode == 0 and re.fullmatch(forme, sortie.stdout.strip()) is not None


def plan_atelier(repo: Path, home: Path) -> tuple[list[tuple], list[str]]:
    """Inspection de l'atelier — clone de dunei-atelier et liens de ses fichiers.

    Entrées : repo — racine du dépôt ; home — inutilisé, pour l'interface commune de DESTINATIONS.
    Sortie : (actions, erreurs). Si le clone manque et que gh est inutilisable : seulement
        ("atelier-saute", cause). Sinon ("atelier-clone", depot, clone) si le clone manque, puis, pour
        chaque destination qui n'est pas déjà le bon lien, ("atelier-lien", src, dst, neuf) où neuf
        est vrai si le clone manquait à l'inspection.
    Erreurs : atelier.toml invalide ; clone qui n'est pas un dépôt git ou dont origin n'est pas le
        dépôt attendu ; destination qui est un dossier ; lien vers un autre chemin que le fichier du
        clone. Chaque message nomme le chemin.
    Dépendances : lire_atelier, gh_accessible, subprocess.
    """
    donnees, erreurs = lire_atelier(repo)
    if erreurs:
        return [], erreurs
    cfg = donnees["atelier"]
    clone, neuf = cfg["clone"], not cfg["clone"].exists()
    actions: list[tuple] = []
    if neuf:
        cause = gh_accessible(cfg["depot"])
        if cause:
            return [("atelier-saute", cause)], []
        actions.append(("atelier-clone", cfg["depot"], clone))
    elif subprocess.run(["git", "-C", str(clone), "rev-parse", "--git-dir"], capture_output=True).returncode:
        return [], [f"{clone} existe sans être un dépôt git : le déplacer ou le supprimer"]
    elif not _origine_ok(clone, cfg["depot"]):
        return [], [f"l'origine de {clone} n'est pas {cfg['depot']} : vérifier avec git -C {clone} remote -v"]
    # Les actions des plugins et de l'inclusion du gitconfig s'insèrent ici, avant les liens.
    for rel, dst in cfg["liens"].items():
        src = clone / rel
        if dst.is_symlink():
            if dst.resolve() != src.resolve():
                erreurs.append(f"{dst} est un lien vers {dst.resolve()}, pas vers {src} : le retirer ou le corriger")
        elif dst.is_dir():
            erreurs.append(f"{dst} est un dossier, pas un fichier : le déplacer ou le supprimer")
        else:
            actions.append(("atelier-lien", src, dst, neuf))
    return ([], erreurs) if erreurs else (actions, [])


def _lier(src: Path, dst: Path, neuf: bool) -> None:
    """Pose du lien dst vers src, en reprenant ou gardant le fichier qui occupe dst.

    Entrées : src — fichier du clone ; dst — destination ; neuf — vrai si le clone vient d'être créé.
    Sortie : aucune ; ajoute à NOTES_APPLIQUEES atelier-garde (fichier gardé en .avant-dunei) ou
        atelier-repris (contenu copié dans src). Erreurs : OSError. Dépendances : os, shutil.
    """
    dst.parent.mkdir(parents=True, exist_ok=True)
    if dst.exists() and not (src.is_file() and dst.read_bytes() == src.read_bytes()):
        if neuf:
            os.replace(dst, dst.with_name(dst.name + ".avant-dunei"))
            NOTES_APPLIQUEES.append(("atelier-garde", dst))
        else:
            src.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(dst, src)
            NOTES_APPLIQUEES.append(("atelier-repris", dst))
    tmp = dst.with_name(f".{dst.name}.dunei-tmp")
    tmp.unlink(missing_ok=True)
    tmp.symlink_to(src)
    os.replace(tmp, dst)


def appliquer(action: tuple) -> bool:
    """Exécution d'une action propre à l'atelier.

    Pour rtk-pose, le membre rtk de l'archive est extrait dans un fichier temporaire du dossier cible,
    sa somme est vérifiée, puis il est rendu exécutable et renommé par os.replace.
    atelier-clone lance gh repo clone ; atelier-lien appelle _lier.
    Entrée : action — tuple produit par plan_rtk ou plan_atelier.
    Sortie : True si l'action appartient à l'atelier et a été exécutée, False sinon.
    Erreurs : subprocess.CalledProcessError si le clone échoue ; OSError si l'archive est illisible ou sans membre rtk, ou si la somme du binaire diffère
        (la destination reste intacte). Dépendances : tarfile, sha256, os, subprocess, _lier.
    """
    kind, *args = action
    if kind == "atelier-clone":
        subprocess.run(["gh", "repo", "clone", args[0], str(args[1])], check=True)
        return True
    if kind == "atelier-lien":
        _lier(*args)
        return True
    if kind != "rtk-pose":
        return False
    archive, attendue, dest = args
    dest.parent.mkdir(parents=True, exist_ok=True)
    tmp = dest.with_name(f".{dest.name}.dunei-tmp")
    try:
        with tarfile.open(archive) as tar:
            membre = tar.extractfile("rtk")
            if membre is None:
                raise OSError(f"{archive} ne contient pas de fichier rtk")
            tmp.write_bytes(membre.read())
        if sha256(tmp) != attendue:
            raise OSError(f"binaire rtk de somme fausse dans {archive} : attendue {attendue}, lue {sha256(tmp)}")
        tmp.chmod(0o755)
        os.replace(tmp, dest)
    except (tarfile.TarError, KeyError) as e:
        raise OSError(f"{archive} illisible : {e}") from e
    finally:
        tmp.unlink(missing_ok=True)
    return True
