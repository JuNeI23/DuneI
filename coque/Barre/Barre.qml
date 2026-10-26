import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../Theme"

// Barre — barre système de DuneI, posée en haut de chaque écran (L2-08, L2-09).
// Rôle : fenêtre de calque de 32 px, transparente, qui réserve 32 px en haut de l'écran ; à gauche le logo et
// l'horloge, à droite les indicateurs, au centre rien. Aucun fond ni capsule : les éléments se posent sur le
// bureau. Le masque de saisie ne couvre que l'interrupteur jour/nuit, seul élément cliquable : partout ailleurs
// les clics traversent la barre jusqu'au bureau. Elle ne prend jamais le focus clavier.
// Entrées : modelData, l'écran que lui donne le Variants de la coque.
// Sorties : une fenêtre de calque au namespace « dunei-barre » (floutée par les règles de calque générées).
// Erreurs : sans jeton de thème, les éléments restent invisibles (voir chacun) ; la fenêtre reste posée.
// Dépendances : quickshell ≥ 0.3 (PanelWindow, Region, WlrLayershell), QtQuick.Layouts, indicateurs du module
// Barre (Logo, Horloge, Notifications, Batterie, JourNuit, Wifi, Vpn, Bluetooth, Parametres), Theme.
PanelWindow {
    id: barre

    required property var modelData

    // Marge de la rangée au bord de l'écran, en pixels logiques.
    readonly property int marge: 10

    screen: modelData
    anchors { top: true; left: true; right: true }
    implicitHeight: 32
    exclusiveZone: 32
    color: "transparent"
    mask: Region { item: jourNuit }
    WlrLayershell.namespace: "dunei-barre"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    RowLayout {
        anchors { fill: parent; leftMargin: barre.marge; rightMargin: barre.marge }
        spacing: 0

        RowLayout {
            Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
            spacing: Theme.space?.scale[1] ?? 0

            Logo {}
            Horloge {}
        }

        Item { Layout.fillWidth: true }

        RowLayout {
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            spacing: Theme.space?.scale[1] ?? 0

            Notifications {}
            Batterie {}
            JourNuit { id: jourNuit }
            Wifi {}
            Vpn {}
            Bluetooth {}
            Parametres {}
        }
    }
}
