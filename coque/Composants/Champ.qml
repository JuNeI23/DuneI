import QtQuick
import QtQuick.Templates as T
import "../Theme"
import "etats.js" as Etats

// Champ — champ de saisie de la coque, enfoncé dans son conteneur.
// Rôle : habille le gabarit sans style T.TextField (conception, § 7.1) : fond enfoncé elevation.field.fill,
// plus sombre que le panneau qui le porte et identique dans tous les états ; son rôle est celui du conteneur,
// sans cran (§ 7.4). L'anneau de focus paraît dès que le champ a le focus actif (activeFocus, y compris à la
// souris, § 7.3), en couleur atténuée sous le modificateur inactive. Désactivé, le texte et le texte indicatif
// prennent la couleur de l'état disabled. La sélection est à l'accent et le curseur de texte, d'un pixel
// physique, au texte primaire.
// Entrées : text, placeholderText, accepted et le reste de l'API de T.TextField.
// Sorties : etat, l'Etat du champ (rôle, interaction, couleurs), lu par les essais.
// Erreurs : aucune ; avant le chargement des tokens, les cotes sont nulles et les couleurs transparentes.
// Dépendances : QtQuick.Templates, Theme (density, elevation, radius, space, color, hairline), Etat,
// AnneauFocus, Texte.
// Cotes : hauteur density.controlHeight, rayon radius.control, retrait horizontal space.scale[2] (12).
T.TextField {
    id: champ

    readonly property alias etat: etat

    focusPolicy: Qt.StrongFocus
    implicitWidth: Math.max(implicitBackgroundWidth, contentWidth + leftPadding + rightPadding)
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
        implicitWidth: champ.implicitHeight * 5
        radius: Theme.radius?.control ?? 0
        color: Theme.elevation?.field?.fill ?? "transparent"

        AnneauFocus {
            cible: parent
            montre: champ.activeFocus
            inactif: etat.inactif
        }
    }

    cursorDelegate: Rectangle {
        width: Theme.hairline(Screen.devicePixelRatio) ?? 0
        color: Theme.color?.textPrimary ?? "transparent"
        visible: champ.activeFocus
    }
}
