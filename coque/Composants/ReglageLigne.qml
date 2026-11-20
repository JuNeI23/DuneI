import QtQuick
import QtQuick.Layouts
import "../Theme"
import "etats.js" as Etats

// ReglageLigne — rangée de réglage d'une Carte de la fenêtre Réseau : médaillon facultatif, titre et aide, contrôle
// à droite, erreur dessous.
// Rôle : aligne titre et aide de toutes les rangées d'une carte sur la même colonne (reglages.textColumn), pour que
// les filets en retrait tombent juste. Bible : « Rangées de liste » (hauteur de rangée, aide sous le titre) ;
// « Interrupteur » et « Compteur » se déclarent comme contrôle de droite ; « Formes » : médaillon et plaque aux rayons
// des jetons. La rangée suit le curseur de sa vue (L2-73) : survolée, ou quand le contrôle qu'elle porte a le focus
// clavier (visualFocus), elle prend la plaque d'accent sur toute sa largeur (l'aplat color.accent, ou l'accent sans
// chroma sous inactive), qui paraît et s'efface au ressort des états ; le contrôle garde ses propres couleurs (un
// interrupteur allumé reste à l'accent) et n'a pas d'anneau de focus. Hors du curseur, la plaque est transparente.
// Sur la plaque, le titre et l'aide passent au sur-accent de l'état, en fondu au même ressort.
// Entrées : titre ; aide ; icone et iconeActive, transmis au Medaillon ; erreur, ligne d'erreur sous la rangée ; le
// contrôle, déclaré comme enfant.
// Sorties : texteX, abscisse de la colonne de texte ; base, hauteur sans l'erreur ; corps, hauteur du corps (base,
// ou celle d'un contrôle plus haut, bordée de space.scale[1]) ; largeurLibre, largeur laissée au contrôle ; survole
// et hovered, la rangée est survolée ; visualFocus, un élément porté par la rangée a le focus clavier ; etat, l'Etat
// de la plaque, lu par les essais.
// Hauteur : reglages.row, ou reglages.rowHelp avec une aide, ou celle du contrôle s'il est plus haut ; l'erreur
// s'ajoute dessous. Le texte sans médaillon reste sur
// la même colonne (rangée alignée). La rangée remplit la largeur de sa Carte (Layout.fillWidth).
// Erreurs : aucune ; avant le chargement des tokens, les cotes sont nulles.
// Dépendances : Medaillon, Texte, Etat, VueCurseur (par Etat), Theme (reglages, space, color, radius, ColorSpring),
// etats.js, QtQuick (propriété attachée Window : activeFocusItem).
Item {
    id: ligne

    property string titre
    property string aide
    property string erreur
    property string icone
    property bool iconeActive: false
    readonly property real gauche: Theme.space?.scale[2] ?? 0
    readonly property real texteX: Theme.reglages?.textColumn ?? 0
    readonly property bool survole: survol.hovered
    readonly property bool hovered: survol.hovered
    readonly property bool down: false
    readonly property bool visualFocus: porte(Window.activeFocusItem)
    readonly property alias etat: etat
    default property alias controle: emplacement.data

    Layout.fillWidth: true

    readonly property real base: (aide !== "" ? Theme.reglages?.rowHelp : Theme.reglages?.row) ?? 0

    // Hauteur du corps de la rangée : base, ou celle d'un contrôle plus haut (valeurs empilées) bordée de space.scale[1].
    readonly property real corps: Math.max(base, emplacement.height + 2 * (Theme.space?.scale[1] ?? 0))
    // Largeur laissée au contrôle : celle de la rangée moins la colonne du libellé, son titre et les retraits.
    readonly property real largeurLibre: width - texteX - titreColonne.width - 2 * gauche

    implicitHeight: corps + (erreur !== "" ? messageErreur.height : 0)

    // porte — dit si un élément focalisé au clavier est porté par la rangée, et le lit dans une liaison réactive.
    // Rôle : remonte les parents de l'élément jusqu'à la rangée ; la liaison relit son visualFocus et sa chaîne de
    // parents, si bien qu'un focus qui passe de la souris au clavier, ou un reparentage, la réévalue.
    // Entrée : item, l'élément qui a le focus actif de la fenêtre, ou null. Sortie : vrai s'il a visualFocus et que
    // la rangée en est un ancêtre. Erreurs : aucune ; null rend faux. Dépendances : aucune.
    function porte(item: Item): bool {
        if (item?.visualFocus !== true) return false
        for (let p = item.parent; p; p = p.parent)
            if (p === ligne) return true
        return false
    }

    HoverHandler { id: survol }
    // La plaque n'existe que pour le curseur : hors de lui, elle est transparente, au survol compris (un survol dont
    // le clavier a repris le curseur ailleurs dans la vue).
    Etat {
        id: etat
        controle: ligne
        role: Etats.cran(Etats.herite(ligne, "dnRole", "surfaceRaised"))
        suitCurseur: true
        curseurAplat: true
        fondReposTransparent: true
        fondSurvolTransparent: true
    }
    // Teinte de l'aide : le texte secondaire hors du curseur, le sur-accent de l'état sous lui.
    ColorSpring {
        id: teinteAide
        target: (etat.sousCurseur ? etat.couleurs?.text : Theme.color?.textSecondary) ?? "transparent"
    }
    Rectangle {
        anchors.fill: parent
        anchors.leftMargin: Theme.reglages?.sidebarInset ?? 0
        anchors.rightMargin: anchors.leftMargin
        radius: Theme.radius?.control ?? 0
        color: etat.fond
    }

    Medaillon {
        x: ligne.gauche
        y: (ligne.base - height) / 2
        visible: ligne.icone !== ""
        nom: ligne.icone
        actif: ligne.iconeActive
    }
    Column {
        id: titreColonne
        x: ligne.texteX
        y: (ligne.base - height) / 2
        Texte { text: ligne.titre; echelon: 2; moyen: true; color: etat.texte }
        Texte {
            visible: ligne.aide !== ""
            text: ligne.aide
            echelon: 0
            color: teinteAide.value
        }
    }
    Item {
        id: emplacement
        anchors.right: parent.right
        anchors.rightMargin: ligne.gauche
        y: (ligne.corps - height) / 2
        width: childrenRect.width
        height: childrenRect.height
    }
    Texte {
        id: messageErreur
        x: ligne.texteX
        y: ligne.corps
        width: ligne.width - ligne.texteX - ligne.gauche
        visible: ligne.erreur !== ""
        text: ligne.erreur
        echelon: 1
        wrapMode: Text.Wrap
        color: Theme.color?.error ?? "transparent"
    }
}
