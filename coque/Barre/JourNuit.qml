import QtQuick
import Quickshell.Io
import "../Theme"
import "icones.js" as Icones

// JourNuit — interrupteur jour/nuit, seul élément cliquable de la barre.
// Rôle : l'icône suit Theme.moment ; un clic lance « dunei-theme bascule ». L'élément est nommé « jourNuit »
// pour que la fenêtre de la barre le désigne dans son masque de saisie.
// Entrées : aucune. Sorties : clicked. Erreurs : sans dunei-theme dans le PATH, le clic est sans effet.
// Dépendances : ElementBarre, Theme (moment), icones.js, Quickshell.Io (Process).
ElementBarre {
    id: jourNuit

    cliquable: true
    icone: Icones.iconeMoment(Theme.moment)
    onClicked: bascule.running = true

    Process {
        id: bascule
        command: ["dunei-theme", "bascule"]
    }
}
