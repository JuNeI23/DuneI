#!/usr/bin/env python3
"""Chiffrement — fait passer la racine LUKS2 de la phrase d'archinstall à TPM2 + PIN et clé de secours.

Une étape par passage (L1-25, spec § 5.3 et § 5.4) ; aucune voie d'accès n'est retirée avant que les
suivantes soient prouvées.

- voies : les voies d'accès d'une racine LUKS2, lues dans ses métadonnées JSON (phrase, secours, puce).
- ligne : la ligne de commande du noyau passée à l'amorçage systemd (rd.luks.name).
- contrôles : refus avant d'agir (LUKS2, puce, tpm2-tss, KEYMAP, fichiers qui lieraient la puce à un état).
- étape : la prochaine étape, déduite de l'état seul, sans mémoire ailleurs que la marque de démarrage.
- lecture : lire_etat interroge le système par lire (sortie capturée, jamais de secret).
- actions : amorçage systemd, clé de secours, puce + phrase, retrait de la phrase d'origine, changement de
  phrase ; toute commande qui écrit, demande ou affiche une clé passe par lancer (terminal hérité).

    python3 chiffrement.py [--etat | --phrase]
"""

from __future__ import annotations

import argparse
import json
import os
import signal
import subprocess
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path

JETON_SECOURS = "systemd-recovery"       # Type du jeton d'une clé de secours (systemd-cryptenroll --recovery-key).
JETON_PUCE = "systemd-tpm2"              # Type du jeton d'une puce TPM2.
RETIRES = ("cryptdevice=", "root=", "rd.luks.")   # Préfixes remplacés dans la ligne de commande du noyau.
TSS = "usr/lib/libtss2-esys.so*"         # Bibliothèque de tpm2-tss, sous la racine.
INTERDITS = (                            # Fichiers qui lieraient la puce à un état d'amorçage, sous la racine.
    "var/lib/systemd/pcrlock.json", "run/systemd/pcrlock.json",
    "etc/systemd/tpm2-pcr-public-key.pem", "run/systemd/tpm2-pcr-public-key.pem",
    "usr/lib/systemd/tpm2-pcr-public-key.pem",
)
MARQUE = Path("/var/lib/dunei/chiffrement-puce")      # boot_id noté juste avant l'inscription de la puce.
FRAGMENT = Path("/etc/mkinitcpio.conf.d/10-dunei-chiffrement.conf")   # Étapes de l'initramfs, posées par l'amorçage.
SOURCE = Path(__file__).resolve().parent / "chiffrement" / FRAGMENT.name  # Le fragment, dans le dépôt.
CMDLINE = Path("/etc/kernel/cmdline")                 # Ligne de commande du noyau des images unifiées.
AVANT = Path("/etc/kernel/cmdline.avant-dunei")       # Ligne d'origine, gardée jusqu'au retrait de la phrase.
PRESET = Path("/etc/mkinitcpio.d/linux.preset")       # Preset du noyau linux, qui nomme son image unifiée.
PUCE = ("--tpm2-device=auto", "--tpm2-with-pin=yes", "--tpm2-pcrs=", "--tpm2-pcrlock=")  # Puce + phrase, sans état.
MESSAGES = {                                          # Étapes qui n'attendent qu'un redémarrage ou rien.
    "redemarrer-amorcage": "L'amorçage systemd n'a pas encore servi : redémarre en laissant l'entrée par défaut "
                           "du menu, puis relance make chiffrement.",
    "redemarrer-puce": "La puce est inscrite. Redémarre ; la puce et ta phrase doivent ouvrir le disque. "
                       "Puis relance make chiffrement.",
    "termine": "Chiffrement terminé : la puce avec ta phrase, ou la clé de secours, ouvrent le disque. "
               "Pour changer ta phrase : make phrase.",
}


@dataclass(frozen=True)
class Voies:
    """Voies d'accès d'une racine LUKS2.

    phrases — emplacements de clé qu'aucun jeton ne référence ; secours — emplacements du jeton
    systemd-recovery ; puces — (id du jeton systemd-tpm2, emplacement) ; puce_conforme — chaque jeton
    tpm2 a tpm2-pin vrai, tpm2-pcrs vide, ni pcrlock ni clé publique (vrai sans jeton tpm2).
    """

    phrases: tuple[int, ...]
    secours: tuple[int, ...]
    puces: tuple[tuple[int, int], ...]
    puce_conforme: bool


