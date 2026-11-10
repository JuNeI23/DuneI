import QtQuick
import QtQuick.Layouts
import "../Theme"
import "../Composants"

// TitrePage — titre d'une page d'onglet de la fenêtre Réseau (D4) : échelon 5 en graisse moyenne, avec un contrôle
// facultatif à droite (l'interrupteur de la radio Wi-Fi).
// Rôle : donne à PageWifi, PageFilaire et PageVpn le même en-tête, aligné sur le bord gauche des cartes ; le contrôle
// se cale sur leur bord droit, qui est aussi celui du champ de recherche (Recette 1 de L2-65, D156).
// Entrées : text, le titre ; un contrôle facultatif déclaré comme enfant, calé sur le bord droit de la page.
// Sortie : aucune. Erreurs : aucune ; avant le chargement des tokens, les cotes sont nulles.
// Dépendances : Texte, Theme (space), QtQuick.Layouts.
// Cotes : hauteur du texte plus deux fois space.scale[0] (4) ; occupe la largeur de sa mise en page.
Item {
    id: titre

    property alias text: libelle.text
    default property alias controle: emplacement.data

    Layout.fillWidth: true
    implicitHeight: libelle.implicitHeight + 2 * (Theme.space?.scale[0] ?? 0)

    Texte { id: libelle; anchors.verticalCenter: parent.verticalCenter; echelon: 5; moyen: true }
    Item {
        id: emplacement
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: childrenRect.width
        height: childrenRect.height
    }
}
