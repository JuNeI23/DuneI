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

import argparse
import os
import hashlib
import http.client
import json
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
NOTES_APPLIQUEES: list[tuple] = []             # Notes nées de l'application (atelier-repris, atelier-garde, atelier-saute...), lues par deploy.main.
_SAUTE = False                                 # Vrai quand le clone a échoué : les actions atelier-* suivantes n'agissent plus.
DELAI = 30                                     # Secondes accordées à chaque appel de gh et de claude pendant l'inspection.
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
    Sortie : aucune. Erreurs : OSError (dont URLError et le délai de 60 s), http.client.HTTPException ou ValueError si le téléchargement échoue.
    Dépendances : urllib.request, shutil.
    """
    with urllib.request.urlopen(url, timeout=60) as reponse, dest.open("wb") as sortie:
        shutil.copyfileobj(reponse, sortie)


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
        ("rtk-pose", archive, somme du binaire attendue, destination), suivi de
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
        except (OSError, http.client.HTTPException, ValueError) as e:
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
            if subprocess.run(commande, capture_output=True, timeout=DELAI).returncode:
                return cause
        except subprocess.TimeoutExpired:
            return cause
        except OSError:
            return "gh est absent : installer github-cli et lancer gh auth login, puis relancer make install"
    return ""


def _origine_ok(clone: Path, depot: str) -> bool:
    """Vrai si l'adresse origin du clone désigne depot (formes https et ssh de GitHub, avec ou sans .git)."""
    sortie = subprocess.run(["git", "-C", str(clone), "remote", "get-url", "origin"], capture_output=True, text=True)
    forme = rf"(https://github\.com/|git@github\.com:|ssh://git@github\.com/){re.escape(depot)}(\.git)?/?"
    return sortie.returncode == 0 and re.fullmatch(forme, sortie.stdout.strip()) is not None


def _inclusions() -> list[str]:
    """Chemins déjà inclus par le gitconfig global (valeurs de include.path).

    Entrée : aucune. Sortie : liste des chemins, vide si aucun ou si git est absent.
    Erreurs : aucune. Dépendances : subprocess, git.
    """
    try:
        sortie = subprocess.run(["git", "config", "--global", "--get-all", "include.path"], capture_output=True, text=True)
    except OSError:
        return []
    return sortie.stdout.splitlines()


