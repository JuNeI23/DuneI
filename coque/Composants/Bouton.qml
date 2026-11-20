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
// Hors du curseur, il reste neutre, bouton principal compris. Quand le thème donne un contour aux contrôles blancs
// (controls.outline, au jour), le bouton hors du curseur en est cerné d'un filet d'un pixel physique, comme la case.
// Un bouton destructeur (danger) actif écrit son texte et son icône en color.error sur son fond neutre ; sous le
// curseur, comme la puce danger du lanceur, il se remplit de color.error (pastilles.errorPressed pressé) et son texte
// passe en color.onAccent : jamais de rouge sur la plaque orange. Posé sur la plaque d'une ligne (un ancêtre déclare
// dnSurPlaque), un bouton plat ou destructeur écrit aussi son texte en color.onAccent, en fondu. Ses couleurs passent par deux ColorSpring.
// Entrées : text, clicked et le reste de l'API de T.AbstractButton ; icone, nom freedesktop facultatif, posé
// avant le texte (seule, sans text, le bouton est réduit à son icône) ; principal, vrai pour le bouton par défaut
// d'un dialogue, faux par défaut : il le désigne sans le peindre ; danger, vrai pour une action destructrice, faux
// par défaut.
// Sorties : etat, l'Etat du bouton (rôle, interaction, sélection, couleurs), lu par la planche et les essais ;
// rouge, vrai pour un bouton destructeur actif ; rougePlein, vrai quand il porte en plus le curseur ; teinte,
// la couleur affichée de son texte et de son icône.
// Erreurs : aucune ; avant le chargement des tokens, les cotes sont nulles et les couleurs transparentes.
// Dépendances : QtQuick.Templates, Quickshell (QsWindow : rapport de pixels, pour le filet), Theme (density,
// radius, space, controls, hairline, color.error, color.onAccent, pastilles.errorPressed, ColorSpring), etats.js
// (contoure), Etat, VueCurseur (par Etat), Texte, Icone.
// Cotes : retrait horizontal space.scale[2] (12), écart entre l'icône et le texte space.scale[0] (4) ; icône de
// icons.sizes.dense (16), plus petite que la taille par défaut, à côté du texte (conception, § 7.10, v0.7).
T.AbstractButton {
    id: bouton

    property string icone
    property bool principal: false
    property bool danger: false
    property bool plat: false
    readonly property alias etat: etat

    focusPolicy: Qt.TabFocus
    // Clavier (bible, « Clavier ») : Espace est géré par le gabarit ; Entrée active aussi le bouton qui a le focus,
    // une fois par frappe (la répétition automatique est absorbée).
    Keys.onPressed: event => {
        event.accepted = [Qt.Key_Return, Qt.Key_Enter].includes(event.key)
        if (event.accepted && !event.isAutoRepeat) click()
    }
    implicitWidth: implicitContentWidth + leftPadding + rightPadding
    implicitHeight: Theme.density?.controlHeight ?? 0
    horizontalPadding: Theme.space?.scale[2] ?? 0
    spacing: Theme.space?.scale[0] ?? 0

    Etat {
        id: etat
        controle: bouton
        suitCurseur: true
        curseurAplat: true
        fondReposTransparent: bouton.plat
        fondSurvolTransparent: bouton.plat
    }

    // Couleurs d'un bouton destructeur ; pour un bouton ordinaire, leur cible reste transparente et leurs ressorts ne
    // démarrent jamais (sobriété, D80). Désactivé, le bouton destructeur reprend les couleurs de son état.
    readonly property color teinte: rangee.teinte
    readonly property bool rouge: danger && enabled
    readonly property bool rougePlein: rouge && etat.sousCurseur
    // Vrai quand un ancêtre (la ligne d'une liste) porte la plaque d'accent du curseur : le texte d'un bouton plat ou
    // destructeur s'y écrit au sur-accent (color.onAccent), jamais en neutre ni en rouge sur l'orange.
    readonly property bool surPlaque: Etats.herite(bouton, "dnSurPlaque", false)
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

    background: Rectangle {
        radius: Theme.radius?.control ?? 0
        color: bouton.danger ? fondDanger.value : etat.fond
        border.width: !bouton.plat && Theme.controls?.outline && Etats.contoure(etat.selection) ? Theme.hairline(QsWindow.window?.devicePixelRatio ?? 1) ?? 0 : 0
        border.color: Theme.controls?.outline ?? "transparent"
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
