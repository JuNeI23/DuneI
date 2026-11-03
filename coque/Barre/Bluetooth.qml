import QtQuick
import Quickshell.Bluetooth as BT
import "icones.js" as Icones

// Bluetooth — état de l'adaptateur Bluetooth par défaut : allumé ou barré.
// Rôle : lit BT.Bluetooth.defaultAdapter (l'alias évite la collision entre ce composant et le singleton).
// Rôle (suite) : cliquable, un clic bascule « ouvert » (la barre y accroche le popover du Bluetooth,
// PopoverBluetooth, L2-14). L'élément est nommé « bluetooth » pour que la barre le désigne dans son masque de saisie.
// Entrées : ouvert (hérité d'ElementBarre), vrai tant que le popover est ouvert. Sorties : clicked.
// Erreurs : sans adaptateur, l'élément disparaît et ne reçoit plus de clic.
// Dépendances : ElementBarre, icones.js, Quickshell.Bluetooth.
ElementBarre {
    readonly property var adaptateur: BT.Bluetooth.defaultAdapter

    cliquable: true
    icone: Icones.iconeBluetooth(adaptateur !== null, adaptateur?.enabled ?? false)
    onClicked: ouvert = !ouvert
}