def plan_atelier(repo: Path, home: Path) -> tuple[list[tuple], list[str]]:
    """Inspection de l'atelier — clone de dunei-atelier et liens de ses fichiers.

    Entrées : repo — racine du dépôt ; home — inutilisé, pour l'interface commune de DESTINATIONS.
    Sortie : (actions, erreurs). Si le clone manque et que gh est inutilisable, ou si le dossier du
        clone existe sans être un dépôt git (la mémoire de Claude Code peut l'avoir créé) : seulement
        ("atelier-saute", cause). Sinon ("atelier-clone", depot, clone) si le clone manque, puis ("atelier-plugins", clone) (si le clone manque ou si un plugin activé manque, ou si claude est absent), puis
        ("atelier-include", gitconfig du clone) si le gitconfig global ne l'inclut pas encore, puis, pour
        chaque destination qui n'est pas déjà le bon lien, ("atelier-lien", src, dst, neuf) où neuf
        est vrai si le clone manquait à l'inspection.
    Erreurs : atelier.toml invalide ; clone dont origin n'est pas le dépôt attendu ; destination qui est un dossier ; lien vers un autre chemin que le fichier du
        clone. Chaque message nomme le chemin.
    Dépendances : lire_atelier, gh_accessible, _plugins_a_poser, _inclusions, subprocess.
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
        return [("atelier-saute", f"{clone} existe sans être un dépôt git (la mémoire de Claude Code l'a peut-être créé) : le déplacer, "
                 f"par exemple en {clone}.avant-dunei, puis relancer make install ; ne pas le supprimer : il peut contenir la mémoire de Claude")], []
    elif not _origine_ok(clone, cfg["depot"]):
        return [], [f"l'origine de {clone} n'est pas {cfg['depot']} : vérifier avec git -C {clone} remote -v"]
    if neuf or (manquants := _plugins_a_poser(clone)) is None or manquants:
        actions.append(("atelier-plugins", clone))
    inclusion = clone / cfg["gitconfig"]
    if str(inclusion) not in _inclusions():
        actions.append(("atelier-include", inclusion))
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


def _plugins_voulus(clone: Path) -> list[str]:
    """Plugins activés (valeur true) dans enabledPlugins du settings.json du clone.

    Entrée : clone — dépôt dunei-atelier. Sortie : identifiants activés.
    Erreurs : ValueError, cause en une phrase, si le fichier est illisible, n'est pas du JSON ou si
        enabledPlugins n'est pas un objet ; un enabledPlugins absent ne déclare aucun plugin.
    Dépendances : json.
    """
    chemin = clone / "claude" / "settings.json"
    try:
        voulus = json.loads(chemin.read_text(encoding="utf-8")).get("enabledPlugins", {})
    except (OSError, ValueError, AttributeError) as e:
        raise ValueError(f"{chemin} illisible ou invalide : {e}") from e
    if not isinstance(voulus, dict):
        raise ValueError(f"enabledPlugins de {chemin} n'est pas un objet")
    return [i for i, actif in voulus.items() if actif is True]


def _plugins_presents() -> set[str]:
    """Identifiants des plugins installés, d'après claude plugin list --json.

    Entrée : aucune. Sortie : ensemble d'identifiants.
    Erreurs : ValueError, cause en une phrase, si la commande échoue ou si sa sortie n'est pas une liste d'objets à id.
    Dépendances : subprocess, json, claude.
    """
    try:
        liste = subprocess.run(["claude", "plugin", "list", "--json"], check=True, capture_output=True, text=True, timeout=DELAI).stdout
        return {p["id"] for p in json.loads(liste)}
    except (subprocess.SubprocessError, OSError, ValueError, KeyError, TypeError) as e:
        raise ValueError(f"claude plugin list --json a échoué : {e}") from e


def _plugins_a_poser(clone: Path) -> list[str] | None:
    """Plugins à installer, pour l'inspection ; ne lève jamais.

    Entrée : clone — dépôt dunei-atelier. Sortie : identifiants manquants ; None si l'état est inconnu (claude absent du PATH, settings.json inutilisable
        ou liste des plugins impossible à lire : l'application signalera l'échec).
    Erreurs : aucune. Dépendances : _plugins_voulus, _plugins_presents, shutil.
    """
    if shutil.which("claude") is None:
        return None
    try:
        voulus = _plugins_voulus(clone)
        presents = _plugins_presents()
    except ValueError:
        return None
    return [i for i in voulus if i not in presents]


def _plugins(clone: Path) -> None:
    """Installation des plugins Claude Code déclarés dans enabledPlugins du clone.

    Entrée : clone — dépôt dunei-atelier, lu à l'application.
    Sortie : aucune ; lance claude plugin install pour chaque plugin manquant. Sans claude dans le
        PATH, ajoute atelier-sans-claude à NOTES_APPLIQUEES ; tout échec (settings.json invalide, liste
        ou installation en échec) ajoute ("atelier-plugins-echec", cause) et n'interrompt rien.
    Erreurs : aucune. Dépendances : _plugins_voulus, _plugins_presents, shutil, subprocess.
    """
    if shutil.which("claude") is None:
        NOTES_APPLIQUEES.append(("atelier-sans-claude",))
        return
    try:
        presents = _plugins_presents()
        for ident in (i for i in _plugins_voulus(clone) if i not in presents):
            subprocess.run(["claude", "plugin", "install", ident], check=True, capture_output=True)
    except ValueError as e:
        NOTES_APPLIQUEES.append(("atelier-plugins-echec", str(e)))
    except (subprocess.CalledProcessError, OSError) as e:
        NOTES_APPLIQUEES.append(("atelier-plugins-echec", f"claude plugin install a échoué : {e}"))


def _libre(chemin: Path) -> Path:
    """Premier nom <chemin>.avant-dunei, puis .avant-dunei.N, qui ne désigne rien.

    Entrée : chemin — fichier à mettre de côté. Sortie : nom libre, dans le même dossier.
    Erreurs : aucune. Dépendances : aucune.
    """
    garde, n = chemin.with_name(chemin.name + ".avant-dunei"), 0
    while garde.exists() or garde.is_symlink():
        n += 1
        garde = chemin.with_name(f"{chemin.name}.avant-dunei.{n}")
    return garde


def _lier(src: Path, dst: Path, neuf: bool) -> None:
    """Pose du lien dst vers src, en reprenant ou gardant le fichier qui occupe dst.

    Entrées : src — fichier du clone ; dst — destination ; neuf — vrai si le clone vient d'être créé.
    Sortie : aucune ; ajoute à NOTES_APPLIQUEES atelier-garde (fichier gardé en .avant-dunei, ou .avant-dunei.N si ce nom est pris) ou
        atelier-repris (contenu copié dans src, atomiquement) ; si src avait une modification non validée, elle est d'abord
        mise de côté sous src.avant-dunei (ou .N), avec la note atelier-repris-garde ; il en va de même si git échoue ou si src est ignoré.
    Erreurs : OSError. Dépendances : _libre, os, shutil, subprocess, git.
    """
    dst.parent.mkdir(parents=True, exist_ok=True)
    if dst.exists() and not (src.is_file() and dst.read_bytes() == src.read_bytes()):
        if neuf:
            garde = _libre(dst)
            os.replace(dst, garde)
            NOTES_APPLIQUEES.append(("atelier-garde", dst, garde))
        else:
            src.parent.mkdir(parents=True, exist_ok=True)
            if src.exists() and ((etat := subprocess.run(["git", "-C", str(src.parent), "status", "--porcelain", "--ignored", "--", src.name],
                                                        capture_output=True, text=True)).returncode or etat.stdout.strip()):
                garde = _libre(src)
                os.replace(src, garde)
                NOTES_APPLIQUEES.append(("atelier-repris-garde", src, garde))
            copie = src.with_name(f".{src.name}.dunei-tmp")
            shutil.copyfile(dst, copie)
            os.replace(copie, src)
            NOTES_APPLIQUEES.append(("atelier-repris", dst))
    tmp = dst.with_name(f".{dst.name}.dunei-tmp")
    tmp.unlink(missing_ok=True)
    tmp.symlink_to(src)
    os.replace(tmp, dst)


def appliquer(action: tuple) -> bool:
    """Exécution d'une action propre à l'atelier.

    Pour rtk-pose, le membre rtk de l'archive est extrait dans un fichier temporaire du dossier cible,
    sa somme est vérifiée, puis il est rendu exécutable et renommé par os.replace.
    atelier-clone lance gh repo clone ; atelier-plugins appelle _plugins ; atelier-include ajoute include.path au gitconfig global ; atelier-lien appelle _lier.
    Entrée : action — tuple produit par plan_rtk ou plan_atelier.
    Sortie : True si l'action appartient à l'atelier et a été exécutée, False sinon.
    Un clone qui échoue (CalledProcessError, OSError) ajoute atelier-saute et fait sauter les actions atelier-* suivantes.
    Erreurs : OSError si l'archive est illisible ou sans membre rtk, ou si la somme du binaire diffère
        (la destination reste intacte). Dépendances : tarfile, sha256, os, subprocess, _lier.
    """
    global _SAUTE
    kind, *args = action
    if kind.startswith("atelier-") and _SAUTE:
        return True
    if kind == "atelier-clone":
        try:
            subprocess.run(["gh", "repo", "clone", args[0], str(args[1])], check=True)
        except (subprocess.CalledProcessError, OSError) as e:
            _SAUTE = True
            NOTES_APPLIQUEES.append(("atelier-saute", f"gh repo clone {args[0]} a échoué ({e}) : vérifier le compte (gh auth status) et le réseau, puis relancer make install"))
        return True
    if kind == "atelier-plugins":
        _plugins(*args)
        return True
    if kind == "atelier-include":
        subprocess.run(["git", "config", "--global", "--add", "include.path", str(args[0])], check=True)
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


def etat_atelier(repo: Path) -> list[str]:
    """Relevé des écarts de l'atelier — ce que le clone garde sans l'avoir envoyé.

    Entrée : repo — racine du dépôt DuneI, où se lit atelier.toml.
    Sortie : une phrase par écart : fichiers modifiés ou non suivis (git status --porcelain), commits
        en avance sur la branche suivie (git rev-list --count @{u}..HEAD), destination d'un lien
        devenue fichier ordinaire. Liste vide si tout va bien, si le clone manque ou si atelier.toml
        est invalide ; sans branche suivie, aucune phrase de commits.
    Erreurs : aucune ; un échec de git ou son absence n'ajoute aucune phrase. Aucun accès au réseau.
    Dépendances : lire_atelier, subprocess, git.
    """
    donnees, erreurs = lire_atelier(repo)
    if erreurs or not (cfg := donnees["atelier"])["clone"].is_dir():
        return []
    clone, phrases = cfg["clone"], []

    def git(*args: str) -> subprocess.CompletedProcess:
        return subprocess.run(["git", "-C", str(clone), *args], capture_output=True, text=True)

    try:
        modifies, avance = git("status", "--porcelain"), git("rev-list", "--count", "@{u}..HEAD")
    except OSError:
        return []
    if modifies.returncode == 0 and (n := len(modifies.stdout.splitlines())):
        phrases.append(f"{n} fichier(s) modifié(s) ou non suivi(s) dans {clone}, à envoyer")
    if avance.returncode == 0 and (n := int(avance.stdout.strip() or 0)):
        phrases.append(f"{n} commit(s) de {clone} pas encore envoyé(s)")
    phrases += [f"{dst} est devenu un fichier ordinaire : le lien vers {clone / rel} est perdu"
                for rel, dst in cfg["liens"].items() if dst.is_file() and not dst.is_symlink()]
    return phrases


def main() -> int:
    """Ligne de commande : --etat imprime le relevé de l'atelier, une phrase par ligne.

    Entrée : argument --etat. Sortie : toujours 0. Erreurs : aucune. Dépendances : etat_atelier.
    """
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--etat", action="store_true", help="imprime les écarts du clone dunei-atelier, sans réseau")
    if ap.parse_args().etat:
        for phrase in etat_atelier(Path(__file__).resolve().parent):
            print(phrase)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
