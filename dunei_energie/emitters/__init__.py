"""Registre des cibles de l'échelle d'inactivité — nom de fichier produit → fonction d'émission.

Pour ajouter une cible, il suffit d'écrire un module et de l'inscrire ici.
"""

from . import coque, hypridle, lua

TARGETS = {
    "hypridle.conf": hypridle.emit,   # service d'inactivité hypridle 0.1.8, en hyprlang
    "energie.lua": lua.emit,          # commande du verrouilleur, lue par modules/demarrage.lua (L1-10)
    "energie.json": coque.emit,       # seuils d'alerte de la batterie, lus par la coque (L2-13)
}
