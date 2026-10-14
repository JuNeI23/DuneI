#!/usr/bin/env python3
"""Déploiement — installe la configuration de DuneI dans le dossier de configuration de l'utilisateur.

Chaque destination de DESTINATIONS planifie ses propres actions ; toutes sont inspectées avant la
moindre modification, et une seule erreur suffit à tout refuser. config/ est déployé par lien
symbolique et generated/ par copie atomique. Le script n'écrase jamais un fichier qu'il n'a pas
posé lui-même.

- hypr : au premier passage, une configuration générique existante est conservée sous le nom
  generique.lua, puis remplacée de façon atomique par le point d'entrée DuneI. Hyprland recharge seul.
- fontconfig : generated/fonts.conf est copié vers fontconfig/conf.d/50-dunei.conf. Les applications
  lancées ensuite le lisent ; aucun fc-cache n'est nécessaire.

    python3 deploy.py [--dry-run]
"""

from __future__ import annotations

import argparse
import os
import sys
from collections.abc import Mapping
from pathlib import Path

REPO = Path(__file__).resolve().parent
ENTRY = "config/hypr/hyprland.lua"            # Point d'entrée, lié sous hypr/hyprland.lua.
LINKS = ("config/hypr/modules", "config/hypr/machines")  # Dossiers écrits à la main, liés sous hypr/ à leur nom.
COPIES = ("hyprland-tokens.lua", "motion.lua")  # Fichiers de generated/ lus par Hyprland.
GENERIC = "generique.lua"                     # Nom donné à la configuration générique de la machine.
TEMP = ".{}.dunei"                            # Nom temporaire, sans extension .lua, invisible pour require.
FONTCONFIG = ("fonts.conf", "conf.d/50-dunei.conf")  # Fichier de generated/ → chemin sous fontconfig/.
MARK = "GÉNÉRÉ depuis tokens.toml"                    # Avertissement de deuxième ligne : le fichier est à DuneI.


def config_home(env: Mapping[str, str]) -> Path:
    """Dossier de configuration racine de l'utilisateur.

    Entrée : env — environnement, os.environ en usage normal.
    Sortie : $XDG_CONFIG_HOME, ou ~/.config si la variable est absente ou vide.
    Erreurs : aucune. Dépendances : aucune.
    """
    return Path(env.get("XDG_CONFIG_HOME") or Path(env.get("HOME") or os.path.expanduser("~")) / ".config")


def _links_to(link: Path, target: Path) -> bool:
    """Correspondance exacte d'un lien symbolique avec sa cible attendue.

    Entrées : link — chemin à examiner ; target — cible absolue attendue.
    Sortie : vrai si link est un lien dont la cible est exactement target.
    Erreurs : aucune pour un lien lisible. Dépendances : os.readlink.
    """
    return link.is_symlink() and Path(os.readlink(link)) == target


def _ours(path: Path) -> bool:
    """Reconnaissance d'un fichier posé par DuneI, à son avertissement de génération.

    Entrée : path — fichier existant à examiner.
    Sortie : vrai si la deuxième ligne porte MARK ; faux si elle ne le porte pas ou si le fichier
             est illisible (dossier, droits, encodage).
    Erreurs : aucune. Dépendances : MARK.
    """
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except (OSError, UnicodeDecodeError):
        return False
    return len(lines) > 1 and MARK in lines[1]


def plan_hypr(repo: Path, home: Path) -> tuple[list[tuple], list[str]]:
    """Inspection de la destination Hyprland, sans aucune modification.

    Entrées : repo — racine du dépôt ; home — dossier de configuration racine.
    Sortie : (actions dans l'ordre d'exécution, erreurs).
    Erreurs : aucune exception ; chaque problème devient un message. Dépendances : _links_to.
    """
    dest = home / "hypr"
    actions, err = [], []
    sources = [repo / ENTRY] + [repo / d for d in LINKS] + [repo / "generated" / f for f in COPIES]
    err += [f"source manquante : {s} (lancer make tokens motion)" for s in sources if not s.exists()]
    if dest.is_symlink() or (dest.exists() and not dest.is_dir()):
        return actions, err + [f"{dest} existe mais n'est pas un dossier réel"]
    if not dest.exists():
        actions.append(("mkdir", dest))

    generated = dest / "generated"
    if generated.is_symlink() or (generated.exists() and not generated.is_dir()):
        err.append(f"{generated} existe mais n'est pas un dossier réel")
    elif not generated.exists():
        actions.append(("mkdir", generated))
    actions += [("copy", repo / "generated" / f, generated / f) for f in COPIES]

    for d in LINKS:
        src, link = repo / d, dest / Path(d).name
        if link.is_symlink() or link.exists():
            if not _links_to(link, src):
                err.append(f"{link} existe mais n'est pas un lien vers {src}"
                           + (f" : il pointe vers {os.readlink(link)}" if link.is_symlink() else ""))
        else:
            actions.append(("link", src, link))

    entry, generic = dest / "hyprland.lua", dest / GENERIC
    if entry.is_symlink():
        if not _links_to(entry, repo / ENTRY):
            err.append(f"{entry} est un lien vers {os.readlink(entry)}, et non vers {repo / ENTRY}")
    elif entry.is_file():
        if generic.is_symlink() or generic.exists():
            err.append(f"{entry} et {generic} existent tous deux : la bascule écraserait l'un d'eux")
        else:
            actions.append(("switch", repo / ENTRY, entry, generic))
    elif entry.exists():
        err.append(f"{entry} existe mais n'est ni un fichier ni un lien")
    elif (dest / "hyprland.conf").exists():
        err.append(f"{dest / 'hyprland.conf'} existe : Hyprland l'ignorerait au profit du point d'entrée DuneI, "
                   "qui ne déclare encore aucun raccourci ; le convertir en hyprland.lua d'abord")
    else:
        actions.append(("link", repo / ENTRY, entry))
    return actions, err