@dataclass(frozen=True)
class Etat:
    """État du système, lu par lire_etat.

    periph — périphérique LUKS sous la racine, ou None ; nom — volume ouvert (/dev/mapper/<nom>), ou None ;
    luks2 — None si la racine n'est pas LUKS, False si LUKS1, True si LUKS2 ; meta — métadonnées JSON
    (vide hors LUKS2) ; puce — puce TPM2 version 2 ; keymap — KEYMAP de /etc/vconsole.conf, vide si absent ;
    fragment — le fragment mkinitcpio est posé et /etc/kernel/cmdline porte rd.luks.name (un amorçage
    interrompu ou à moitié rétabli est ainsi refait, jamais pris pour posé) ; cmdline — /proc/cmdline ;
    boot — boot_id en cours ; marque — boot_id noté dans MARQUE, ou None.
    """

    periph: str | None
    nom: str | None
    luks2: bool | None
    meta: dict
    puce: bool
    keymap: str
    fragment: bool
    cmdline: str
    boot: str
    marque: str | None


def system_root(env: dict[str, str]) -> Path:
    """Racine du système.

    Entrée : env — environnement, os.environ en usage normal.
    Sortie : $DUNEI_SYSROOT, réservé aux tests, ou / si la variable est absente ou vide.
    Erreurs : aucune. Dépendances : aucune.
    """
    return Path(env.get("DUNEI_SYSROOT") or "/")


def voies(meta: dict) -> Voies:
    """Voies d'accès d'une racine LUKS2.

    Entrée : meta — métadonnées de `cryptsetup luksDump --dump-json-metadata` (clés « keyslots » et « tokens »).
    Sortie : Voies, emplacements et identifiants de jeton en entiers, triés.
    Erreurs : aucune exception propre ; KeyError si « keyslots » manque. Dépendances : JETON_SECOURS, JETON_PUCE.
    """
    jetons = meta.get("tokens", {})
    liés = {int(s) for j in jetons.values() for s in j.get("keyslots", [])}
    par = lambda type_: sorted((int(i), int(s)) for i, j in jetons.items() if j.get("type") == type_
                               for s in j.get("keyslots", []))
    puces = par(JETON_PUCE)
    conforme = all(j.get("tpm2-pin") is True and not j.get("tpm2-pcrs") and not j.get("tpm2_pcrlock")
                   and not j.get("tpm2_pubkey_pcrs") and not j.get("tpm2_pubkey")
                   for j in jetons.values() if j.get("type") == JETON_PUCE)
    return Voies(tuple(sorted(int(k) for k in meta["keyslots"] if int(k) not in liés)),
                 tuple(s for _, s in par(JETON_SECOURS)), tuple(puces), conforme)


def nouvelle_ligne(ligne: str, uuid: str, nom: str) -> str:
    """Ligne de commande du noyau pour l'amorçage systemd (rd.luks.name).

    Entrée : ligne — ligne actuelle ; uuid — UUID du conteneur LUKS ; nom — nom du volume ouvert.
    Sortie : la ligne sans cryptdevice=, root= ni rd.luks.*, les autres éléments dans l'ordre, puis
             rd.luks.name, rd.luks.options et root. Idempotente.
    Erreurs : aucune. Dépendances : RETIRES.
    """
    gardés = [t for t in ligne.split() if not t.startswith(RETIRES)]
    return " ".join(gardés + [f"rd.luks.name={uuid}={nom}", f"rd.luks.options={uuid}=tpm2-device=auto,discard",
                              f"root=/dev/mapper/{nom}"])


def controles(racine: Path, luks2: bool | None, puce: bool, keymap: bool) -> list[str]:
    """Refus avant d'agir.

    Entrée : racine — racine du système ; luks2 — None si la racine n'est pas LUKS, False si LUKS1, True si
             LUKS2 ; puce — une puce TPM2 est présente ; keymap — /etc/vconsole.conf définit KEYMAP.
    Sortie : une erreur par problème, liste vide si tout va bien.
    Erreurs : aucune exception. Dépendances : TSS, INTERDITS.
    """
    err = []
    if luks2 is None:
        err.append("la racine n'est pas chiffrée par LUKS")
    elif not luks2:
        err.append("la racine est en LUKS1 : LUKS2 est requis")
    if not puce:
        err.append("aucune puce TPM2 détectée")
    if not any(racine.glob(TSS)):
        err.append("tpm2-tss absent : sudo pacman -S --needed tpm2-tss")
    if not keymap:
        err.append("KEYMAP absent de /etc/vconsole.conf : le PIN serait saisi dans une disposition inconnue")
    err += [f"{racine / f} existe : la puce serait liée à un état d'amorçage" for f in INTERDITS
            if (racine / f).exists()]
    return err


