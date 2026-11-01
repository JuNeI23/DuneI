import QtQuick
import QtQuick.Layouts
import "../Theme"
import "../Composants"

// TitrePage — titre d'une page d'onglet de la fenêtre Réseau (D4) : échelon 5 en graisse moyenne, avec un contrôle
// facultatif à droite (l'interrupteur de la radio, à l'étape suivante).
// Rôle : donne à PageWifi, PageFilaire et PageVpn le même en-tête, aligné sur le bord gauche des cartes.
// Entrées : text, le titre ; un contrôle facultatif déclaré comme enfant, calé à space.scale[2] du bord droit.
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
        anchors.rightMargin: Theme.space?.scale[2] ?? 0
        anchors.verticalCenter: parent.verticalCenter
        width: childrenRect.width
        height: childrenRect.height
    }
}
