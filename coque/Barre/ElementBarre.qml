import QtQuick
import QtQuick.Templates as T
import "../Theme"
import "../Composants"

// ElementBarre — élément générique de la barre système : une icône ou une image, et un texte, sans fond.
// Rôle : affiche un état ou une action de la barre. Sans fond ni capsule, la couleur porte tout l'état : repos
// Theme.texteBureau, survol (éléments cliquables seuls) Theme.texteBureauSurvol, appui ou menu ouvert
// Theme.color.accentStandalone, chaque changement lissé par un ColorSpring. Tant que le menu de l'élément est ouvert,
// l'icône passe aussi à sa variante pleine, en fondu enchaîné, pour lier la barre au popover qu'elle a ouvert (D103).
// L'icône et son texte descendent de Theme.motion.popover.icon_travel_px tant que le menu est ouvert. À l'appui, à
// l'ouverture comme à la fermeture, la couleur, la descente et le passage à l'icône pleine suivent le ressort
// « overlay » ; le survol seul garde le ressort « state ». Mouvement réduit : l'icône ne descend pas (la descente est
// un déplacement), la variante pleine paraît en fondu court et les couleurs restent animées.
// Entrées : icone, nom d'icône sans « -symbolic » ; source, image recolorée à la place d'une icône nommée (le
// logo) ; texte ; cliquable, faux par défaut (un élément d'affichage ne réagit ni au survol ni à l'appui) ;
// ouvert, vrai tant que le menu de l'élément est ouvert ; taille, côté de l'icône en pixels logiques,
// Theme.icons.sizes.dense par défaut (le logo la fixe à Theme.icons.sizes.default). Le texte suit l'échelon 3
// de l'échelle typographique (15 px), en chiffres tabulaires.
// Sorties : celles de T.AbstractButton (clicked, hovered, down) ; couleurRessort, le ColorSpring de la couleur, lu par
// les essais. L'élément est invisible, et donc absent de la rangée, quand ni icône, ni image, ni texte ne sont fournis
// (matériel absent).
// Erreurs : aucune ; avant le chargement des jetons, la couleur est transparente.
// Dépendances : Theme (texteBureau, color, typo), Composants (Icone, qui porte l'image recolorée, et Texte),
// ColorSpring, Ressort.
T.AbstractButton {
    id: element

    property string icone
    property url source
    property string texte
    property bool cliquable: false
    property bool ouvert: false
    property int taille: Theme.icons?.sizes.dense ?? 0

    focusPolicy: Qt.NoFocus
    hoverEnabled: true
    enabled: cliquable
    visible: icone !== "" || source != "" || texte !== ""
    implicitWidth: rangee.implicitWidth
    implicitHeight: 24

    readonly property alias couleurRessort: ressort

    // Descente de l'icône, en pixels : icon_travel_px tant que son menu est ouvert, et jamais en mouvement réduit. Le
    // seuil de repos est celui du cadre des popovers (rest_threshold_px) : il supprime la fin du mouvement qui rampe.
    Ressort {
        id: abaisse
        transition: "overlay"
        seuil: Theme.motion?.popover.rest_threshold_px ?? 0
        cible: element.ouvert && !Theme.mouvementReduit ? Theme.motion?.popover.icon_travel_px ?? 0 : 0
    }

    // La couleur suit le ressort « overlay » à l'appui, tant que le menu est ouvert et tant que l'icône bouge (y compris
    // à la fermeture) ; le survol seul garde « state ».
    ColorSpring {
        id: ressort
        params: element.down || element.ouvert || abaisse.moving ? Theme.motion?.transitions.overlay.in : Theme.motion?.transitions.state.in
        target: element.down || element.ouvert ? Theme.color?.accentStandalone ?? "transparent"
              : element.cliquable && element.hovered ? Theme.texteBureauSurvol : Theme.texteBureau
    }

    contentItem: Row {
        id: rangee
        transform: Translate { y: abaisse.value }
        spacing: Theme.space?.scale[0] ?? 0

        // Icône creuse et icône pleine superposées ; le ressort plein va de 0 (creuse) à 1 (pleine, menu ouvert).
        Item {
            anchors.verticalCenter: parent.verticalCenter
            visible: element.icone !== "" || element.source != ""
            implicitWidth: element.taille
            implicitHeight: element.taille

            Ressort { id: plein; transition: "overlay"; nature: "fondu"; cible: element.ouvert && element.icone !== "" ? 1 : 0 }
            Icone {
                anchors.fill: parent
                opacity: 1 - plein.value
                taille: element.taille
                nom: element.icone
                image: element.source
                couleur: ressort.value
            }
            Icone {
                anchors.fill: parent
                visible: plein.value > 0
                opacity: plein.value
                taille: element.taille
                nom: element.icone
                pleine: true
                couleur: ressort.value
            }
        }

        Texte {
            anchors.verticalCenter: parent.verticalCenter
            visible: element.texte !== ""
            echelon: 3
            tabulaire: true
            text: element.texte
            color: ressort.value
        }
    }
}
