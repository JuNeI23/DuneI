import QtQuick

// Vpn — témoin de connexion VPN, visible seulement quand un VPN est actif.
// Rôle : nmcli monitor signale chaque changement de NetworkManager ; chaque ligne relance la liste des types de
// connexions actives, et l'élément apparaît si l'un vaut « vpn » ou « wireguard ».
// Entrées : surveille (commande du processus résident, remplaçable par un test), lecture. Sorties : connecte.
// Erreurs : sans nmcli ou sans NetworkManager, l'élément reste invisible ; la surveillance est relancée
// toutes les secondes. Dépendances : ElementBarre, Relance.
ElementBarre {
    id: element

    property alias surveille: relance.surveille
    property alias lecture: relance.lecture
    property alias actif: relance.actif
    property alias relances: relance.relances
    property bool connecte: false

    icone: connecte ? "network-vpn" : ""

    Relance {
        id: relance
        surveille: ["nmcli", "monitor"]
        lecture: ["nmcli", "-t", "-f", "TYPE", "connection", "show", "--active"]
        onLu: texte => element.connecte = texte.split("\n").some(t => ["vpn", "wireguard"].includes(t.trim()))
    }
}