def etape(v: Voies, fragment: bool, cmdline: str, boot: str, marque: str | None) -> str:
    """Prochaine étape, déduite de l'état.

    Entrée : v — voies d'accès ; fragment — le fragment mkinitcpio/amorçage est posé ; cmdline — contenu de
             /proc/cmdline ; boot — identifiant du démarrage en cours ; marque — identifiant noté à l'inscription
             de la puce, ou None.
    Sortie : amorcage, redemarrer-amorcage, secours, verifier-secours, redemarrer-puce, retirer-phrase,
             termine ou incoherent. « puce » n'est jamais rendue : la commande inscrit la puce dans le même
             passage, juste après un « verifier-secours » réussi, donc la clé de secours est toujours retapée avant.
             Puce présente sans marque tant qu'une phrase reste : incoherent.
    Erreurs : aucune exception. Dépendances : aucune.
    """
    if len(v.puces) > 1 or (v.puces and not v.puce_conforme) or not (v.phrases or v.secours or v.puces):
        return "incoherent"
    if not fragment:
        return "incoherent" if v.puces else "amorcage"
    if not any(t.startswith("rd.luks.name=") for t in cmdline.split()):
        return "redemarrer-amorcage"
    if not v.secours:
        return "secours"
    if not v.puces:
        return "verifier-secours"
    if marque == boot:
        return "redemarrer-puce"
    if not v.phrases:
        return "termine"
    return "retirer-phrase" if marque else "incoherent"   # Sans marque, la preuve du second redémarrage manque.


def lancer(cmd: list[str]) -> int:
    """Lance une commande sur le terminal, seul point d'appel des commandes qui agissent.

    Entrée : cmd — commande et arguments. Sortie : son code de sortie, 127 si elle est introuvable.
    Erreurs : aucune exception ; message sur la sortie d'erreur si la commande est introuvable.
    Dépendances : subprocess, signal. Rien n'est capturé : invites, phrases et clé de secours restent au
    terminal. Pendant la commande, Ctrl-C ne vise qu'elle : le gestionnaire vide du parent (remis à défaut
    dans l'enfant à l'exec, contrairement à SIG_IGN) évite que Python tue sudo en pleine écriture.
    """
    avant = signal.signal(signal.SIGINT, lambda *_: None)
    try:
        return subprocess.run(cmd).returncode
    except OSError as e:
        print(f"erreur : {cmd[0]} introuvable ({e})", file=sys.stderr)
        return 127
    finally:
        signal.signal(signal.SIGINT, avant)


def lire(cmd: list[str]) -> subprocess.CompletedProcess:
    """Lance une commande de lecture et capture sa sortie, jamais pour une commande qui porte un secret.

    Entrée : cmd — commande et arguments (findmnt, cryptsetup status, isLuks, luksUUID, luksDump).
    Sortie : le résultat, sortie standard en texte ; code 127 si la commande est introuvable.
    Erreurs : aucune exception. Dépendances : subprocess.
    """
    try:
        return subprocess.run(cmd, capture_output=True, text=True)
    except OSError as e:
        return subprocess.CompletedProcess(cmd, 127, "", str(e))


def sous(racine: Path, chemin: Path) -> Path:
    """Chemin système absolu ramené sous la racine. Entrée : racine, chemin absolu. Sortie : le chemin.
    Erreurs : ValueError si chemin est relatif. Dépendances : aucune."""
    return racine / chemin.relative_to("/")


def texte(chemin: Path) -> str:
    """Contenu d'un fichier, vide s'il est absent ou illisible. Entrée : chemin. Sortie : le texte.
    Erreurs : aucune. Dépendances : aucune."""
    try:
        return chemin.read_text()
    except (OSError, UnicodeDecodeError):
        return ""


def image(racine: Path) -> Path | None:
    """Image unifiée du noyau linux.

    Entrée : racine. Sortie : chemin sous la racine de default_uki= dans PRESET (guillemets ôtés), ou None.
    Erreurs : aucune. Dépendances : PRESET, sous, texte.
    """
    val = next((l.split("=", 1)[1].strip().strip("'\"") for l in texte(sous(racine, PRESET)).splitlines()
                if l.startswith("default_uki=")), "")
    return sous(racine, Path(val)) if val.startswith("/") else None


