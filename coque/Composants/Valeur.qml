import QtQuick
import Quickshell
import "../Theme"

// Valeur — valeur d'adresse en police mono, que le clic copie : « Copié » la remplace en fondu pendant
// motion.delays.copied.
// Rôle : retour visuel de la copie d'une valeur (adresse IP, passerelle, DNS, MAC) dans une rangée de réglage.
// Bible, « Les six états » : survol par le curseur main, jamais de changement de couleur du texte.
// Entrées : text ; copiable, vrai par défaut ; couleur, texte secondaire par défaut ; echelon (2).
// Sorties : copie, vrai tant que « Copié » tient la place ; fin, le minuteur de ce retour (lu par les essais).
// Fonction copier : copie text dans le presse-papiers et arme le retour ; sans entrée ni sortie. Erreurs : aucune ;
// sous Wayland, le presse-papiers n'est rempli que si une fenêtre de la coque a le focus, ce qu'assure le clic.
// Fondu : motion.rules.reduced_fade_ms, le seul jeton de fondu. Dépendances : Quickshell (clipboardText), Theme
// (typo.mono, police, color, motion.delays.copied).
Item {
    id: valeur

    property string text
    property int echelon: 2
    property bool copiable: true
    property color couleur: Theme.color?.textSecondary ?? "transparent"
    property bool copie: false
    readonly property alias fin: fin

    implicitWidth: Math.max(t.implicitWidth, c.implicitWidth)
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
    HoverHandler { enabled: valeur.copiable; cursorShape: Qt.PointingHandCursor }
    TapHandler { enabled: valeur.copiable; onTapped: valeur.copier() }
    Timer { id: fin; interval: Theme.motion?.delays?.copied ?? 0; onTriggered: valeur.copie = false }
}
