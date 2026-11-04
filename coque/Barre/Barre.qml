import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../Theme"
import "../Reseau"
import "../Bluetooth"

// Barre — barre système de DuneI, posée en haut de chaque écran (L2-08, L2-09).
// Rôle : fenêtre de calque de 28 px, transparente, qui réserve 28 px en haut de l'écran ; à gauche le logo et
// l'horloge, à droite les indicateurs, au centre rien. Aucun fond ni capsule : les éléments se posent sur le
// bureau. Le masque de saisie ne couvre que l'interrupteur jour/nuit, l'indicateur réseau et l'indicateur Bluetooth,
// seuls éléments cliquables : partout ailleurs les clics traversent la barre jusqu'au bureau. Elle ne prend jamais
// le focus clavier. Elle porte le popover du réseau et celui du Bluetooth, chacun ancré sous son indicateur et rendu
// par la fenêtre unique HotePopovers.
// Entrées : modelData, l'écran que lui donne le Variants de la coque.
// Sorties : une fenêtre de calque au namespace « dunei-barre » (floutée par les règles de calque générées).
// Erreurs : sans jeton de thème, les éléments restent invisibles (voir chacun) ; la fenêtre reste posée.
// Dépendances : quickshell ≥ 0.3 (PanelWindow, Region, WlrLayershell), QtQuick.Layouts, indicateurs du module
// Barre (Logo, Horloge, Notifications, Batterie, JourNuit, Reseau, Vpn, Bluetooth, Parametres), PopoverReseau
// (module Reseau), PopoverBluetooth (module Bluetooth), HotePopovers, Theme.
PanelWindow {
    id: barre

    required property var modelData

    // Marge de la rangée au bord de l'écran, en pixels logiques.
    readonly property int marge: 10

    screen: modelData
    anchors { top: true; left: true; right: true }
    implicitHeight: 28
    exclusiveZone: 28
    color: "transparent"
    // Masque de saisie posé sur l'interrupteur et sur les indicateurs réseau et Bluetooth, leurs coordonnées cumulées rangée par
    // rangée (D100) : une Region qui nomme un item ne suit que ses déplacements dans son parent, et l'apparition
    // d'une icône à leur droite (le réseau au lancement ou au réveil) faisait glisser la rangée sans déplacer le
    // masque, laissé sur l'icône voisine. Invisible (matériel absent), l'indicateur sort de la rangée (un Item
    // invisible n'y occupe plus de place) : sa région est alors mise à zéro, pour ne pas intercepter les clics du
    // bureau à la position qu'il garde.
    mask: Region {
        x: rangee.x + droite.x + jourNuit.x
        y: rangee.y + droite.y + jourNuit.y
        width: jourNuit.width
        height: jourNuit.height

        Region {
            x: rangee.x + droite.x + reseau.x
            y: rangee.y + droite.y + reseau.y
            width: reseau.visible ? reseau.width : 0
            height: reseau.height
        }
        Region {
            x: rangee.x + droite.x + bluetooth.x
            y: rangee.y + droite.y + bluetooth.y
            width: bluetooth.visible ? bluetooth.width : 0
            height: bluetooth.height
        }
    }
    WlrLayershell.namespace: "dunei-barre"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    RowLayout {
        id: rangee
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
            id: droite
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            spacing: Theme.space?.scale[1] ?? 0

            Notifications {}
            Batterie {}
            JourNuit { id: jourNuit }
            Reseau {
                id: reseau
                onOuvertChanged: popoverReseau.ouvert = ouvert
            }
            Vpn {}
            Bluetooth {
                id: bluetooth
                onOuvertChanged: popoverBluetooth.ouvert = ouvert
            }
            Parametres {}
        }
    }

    // Popover du réseau, sous l'indicateur. « ouvert » s'affecte dans les deux sens (voir Overlay) : l'indicateur
    // l'ouvre et le ferme, et toute fermeture du popover (Échap, clic à l'extérieur, action) rend la main à
    // l'indicateur. La fenêtre hôte associe la barre à sa prise du clavier : un clic sur l'indicateur ne lève pas la
    // prise et ferme le popover par l'indicateur, au lieu de le fermer à l'appui puis de le rouvrir au relâchement.
    PopoverReseau {
        id: popoverReseau
        heberge: true
        ancre: reseau
        onFerme: reseau.ouvert = false
    }

    // Popover du Bluetooth, accroché comme celui du réseau (voir ci-dessus).
    PopoverBluetooth {
        id: popoverBluetooth
        heberge: true
        ancre: bluetooth
        onFerme: bluetooth.ouvert = false
    }

    // Fenêtre unique qui porte le cadre et le contenu de ces deux popovers (D109).
    HotePopovers {
        barre: barre
        popovers: [popoverReseau, popoverBluetooth]
    }
}
