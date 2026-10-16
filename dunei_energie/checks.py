"""Contrôles de l'échelle d'inactivité — energie.toml, avant toute génération.

errors travaille sur le TOML brut et ne lève jamais d'exception : chaque défaut devient un message qui
nomme le palier en cause. Une seule erreur bloque la génération. Les types sont vérifiés avant l'ordre.
"""

from __future__ import annotations

VERSION = "0.1.0"
ORDRE = ("attenuation", "verrouillage", "ecran", "veille")   # Ordre imposé des paliers dans le temps.
ALIMENTATIONS = ("batterie", "secteur")
SECTIONS = ("version", "commandes", "attenuation", "paliers")
COMMANDES = ("verrouiller", "verrouilleur")


def _entier(v) -> bool:
    """Entier au sens strict, booléens exclus.

    Entrée : v — valeur quelconque. Sortie : vrai pour un int qui n'est pas un bool.
    Erreurs : aucune. Dépendances : aucune.
    """
    return isinstance(v, int) and not isinstance(v, bool)


def _types(raw: dict) -> list[str]:
    """Contrôle des sections, des clés et des types.

    Entrée : raw — TOML brut. Sortie : liste des erreurs, vide si tout est bien formé.
    Erreurs : aucune exception. Dépendances : SECTIONS, COMMANDES, ORDRE, ALIMENTATIONS, _entier.
    """
    err = [f"section inconnue « {k} »" for k in raw if k not in SECTIONS]
    if raw.get("version") != VERSION:
        err.append(f"version « {raw.get('version')} » : {VERSION} attendue")
    cmd = raw.get("commandes", {})
    cmd = cmd if isinstance(cmd, dict) else {}
    err += [f"commandes : « {k} » manquante ou vide" for k in COMMANDES
            if not (isinstance(cmd.get(k), str) and cmd[k].strip())]
    err += [f"commandes : clé inconnue « {k} »" for k in cmd if k not in COMMANDES]
    att = raw.get("attenuation", {})
    niveau = att.get("niveau") if isinstance(att, dict) else None
    if not (_entier(niveau) and 1 <= niveau <= 100):
        err.append(f"attenuation : niveau « {niveau} » hors de 1 à 100")
    paliers = raw.get("paliers", {})
    if not isinstance(paliers, dict):
        return err + ["paliers : table attendue"]
    err += [f"palier inconnu « {k} »" for k in paliers if k not in ORDRE]
    for nom in ORDRE:
        table = paliers.get(nom, {})
        if not isinstance(table, dict):
            err.append(f"palier {nom} : table attendue")
            continue
        for a, d in table.items():
            if a not in ALIMENTATIONS:
                err.append(f"palier {nom} : alimentation inconnue « {a} »")
            elif not (_entier(d) and d > 0):
                err.append(f"palier {nom}, {a} : délai « {d} » qui n'est pas un entier positif")
    return err


def errors(raw: dict) -> list[str]:
    """Contrôle complet d'une source.

    Entrée : raw — TOML brut. Sortie : liste des erreurs, vide si la source est juste.
             Pour chaque alimentation : un palier présent exige tous ceux qui le précèdent, et son délai
             dépasse strictement celui du palier précédent.
    Erreurs : aucune exception. Dépendances : _types, ORDRE, ALIMENTATIONS.
    """
    if err := _types(raw):
        return err
    for a in ALIMENTATIONS:
        vus = [(n, raw["paliers"].get(n, {}).get(a)) for n in ORDRE]
        for i, (nom, d) in enumerate(vus):
            if d is None:
                continue
            err += [f"palier {nom}, {a} : exige le palier {n}" for n, x in vus[:i] if x is None]
            avant = [(n, x) for n, x in vus[:i] if x is not None]
            if avant and d <= avant[-1][1]:
                err.append(f"palier {nom}, {a} : {d} s ne suit pas le palier {avant[-1][0]} ({avant[-1][1]} s)")
    return err
