#!/usr/bin/env python3
"""Déploiement — installe la configuration Hyprland de DuneI dans le dossier de configuration.

config/ est déployé par lien symbolique et generated/ par copie. Au premier passage, une
configuration générique existante est conservée sous le nom generique.lua, puis remplacée de
façon atomique par le point d'entrée DuneI. Le script vérifie tout avant d'agir, n'écrase jamais
un fichier qu'il n'a pas posé lui-même et ne recharge pas Hyprland, qui recharge seul.

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
MODULES = "config/hypr/modules"               # Modules écrits à la main, liés sous hypr/modules.
COPIES = ("hyprland-tokens.lua", "motion.lua")  # Fichiers de generated/ lus par Hyprland.
GENERIC = "generique.lua"                     # Nom donné à la configuration générique de la machine.
TEMP = ".{}.dunei"                            # Nom temporaire, sans extension .lua, invisible pour require.


def config_dir(env: Mapping[str, str]) -> Path:
    """Dossier de configuration Hyprland de l'utilisateur.

    Entrée : env — environnement, os.environ en usage normal.
    Sortie : $XDG_CONFIG_HOME/hypr, ou ~/.config/hypr si la variable est absente ou vide.
    Erreurs : aucune. Dépendances : aucune.
    """
    return Path(env.get("XDG_CONFIG_HOME") or Path(env.get("HOME") or os.path.expanduser("~")) / ".config") / "hypr"


def _links_to(link: Path, target: Path) -> bool:
    """Vrai si link est un lien symbolique dont la cible est exactement target."""
    return link.is_symlink() and Path(os.readlink(link)) == target


def plan(repo: Path, dest: Path) -> tuple[list[tuple], list[str]]:
    """Inspection de la destination, sans aucune modification.

    Entrées : repo — racine du dépôt ; dest — dossier de configuration Hyprland.
    Sortie : (actions dans l'ordre d'exécution, erreurs). Une seule erreur suffit à tout refuser.
    Erreurs : aucune exception ; chaque problème devient un message. Dépendances : _links_to.
    """
    actions, err = [], []
    sources = [repo / ENTRY, repo / MODULES] + [repo / "generated" / f for f in COPIES]
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

    modules = dest / "modules"
    if modules.is_symlink() or modules.exists():
        if not _links_to(modules, repo / MODULES):
            err.append(f"{modules} existe mais n'est pas un lien vers {repo / MODULES}")
    else:
        actions.append(("link", repo / MODULES, modules))

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
    else:
        actions.append(("link", repo / ENTRY, entry))
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
    Dépendances : config_dir, plan, describe, apply.
    """
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--dry-run", action="store_true", help="affiche les actions prévues sans les effectuer")
    args = ap.parse_args()

    dest = config_dir(os.environ)
    actions, err = plan(REPO, dest)
    if err:
        for e in err:
            print(f"  erreur : {e}", file=sys.stderr)
        print(f"\n{len(err)} erreur(s) : rien n'a été modifié dans {dest}.", file=sys.stderr)
        return 1

    if not args.dry_run:
        try:
            apply(actions)
        except OSError as e:
            print(f"déploiement interrompu : {e}", file=sys.stderr)
            return 1
    for a in actions:
        print(f"  {'prévu' if args.dry_run else 'fait'} : {describe(a)}")
    print(f"\n{dest} : {len(actions)} action(s) {'prévue(s)' if args.dry_run else 'effectuée(s)'}.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
