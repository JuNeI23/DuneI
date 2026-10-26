import QtQuick
import Quickshell.Bluetooth as BT
import "icones.js" as Icones

// Bluetooth — état de l'adaptateur Bluetooth par défaut : allumé ou barré.
// Rôle : lit BT.Bluetooth.defaultAdapter (l'alias évite la collision entre ce composant et le singleton).
// Entrées : aucune. Sorties : aucune. Erreurs : sans adaptateur, l'élément disparaît.
// Dépendances : ElementBarre, icones.js, Quickshell.Bluetooth.
ElementBarre {
    readonly property var adaptateur: BT.Bluetooth.defaultAdapter

    icone: Icones.iconeBluetooth(adaptateur !== null, adaptateur?.enabled ?? false)
}
