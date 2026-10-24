import QtQuick
import QtQuick.Templates as T
import "../Theme"

// Depliable — section dépliable de la coque : un en-tête cliquable au-dessus d'un bloc de contenu.
// Rôle : à la manière de macOS (conception, § 7.10), l'en-tête porte un chevron dessiné, qui pointe à droite quand
// la section est repliée et en bas quand elle est dépliée (le Chevron bas, pivoté d'un quart de tour, sans animation
// jusqu'à L2-06), puis le libellé ; le contenu, aligné sur le libellé, n'est visible que déplié. Un clic, Espace ou
// Entrée basculent la section. L'en-tête est un arrêt de tabulation, entouré de l'anneau de focus au clavier
// (visualFocus) ; un clic ne vole pas le focus d'un champ (Qt.TabFocus, § 7.3). Le libellé prend le texte non
// sélectionné de l'Etat de l'en-tête, qui ne le ternit que désactivé ; le chevron prend le texte secondaire.
// Entrées : text, le libellé ; ouvert, vrai si la section est dépliée, faux par défaut ; contenu, propriété par
// défaut : les éléments déclarés dans la Depliable, posés en colonne dans le bloc.
// Sorties : etat, l'Etat de l'en-tête ; entete (objectName « entete »), chevron, bloc, anneau, et cibleFocus (le
// fond de l'en-tête, que la planche entoure de l'anneau), lus par les essais et la planche.
// Erreurs : aucune ; avant le chargement des tokens, les cotes sont nulles et les couleurs transparentes.
// Dépendances : QtQuick.Templates, Theme (density, icons, space, radius, color, stateColors), Etat, Chevron, Texte,
// AnneauFocus.
// Cotes : en-tête de density.rowHeight de haut, au rayon radius.small ; chevron de icons.sizes.dense ; écart entre le
// chevron et le libellé space.scale[0] (4) ; le bloc est en retrait du chevron et de cet écart.
Column {
    id: depliable

    property string text
    property bool ouvert: false
    default property alias contenu: bloc.data
    readonly property alias etat: etat
    readonly property alias entete: entete
    readonly property alias chevron: chevron
    readonly property alias bloc: bloc
    readonly property alias anneau: anneau
    readonly property alias cibleFocus: fond

    T.AbstractButton {
        id: entete

        objectName: "entete"
        focusPolicy: Qt.TabFocus
        implicitWidth: implicitContentWidth
        implicitHeight: Theme.density?.rowHeight ?? 0
        spacing: Theme.space?.scale[0] ?? 0
        text: depliable.text
        onClicked: depliable.ouvert = !depliable.ouvert
        Keys.onReturnPressed: depliable.ouvert = !depliable.ouvert
        Keys.onEnterPressed: depliable.ouvert = !depliable.ouvert

        Etat {
            id: etat
            controle: entete
        }

        background: Rectangle {
            id: fond
            color: "transparent"
            radius: Theme.radius?.small ?? 0

            AnneauFocus {
                id: anneau
                cible: fond
                montre: entete.visualFocus
                inactif: etat.inactif
            }
        }

        contentItem: Row {
            spacing: entete.spacing

            Chevron {
                id: chevron
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.icons?.sizes.dense ?? 0
                height: width
                sens: "bas"
                rotation: depliable.ouvert ? 0 : -90
                couleur: Theme.color?.textSecondary ?? "transparent"
            }

            Texte {
                anchors.verticalCenter: parent.verticalCenter
                text: entete.text
                moyen: true
                color: Theme.stateColors(etat.role, "none", etat.interaction)?.text ?? "transparent"
            }
        }
    }

    Column {
        id: bloc
        leftPadding: chevron.width + entete.spacing
        visible: depliable.ouvert
    }
}
