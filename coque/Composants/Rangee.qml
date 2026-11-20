import QtQuick
import QtQuick.Layouts
import QtQuick.Templates as T
import "../Theme"
import "etats.js" as Etats

// Rangee — rangée d'une Liste : libellé, icône facultative, sélection et curseur.
// Rôle : habille le gabarit sans style T.ItemDelegate (conception, § 7.1). La rangée prend le rôle de son conteneur,
// sans cran (§ 7.4). Elle est sélectionnée quand elle est la rangée courante, ou, si la liste ne fait pas suivre la
// sélection, quand l'appelant pose selectionnee (§ 7.5). Elle suit le curseur de sa vue (Etat.suitCurseur) : survolée,
// elle le prend et, dans une Liste, devient la rangée courante, comme dans un menu de macOS ; la Liste le lui donne
// aussi au clavier. Dans une Liste, la rangée ne peint pas son fond : la plaque de la liste se tient sous la rangée
// courante, à l'accent sous le curseur, au fond neutre controlRaised sinon, et le libellé de la rangée sous le curseur
// passe en onAccent (couleurs de la sélection active). Hors d'une Liste (seule dans un popover, ou dans un Repeater),
// la rangée garde son propre fond, une pastille arrondie en retrait des bords à la manière de macOS (§ 7.10) : l'aplat
// d'accent de la plaque sous le curseur (Etat.curseurAplat), transparente sinon, survolée sans le curseur comprise,
// pour laisser voir le fond de verre ou opaque du conteneur au lieu d'en repeindre la couleur (une sélection fournie y
// garde le fond neutre de la clé « inactive »). Dans une colonne de navigation (Liste.navigation), la rangée
// sélectionnée prend un fond neutre levé d'un cran (controlRaised, Etat.selectionNeutre) et son libellé passe en
// graisse moyenne. Aucun contour ni anneau de focus : le curseur suffit (L2-73). Sous le curseur, la rangée déclare
// dnSurPlaque : un contrôle allumé qu'elle porte s'inverse sur la plaque (Etat.inverseSurPlaque). La rangée n'accepte
// aucun focus : la liste est l'unique arrêt. Un clic en fait la rangée courante, donne le focus à la liste sans le
// compter comme clavier, puis émet active().
// Entrées : index, requis, rang dans le modèle (fourni par la ListView) ; text, libellé ; icone, nom
// freedesktop d'une icône symbolique, vide par défaut (pas d'icône) ; selectionnee, sélection fournie par
// l'appelant quand la liste ne la fait pas suivre currentIndex ; accessoire, composant facultatif posé en tête
// de la rangée, avant l'icône, comme la colonne des coches d'un menu de macOS (le Deroulant y pose sa Coche) ;
// null par défaut ; suffixe, composant facultatif posé en fin de rangée, après le libellé (le popover réseau y pose
// « Connexion… », l'indicateur d'activité et le cadenas), null par défaut ; accentue, libellé à l'accent autonome et en
// graisse moyenne, comme le réseau joint du popover, faux par défaut ; pleine, variante pleine de l'icône
// (Icone.pleine), faux par défaut ; teinteIcone et teinteTexte, couleurs imposées à l'icône et au libellé,
// transparentes par défaut : les couleurs de l'état s'appliquent alors, sinon l'imposée les remplace, en fondu
// (ColorSpring), et elle l'emporte sur accentue.
// Sorties : etat, l'Etat de la rangée (rôle, interaction, sélection, curseur, couleurs) ; dansListe, vrai quand la
// rangée est le délégué d'une Liste ; gras, vrai quand le libellé est en graisse moyenne (par défaut accentue, ou
// rangée sélectionnée d'une colonne de navigation ; l'appelant peut le poser), que suit un contentItem remplacé ;
// fondIcone et fondTexte, les ressorts des couleurs de l'icône et du libellé ; libelle, le Texte du libellé par
// défaut ; glyphe, l'Icone ; dnSurPlaque, vrai sous le curseur ; signal active(), émis au clic et à Entrée (la Liste
// l'émet pour sa rangée courante).
// Erreurs : aucune ; hors d'une ListView, la rangée garde sa largeur implicite et n'est jamais courante ni
// sélectionnée par currentIndex ; avant le chargement des tokens, les cotes sont nulles et les couleurs transparentes.
// Le clic suppose une Liste : une ListView ordinaire ne déclare pas focusClavier, que le clic écrit.
// Dépendances : QtQuick.Templates (ItemDelegate), QtQuick.Layouts, propriétés attachées ListView (view,
// isCurrentItem) et Liste (focusClavier, selectionSuitCourant, navigation, curseurDedans) ; Theme (density, radius,
// space), Etat, Texte, Icone, etats.js (herite).
// Cotes : hauteur density.rowHeight ; pastille en retrait de space.scale[0] (4) des bords, rayon radius.control ;
// retrait horizontal du contenu space.scale[2] (12), soit 8 dans la pastille ; écart entre icône et libellé
// space.scale[1] (8) ; icône de icons.sizes.dense (16), centrée dans la hauteur par la mise en page (§ 7.10, v0.7). La
// pastille est le premier enfant du fond : la coque d'essai la lit ainsi.
T.ItemDelegate {
    id: rangee

    required property int index
    property string icone
    property bool selectionnee: false
    property Component accessoire: null
    property Component suffixe: null
    property bool accentue: false
    property bool pleine: false
    property color teinteIcone: "transparent"
    property color teinteTexte: "transparent"

    readonly property alias etat: etat
    readonly property bool dnSurPlaque: etat.sousCurseur
    readonly property alias fondIcone: fondIcone
    readonly property alias fondTexte: fondTexte
    property bool gras: accentue || (vue?.navigation ?? false) && etat.selectionne
    readonly property alias libelle: libelle
    readonly property alias glyphe: glyphe
    // Les propriétés attachées se lisent ici, dans la portée de la rangée : lues dans un enfant, elles
    // viseraient cet enfant, qui n'est pas le délégué.
    readonly property ListView vue: ListView.view
    readonly property bool courante: ListView.isCurrentItem
    readonly property bool dansListe: vue?.curseurDedans !== undefined

    signal active()

    focusPolicy: Qt.NoFocus
    activeFocusOnTab: false
    width: vue?.width ?? implicitWidth
    implicitWidth: implicitContentWidth + leftPadding + rightPadding
    implicitHeight: Theme.density?.rowHeight ?? 0
    horizontalPadding: Theme.space?.scale[2] ?? 0

    // clic — fait de la rangée la rangée courante, donne le focus à la liste sans le compter comme clavier, puis
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

    // survol — dans une Liste, fait de la rangée survolée la rangée courante, donc la rangée sélectionnée ; l'Etat
    // lui donne le curseur. Entrées : aucune. Sortie : aucune. Erreurs : aucune ; hors d'une Liste, et quand le
    // pointeur quitte la rangée, la rangée courante ne change pas. Dépendances : vue (Liste), dansListe.
    onHoveredChanged: if (hovered && dansListe) vue.currentIndex = index

    // La rangée reste au rôle de son conteneur : pas de cran, donc le dnRole hérité tel quel. Dans une Liste, la
    // plaque peint le fond à sa place ; ailleurs, survolée sans le curseur, elle reste transparente.
    Etat {
        id: etat
        controle: rangee
        role: Etats.herite(rangee, "dnRole", "surfaceWindow")
        selectionne: (rangee.vue?.selectionSuitCourant ?? true) ? rangee.courante : rangee.selectionnee
        suitCurseur: true
        curseurAplat: true
        peintFond: !rangee.dansListe
        fondReposTransparent: true
        fondSurvolTransparent: true
        selectionNeutre: rangee.vue?.navigation ?? false
    }

    // Couleurs de l'icône et du libellé : celles de l'état (ou de l'accent autonome pour un libellé accentué), ou
    // la teinte imposée quand elle n'est pas transparente, en fondu.
    ColorSpring {
        id: fondIcone
        target: rangee.teinteIcone.a > 0 ? rangee.teinteIcone : etat.texte
    }

    ColorSpring {
        id: fondTexte
        target: rangee.teinteTexte.a > 0 ? rangee.teinteTexte
            : rangee.accentue ? Theme.color?.accentStandalone ?? "transparent" : etat.texte
    }

    // Fond : une pastille de sélection et de curseur, premier enfant du fond, en retrait de space.scale[0] de
    // chaque bord et sur toute la hauteur, au rayon radius.control, comme la sélection d'une barre latérale ou d'un
    // menu de macOS (§ 7.10) ; transparente dans une Liste, dont la plaque prend le relais.
    background: Item {
        Rectangle {
            anchors.fill: parent
            anchors.leftMargin: Theme.space?.scale[0] ?? 0
            anchors.rightMargin: anchors.leftMargin
            radius: Theme.radius?.control ?? 0
            color: etat.fond
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
            id: glyphe
            nom: rangee.icone
            taille: Theme.icons?.sizes.dense ?? 0
            pleine: rangee.pleine
            couleur: fondIcone.value
            visible: nom !== ""
        }

        Texte {
            id: libelle
            Layout.fillWidth: true
            text: rangee.text
            moyen: rangee.gras
            color: fondTexte.value
            elide: Text.ElideRight
            verticalAlignment: Text.AlignVCenter
        }

        Loader {
            active: rangee.suffixe !== null
            visible: active
            sourceComponent: rangee.suffixe
        }
    }
}