def de_secours(uki: Path) -> Path:
    """Copie d'origine de l'image unifiée, à côté d'elle : <nom>-avant-dunei.efi, au menu de systemd-boot.
    Entrée : uki. Sortie : le chemin de la copie. Erreurs : aucune. Dépendances : aucune."""
    return uki.with_name(f"{uki.stem}-avant-dunei.efi")


def lire_etat(racine: Path) -> Etat:
    """État du système, seule fonction qui l'interroge.

    Entrée : racine — racine du système (fichiers lus dessous ; les commandes visent le système en cours).
    Sortie : Etat. La racine montée est lue par findmnt ; si c'est /dev/mapper/<nom>, son périphérique par
             sudo cryptsetup status, LUKS par isLuks (puis --type luks2), les métadonnées par luksDump.
    Erreurs : RuntimeError si cryptsetup status ou luksDump échouent. Dépendances : lire, sous, texte, MARQUE,
              FRAGMENT, sudo, findmnt, cryptsetup.
    """
    source = lire(["findmnt", "-no", "SOURCE", "/"]).stdout.strip().split("[")[0]   # [/@] : sous-volume btrfs.
    nom = source.removeprefix("/dev/mapper/") if source.startswith("/dev/mapper/") else None
    periph, luks2, meta = None, None, {}
    if nom:
        r = lire(["sudo", "cryptsetup", "status", nom])
        if r.returncode:
            raise RuntimeError(f"sudo cryptsetup status {nom} a échoué (code {r.returncode}) : {r.stderr.strip()}")
        periph = next((l.split(":", 1)[1].strip() for l in r.stdout.splitlines()
                       if l.strip().startswith("device:")), None)
    if periph and not lire(["sudo", "cryptsetup", "isLuks", periph]).returncode:
        luks2 = not lire(["sudo", "cryptsetup", "isLuks", "--type", "luks2", periph]).returncode
    if luks2:
        r = lire(["sudo", "cryptsetup", "luksDump", "--dump-json-metadata", periph])
        if r.returncode:
            raise RuntimeError(f"sudo cryptsetup luksDump {periph} a échoué (code {r.returncode}) : "
                               f"{r.stderr.strip()}")
        meta = json.loads(r.stdout)
    keymap = next((l.split("=", 1)[1].strip().strip('"') for l in texte(racine / "etc/vconsole.conf").splitlines()
                   if l.startswith("KEYMAP=")), "")
    return Etat(periph, nom, luks2, meta,
                texte(racine / "sys/class/tpm/tpm0/tpm_version_major").strip() == "2", keymap,
                sous(racine, FRAGMENT).exists() and "rd.luks.name=" in texte(sous(racine, CMDLINE)),
                texte(racine / "proc/cmdline"),
                texte(racine / "proc/sys/kernel/random/boot_id").strip(),
                texte(sous(racine, MARQUE)).strip() or None)


def demander(question: str) -> bool:
    """Question oui/non, « non » par défaut.

    Entrée : question — texte affiché, terminé par « [o/N] ».
    Sortie : True seulement si l'entrée standard est un terminal et que la réponse, blancs et casse ignorés,
             est « o » ou « oui ». Erreurs : fin de fichier vaut « non ». Dépendances : sys.stdin, input.
    """
    if not sys.stdin.isatty():
        return False
    try:
        return input(question).strip().lower() in ("o", "oui")
    except EOFError:
        return False


def poser(contenu: str, cible: Path) -> int:
    """Écrit un fichier système par sudo install, sans écriture Python en root.

    Entrée : contenu — texte sans secret ; cible — chemin du fichier (dossiers créés au besoin).
    Sortie : code de sudo install (0 si réussi). Erreurs : aucune exception. Dépendances : lancer, tempfile.
    """
    with tempfile.TemporaryDirectory() as d:
        src = Path(d) / cible.name
        src.write_text(contenu)
        return lancer(["sudo", "install", "-D", "-m", "644", str(src), str(cible)])


def afficher(e: Etat, v: Voies, et: str) -> None:
    """Affiche les voies d'accès et l'étape. Entrées : e, v, et — état, voies, étape. Sortie : aucune.
    Erreurs : aucune. Dépendances : print."""
    nums = lambda t: ", ".join(map(str, t)) or "aucun"
    print(f"disque : {e.periph} (volume {e.nom})\nphrase d'origine : emplacement(s) {nums(v.phrases)}\n"
          f"clé de secours : emplacement(s) {nums(v.secours)}\n"
          f"puce : {', '.join(f'jeton {j}, emplacement {s}' for j, s in v.puces) or 'aucune'}"
          f"{'' if v.puce_conforme else ' (NON conforme : liée à un état ou sans phrase)'}\nétape : {et}")


