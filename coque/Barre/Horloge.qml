import QtQuick
import Quickshell

// Horloge — date et heure de la barre, au format « lun. 26 oct. 09:41 ».
// Rôle : affiche le texte de SystemClock à la minute, en français ; ElementBarre porte les chiffres tabulaires.
// Entrées : aucune. Sorties : texte. Erreurs : aucune.
// Dépendances : ElementBarre, Quickshell (SystemClock).
ElementBarre {
    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    texte: Qt.locale("fr_FR").toString(clock.date, "ddd d MMM HH:mm")
}
