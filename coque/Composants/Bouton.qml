import QtQuick
import QtQuick.Templates as T
import "../Theme"

// Bouton — bouton de la coque, texte et icône facultative sur le fond de son état.
// Rôle : habille le gabarit sans style T.AbstractButton (conception, § 7.1) : fond au rôle un cran au-dessus
// de son conteneur, animé par Etat ; pressé, il descend sous le repos (bible, annexe E) sans se déplacer ni se
// réduire ; anneau de focus seulement pour un focus venu du clavier (visualFocus). Un clic ne vole pas le focus
// d'un champ (focusPolicy Qt.TabFocus, § 7.3). Le bouton principal d'un dialogue, comme le bouton bleu de
// macOS, est sélectionné : l'accent et le sur-accent, ou l'accent sans chroma sous le modificateur inactive
// (§ 7.5 et 7.10), sans couleur nouvelle.
// Entrées : text, clicked et le reste de l'API de T.AbstractButton ; icone, nom freedesktop facultatif, posé
// avant le texte ; principal, vrai pour le bouton par défaut d'un dialogue, faux par défaut.
// Sorties : etat, l'Etat du bouton (rôle, interaction, sélection, couleurs), lu par la planche et les essais.
// Erreurs : aucune ; avant le chargement des tokens, les cotes sont nulles et les couleurs transparentes.
// Dépendances : QtQuick.Templates, Theme (density, radius, space), Etat, AnneauFocus, Texte, Icone.
// Cotes : retrait horizontal space.scale[2] (12), écart entre l'icône et le texte space.scale[0] (4) ; icône de
// icons.sizes.dense (16), plus petite que la taille par défaut, à côté du texte (conception, § 7.10, v0.7).
T.AbstractButton {
    id: bouton

    property string icone
    property bool principal: false
    readonly property alias etat: etat

    focusPolicy: Qt.TabFocus
    implicitWidth: implicitContentWidth + leftPadding + rightPadding
    implicitHeight: Theme.density?.controlHeight ?? 0
    horizontalPadding: Theme.space?.scale[2] ?? 0
    spacing: Theme.space?.scale[0] ?? 0

    Etat {
        id: etat
        controle: bouton
        selectionne: bouton.principal
    }

    background: Rectangle {
        radius: Theme.radius?.control ?? 0
        color: etat.fond

        AnneauFocus {
            cible: parent
            montre: bouton.visualFocus
            inactif: etat.inactif
        }
    }

    // L'icône et le texte forment une rangée centrée dans le bouton, quelle que soit sa largeur.
    contentItem: Item {
        implicitWidth: rangee.implicitWidth
        implicitHeight: rangee.implicitHeight

        Row {
            id: rangee
            anchors.centerIn: parent
            spacing: bouton.spacing

            Icone {
                anchors.verticalCenter: parent.verticalCenter
                visible: bouton.icone !== ""
                nom: bouton.icone
                taille: Theme.icons?.sizes.dense ?? 0
                couleur: etat.texte
            }

            Texte {
                anchors.verticalCenter: parent.verticalCenter
                text: bouton.text
                color: etat.texte
            }
        }
    }
}
