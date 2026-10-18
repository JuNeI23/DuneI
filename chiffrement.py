#!/usr/bin/env python3
"""Chiffrement — fait passer la racine LUKS2 de la phrase d'archinstall à TPM2 + PIN et clé de secours.

Ce module lit l'état ; les actions et la commande viennent ensuite (L1-25, spec § 5.3).

- voies : les voies d'accès d'une racine LUKS2, lues dans ses métadonnées JSON (phrase, secours, puce).
- ligne : la ligne de commande du noyau passée à l'amorçage systemd (rd.luks.name).
- contrôles : refus avant d'agir (LUKS2, puce, tpm2-tss, KEYMAP, fichiers qui lieraient la puce à un état).
- étape : la prochaine étape, déduite de l'état seul, sans mémoire ailleurs que la marque de démarrage.

Aucune fonction n'écrit ni n'appelle cryptsetup : tout est pur ou lit sous une racine.
"""

from __future__ import annotations

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
