import QtQuick
import "../Reseau"

// Reseau — état du réseau dans la barre : coupé, déconnecté, filaire ou force du signal en cinq paliers.
// Rôle : affiche EtatReseau.icone, calculée à partir de Quickshell.Networking par le singleton ; cliquable, un
// clic bascule « ouvert » (le popover du réseau s'y accroche, voir PopoverReseau). L'élément est nommé « reseau »
// pour que la fenêtre de la barre le désigne dans son masque de saisie.
// Entrées : ouvert (hérité d'ElementBarre), vrai tant que le popover est ouvert. Sorties : clicked.
// Erreurs : sans carte Wi-Fi ni lien filaire, l'élément disparaît et ne reçoit plus de clic.
// Dépendances : ElementBarre, EtatReseau.
ElementBarre {
    cliquable: true
    icone: EtatReseau.icone
    onClicked: ouvert = !ouvert
}