def amorcage(racine: Path, e: Etat, v: Voies) -> int:
    """Étape 1 : passe l'initramfs et la ligne de commande du noyau à l'amorçage systemd.

    Entrées : racine, e, v — racine, état, voies (v inutilisé, signature commune des étapes).
    Sortie : 0 si posé ou refusé par l'utilisateur ; 1 ou le code d'une copie en échec sinon. Garde la ligne
             d'origine (AVANT) et l'image unifiée d'origine (de_secours, entrée de secours au menu), une seule
             fois ; pose le fragment et la nouvelle ligne ; sudo mkinitcpio -P. En cas d'échec ou
             d'interruption (Ctrl-C, relancé ensuite), retire le fragment, rétablit la ligne et relance
             mkinitcpio -P.
    Erreurs : messages sur la sortie d'erreur. Dépendances : image, de_secours, nouvelle_ligne, lire, lancer,
              poser, demander, SOURCE, FRAGMENT, CMDLINE, AVANT.
    """
    uki, cmdline, avant, fragment = image(racine), sous(racine, CMDLINE), sous(racine, AVANT), sous(racine, FRAGMENT)
    ligne = texte(cmdline)
    uuid = lire(["sudo", "cryptsetup", "luksUUID", e.periph]).stdout.strip()
    if not (uki and ligne.strip() and uuid):
        print(f"erreur : image unifiée (default_uki= de {PRESET}), {CMDLINE} ou UUID LUKS introuvable : "
              "voir la section chiffrement du carnet. Rien n'a été modifié.", file=sys.stderr)
        return 1
    print(f"Amorçage systemd : étapes de l'initramfs, ligne de commande du noyau, image refaite. L'image actuelle "
          f"reste au menu de démarrage sous « {de_secours(uki).stem} ».")
    if not demander("Poser l'amorçage systemd ? [o/N] "):
        print("Rien n'a été modifié.")
        return 0
    if not avant.exists():   # Une seule fois : un second passage ne doit pas écraser l'origine.
        for src, dst in ((uki, de_secours(uki)), (cmdline, avant)):
            if code := lancer(["sudo", "cp", "-p", str(src), str(dst)]):
                return code

    def retour() -> None:
        """Rétablit l'état d'avant : fragment retiré, ligne d'origine, image refaite ; les trois sont tentés."""
        print("erreur : l'amorçage systemd n'a pas été posé ; retour à l'état d'avant.", file=sys.stderr)
        retours = (["sudo", "rm", "-f", str(fragment)], ["sudo", "cp", "-p", str(avant), str(cmdline)],
                   ["sudo", "mkinitcpio", "-P"])
        if any([lancer(c) for c in retours]):   # Liste, non générateur : les trois retours sont tentés.
            print(f"attention : le retour n'a pas abouti ; relance make chiffrement, et au redémarrage choisis "
                  f"« {de_secours(uki).stem} » au menu si l'entrée par défaut ne démarre pas.", file=sys.stderr)

    try:
        echec = (lancer(["sudo", "install", "-D", "-m", "644", str(SOURCE), str(fragment)])
                 or poser(nouvelle_ligne(ligne, uuid, e.nom) + "\n", cmdline) or lancer(["sudo", "mkinitcpio", "-P"]))
    except BaseException:
        retour()
        raise
    if echec:
        retour()
        return 1
    print(f"Amorçage systemd posé. Redémarre ; ta phrase est demandée en disposition {e.keymap}. "
          "Puis relance make chiffrement.")
    return 0


def secours(racine: Path, e: Etat, v: Voies) -> int:
    """Étape 3 : inscrit une clé de secours, puis la fait retaper (verifier_secours).

    Entrées : racine, e, v. Sortie : 0 si refusé ou si la suite réussit ; code de l'échec sinon.
             Sans phrase restante (puce seule), le volume s'ouvre par la puce (--unlock-tpm2-device=auto).
    Erreurs : messages sur la sortie d'erreur. Dépendances : demander, lancer, lire_etat, voies, verifier_secours.
    """
    print("Clé de secours : elle s'affiche une seule fois et n'est écrite nulle part. Range-la dans Bitwarden.")
    if not demander("Bitwarden est-il ouvert pour la ranger ? [o/N] "):
        print("Rien n'a été inscrit.")
        return 0
    if code := lancer(["sudo", "-v"]):   # Le mot de passe de sudo d'abord, jamais entre deux secrets.
        return code
    ouvrir = [] if v.phrases else ["--unlock-tpm2-device=auto"]
    if code := lancer(["sudo", "systemd-cryptenroll", "--recovery-key", *ouvrir, e.periph]):
        print("erreur : la clé de secours n'a pas été inscrite.", file=sys.stderr)
        return code
    e = lire_etat(racine)
    return verifier_secours(racine, e, voies(e.meta))


