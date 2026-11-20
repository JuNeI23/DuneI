import QtQuick
import Quickshell
import "../Theme"
import "etats.js" as Etats

// Valeur — valeur d'adresse en police mono, que le clic copie : « Copié » la remplace en fondu pendant
// motion.delays.copied.
// Rôle : retour visuel de la copie d'une valeur (adresse IP, passerelle, DNS, MAC) dans une rangée de réglage.
// Bible, « Les six états » : survol par le curseur main. Clavier (bible, « Clavier ») : une valeur copiable est un
// arrêt de tabulation, Entrée et Espace la copient ; un clic ne prend pas le focus. Une valeur copiable suit le
// curseur de sa vue (L2-73) : survolée ou atteinte au clavier, elle porte la plaque du curseur, l'aplat d'accent
// (Etat.curseurAplat) au rayon radius.control, débordant de space.scale[0] autour du texte, et sa valeur comme
// « Copié » passent alors à l'encre de la plaque, en fondu ; aucun contour de focus. Hors du curseur, la plaque est
// transparente et le texte garde sa couleur.
// Entrées : text ; copiable, vrai par défaut ; couleur, texte secondaire par défaut ; echelon (2) ; largeurMax,
// largeur au-delà de laquelle le texte est tronqué au milieu (ElideMiddle), illimitée par défaut ; mono, vrai par
// défaut (police mono des adresses) : faux, la valeur prend la police de l'interface en graisse moyenne et chiffres
// tabulaires, comme les tuiles de mesure de la fenêtre Réseau.
// Sorties : copie, vrai tant que « Copié » tient la place ; fin, le minuteur de ce retour ; etat, l'Etat de la
// plaque ; plaque, le rectangle peint (lus par les essais) ; hovered, visualFocus (le focus actif, qui ne vient que du
// clavier) et down (toujours faux), lus par l'Etat ; dnSurPlaque, vrai sous le curseur.
// Fonction copier : copie text dans le presse-papiers et arme le retour ; sans entrée ni sortie. Erreurs : aucune ;
// sous Wayland, le presse-papiers n'est rempli que si une fenêtre de la coque a le focus, ce qu'assure le clic.
// Fondu : motion.rules.reduced_fade_ms, le seul jeton de fondu. Dépendances : Quickshell (clipboardText), Theme
// (typo.mono, police, color, space, radius.control, motion.delays.copied, ColorSpring), Etat, VueCurseur (par Etat),
// etats.js (cran, herite).
Item {
    id: valeur

    property string text
    property int echelon: 2
    property bool copiable: true
    property color couleur: Theme.color?.textSecondary ?? "transparent"
    property bool copie: false
    property real largeurMax: Infinity
    property bool mono: true
    readonly property alias fin: fin
    readonly property alias etat: etat
    readonly property alias plaque: plaque
    readonly property bool hovered: survol.hovered
    readonly property bool visualFocus: activeFocus
    readonly property bool down: false
    readonly property bool dnSurPlaque: etat.sousCurseur

    implicitWidth: Math.min(Math.max(t.implicitWidth, c.implicitWidth), Math.max(largeurMax, 0))
    implicitHeight: t.implicitHeight
    width: implicitWidth
    height: implicitHeight

    // copier — copie la valeur et montre « Copié » jusqu'à la fin du minuteur. Entrées et sorties : aucune.
    // Erreurs : aucune. Dépendances : Quickshell.clipboardText, fin.
    function copier() {
        Quickshell.clipboardText = text
        copie = true
        fin.restart()
    }

    Text {
        id: t
        anchors.right: parent.right
        width: Math.min(implicitWidth, valeur.width)
        elide: Text.ElideMiddle
        text: valeur.text
        font: valeur.mono ? Qt.font({family: Theme.typo?.mono ?? "", pixelSize: Theme.typo?.scale[valeur.echelon] ?? 0})
                          : Theme.police(valeur.echelon, true, true)
        color: encreValeur.value
        opacity: valeur.copie ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: Theme.motion?.rules?.reduced_fade_ms ?? 0 } }
    }
    Text {
        id: c
        anchors.right: parent.right
        anchors.verticalCenter: t.verticalCenter
        text: "Copié"
        font: Theme.police(valeur.echelon, true, false)
        color: encreCopie.value
        opacity: valeur.copie ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.motion?.rules?.reduced_fade_ms ?? 0 } }
    }
    // Plaque du curseur, sous le texte (z), et ses couleurs, un cran au-dessus du conteneur : transparente hors du
    // curseur. Elles suivent les deux textes, premiers enfants, que la coque d'essai lit ainsi.
    Etat {
        id: etat
        controle: valeur
        role: Etats.cran(Etats.herite(valeur, "dnRole", "surfaceWindow"))
        suitCurseur: valeur.copiable
        curseurAplat: true
        fondReposTransparent: true
        fondSurvolTransparent: true
    }
    Rectangle {
        id: plaque
        anchors.fill: parent
        anchors.margins: -(Theme.space?.scale[0] ?? 0)
        z: -1
        radius: Theme.radius?.control ?? 0
        color: etat.fond
    }
    // Encres de la valeur et de « Copié » : leur couleur hors du curseur, le texte de l'état (le sur-accent) sous lui.
    ColorSpring { id: encreValeur; target: etat.sousCurseur ? etat.texte : valeur.couleur }
    ColorSpring {
        id: encreCopie
        target: etat.sousCurseur ? etat.texte : Theme.color?.accentStandalone ?? "transparent"
    }

    activeFocusOnTab: copiable
    Keys.onPressed: event => {
        event.accepted = copiable && [Qt.Key_Return, Qt.Key_Enter, Qt.Key_Space].includes(event.key)
        if (event.accepted && !event.isAutoRepeat) copier()
    }
    HoverHandler { id: survol; enabled: valeur.copiable; cursorShape: Qt.PointingHandCursor }
    TapHandler { enabled: valeur.copiable; onTapped: valeur.copier() }
    Timer { id: fin; interval: Theme.motion?.delays?.copied ?? 0; onTriggered: valeur.copie = false }
}
