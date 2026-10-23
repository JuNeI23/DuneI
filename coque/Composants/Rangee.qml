import QtQuick
import QtQuick.Layouts
import QtQuick.Templates as T
import "../Theme"
import "etats.js" as Etats

// Rangee — rangée d'une Liste : libellé, icône facultative, sélection et contour de focus pleine largeur.
// Rôle : habille le gabarit sans style T.ItemDelegate (conception, § 7.1). La rangée prend le rôle de son
// conteneur, sans cran : non sélectionnée et au repos, elle se confond avec le fond de la liste (§ 7.4). Elle
// est sélectionnée quand elle est la rangée courante, ou, si la liste ne fait pas suivre la sélection, quand
// l'appelant pose selectionnee (§ 7.5) ; la sélection prend l'accent quand la liste a le focus. Le focus se
// montre par un contour sans fond de focus.width, sur toute la largeur, rentré de -focus.rowOffset pixel, et
// jamais par un anneau ni par un changement de fond (§ 7.3) ; il paraît sur la rangée courante d'une liste
// qui a le focus obtenu au clavier. La rangée n'accepte aucun focus : la liste est l'unique arrêt. Un clic
// en fait la rangée courante, donne le focus à la liste sans montrer le contour, puis émet active().
// Entrées : index, requis, rang dans le modèle (fourni par la ListView) ; text, libellé ; icone, nom
// freedesktop d'une icône symbolique, vide par défaut (pas d'icône) ; selectionnee, sélection fournie par
// l'appelant quand la liste ne la fait pas suivre currentIndex ; forcerContour, réservée à la planche de
// contrôle : montre le contour de focus sans que la liste ait le focus, faux par défaut.
// Sorties : etat, l'Etat de la rangée (rôle, interaction, sélection, couleurs) ; signal active(), émis au clic
// et à Entrée (la Liste l'émet pour sa rangée courante).
// Erreurs : aucune ; hors d'une ListView, la rangée garde sa largeur implicite, n'est jamais courante ni
// sélectionnée par currentIndex, et se comporte comme si son groupe avait le focus ; avant le chargement des
// tokens, les cotes sont nulles et les couleurs transparentes. Le clic suppose une Liste : une ListView
// ordinaire ne déclare pas focusClavier, que le clic écrit.
// Dépendances : QtQuick.Templates (ItemDelegate), QtQuick.Layouts, propriétés attachées ListView (view,
// isCurrentItem) et Liste (focusClavier, selectionSuitCourant) ; Theme (density, focus, space), Etat, Texte,
// Icone, etats.js (herite).
// Cotes : hauteur density.rowHeight, retrait horizontal space.scale[2] (12), écart entre icône et libellé
// space.scale[1] (8). Le contour est le premier enfant du fond : la coque d'essai le lit ainsi.
T.ItemDelegate {
    id: rangee

    required property int index
    property string icone
    property bool selectionnee: false
    property bool forcerContour: false

    readonly property alias etat: etat
    // Les propriétés attachées se lisent ici, dans la portée de la rangée : lues dans un enfant, elles
    // viseraient cet enfant, qui n'est pas le délégué.
    readonly property ListView vue: ListView.view
    readonly property bool courante: ListView.isCurrentItem
    readonly property bool contourMontre: forcerContour || courante && (vue?.activeFocus ?? false) && (vue?.focusClavier ?? false)

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

    // La rangée reste au rôle de son conteneur : pas de cran, donc le dnRole hérité tel quel.
    Etat {
        id: etat
        controle: rangee
        role: Etats.herite(rangee, "dnRole", "surfaceWindow")
        selectionne: (rangee.vue?.selectionSuitCourant ?? true) ? rangee.courante : rangee.selectionnee
        focusDansGroupe: rangee.vue?.activeFocus ?? true
    }

    background: Rectangle {
        color: etat.fond

        // Contour de focus : sans fond, pleine largeur, rentré de -rowOffset (−1 donne un pixel vers l'intérieur).
        Rectangle {
            anchors.fill: parent
            anchors.margins: -(Theme.focus?.rowOffset ?? 0)
            visible: rangee.contourMontre
            color: "transparent"
            border.width: Theme.focus?.width ?? 0
            border.color: (etat.inactif ? Theme.focus?.colorMuted : Theme.focus?.color) ?? "transparent"
        }
    }

    contentItem: RowLayout {
        spacing: Theme.space?.scale[1] ?? 0

        Icone {
            nom: rangee.icone
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
