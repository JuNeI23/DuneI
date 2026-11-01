import QtQuick
import QtQuick.Layouts
import "../Theme"
import "../Composants"

// PageVpn — page de l'onglet VPN de la fenêtre Réseau.
// Rôle : le titre « VPN » seul ; la liste des connexions VPN et WireGuard et leur interrupteur y viendront.
// Entrées : panneau, le PanneauReseau ; etat, la source de l'état, EtatReseau par défaut. Sortie : aucune.
// Erreurs : aucune. Dépendances : TitrePage.
ColumnLayout {
    required property var panneau
    property var etat: EtatReseau

    spacing: 0

    TitrePage { text: "VPN" }
}
