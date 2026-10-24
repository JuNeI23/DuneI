import QtQuick
import QtQuick.Templates as T
import Quickshell
import "../Theme"

// Curseur — curseur horizontal de la coque : une piste, sa partie remplie et une poignée.
// Rôle : habille le gabarit sans style T.Slider (conception, § 7.1), qui fournit les flèches du clavier et le
// glissement, à la forme de macOS (§ 7.10). La piste, en pilule, est au fond du bureau (elevation.e0, bible :
// « piste à E0 ») ; la partie remplie, de l'origine au centre de la poignée, est à l'accent, ou à l'accent sans
// chroma sous le modificateur inactive (§ 7.5) ; la poignée, ronde et claire, prend le rôle color.knob du thème
// actif, et knob.disabled, précalculé par l'émetteur, quand le curseur est désactivé. L'anneau de focus entoure
// la poignée, sur visualFocus ; un clic ne vole pas le focus d'un champ (focusPolicy
// Qt.TabFocus, § 7.3).
// Entrées : value, from, to, stepSize et le reste de l'API de T.Slider ; l'orientation verticale n'est pas
// habillée.
// Sorties : etat, l'Etat de la poignée (rôle, interaction, sélection, couleurs) ; down, copie de pressed, que
// lit Etats.interaction (T.Slider n'a pas de down) ; poignee, diamètre de la poignée.
// Erreurs : aucune ; avant le chargement des tokens, les cotes sont nulles et les couleurs transparentes.
// Quand le thème traite les contrôles blancs (au jour), la poignée est cernée du contour controls.outline et porte
// l'ombre controls.shadow, qui la détachent de la piste et du fond.
// Dépendances : QtQuick.Templates, Quickshell (QsWindow : rapport de pixels, pour le filet), Theme (density,
// elevation, stateColors, color.knob, knob.disabled, controls, hairline), Etat, AnneauFocus, OmbreControle.
// Cotes : largeur implicite density.sliderWidth, piste de density.sliderTrack d'épaisseur, poignée de
// density.sliderHandle ; rayons en demi-hauteur.
T.Slider {
    id: curseur

    readonly property alias etat: etat
    readonly property bool down: pressed
    readonly property real poignee: Theme.density?.sliderHandle ?? 0

    focusPolicy: Qt.TabFocus
    implicitWidth: Theme.density?.sliderWidth ?? 0
    implicitHeight: Theme.density?.controlHeight ?? 0

    Etat {
        id: etat
        controle: curseur
        role: "controlRaised"
    }

    background: Rectangle {
        x: curseur.leftPadding
        y: curseur.topPadding + (curseur.availableHeight - height) / 2
        width: curseur.availableWidth
        height: Theme.density?.sliderTrack ?? 0
        radius: height / 2
        color: Theme.elevation?.e0.fill ?? "transparent"

        // La partie remplie, premier enfant de la piste (la coque d'essai le lit ainsi). Désactivé, l'accent
        // prend la couleur désactivée de la sélection.
        Rectangle {
            width: curseur.visualPosition * (curseur.availableWidth - curseur.poignee) + curseur.poignee / 2
            height: parent.height
            radius: height / 2
            color: Theme.stateColors(etat.role, etat.inactif ? "activeMuted" : "active",
                                     etat.interaction === "disabled" ? "disabled" : "rest")?.fill ?? "transparent"
        }
    }

    handle: Rectangle {
        x: curseur.leftPadding + curseur.visualPosition * (curseur.availableWidth - width)
        y: curseur.topPadding + (curseur.availableHeight - height) / 2
        width: curseur.poignee
        height: width
        radius: width / 2
        color: (etat.interaction === "disabled" ? Theme.knob?.disabled : Theme.color?.knob) ?? "transparent"
        border.width: Theme.controls?.outline ? Theme.hairline(QsWindow.window?.devicePixelRatio ?? 1) ?? 0 : 0
        border.color: Theme.controls?.outline ?? "transparent"

        OmbreControle {
            cible: parent
        }

        AnneauFocus {
            cible: parent
            montre: curseur.visualFocus
            inactif: etat.inactif
        }
    }
}
