"""Cible hypridle 0.1.8 — l'échelle d'inactivité en hyprlang.

Chaque palier est écrit une fois par alimentation, conditionné par dunei-sur-batterie et retenté toutes
les 5 s : débrancher pendant l'inactivité applique l'échelle de la batterie au retry suivant. Les chaînes
dpms sont exactes, car Hyprland 0.56.2 fait basculer l'écran sur toute valeur inconnue.
"""

from __future__ import annotations

SCRIPTS = '"${XDG_CONFIG_HOME:-$HOME/.config}/hypr/scripts'   # Guillemet fermé après le nom du script.
ALLUMER = "hyprctl dispatch 'hl.dsp.dpms({ action = \"on\" })'"
ETEINDRE = "hyprctl dispatch 'hl.dsp.dpms({ action = \"off\" })'"
CONDITIONS = {"batterie": f'{SCRIPTS}/dunei-sur-batterie"', "secteur": f'! {SCRIPTS}/dunei-sur-batterie"'}
NOMS = {"attenuation": "écran atténué, clavier éteint", "verrouillage": "verrouillage",
        "ecran": "écran éteint", "veille": "mise en veille"}


def actions(model: dict) -> dict:
    """Commandes de chaque palier.

    Entrée : model — sortie de dunei_energie.model.resolve.
    Sortie : palier → (commande à l'échéance, commande au retour ou None).
    Erreurs : KeyError si model est incomplet. Dépendances : SCRIPTS, ALLUMER, ETEINDRE.
    """
    return {"attenuation": (f'{SCRIPTS}/dunei-attenuer" {model["niveau"]}', f'{SCRIPTS}/dunei-attenuer" --restaurer'),
            "verrouillage": (model["verrouiller"], None),
            "ecran": (ETEINDRE, ALLUMER),
            "veille": ("systemctl suspend", None)}


def emit(model: dict) -> str:
    """Texte complet de hypridle.conf.

    Entrée : model — sortie de dunei_energie.model.resolve.
    Sortie : section general, puis un listener par palier et par alimentation, batterie d'abord.
    Erreurs : KeyError si model est incomplet. Dépendances : actions, CONDITIONS, NOMS, ALLUMER.
    """
    act = actions(model)
    out = ["# hypridle.conf — échelle d'inactivité de DuneI (L1-09).",
           "# GÉNÉRÉ depuis energie.toml par generate_energie.py — NE PAS MODIFIER À LA MAIN",
           "", "general {",
           f"    lock_cmd = {model['verrouilleur']}",
           f"    before_sleep_cmd = {model['verrouiller']}",
           f"    after_sleep_cmd = {ALLUMER}",
           "    inhibit_sleep = 3",
           "    ignore_dbus_inhibit = false",
           "    ignore_systemd_inhibit = false",
           "    ignore_wayland_inhibit = false",
           "}"]
    for alim, paliers in model["paliers"].items():
        for nom, delai in paliers:
            fin, retour = act[nom]
            out += ["", f"# {alim.capitalize()} : {NOMS[nom]} à {delai} s", "listener {",
                    f"    timeout = {delai}", f"    on-timeout = {fin}",
                    *([f"    on-resume = {retour}"] if retour else []),
                    f"    condition_cmd = {CONDITIONS[alim]}", "    condition_retry = 5", "}"]
    return "\n".join(out) + "\n"
