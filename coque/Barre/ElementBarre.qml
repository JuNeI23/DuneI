import QtQuick
import QtQuick.Templates as T
import "../Theme"
import "../Composants"

// ElementBarre — élément générique de la barre système : une icône ou une image, et un texte, sans fond.
// Rôle : affiche un état ou une action de la barre. Sans fond ni capsule, la couleur porte tout l'état : repos
// Theme.texteBureau, survol (éléments cliquables seuls) Theme.texteBureauSurvol, appui ou menu ouvert
// Theme.color.accentStandalone, chaque changement lissé par un ColorSpring.
// Entrées : icone, nom d'icône sans « -symbolic » ; source, image recolorée à la place d'une icône nommée (le
// logo) ; texte ; cliquable, faux par défaut (un élément d'affichage ne réagit ni au survol ni à l'appui) ;
// ouvert, vrai tant que le menu de l'élément est ouvert ; taille, côté de l'icône en pixels logiques,
// Theme.icons.sizes.dense par défaut (le logo la fixe à Theme.icons.sizes.default). Le texte suit l'échelon 3
// de l'échelle typographique (15 px), en chiffres tabulaires.
// Sorties : celles de T.AbstractButton (clicked, hovered, down). L'élément est invisible, et donc absent de la
// rangée, quand ni icône, ni image, ni texte ne sont fournis (matériel absent).
// Erreurs : aucune ; avant le chargement des jetons, la couleur est transparente.
// Dépendances : Theme (texteBureau, color, typo), Composants (Icone, qui porte l'image recolorée, et Texte), ColorSpring.
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
            visible: element.icone !== "" || element.source != ""
            taille: element.taille
            nom: element.icone
            image: element.source
            couleur: ressort.value
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
