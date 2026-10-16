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
- services : hyprlock doit être installé ; les unités et surcharges de config/systemd/user/ sont
  copiées, l'autostart XDG d'uwsm est masqué (liste blanche de session.toml) ; chaque service de la
  liste est activé, démarré, ou redémarré si sa configuration change (daemon-reload d'abord). Un
  service accroché à la session hors de la liste est signalé, jamais désactivé.
  Cette étape précède les fichiers système : un échec de sudo ne laisse jamais l'ancienne échelle active.
- systeme : chaque fichier de systeme/ est copié sous la racine du système, /etc compris, avec sudo, et
  seulement s'il manque ou diffère ; {utilisateur} est rempli par l'utilisateur courant ; un fichier de
  logind.conf.d recharge logind, sans le redémarrer ; un fichier sous etc/systemd/system recharge systemd.
- connexion : greetd et tuigreet doivent être installés ; si display-manager.service ne désigne pas
  greetd, le gestionnaire actuel est désactivé et greetd activé, pour le démarrage suivant. Refus en root.

    python3 deploy.py [--dry-run]
"""

from __future__ import annotations

import argparse
import os
import pwd
import shutil
import subprocess
import sys
import tempfile
import tomllib
from collections.abc import Mapping
from pathlib import Path

REPO = Path(__file__).resolve().parent
ENTRY = "config/hypr/hyprland.lua"            # Point d'entrée, lié sous hypr/hyprland.lua.
LINKS = ("config/hypr/modules", "config/hypr/machines", "config/hypr/donnees",
         "config/hypr/scripts", "config/hypr/hyprlock.conf")   # Écrits à la main, liés sous hypr/ à leur nom.
COPIES = ("hyprland-tokens.lua", "hyprland-rules.lua", "hyprland-binds.lua", "motion.lua", "energie.lua")  # Fichiers de generated/ lus par Hyprland.
GENERIC = "generique.lua"                     # Nom donné à la configuration générique de la machine.
TEMP = ".{}.dunei"                            # Nom temporaire, sans extension .lua, invisible pour require.
FONTCONFIG = ("fonts.conf", "conf.d/50-dunei.conf")  # Fichier de generated/ → chemin sous fontconfig/.
MARK = "GÉNÉRÉ depuis tokens.toml"                    # Avertissement de deuxième ligne : le fichier est à DuneI.
IDLE = ("hypridle.conf", "GÉNÉRÉ depuis energie.toml")       # Fichier de generated/ copié sous hypr/, et sa marque.
SYSTEME = "systeme"                                          # Arborescence copiée sous la racine du système.
SYSTEM_MARK = "Posé par DuneI"                               # Marque de deuxième ligne d'un fichier système.
SERVICE = "hypridle.service"                                 # Service de l'échelle d'inactivité, redémarré si hypridle.conf change.
SESSION = "session.toml"                                     # Liste blanche du démarrage de session (L1-10).
SESSION_VERSION = "0.1.0"
UNITES = "config/systemd/user"                               # Unités et surcharges utilisateur du dépôt, copiées sous systemd/user/.
MASQUE = "systemd/user/wayland-session-xdg-autostart@.target"  # Autostart XDG d'uwsm, masqué : liste blanche.
SESSION_WANTS = "systemd/user/graphical-session.target.wants"  # Services accrochés à la session graphique.
CHAMP = b"{utilisateur}"                                     # Champ des fichiers système, rempli par l'utilisateur courant.
CONNEXION = ("greetd", "tuigreet")                           # Gestionnaire de connexion et écran provisoire exigés (L1-10).
GESTIONNAIRE = "greetd.service"
DM = "etc/systemd/system/display-manager.service"            # Alias du gestionnaire de connexion actif, sous la racine.
VERROUILLEUR = "hyprlock"                                    # Verrouilleur exigé ; provisoire, remplacé à L2-22.


def config_home(env: Mapping[str, str]) -> Path:
    """Dossier de configuration racine de l'utilisateur.

    Entrée : env — environnement, os.environ en usage normal.
    Sortie : $XDG_CONFIG_HOME, ou ~/.config si la variable est absente ou vide.
    Erreurs : aucune. Dépendances : aucune.
    """
    return Path(env.get("XDG_CONFIG_HOME") or Path(env.get("HOME") or os.path.expanduser("~")) / ".config")


def system_root(env: Mapping[str, str]) -> Path:
    """Racine du système où les fichiers de systeme/ sont copiés.

    Entrée : env — environnement, os.environ en usage normal.
    Sortie : $DUNEI_SYSROOT, réservé aux tests, ou / si la variable est absente ou vide.
    Erreurs : aucune. Dépendances : aucune.
    """
    return Path(env.get("DUNEI_SYSROOT") or "/")


def utilisateur() -> str:
    """Nom de l'utilisateur qui lance le déploiement.

    Entrée : aucune. Sortie : nom du compte de l'uid courant.
    Erreurs : KeyError si l'uid n'a pas de compte. Dépendances : pwd.
    """
    return pwd.getpwuid(os.getuid()).pw_name


def _links_to(link: Path, target: Path) -> bool:
    """Correspondance exacte d'un lien symbolique avec sa cible attendue.

    Entrées : link — chemin à examiner ; target — cible absolue attendue.
    Sortie : vrai si link est un lien dont la cible est exactement target.
    Erreurs : aucune pour un lien lisible. Dépendances : os.readlink.
    """
    return link.is_symlink() and Path(os.readlink(link)) == target


def _ours(path: Path, mark: str = MARK) -> bool:
    """Reconnaissance d'un fichier posé par DuneI, à son avertissement de génération.

    Entrées : path — fichier existant à examiner ; mark — texte attendu en deuxième ligne (MARK par défaut).
    Sortie : vrai si la deuxième ligne porte mark ; faux si elle ne le porte pas ou si le fichier
             est illisible (dossier, droits, encodage).
    Erreurs : aucune. Dépendances : MARK.
    """
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except (OSError, UnicodeDecodeError):
        return False
    return len(lines) > 1 and mark in lines[1]


def plan_hypr(repo: Path, home: Path) -> tuple[list[tuple], list[str]]:
    """Inspection de la destination Hyprland, sans aucune modification.

    Entrées : repo — racine du dépôt ; home — dossier de configuration racine.
    Sortie : (actions dans l'ordre d'exécution, erreurs).
    Erreurs : aucune exception ; chaque problème devient un message. Dépendances : _links_to.
    """
    dest = home / "hypr"
    actions, err = [], []
    sources = [repo / ENTRY] + [repo / d for d in LINKS] + [repo / "generated" / f for f in COPIES]
    sources.append(repo / "generated" / IDLE[0])
    err += [f"source manquante : {s} (lancer make tokens motion energie)" for s in sources if not s.exists()]
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

    idle = dest / IDLE[0]
    if idle.is_symlink() or (idle.exists() and not _ours(idle, IDLE[1])):
        err.append(f"{idle} existe mais n'a pas été posé par DuneI")
    else:
        actions.append(("copy", repo / "generated" / IDLE[0], idle))

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
        err.append(f"{dest / 'hyprland.conf'} existe : Hyprland l'ignorerait au profit du point d'entrée DuneI ; "
                   "le convertir en hyprland.lua d'abord")
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


def plan_systeme(repo: Path, home: Path) -> tuple[list[tuple], list[str]]:
    """Inspection des fichiers système, sans aucune modification.

    Entrées : repo — racine du dépôt ; home — dossier de configuration racine, inutilisé ici.
    Sortie : (copies avec sudo des fichiers absents ou différents, une fois {utilisateur} rempli ; puis
             rechargement de logind si l'un d'eux est sous logind.conf.d, et daemon-reload si l'un d'eux
             est sous etc/systemd/system ; erreurs). Aucune action si tout est identique.
    Erreurs : aucune exception ; un fichier ou un lien étranger à la place d'un fichier de DuneI devient
              un message. Dépendances : system_root, utilisateur, _ours, SYSTEME, SYSTEM_MARK, CHAMP.
    """
    root, actions, err = system_root(os.environ), [], []
    nom = utilisateur().encode()
    for src in sorted(p for p in (repo / SYSTEME).rglob("*") if p.is_file()):
        rel = src.relative_to(repo / SYSTEME)
        dst, contenu = root / rel, src.read_bytes().replace(CHAMP, nom)
        if dst.is_symlink() or (dst.exists() and not _ours(dst, SYSTEM_MARK)):
            err.append(f"{dst} existe mais n'a pas été posé par DuneI")
        elif not dst.exists() or dst.read_bytes() != contenu:
            actions.append(("sudo-copy", src, dst, contenu))
    rels = [a[2].relative_to(root).parts for a in actions]
    if any("logind.conf.d" in p for p in rels):
        actions.append(("sudo-reload", "systemd-logind"))
    if any(p[:3] == ("etc", "systemd", "system") for p in rels):
        actions.append(("sudo-daemon-reload",))
    return actions, err


def plan_connexion(repo: Path, home: Path) -> tuple[list[tuple], list[str]]:
    """Inspection du gestionnaire de connexion, sans aucune modification (L1-10).

    Entrées : repo, home — inutilisés, pour l'interface commune de DESTINATIONS.
    Sortie : (bascule vers greetd si display-manager.service ne le désigne pas ; erreurs). La bascule
             prend effet au démarrage suivant ; elle suit la copie des fichiers système.
    Erreurs : aucune exception ; greetd ou tuigreet absent devient un message.
    Dépendances : shutil.which, system_root, CONNEXION, GESTIONNAIRE, DM.
    """
    manquants = [b for b in CONNEXION if not shutil.which(b)]
    if manquants:
        return [], [f"{', '.join(manquants)} introuvable : sudo pacman -S --needed greetd greetd-tuigreet"]
    alias = system_root(os.environ) / DM
    actuel = Path(os.readlink(alias)).name if alias.is_symlink() else "aucun"
    return ([] if actuel == GESTIONNAIRE else [("sudo-dm", actuel, GESTIONNAIRE)]), []


def lire_session(repo: Path) -> tuple[list[str], list[str]]:
    """Lecture et contrôle de la liste blanche du démarrage de session.

    Entrée : repo — racine du dépôt.
    Sortie : (services de demarrage.services, dans l'ordre ; erreurs). La liste est vide dès qu'une
             erreur existe.
    Erreurs : aucune exception ; fichier illisible, version inattendue, liste absente ou vide, nom qui
              n'est pas une unité .service, doublon deviennent des messages. Dépendances : tomllib,
              SESSION, SESSION_VERSION.
    """
    try:
        with (repo / SESSION).open("rb") as fh:
            raw = tomllib.load(fh)
    except (OSError, ValueError) as e:   # ValueError couvre la syntaxe TOML et l'encodage.
        return [], [f"{SESSION} illisible ({e})"]
    if raw.get("version") != SESSION_VERSION:
        return [], [f"{SESSION} : version « {raw.get('version')} », {SESSION_VERSION} attendue"]
    services = raw.get("demarrage", {}).get("services") if isinstance(raw.get("demarrage"), dict) else None
    if not isinstance(services, list) or not services:
        return [], [f"{SESSION} : demarrage.services doit être une liste non vide"]
    err = [f"{SESSION} : « {s} » n'est pas un nom d'unité .service" for s in services
           if not (isinstance(s, str) and s.endswith(".service") and "/" not in s)]
    err += [f"{SESSION} : « {s} » apparaît deux fois" for s in sorted({s for s in services if isinstance(s, str)})
            if services.count(s) > 1]
    return ([] if err else services), err


def _etat(service: str) -> tuple[str, bool]:
    """État d'un service utilisateur auprès de systemd.

    Entrée : service — nom d'unité. Sortie : (réponse de is-enabled, vrai s'il tourne) ; ("", False) si
             systemctl est absent. Erreurs : aucune. Dépendances : systemctl.
    """
    try:
        state = subprocess.run(["systemctl", "--user", "is-enabled", service], capture_output=True, text=True).stdout.strip()
        active = subprocess.run(["systemctl", "--user", "is-active", service], capture_output=True).returncode == 0
    except OSError:
        return "", False
    return state, active


def plan_services(repo: Path, home: Path) -> tuple[list[tuple], list[str]]:
    """Inspection du démarrage de session, sans aucune modification (L1-09, L1-10).

    Entrées : repo — racine du dépôt ; home — dossier de configuration racine.
    Sortie : (actions, erreurs). Dans l'ordre : copie des unités et surcharges du dépôt absentes ou
             différentes, masque de l'autostart XDG s'il manque, daemon-reload si l'un ou l'autre change ;
             puis pour chaque service de la liste blanche : activation s'il ne l'est pas, redémarrage si
             son unité, sa surcharge ou (pour hypridle) hypridle.conf change, démarrage s'il est arrêté ;
             enfin un signalement ("hors-liste") par service accroché à la session hors de la liste.
    Erreurs : aucune exception ; liste fautive, verrouilleur absent, unité introuvable, fichier ou lien
              étranger deviennent des messages. Dépendances : lire_session, _etat, _ours, _links_to,
              shutil.which, SERVICE, VERROUILLEUR, UNITES, MASQUE, SESSION_WANTS, IDLE, SYSTEM_MARK.
    """
    services, err = lire_session(repo)
    if not shutil.which(VERROUILLEUR):
        err.append(f"{VERROUILLEUR} introuvable : sans verrouilleur la machine dormirait déverrouillée "
                   "(sudo pacman -S hypridle hyprlock)")
    actions, changes, dossiers = [], set(), set()

    def dossier(d: Path) -> None:
        """Planifie la création de d une seule fois, ou signale un faux dossier."""
        if d.is_symlink() or (d.exists() and not d.is_dir()):
            err.append(f"{d} existe mais n'est pas un dossier")
        elif not d.exists() and d not in dossiers:
            dossiers.add(d)
            actions.append(("mkdir", d))

    for src in sorted(p for p in (repo / UNITES).rglob("*") if p.is_file()):
        rel = src.relative_to(repo / UNITES)
        dst = home / "systemd" / "user" / rel
        if dst.is_symlink() or (dst.exists() and not _ours(dst, SYSTEM_MARK)):
            err.append(f"{dst} existe mais n'a pas été posé par DuneI")
        elif not dst.exists() or dst.read_bytes() != src.read_bytes():
            dossier(dst.parent)
            actions.append(("copy", src, dst))
            changes.add(rel.parts[0].removesuffix(".d"))
    masque = home / MASQUE
    if masque.is_symlink() or masque.exists():
        if not _links_to(masque, Path("/dev/null")):
            err.append(f"{masque} existe mais ne masque pas l'autostart XDG")
    else:
        dossier(masque.parent)
        actions.append(("link", Path("/dev/null"), masque))
        changes.add(masque.name)
    if changes:
        actions.append(("daemon-reload",))

    idle_src, idle_dst = repo / "generated" / IDLE[0], home / "hypr" / IDLE[0]
    if idle_src.exists() and (not idle_dst.exists() or idle_dst.read_bytes() != idle_src.read_bytes()):
        changes.add(SERVICE)
    for s in services:
        state, active = _etat(s)
        if state not in ("enabled", "disabled") and not (repo / UNITES / s).exists():
            err.append(f"{s} introuvable ({state or 'systemctl sans réponse'}) : installer le paquet qui le "
                       "fournit, ou écrire son unité dans config/systemd/user/")
        elif state != "enabled":
            actions.append(("enable", s))
        elif s in changes:
            actions.append(("restart", s))
        elif not active:
            actions.append(("start", s))
    wants = home / SESSION_WANTS
    if wants.is_dir():
        actions += [("hors-liste", p.name) for p in sorted(wants.iterdir()) if p.name not in services]
    return actions, err


DESTINATIONS = {"hypr": plan_hypr, "fontconfig": plan_fontconfig,
                "services": plan_services, "systeme": plan_systeme, "connexion": plan_connexion}  # Nom → planification, dans l'ordre d'exécution (sudo en dernier).


def plan(repo: Path, home: Path) -> tuple[list[tuple], list[str]]:
    """Inspection de toutes les destinations, sans aucune modification.

    Entrées : repo — racine du dépôt ; home — dossier de configuration racine.
    Sortie : (actions de toutes les destinations, dans l'ordre de DESTINATIONS ; erreurs).
             Une seule erreur suffit à tout refuser.
    Erreurs : aucune exception ; chaque problème devient un message. Dépendances : DESTINATIONS.
    """
    if os.getuid() == 0:
        return [], ["make install ne se lance pas en root : les fichiers système nommeraient root, et les "
                    "fichiers utilisateur iraient dans /root"]
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
        "sudo-copy": "copier {0} vers {1}, avec sudo",
        "sudo-reload": "recharger {0}, avec sudo",
        "sudo-daemon-reload": "recharger les unités système de systemd, avec sudo",
        "sudo-dm": "remplacer le gestionnaire de connexion {0} par {1} au prochain démarrage, avec sudo",
        "daemon-reload": "recharger les unités utilisateur de systemd",
        "start": "démarrer {0}",
        "enable": "activer et démarrer {0}",
        "restart": "redémarrer {0}",
        "hors-liste": "{0} est accroché à la session sans figurer dans session.toml ; laissé en place",
    }[kind].format(*args)


def apply(actions: list[tuple]) -> None:
    """Exécution des actions, dans l'ordre fourni par plan.

    Les copies passent par un fichier temporaire renommé par os.replace ; la bascule donne un
    second nom au fichier générique (os.link), puis remplace hyprland.lua par un lien temporaire
    renommé par os.replace. hyprland.lua existe ainsi à chaque instant. Les actions système passent par
    sudo, les services par systemctl --user.
    Entrée : actions — liste produite par plan, sans erreur.
    Sortie : aucune. Erreurs : OSError si le système de fichiers refuse une opération ou si une commande
             est absente ; subprocess.CalledProcessError si une commande échoue.
    Dépendances : os, subprocess, tempfile, TEMP.
    """
    for kind, *args in actions:
        if kind == "mkdir":
            args[0].mkdir(parents=True, exist_ok=True)
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
        elif kind == "sudo-copy":
            with tempfile.NamedTemporaryFile(prefix="dunei-") as tmp:
                tmp.write(args[2])
                tmp.flush()
                subprocess.run(["sudo", "install", "-D", "-m", "644", tmp.name, str(args[1])], check=True)
        elif kind == "sudo-daemon-reload":
            subprocess.run(["sudo", "systemctl", "daemon-reload"], check=True)
        elif kind == "sudo-dm":
            if args[0] != "aucun":
                subprocess.run(["sudo", "systemctl", "disable", args[0]], check=True)
            subprocess.run(["sudo", "systemctl", "enable", args[1]], check=True)
        elif kind == "sudo-reload":
            subprocess.run(["sudo", "systemctl", "reload", args[0]], check=True)
        elif kind == "enable":
            subprocess.run(["systemctl", "--user", "enable", "--now", args[0]], check=True)
        elif kind in ("restart", "start"):
            subprocess.run(["systemctl", "--user", kind, args[0]], check=True)
        elif kind == "daemon-reload":
            subprocess.run(["systemctl", "--user", "daemon-reload"], check=True)


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
        except (OSError, subprocess.CalledProcessError) as e:
            print(f"déploiement interrompu : {e}", file=sys.stderr)
            if isinstance(e, subprocess.CalledProcessError) and e.cmd[0] == "sudo":
                print("La configuration utilisateur est installée ; seuls les fichiers système restent à poser : "
                      "relancer make install dans un terminal.", file=sys.stderr)
            return 1
    notes = [a for a in actions if a[0] == "hors-liste"]
    actions = [a for a in actions if a[0] != "hors-liste"]
    for a in actions:
        print(f"  {'prévu' if args.dry_run else 'fait'} : {describe(a)}")
    print(f"\n{home} : {len(actions)} action(s) {'prévue(s)' if args.dry_run else 'effectuée(s)'}.")
    for a in notes:
        print(f"  attention : {describe(a)}")
    if any(a[0] == "switch" for a in actions):
        # Hyprland surveille le fichier générique lui-même, qui survit sous un autre nom : la bascule
        # ne déclenche donc pas le rechargement automatique. Les passages suivants le déclenchent.
        print("Première bascule : lancer hyprctl reload une fois pour charger le point d'entrée DuneI.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
