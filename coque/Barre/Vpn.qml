import QtQuick
import "../Reseau"

// Vpn — témoin de connexion VPN, visible seulement quand un VPN est actif.
// Rôle : lit EtatReseau.vpnActif, que le singleton déduit des types de connexions actives (« vpn » ou
// « wireguard ») à chaque ligne de l'unique « nmcli monitor » de la coque ; l'élément apparaît si l'un est actif.
// Entrées : aucune. Sorties : connecte.
// Erreurs : sans nmcli ou sans NetworkManager, l'élément reste invisible. Dépendances : ElementBarre, EtatReseau.
ElementBarre {
    readonly property bool connecte: EtatReseau.vpnActif

    icone: connecte ? "network-vpn" : ""
}
