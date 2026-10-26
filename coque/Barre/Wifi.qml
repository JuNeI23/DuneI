import QtQuick
import Quickshell.Networking
import "icones.js" as Icones

// Wifi — état du Wi-Fi : coupé, déconnecté ou force du signal en cinq paliers.
// Rôle : lit Networking (radio, cartes) et le réseau joint par la première carte Wi-Fi qui en a un.
// Entrées : aucune. Sorties : aucune. Erreurs : sans carte Wi-Fi, l'élément disparaît.
// Dépendances : ElementBarre, icones.js, Quickshell.Networking.
ElementBarre {
    // Cartes Wi-Fi présentes.
    readonly property var cartes: Array.from(Networking.devices.values).filter(d => d.type === DeviceType.Wifi)
    // Réseau joint, ou undefined.
    readonly property var joint: cartes.reduce((tous, c) => tous.concat(Array.from(c.networks.values)), []).find(n => n.connected)

    icone: Icones.iconeWifi(cartes.length > 0, Networking.wifiEnabled, joint !== undefined, joint?.signalStrength ?? 0)
}
