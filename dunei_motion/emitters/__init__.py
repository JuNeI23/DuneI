"""Registre des cibles du mouvement — nom de fichier produit → fonction d'émission.

Pour ajouter une cible, il suffit d'écrire un module et de l'inscrire ici.
"""

from . import json_, lua

TARGETS = {
    "motion.lua": lua.emit,     # compositeur, API Lua hl.* de Hyprland 0.56
    "motion.json": json_.emit,  # future coque Quickshell
}
