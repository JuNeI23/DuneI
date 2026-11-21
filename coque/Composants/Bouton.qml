import QtQuick
import QtQuick.Templates as T
import Quickshell
import "../Theme"
import "etats.js" as Etats

// Bouton — bouton de la coque, texte et icône facultative sur le fond de son état.
// Rôle : habille le gabarit sans style T.AbstractButton (conception, § 7.1) : fond au rôle un cran au-dessus
// de son conteneur, animé par Etat ; pressé, il descend sous le repos (bible, annexe E) sans se déplacer ni se
// réduire. Un clic ne vole pas le focus d'un champ (focusPolicy Qt.TabFocus, § 7.3). Le bouton suit le curseur de
// sa vue (L2-73) : survolé ou focalisé au clavier, il en porte la marque, l'aplat d'accent de la plaque des listes
// (color.accent et le sur-accent, ou l'accent sans chroma sous le modificateur inactive) ; aucun anneau de focus.
// Hors du curseur, il reste neutre. Quand le thème donne un contour aux contrôles blancs (controls.outline, au jour),
// le bouton non plat porte un filet d'un pixel physique, comme la case : à la couleur du contour hors du curseur, à
// celle du fond visé sous lui, où il se fond dans l'aplat ; sa couleur suit le ressort des états, comme le fond, et son
// épaisseur ne change pas d'un état à l'autre.
// Un bouton destructeur (danger) actif écrit son texte et son icône en color.error sur son fond neutre ; sous le
// curseur, comme la puce danger du lanceur, il se remplit de color.error (pastilles.errorPressed pressé) et son texte
// passe en color.onAccent : jamais de rouge sur la plaque orange. Posé sur la plaque d'une ligne (un ancêtre déclare
// dnSurPlaque), un bouton plat, destructeur ou non, écrit aussi son texte en color.onAccent, en fondu ; un bouton
// plein y garde le fond et le texte de son état, qui le détachent de la plaque. Ses couleurs passent par des
// ColorSpring. Entrées : text, clicked et le reste de l'API de T.AbstractButton ; icone, nom freedesktop
// facultatif, posé avant le texte (seule, sans text, le bouton est réduit à son icône) ; danger, vrai pour une
// action destructrice, faux par défaut ; plat, vrai pour un bouton sans fond hors du curseur, faux par défaut ;
// marque, vrai par défaut : faux, le bouton ne prend jamais le curseur de sa vue ni sa plaque, et reste un lien
// en texte (action d'en-tête d'un popover, recette de L2-73).
// Sorties : etat, l'Etat du bouton (rôle, interaction, sélection, couleurs), lu par la planche et les essais ;
// rouge, vrai pour un bouton destructeur actif ; rougePlein, vrai quand il porte en plus le curseur ; surPlaque, vrai
// pour un bouton plat posé sur la plaque d'un ancêtre ; teinte, la couleur affichée de son texte et de son icône.
// Erreurs : aucune ; avant le chargement des tokens, les cotes sont nulles et les couleurs transparentes.
// Dépendances : QtQuick.Templates, Quickshell (QsWindow : rapport de pixels, pour le filet), Theme (density,
// radius, space, controls, hairline, color.error, color.onAccent, pastilles.errorPressed, ColorSpring), etats.js
// (contoure), Etat, VueCurseur (par Etat), Texte, Icone.
// Cotes : retrait horizontal space.scale[2] (12), écart entre l'icône et le texte space.scale[0] (4) ; icône de
// icons.sizes.dense (16), plus petite que la taille par défaut, à côté du texte (conception, § 7.10, v0.7).
T.AbstractButton {
    id: bouton

    property string icone
    property bool danger: false
    property bool plat: false
    property bool marque: true
    readonly property alias etat: etat

    focusPolicy: Qt.TabFocus
    // Clavier (bible, « Clavier ») : Espace est géré par le gabarit ; Entrée active aussi le bouton qui a le focus,
    // une fois par frappe (la répétition automatique est absorbée), et y ramène le curseur de la vue, comme la
    // pression.
    Keys.onPressed: event => {
        event.accepted = [Qt.Key_Return, Qt.Key_Enter].includes(event.key)
        if (event.accepted && !event.isAutoRepeat) { etat.suivre(true); click() }
    }
    implicitWidth: implicitContentWidth + leftPadding + rightPadding
    implicitHeight: Theme.density?.controlHeight ?? 0
    horizontalPadding: Theme.space?.scale[2] ?? 0
    spacing: Theme.space?.scale[0] ?? 0

    Etat {
        id: etat
        controle: bouton
        suitCurseur: bouton.marque
        curseurAplat: true
        fondReposTransparent: bouton.plat
        fondSurvolTransparent: bouton.plat
    }

    // Couleurs d'un bouton destructeur ; pour un bouton ordinaire, leur cible reste transparente et leurs ressorts ne
    // démarrent jamais (sobriété, D80). Désactivé, le bouton destructeur reprend les couleurs de son état.
    readonly property color teinte: rangee.teinte
    readonly property bool rouge: danger && enabled
    readonly property bool rougePlein: rouge && marque && etat.sousCurseur
    // Vrai quand un ancêtre (la ligne d'une liste) porte la plaque d'accent du curseur sous un bouton plat : son texte
    // s'y écrit au sur-accent (color.onAccent), jamais en neutre ni en rouge sur l'orange. Un bouton plein garde le
    // fond de son état : le sur-accent y serait illisible.
    readonly property bool surPlaque: plat && Etats.herite(bouton, "dnSurPlaque", false)
    ColorSpring {
        id: fondDanger
        target: (!bouton.danger ? "transparent" : bouton.rougePlein
                 ? (bouton.down ? Theme.pastilles?.errorPressed : Theme.color?.error)
                 : bouton.plat ? etat.fond : etat.couleurs?.fill) ?? "transparent"
    }
    ColorSpring {
        id: encreDanger
        target: (!(bouton.danger || bouton.plat) ? "transparent" : bouton.rougePlein || bouton.surPlaque
                 ? Theme.color?.onAccent : bouton.rouge ? Theme.color?.error : etat.couleurs?.text) ?? "transparent"
    }

    // Filet du jour : sa couleur rejoint le contour hors du curseur, le fond visé sous lui ; sans contour (la nuit) ou
    // pour un bouton plat, sa cible reste transparente et le ressort ne démarre jamais (sobriété, D80).
    ColorSpring {
        id: filet
        target: (!Theme.controls?.outline || bouton.plat ? "transparent" : Etats.contoure(etat.selection)
                 ? Theme.controls.outline : bouton.danger ? fondDanger.target : etat.couleurs?.fill) ?? "transparent"
    }

    background: Rectangle {
        radius: Theme.radius?.control ?? 0
        color: bouton.danger ? fondDanger.value : etat.fond
        border.width: !bouton.plat && Theme.controls?.outline
            ? Theme.hairline(QsWindow.window?.devicePixelRatio ?? 1) ?? 0 : 0
        border.color: filet.value
    }

    // L'icône et le texte forment une rangée centrée dans le bouton, quelle que soit sa largeur.
    contentItem: Item {
        implicitWidth: rangee.implicitWidth
        implicitHeight: rangee.implicitHeight

        Row {
            id: rangee
            readonly property color teinte: bouton.danger || bouton.plat ? encreDanger.value : etat.texte
            anchors.centerIn: parent
            spacing: bouton.spacing

            Icone {
                anchors.verticalCenter: parent.verticalCenter
                visible: bouton.icone !== ""
                nom: bouton.icone
                taille: Theme.icons?.sizes.dense ?? 0
                couleur: rangee.teinte
            }

            // Un bouton réduit à son icône n'a pas de texte : l'écart ne le décentre pas.
            Texte {
                anchors.verticalCenter: parent.verticalCenter
                visible: text !== ""
                text: bouton.text
                color: rangee.teinte
            }
        }
    }
}