def verifier_secours(racine: Path, e: Etat, v: Voies) -> int:
    """Étape 3 bis : la clé de secours retapée doit ouvrir le volume ; puis la puce, s'il n'y en a pas.

    Entrées : racine, e, v. Sortie : 0 si vérifiée (et puce réussie) ; 1 si elle n'ouvre pas le volume,
             après avoir proposé de la retirer par son numéro pour en inscrire une autre au passage suivant,
             jamais quand elle est la dernière voie ; code de sudo -v s'il échoue.
    Erreurs : messages sur la sortie d'erreur. Dépendances : lancer, demander, puce.
    """
    if len(v.secours) != 1:
        print("erreur : plusieurs clés de secours ; voir la section chiffrement du carnet.", file=sys.stderr)
        return 1
    if code := lancer(["sudo", "-v"]):
        return code
    print("Retape la clé de secours rangée dans Bitwarden.")
    if lancer(["sudo", "cryptsetup", "open", "--test-passphrase", "--key-slot", str(v.secours[0]), e.periph]):
        print("Cette clé n'ouvre pas le disque.", file=sys.stderr)
        if not (v.phrases or v.puces):
            print("C'est la seule voie d'accès : elle reste. Voir la section chiffrement du carnet.", file=sys.stderr)
        elif demander("Retirer cette clé de secours pour en inscrire une nouvelle ? [o/N] "):
            if lancer(["sudo", "systemd-cryptenroll", f"--wipe-slot={v.secours[0]}", e.periph]):
                print("erreur : la clé de secours n'a pas été retirée.", file=sys.stderr)
            else:
                print("Clé retirée. Relance make chiffrement pour en inscrire une nouvelle.")
        return 1
    print("Clé de secours vérifiée.")
    return 0 if v.puces else puce(racine, e)


def verifier_puce(periph: str, jeton: int) -> bool:
    """La puce et sa phrase ouvrent-elles le volume, sans redémarrer ?

    Entrées : periph — périphérique LUKS ; jeton — id du jeton systemd-tpm2 à éprouver.
    Sortie : True si cryptsetup ouvre le volume en test par ce seul jeton (il demande la phrase) ; False
             aussi si sudo -v échoue.
    Erreurs : aucune exception. Dépendances : lancer, cryptsetup et son greffon systemd-tpm2.
    """
    if lancer(["sudo", "-v"]):
        return False
    print("Vérification : tape ta phrase de démarrage.")
    return not lancer(["sudo", "cryptsetup", "open", "--test-passphrase", "--token-only", "--token-id", str(jeton),
                       periph])


def puce(racine: Path, e: Etat) -> int:
    """Étape 4 : inscrit puce + phrase, liée à aucun état d'amorçage.

    Entrées : racine, e. Sortie : 0 si inscrite ; code de l'échec sinon. MARQUE reçoit le boot_id AVANT
             l'inscription : une puce sans marque reste ainsi « incoherent », jamais prise pour redémarrée.
    Erreurs : messages sur la sortie d'erreur. Dépendances : poser, lancer, lire_etat, voies, verifier_puce, PUCE.
    """
    if code := poser(e.boot + "\n", sous(racine, MARQUE)) or lancer(["sudo", "-v"]):
        return code
    print(f"Puce : ouvre avec ta phrase actuelle, puis choisis la phrase de chaque démarrage "
          f"(tapée en disposition {e.keymap}).")
    if code := lancer(["sudo", "systemd-cryptenroll", *PUCE, e.periph]):
        print("erreur : la puce n'a pas été inscrite ; ta phrase d'origine reste en place.", file=sys.stderr)
        return code
    puces = voies(lire_etat(racine).meta).puces
    if len(puces) != 1:
        print("erreur : puce introuvable après l'inscription ; voir la section chiffrement du carnet.", file=sys.stderr)
        return 1
    # Vérification sans redémarrage par le seul jeton : la tâche 5 confirme en machine virtuelle que cryptsetup
    # l'accepte. Un échec ne retire rien : la phrase d'origine reste, le redémarrage fera foi.
    if verifier_puce(e.periph, puces[0][0]):
        print("La puce et ta phrase ouvrent le disque.")
    else:
        print("La vérification sans redémarrage n'a pas abouti : le redémarrage fera foi, ta phrase d'origine "
              "reste en place.")
    print(MESSAGES["redemarrer-puce"])
    return 0


