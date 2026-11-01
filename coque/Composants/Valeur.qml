import QtQuick
import Quickshell
import "../Theme"

// Valeur — valeur d'adresse en police mono, que le clic copie : « Copié » la remplace en fondu pendant
// motion.delays.copied.
// Rôle : retour visuel de la copie d'une valeur (adresse IP, passerelle, DNS, MAC) dans une rangée de réglage.
// Bible, « Les six états » : survol par le curseur main, jamais de changement de couleur du texte. Clavier (bible,
// « Clavier ») : une valeur copiable est un arrêt de tabulation, Entrée et Espace la copient, et le contour de focus
// (focus.width, jamais un anneau) ne paraît que pour le focus venu du clavier : un clic ne prend pas le focus.
// Entrées : text ; copiable, vrai par défaut ; couleur, texte secondaire par défaut ; echelon (2) ; largeurMax,
// largeur au-delà de laquelle le texte est tronqué au milieu (ElideMiddle), illimitée par défaut.
// Sorties : copie, vrai tant que « Copié » tient la place ; fin, le minuteur de ce retour (lu par les essais).
// Fonction copier : copie text dans le presse-papiers et arme le retour ; sans entrée ni sortie. Erreurs : aucune ;
// sous Wayland, le presse-papiers n'est rempli que si une fenêtre de la coque a le focus, ce qu'assure le clic.
// Fondu : motion.rules.reduced_fade_ms, le seul jeton de fondu. Dépendances : Quickshell (clipboardText), Theme
// (typo.mono, police, color, focus, radius.control, motion.delays.copied).
Item {
    id: valeur

    property string text
    property int echelon: 2
    property bool copiable: true
    property color couleur: Theme.color?.textSecondary ?? "transparent"
    property bool copie: false
    property real largeurMax: Infinity
    readonly property alias fin: fin

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
        font.family: Theme.typo?.mono ?? ""
        font.pixelSize: Theme.typo?.scale[valeur.echelon] ?? 0
        color: valeur.couleur
        opacity: valeur.copie ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: Theme.motion?.rules?.reduced_fade_ms ?? 0 } }
    }
    Text {
        id: c
        anchors.right: parent.right
        anchors.verticalCenter: t.verticalCenter
        text: "Copié"
        font: Theme.police(valeur.echelon, true, false)
        color: Theme.color?.accentStandalone ?? "transparent"
        opacity: valeur.copie ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.motion?.rules?.reduced_fade_ms ?? 0 } }
    }
    activeFocusOnTab: copiable
    Keys.onPressed: event => {
        event.accepted = copiable && [Qt.Key_Return, Qt.Key_Enter, Qt.Key_Space].includes(event.key)
        if (event.accepted && !event.isAutoRepeat) copier()
    }
    Rectangle {
        readonly property real decalage: Theme.focus?.rowOffset ?? 0
        anchors.fill: parent
        anchors.margins: -decalage
        radius: (Theme.radius?.control ?? 0) + decalage
        visible: valeur.activeFocus
        color: "transparent"
        border.width: Theme.focus?.width ?? 0
        border.color: Theme.focus?.color ?? "transparent"
    }
    HoverHandler { enabled: valeur.copiable; cursorShape: Qt.PointingHandCursor }
    TapHandler { enabled: valeur.copiable; onTapped: valeur.copier() }
    Timer { id: fin; interval: Theme.motion?.delays?.copied ?? 0; onTriggered: valeur.copie = false }
}