def plan_fontconfig(repo: Path, home: Path) -> tuple[list[tuple], list[str]]:
    """Inspection de la destination fontconfig, sans aucune modification.

    Entrées : repo — racine du dépôt ; home — dossier de configuration racine.
    Sortie : (actions dans l'ordre d'exécution, erreurs).
    Erreurs : aucune exception ; source absente, dossier qui n'en est pas un, fichier ou lien
              étranger à la place de 50-dunei.conf deviennent des messages.
    Dépendances : _ours, FONTCONFIG.
    """
    src, dest = repo / "generated" / FONTCONFIG[0], home / "fontconfig" / FONTCONFIG[1]
    actions, err = [], []
    if not src.exists():
        err.append(f"source manquante : {src} (lancer make tokens)")
    for d in (dest.parent.parent, dest.parent):
        if d.is_symlink() or (d.exists() and not d.is_dir()):
            return actions, err + [f"{d} existe mais n'est pas un dossier réel"]
        if not d.exists():
            actions.append(("mkdir", d))
    if dest.is_symlink() or (dest.exists() and not _ours(dest)):
        err.append(f"{dest} existe mais n'a pas été posé par DuneI")
    return actions + [("copy", src, dest)], err


DESTINATIONS = {"hypr": plan_hypr, "fontconfig": plan_fontconfig}  # Nom → planification.


def plan(repo: Path, home: Path) -> tuple[list[tuple], list[str]]:
    """Inspection de toutes les destinations, sans aucune modification.

    Entrées : repo — racine du dépôt ; home — dossier de configuration racine.
    Sortie : (actions de toutes les destinations, dans l'ordre de DESTINATIONS ; erreurs).
             Une seule erreur suffit à tout refuser.
    Erreurs : aucune exception ; chaque problème devient un message. Dépendances : DESTINATIONS.
    """
    actions, err = [], []
    if (repo / ".git").is_file():
        err.append(f"{repo} est un arbre de travail secondaire : les liens disparaîtraient avec lui, "
                   "lancer make install depuis le dépôt principal")
    for plan_one in DESTINATIONS.values():
        a, e = plan_one(repo, home)
        actions, err = actions + a, err + e
    return actions, err


def describe(action: tuple) -> str:
    """Phrase décrivant une action, pour l'affichage.

    Entrée : action — tuple produit par plan. Sortie : texte. Erreurs : KeyError si le type est inconnu.
    Dépendances : aucune.
    """
    kind, *args = action
    return {
        "mkdir": "créer le dossier {0}",
        "copy": "copier {0} vers {1}",
        "link": "lier {1} à {0}",
        "switch": "conserver {1} sous le nom {2}, puis lier {1} à {0}",
    }[kind].format(*args)


def apply(actions: list[tuple]) -> None:
    """Exécution des actions, dans l'ordre fourni par plan.

    Les copies passent par un fichier temporaire renommé par os.replace ; la bascule donne un
    second nom au fichier générique (os.link), puis remplace hyprland.lua par un lien temporaire
    renommé par os.replace. hyprland.lua existe ainsi à chaque instant.
    Entrée : actions — liste produite par plan, sans erreur.
    Sortie : aucune. Erreurs : OSError si le système de fichiers refuse une opération.
    Dépendances : os, TEMP.
    """
    for kind, *args in actions:
        if kind == "mkdir":
            args[0].mkdir(parents=True)
        elif kind == "copy":
            src, dst = args
            tmp = dst.with_name(TEMP.format(dst.name))
            tmp.write_bytes(src.read_bytes())
            os.replace(tmp, dst)
        elif kind == "link":
            args[1].symlink_to(args[0])
        elif kind == "switch":
            target, entry, generic = args
            tmp = entry.with_name(TEMP.format(entry.name))
            os.link(entry, generic)
            tmp.unlink(missing_ok=True)
            tmp.symlink_to(target)
            os.replace(tmp, entry)


def main() -> int:
    """Déploiement complet, ou simple affichage avec --dry-run.

    Entrée : argument de ligne de commande --dry-run.
    Sortie : code de retour 0 si succès, 1 si la destination est douteuse ou si une opération échoue.
    Erreurs : messages sur la sortie d'erreur ; en cas de refus, rien n'est modifié.
    Dépendances : config_home, plan, describe, apply.
    """
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--dry-run", action="store_true", help="affiche les actions prévues sans les effectuer")
    args = ap.parse_args()

    home = config_home(os.environ)
    actions, err = plan(REPO, home)
    if err:
        for e in err:
            print(f"  erreur : {e}", file=sys.stderr)
        print(f"\n{len(err)} erreur(s) : rien n'a été modifié dans {home}.", file=sys.stderr)
        return 1

    if not args.dry_run:
        try:
            apply(actions)
        except OSError as e:
            print(f"déploiement interrompu : {e}", file=sys.stderr)
            return 1
    for a in actions:
        print(f"  {'prévu' if args.dry_run else 'fait'} : {describe(a)}")
    print(f"\n{home} : {len(actions)} action(s) {'prévue(s)' if args.dry_run else 'effectuée(s)'}.")
    if any(a[0] == "switch" for a in actions):
        # Hyprland surveille le fichier générique lui-même, qui survit sous un autre nom : la bascule
        # ne déclenche donc pas le rechargement automatique. Les passages suivants le déclenchent.
        print("Première bascule : lancer hyprctl reload une fois pour charger le point d'entrée DuneI.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
