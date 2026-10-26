import QtQuick
import QtQuick.Controls.impl
import QtQuick.Templates as T
import "../Theme"
import "../Composants"

// ElementBarre — élément générique de la barre système : une icône ou une image, et un texte, sans fond.
// Rôle : affiche un état ou une action de la barre. Sans fond ni capsule, la couleur porte tout l'état : repos
// Theme.texteBureau, survol (éléments cliquables seuls) Theme.texteBureauSurvol, appui ou menu ouvert
// Theme.color.accentStandalone, chaque changement lissé par un ColorSpring.
// Entrées : icone, nom d'icône sans « -symbolic » ; source, image recolorée à la place d'une icône nommée (le
// logo) ; texte ; cliquable, faux par défaut (un élément d'affichage ne réagit ni au survol ni à l'appui) ;
// ouvert, vrai tant que le menu de l'élément est ouvert.
// Sorties : celles de T.AbstractButton (clicked, hovered, down). L'élément est invisible, et donc absent de la
// rangée, quand ni icône, ni image, ni texte ne sont fournis (matériel absent).
// Erreurs : aucune ; avant le chargement des jetons, la couleur est transparente.
// Dépendances : Theme (texteBureau, color, typo, icons), Composants (Icone, Texte), ColorSpring.
T.AbstractButton {
    id: element

    property string icone
    property url source
    property string texte
    property bool cliquable: false
    property bool ouvert: false

    focusPolicy: Qt.NoFocus
    enabled: cliquable
    visible: icone !== "" || source != "" || texte !== ""
    implicitWidth: rangee.implicitWidth
    implicitHeight: 24

    ColorSpring {
        id: ressort
        target: element.down || element.ouvert ? Theme.color?.accentStandalone ?? "transparent"
              : element.hovered ? Theme.texteBureauSurvol : Theme.texteBureau
    }

    contentItem: Row {
        id: rangee
        spacing: Theme.space?.scale[0] ?? 0

        Icone {
            anchors.verticalCenter: parent.verticalCenter
            visible: element.icone !== ""
            nom: element.icone
            couleur: ressort.value
        }

        ColorImage {
            anchors.verticalCenter: parent.verticalCenter
            visible: element.source != ""
            source: element.source
            color: ressort.value
            sourceSize: Qt.size(width, height)
            width: Theme.icons?.sizes.default ?? 0
            height: width
        }

        Texte {
            anchors.verticalCenter: parent.verticalCenter
            visible: element.texte !== ""
            text: element.texte
            color: ressort.value
            font.features: Theme.typo?.tabularNumerals ? { "tnum": 1 } : ({})
        }
    }
}
