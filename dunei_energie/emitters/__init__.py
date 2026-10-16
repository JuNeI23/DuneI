"""Registre des cibles de l'échelle d'inactivité — nom de fichier produit → fonction d'émission.

Pour ajouter une cible, il suffit d'écrire un module et de l'inscrire ici.
"""

from . import hypridle

TARGETS = {
    "hypridle.conf": hypridle.emit,   # service d'inactivité hypridle 0.1.8, en hyprlang
}