def retirer_phrase(racine: Path, e: Etat, v: Voies) -> int:
    """Étape 6 : retire la phrase d'origine après un démarrage par la puce, puis ce qui gardait l'origine.

    Entrées : racine, e, v. Sortie : 0 si retirée ou si l'utilisateur répond non ; 1 si la puce ne
             s'éprouve pas sans redémarrer (rien n'est retiré) ; code de l'échec sinon. Retire les
             emplacements de v.phrases par leurs numéros, puis MARQUE, AVANT et l'image de secours.
    Erreurs : messages sur la sortie d'erreur. Dépendances : demander, verifier_puce, lancer, image, de_secours.
    """
    # Phrase de puce et phrase d'origine sont la même chaîne : seule l'invite vue au démarrage distingue
    # l'ouverture par la puce d'un repli sur la phrase d'origine (invites à confirmer en machine virtuelle).
    print("Il resterait deux voies : la puce avec ta phrase, et la clé de secours. Au démarrage, la puce "
          "demande « Please enter TPM2 PIN » ; « Please enter passphrase for disk … » est la phrase d'origine.")
    if not demander("Au dernier démarrage, l'invite était-elle celle de la puce (TPM2 PIN) ? [o/N] "):
        print("Rien n'a été retiré. Si la puce n'a pas ouvert le disque, voir la section chiffrement du carnet.")
        return 0
    if not verifier_puce(e.periph, v.puces[0][0]):
        print("erreur : la puce et ta phrase n'ont pas ouvert le disque ; l'ouverture par la puce n'est pas "
              "confirmée, la phrase d'origine reste. Voir la section chiffrement du carnet.", file=sys.stderr)
        return 1
    if code := lancer(["sudo", "systemd-cryptenroll", f"--wipe-slot={','.join(map(str, v.phrases))}", e.periph]):
        print("erreur : la phrase d'origine n'a pas été retirée.", file=sys.stderr)
        return code
    uki = image(racine)
    if lancer(["sudo", "rm", "-f", str(sous(racine, MARQUE)), str(sous(racine, AVANT)),
               *([str(de_secours(uki))] if uki else [])]):
        print(f"attention : {MARQUE}, {AVANT} ou l'image « avant-dunei » restent à retirer.", file=sys.stderr)
    print("Phrase d'origine retirée. " + MESSAGES["termine"])
    return 0


def changer_phrase(racine: Path, e: Etat, v: Voies) -> int:
    """Change la phrase de la puce (§ 5.4) : nouvelle inscription, vérifiée, puis retrait de l'ancienne.

    Entrées : racine, e, v — v avec exactement une puce (chiffrement terminé).
    Sortie : 0 si changée ; 1 si la nouvelle n'est pas vérifiée (elle est retirée, l'ancienne reste) ;
             code de l'échec sinon. Le volume s'ouvre par la puce et l'ancienne phrase, ou, sur demande,
             par la clé de secours.
    Erreurs : messages sur la sortie d'erreur. Dépendances : lancer, demander, lire_etat, voies, verifier_puce, PUCE.
    """
    ancienne = v.puces[0]
    if code := lancer(["sudo", "-v"]):
        return code
    print("Changement de phrase : tape ton ancienne phrase, puis choisis la nouvelle.")
    code = lancer(["sudo", "systemd-cryptenroll", "--unlock-tpm2-device=auto", *PUCE, e.periph])
    if code and demander("Ouvrir plutôt avec la clé de secours ? [o/N] "):
        code = lancer(["sudo", "systemd-cryptenroll", *PUCE, e.periph])
    if code:
        print("erreur : aucune nouvelle phrase inscrite ; l'ancienne reste.", file=sys.stderr)
        return code
    nouvelles = [p for p in voies(lire_etat(racine).meta).puces if p != ancienne]
    if len(nouvelles) != 1:
        print("erreur : nouvelle inscription introuvable ; voir la section chiffrement du carnet.", file=sys.stderr)
        return 1
    jeton, slot = nouvelles[0]
    if not verifier_puce(e.periph, jeton):
        if lancer(["sudo", "systemd-cryptenroll", f"--wipe-slot={slot}", e.periph]):
            print(f"erreur : la nouvelle phrase n'a pas été vérifiée ni retirée (emplacement {slot}) ; l'ancienne "
                  "reste. Voir la section chiffrement du carnet.", file=sys.stderr)
        else:
            print("erreur : la nouvelle phrase n'a pas été vérifiée ; elle est retirée, l'ancienne reste.",
                  file=sys.stderr)
        return 1
    if code := lancer(["sudo", "systemd-cryptenroll", f"--wipe-slot={ancienne[1]}", e.periph]):
        print("erreur : l'ancienne inscription n'a pas été retirée ; voir la section chiffrement du carnet.",
              file=sys.stderr)
        return code
    print("Nouvelle phrase inscrite et vérifiée ; l'ancienne est retirée.")
    return 0


