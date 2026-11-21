import QtQuick
import QtQuick.Templates as T
import "../Theme"

// Depliable — section dépliable de la coque : un en-tête cliquable au-dessus d'un bloc de contenu.
// Rôle : à la manière de macOS (conception, § 7.10), l'en-tête porte un chevron dessiné, qui pointe à droite quand
// la section est repliée et en bas quand elle est dépliée (le Chevron bas, pivoté d'un quart de tour par le ressort
// reveal, comme le dépliage d'une rangée du popover), puis le libellé. Le contenu, aligné sur le libellé, s'ouvre et se
// ferme en dépliant sa hauteur sur ce même ressort (Recette 1 de L2-65, D157) : la hauteur montrée est celle du
// contenu multipliée par la progression du chevron, de 0 replié à 1 déplié, si bien qu'un contenu qui change de
// hauteur pendant ou après le dépliage est suivi sans second ressort ; le bloc est découpé tant qu'il bouge, et caché
// replié. Un clic, Espace ou Entrée basculent la section. L'en-tête est un arrêt de tabulation ; un clic ne vole pas le
// focus d'un champ (Qt.TabFocus, § 7.3). Il se comporte comme une rangée (L2-73) : il suit le curseur de sa vue, et
// survolé ou focalisé au clavier, il en porte la plaque, l'aplat color.accent (l'accent sans chroma sous inactive),
// sans anneau de focus ; hors du curseur, il n'a pas de fond. Le libellé prend le texte de l'Etat de l'en-tête,
// neutre hors du curseur et terni désactivé ; le chevron prend le texte secondaire ; sous le curseur, tous deux
// passent au sur-accent, en fondu au ressort des états.
// Entrées : text, le libellé ; ouvert, vrai si la section est dépliée, faux par défaut ; retrait, vrai par défaut : le
// bloc est aligné sur le libellé ; faux, il part du bord gauche de la section (une carte pleine largeur) ; contenu,
// propriété par défaut : les éléments déclarés dans la Depliable, posés en colonne dans le bloc.
// Sorties : etat, l'Etat de l'en-tête ; entete (objectName « entete »), chevron, bloc, cadre (l'élément découpé qui
// porte le bloc, à la hauteur montrée), lus par les essais et la planche ; progression, de 0 (replié) à 1 (déplié) ;
// enMouvement, vrai tant que le ressort avance ; largeurContenu, la largeur offerte au contenu, celle de la section
// moins le retrait du bloc.
// Erreurs : aucune ; avant le chargement des tokens, les cotes sont nulles et les couleurs transparentes.
// Dépendances : QtQuick.Templates, Theme (density, icons, space, radius, color, ColorSpring), Etat, VueCurseur (par
// Etat), Chevron, Texte, Ressort (transition reveal ; le mouvement réduit pose le chevron et la hauteur d'un coup).
// Cotes : en-tête de density.rowHeight de haut, au rayon radius.small ; le contenu y est en retrait de space.scale[1]
// (8) à gauche et à droite, pour que la plaque du curseur, peinte sur le fond, ne touche ni le chevron ni la fin du
// libellé (v0.7) ; chevron de icons.sizes.dense ; écart entre le chevron et le libellé space.scale[0] (4) ; le bloc
// est en retrait de ce retrait, du chevron et de cet écart, donc aligné sur le libellé.
Column {
    id: depliable

    property string text
    property bool ouvert: false
    property bool retrait: true
    default property alias contenu: bloc.data
    readonly property alias etat: etat
    readonly property alias entete: entete
    readonly property alias chevron: chevron
    readonly property alias bloc: bloc
    readonly property alias cadre: cadre
    readonly property real progression: (pivot.value + 90) / 90
    readonly property bool enMouvement: pivot.moving
    readonly property real largeurContenu: width - bloc.leftPadding

    // Angle du chevron, de -90 (replié) à 0 (déplié), porté par le ressort reveal.
    Ressort { id: pivot; transition: "reveal"; cible: depliable.ouvert ? 0 : -90 }

    T.AbstractButton {
        id: entete

        objectName: "entete"
        focusPolicy: Qt.TabFocus
        implicitWidth: implicitContentWidth + leftPadding + rightPadding
        implicitHeight: Theme.density?.rowHeight ?? 0
        horizontalPadding: Theme.space?.scale[1] ?? 0
        spacing: Theme.space?.scale[0] ?? 0
        text: depliable.text
        onClicked: depliable.ouvert = !depliable.ouvert
        Keys.onReturnPressed: depliable.ouvert = !depliable.ouvert
        Keys.onEnterPressed: depliable.ouvert = !depliable.ouvert

        // L'en-tête suit le curseur : son fond n'est peint que sous lui, transparent au repos comme au survol.
        Etat {
            id: etat
            controle: entete
            suitCurseur: true
            curseurAplat: true
            fondReposTransparent: true
            fondSurvolTransparent: true
        }

        // Teinte du chevron : le texte secondaire hors du curseur, le sur-accent de l'état sous lui.
        ColorSpring {
            id: teinteChevron
            target: (etat.sousCurseur ? etat.couleurs?.text : Theme.color?.textSecondary) ?? "transparent"
        }

        background: Rectangle {
            id: fond
            color: etat.fond
            radius: Theme.radius?.small ?? 0
        }

        contentItem: Row {
            spacing: entete.spacing

            Chevron {
                id: chevron
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.icons?.sizes.dense ?? 0
                height: width
                sens: "bas"
                rotation: pivot.value
                couleur: teinteChevron.value
            }

            Texte {
                anchors.verticalCenter: parent.verticalCenter
                text: entete.text
                moyen: true
                color: etat.texte
            }
        }
    }

    // Le bloc, dans un cadre à la hauteur montrée : découpé pendant le mouvement, caché replié.
    Item {
        id: cadre
        width: bloc.width
        height: bloc.implicitHeight * depliable.progression
        clip: pivot.moving
        visible: depliable.progression > 0

        Column {
            id: bloc
            leftPadding: depliable.retrait ? entete.leftPadding + chevron.width + entete.spacing : 0
        }
    }
}
