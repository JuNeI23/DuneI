import QtQuick
import QtQuick.Layouts
import QtQuick.Templates as T
import "../Theme"
import "etats.js" as Etats

// Rangee — rangée d'une Liste : libellé, icône facultative, sélection en pastille et contour de focus.
// Rôle : habille le gabarit sans style T.ItemDelegate (conception, § 7.1). La rangée prend le rôle de son
// conteneur, sans cran : non sélectionnée et au repos, elle se confond avec le fond de la liste (§ 7.4). Elle
// est sélectionnée quand elle est la rangée courante, ou, si la liste ne fait pas suivre la sélection, quand
// l'appelant pose selectionnee (§ 7.5) ; la sélection prend l'accent quand la liste a le focus. Sélection et
// survol se peignent dans une pastille arrondie en retrait des bords de la liste, à la manière de macOS
// (§ 7.10). Le focus se montre par un contour sans fond de focus.width, qui suit la pastille rentré de
// -focus.rowOffset pixel, et jamais par un anneau ni par un changement de fond (§ 7.3) ; il paraît sur la
// rangée courante d'une liste qui a le focus obtenu au clavier. La rangée n'accepte aucun focus : la liste est
// l'unique arrêt. Un clic en fait la rangée courante, donne le focus à la liste sans montrer le contour, puis
// émet active(). Dans une liste qui porte selectionSuitSurvol (un menu), le survol en fait aussi la rangée
// courante.
// Entrées : index, requis, rang dans le modèle (fourni par la ListView) ; text, libellé ; icone, nom
// freedesktop d'une icône symbolique, vide par défaut (pas d'icône) ; selectionnee, sélection fournie par
// l'appelant quand la liste ne la fait pas suivre currentIndex ; accessoire, composant facultatif posé en tête
// de la rangée, avant l'icône, comme la colonne des coches d'un menu de macOS (le Deroulant y pose sa Coche) ;
// null par défaut ; forcerContour, réservée à la planche de contrôle : montre le contour de focus sans que la
// liste ait le focus, faux par défaut.
// Sorties : etat, l'Etat de la rangée (rôle, interaction, sélection, couleurs) ; signal active(), émis au clic
// et à Entrée (la Liste l'émet pour sa rangée courante).
// Erreurs : aucune ; hors d'une ListView, la rangée garde sa largeur implicite, n'est jamais courante ni
// sélectionnée par currentIndex, et se comporte comme si son groupe avait le focus ; avant le chargement des
// tokens, les cotes sont nulles et les couleurs transparentes. Le clic suppose une Liste : une ListView
// ordinaire ne déclare pas focusClavier, que le clic écrit.
// Dépendances : QtQuick.Templates (ItemDelegate), QtQuick.Layouts, propriétés attachées ListView (view,
// isCurrentItem) et Liste (focusClavier, selectionSuitCourant, selectionSuitSurvol) ; Theme (density, focus,
// radius, space), Etat, Texte, Icone, etats.js (herite).
// Cotes : hauteur density.rowHeight ; pastille en retrait de space.scale[0] (4) des bords, rayon radius.control ;
// retrait horizontal du contenu space.scale[2] (12), soit 8 dans la pastille ; écart entre icône et libellé
// space.scale[1] (8) ; icône de icons.sizes.dense (16), centrée dans la hauteur par la mise en page (§ 7.10, v0.7). La pastille est le premier enfant du fond et le contour le premier enfant de la pastille :
// la coque d'essai les lit ainsi.
T.ItemDelegate {
    id: rangee

    required property int index
    property string icone
    property bool selectionnee: false
    property bool forcerContour: false
    property Component accessoire: null

    readonly property alias etat: etat
    // Les propriétés attachées se lisent ici, dans la portée de la rangée : lues dans un enfant, elles
    // viseraient cet enfant, qui n'est pas le délégué.
    readonly property ListView vue: ListView.view
    readonly property bool courante: ListView.isCurrentItem
    readonly property bool contourMontre: forcerContour
        || courante && (vue?.activeFocus ?? false) && (vue?.focusClavier ?? false)

    signal active()

    focusPolicy: Qt.NoFocus
    activeFocusOnTab: false
    width: vue?.width ?? implicitWidth
    implicitWidth: implicitContentWidth + leftPadding + rightPadding
    implicitHeight: Theme.density?.rowHeight ?? 0
    horizontalPadding: Theme.space?.scale[2] ?? 0

    // clic — fait de la rangée la rangée courante, donne le focus à la liste sans montrer le contour, puis
    // émet active(). Entrées : aucune. Sortie : aucune. Erreurs : aucune ; hors d'une ListView, seul active()
    // est émis. Dépendances : vue (Liste).
    onClicked: {
        if (vue) {
            vue.currentIndex = index
            vue.forceActiveFocus()
            vue.focusClavier = false
        }
        active()
    }

    // survol — dans une liste qui porte selectionSuitSurvol (un menu), fait de la rangée survolée la rangée
    // courante, donc la rangée sélectionnée. Entrées : aucune. Sortie : aucune. Erreurs : aucune ; ailleurs, et
    // quand le pointeur quitte la rangée, rien ne se passe. Dépendances : vue (Liste, selectionSuitSurvol).
    onHoveredChanged: if (hovered && (vue?.selectionSuitSurvol ?? false)) vue.currentIndex = index

    // La rangée reste au rôle de son conteneur : pas de cran, donc le dnRole hérité tel quel.
    Etat {
        id: etat
        controle: rangee
        role: Etats.herite(rangee, "dnRole", "surfaceWindow")
        selectionne: (rangee.vue?.selectionSuitCourant ?? true) ? rangee.courante : rangee.selectionnee
        focusDansGroupe: rangee.vue?.activeFocus ?? true
    }

    // Fond : une pastille de sélection et de survol, premier enfant du fond, en retrait de space.scale[0] de
    // chaque bord de la liste et sur toute la hauteur, au rayon radius.control, comme la sélection d'une barre
    // latérale ou d'un menu de macOS (§ 7.10). Son premier enfant est le contour de focus : sans fond, il suit le
    // même rectangle arrondi, rentré de -rowOffset (−1 donne un pixel vers l'intérieur) et au rayon diminué
    // d'autant.
    background: Item {
        Rectangle {
            id: pastille
            anchors.fill: parent
            anchors.leftMargin: Theme.space?.scale[0] ?? 0
            anchors.rightMargin: anchors.leftMargin
            radius: Theme.radius?.control ?? 0
            color: etat.fond

            Rectangle {
                readonly property real decalage: Theme.focus?.rowOffset ?? 0
                anchors.fill: parent
                anchors.margins: -decalage
                radius: pastille.radius + decalage
                visible: rangee.contourMontre
                color: "transparent"
                border.width: Theme.focus?.width ?? 0
                border.color: (etat.inactif ? Theme.focus?.colorMuted : Theme.focus?.color) ?? "transparent"
            }
        }
    }

    contentItem: RowLayout {
        spacing: Theme.space?.scale[1] ?? 0

        Loader {
            active: rangee.accessoire !== null
            visible: active
            sourceComponent: rangee.accessoire
        }

        Icone {
            nom: rangee.icone
            taille: Theme.icons?.sizes.dense ?? 0
            couleur: etat.texte
            visible: nom !== ""
        }

        Texte {
            Layout.fillWidth: true
            text: rangee.text
            color: etat.texte
            elide: Text.ElideRight
            verticalAlignment: Text.AlignVCenter
        }
    }
}