def incoherent(racine: Path, e: Etat, v: Voies) -> int:
    """État que la commande ne sait pas poursuivre : affiche l'état et renvoie au carnet.
    Entrées : racine, e, v. Sortie : 1. Erreurs : aucune. Dépendances : afficher."""
    afficher(e, v, "incoherent")
    print("Rien n'est fait : état inattendu, voir la section chiffrement du carnet.", file=sys.stderr)
    return 1


ACTIONS = {"amorcage": amorcage, "secours": secours, "verifier-secours": verifier_secours,
           "retirer-phrase": retirer_phrase, "incoherent": incoherent}   # Étapes qui agissent.


def main(argv: list[str] | None = None) -> int:
    """Fait l'étape suivante du chiffrement, affiche l'état (--etat) ou change la phrase (--phrase).

    Entrée : argv — arguments, sys.argv[1:] par défaut.
    Sortie : 0 en cas de succès ; 1 en cas de refus (root, entrée ou sorties hors terminal sauf --etat :
             la clé de secours s'affiche sur la sortie, jamais dans un fichier ou un tube ; contrôles, état
             incohérent, --phrase avant la fin) sans rien modifier ; 1 sur métadonnées LUKS inattendues ;
             code de la commande en échec ; 130 sur Ctrl-C.
    Erreurs : messages sur la sortie d'erreur, sans trace Python. Dépendances : system_root, lire_etat,
              controles, voies, etape, afficher, ACTIONS, MESSAGES, changer_phrase.
    """
    ap = argparse.ArgumentParser(description="Chiffrement de la racine : puce + phrase et clé de secours.")
    g = ap.add_mutually_exclusive_group()
    g.add_argument("--etat", action="store_true", help="affiche les voies d'accès et l'étape, sans rien modifier")
    g.add_argument("--phrase", action="store_true", help="change la phrase de la puce, chiffrement terminé")
    args = ap.parse_args(argv)
    if os.geteuid() == 0:
        print("erreur : make chiffrement ne se lance pas en root ; sudo est demandé au besoin.", file=sys.stderr)
        return 1
    if not (args.etat or all(f.isatty() for f in (sys.stdin, sys.stdout, sys.stderr))):
        print("erreur : terminal interactif requis, sans redirection (phrases et clé de secours y passent).",
              file=sys.stderr)
        return 1
    racine = system_root(os.environ)
    try:
        e = lire_etat(racine)
        err = controles(racine, e.luks2, e.puce, bool(e.keymap))
        for x in err:
            print(f"erreur : {x}", file=sys.stderr)
        v = voies(e.meta) if e.luks2 else None
        et = etape(v, e.fragment, e.cmdline, e.boot, e.marque) if v else None
        if args.etat and v:
            afficher(e, v, et)
        if err or args.etat:
            return 1 if err else 0
        if args.phrase:
            if et != "termine" or len(v.puces) != 1:
                print(f"erreur : make phrase n'est permis qu'une fois le chiffrement terminé (étape : {et}).",
                      file=sys.stderr)
                return 1
            return changer_phrase(racine, e, v)
        if et in MESSAGES:
            print(MESSAGES[et])
            return 0
        return ACTIONS[et](racine, e, v)
    except KeyboardInterrupt:
        print("\ninterrompu : relance make chiffrement, l'état du disque dit où reprendre.", file=sys.stderr)
        return 130
    except RuntimeError as x:
        print(f"erreur : {x}", file=sys.stderr)
        return 1
    except (KeyError, ValueError, TypeError) as x:
        print(f"erreur : métadonnées LUKS inattendues ({type(x).__name__} : {x}) ; voir la section chiffrement "
              "du carnet.", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
