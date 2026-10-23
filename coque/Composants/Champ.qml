import QtQuick
import QtQuick.Templates as T
import Quickshell
import "../Theme"
import "etats.js" as Etats

// Champ — champ de saisie de la coque, enfoncé dans son conteneur.
// Rôle : habille le gabarit sans style T.TextField (conception, § 7.1), à la forme de macOS (§ 7.10) : fond
// enfoncé elevation.field.fill, plus sombre que le panneau qui le porte et identique dans tous les états, cerné
// d'un filet d'un pixel physique à color.borderSubtle ; son rôle est celui du conteneur, sans cran (§ 7.4).
// L'anneau de focus paraît dès que le champ a le focus actif (activeFocus, y compris à la souris, § 7.3), en
// couleur atténuée sous le modificateur inactive. Désactivé, le texte et le texte indicatif
// prennent la couleur de l'état disabled. La sélection est à l'accent et le curseur de texte, d'un pixel
// physique, au texte primaire ; il ne paraît qu'au focus actif et y clignote comme le curseur natif.
// Entrées : text, placeholderText (texte indicatif, montré tant que le champ est vide), accepted et le reste de
// l'API de T.TextField.
// Sorties : etat, l'Etat du champ (rôle, interaction, couleurs) ; indicatif, le texte indicatif ; tous deux lus
// par les essais.
// Erreurs : aucune ; avant le chargement des tokens, les cotes sont nulles et les couleurs transparentes.
// Dépendances : QtQuick.Templates, Quickshell (propriété attachée QsWindow : rapport de pixels de la fenêtre,
// pour le curseur de texte ; 1 hors de toute fenêtre), Theme (density, elevation, radius, space, color,
// hairline), Etat, AnneauFocus, Qt.styleHints (cursorFlashTime, cadence du clignotement).
// Cotes : largeur implicite density.fieldWidth, fixe, hauteur density.controlHeight, rayon radius.control,
// filet Theme.hairline, retrait horizontal space.scale[2] (12).
T.TextField {
    id: champ

    readonly property alias etat: etat
    readonly property alias indicatif: indicatif

    focusPolicy: Qt.StrongFocus
    implicitWidth: Theme.density?.fieldWidth ?? 0
    implicitHeight: Theme.density?.controlHeight ?? 0
    leftPadding: Theme.space?.scale[2] ?? 0
    rightPadding: leftPadding
    verticalAlignment: TextInput.AlignVCenter
    font.family: Theme.typo?.interface ?? Qt.application.font.family
    font.pixelSize: Theme.typo?.scale[2] ?? Qt.application.font.pixelSize
    font.weight: Theme.typo?.weightRegular ?? Font.Normal
    color: etat.texte
    placeholderTextColor: enabled ? (Theme.color?.textTertiary ?? "transparent") : etat.texte
    selectionColor: Theme.color?.accent ?? "transparent"
    selectedTextColor: Theme.color?.onAccent ?? "transparent"

    // Le champ reste au rôle de son conteneur : pas de cran, donc le dnRole hérité tel quel.
    Etat {
        id: etat
        controle: champ
        role: Etats.herite(champ, "dnRole", "surfaceWindow")
    }

    background: Rectangle {
        radius: Theme.radius?.control ?? 0
        color: Theme.elevation?.field?.fill ?? "transparent"
        border.width: Theme.hairline(QsWindow.window?.devicePixelRatio ?? 1) ?? 0
        border.color: Theme.color?.borderSubtle ?? "transparent"

        AnneauFocus {
            cible: parent
            montre: champ.activeFocus
            inactif: etat.inactif
        }
    }

    // Texte indicatif : T.TextField n'en dessine aucun. Il occupe la zone de saisie tant que le champ est vide,
    // dans la police du champ et à placeholderTextColor.
    Text {
        id: indicatif
        x: champ.leftPadding
        width: champ.availableWidth
        height: champ.height
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        text: champ.placeholderText
        color: champ.placeholderTextColor
        font: champ.font
        visible: !champ.length && !champ.preeditText
    }

    // Curseur de texte. TextInput place le délégué (position, hauteur) mais n'en pilote ni la visibilité ni le
    // clignotement, réservés à son curseur natif : le délégué suit donc cursorVisible, que TextInput lève au focus
    // actif hors lecture seule, et clignote lui-même à la demi-période de Qt.styleHints.cursorFlashTime, comme le
    // curseur natif (aucun clignotement si elle est nulle) ; il se rallume à chaque déplacement du curseur.
    cursorDelegate: Rectangle {
        id: curseur

        property bool allume: true

        objectName: "curseur"
        width: Theme.hairline(QsWindow.window?.devicePixelRatio ?? 1) ?? 0
        color: Theme.color?.textPrimary ?? "transparent"
        visible: champ.cursorVisible && allume

        Timer {
            id: clignotement
            interval: Qt.styleHints.cursorFlashTime / 2
            running: champ.cursorVisible && interval > 0
            repeat: true
            onTriggered: curseur.allume = !curseur.allume
            onRunningChanged: curseur.allume = true
        }

        Connections {
            target: champ
            function onCursorPositionChanged() {
                curseur.allume = true
                if (clignotement.running) clignotement.restart()
            }
        }
    }
}
