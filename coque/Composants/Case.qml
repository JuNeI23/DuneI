import QtQuick
import QtQuick.Templates as T
import Quickshell
import "../Theme"

// Case — case à cocher de la coque : une boîte suivie de son libellé.
// Rôle : habille le gabarit sans style T.CheckBox (conception, § 7.1), à la forme de macOS (§ 7.10). La boîte
// prend le fond de son Etat, un cran au-dessus du conteneur ; décochée, elle est cernée d'un filet d'un pixel
// physique à color.borderDefault, qui la détache du fond ; cochée, elle est sélectionnée : l'accent, ou l'accent
// sans chroma sous le modificateur inactive (§ 7.5), sans filet, et la coche au sur-accent. La coche est
// l'indice non coloré : l'état ne se lit jamais par la couleur seule (bible, annexe E). C'est la Coche partagée,
// tracé vectoriel à la manière de macOS et non icône du thème (§ 7.10), dont les points et le trait sont des
// fractions du côté de la boîte. Un état mixte (tiret) viendra par le même moyen. L'anneau de focus
// entoure la boîte, sur visualFocus ; un clic ne vole pas le focus d'un champ (focusPolicy Qt.TabFocus, § 7.3).
// Entrées : text, checked et le reste de l'API de T.CheckBox.
// Sorties : etat, l'Etat de la boîte (rôle, interaction, sélection, couleurs).
// Erreurs : aucune ; avant le chargement des tokens, les cotes sont nulles et les couleurs transparentes.
// Dépendances : QtQuick.Templates, Coche (le tracé de la coche),
// Quickshell (propriété attachée QsWindow : rapport de pixels de la fenêtre, pour le filet ; 1 hors de toute
// fenêtre), Theme (density, radius, space, stateColors, color, hairline), Etat, AnneauFocus, Texte.
// Cotes : boîte de density.checkSize, rayon radius.small, filet Theme.hairline ; écart entre la boîte et le
// libellé space.scale[1] (8).
T.CheckBox {
    id: caseACocher

    readonly property alias etat: etat

    focusPolicy: Qt.TabFocus
    implicitWidth: implicitContentWidth + leftPadding + rightPadding
    implicitHeight: Math.max(Theme.density?.controlHeight ?? 0, implicitIndicatorHeight + topPadding + bottomPadding)
    spacing: Theme.space?.scale[1] ?? 0

    Etat {
        id: etat
        controle: caseACocher
        selectionne: caseACocher.checked
    }

    indicator: Rectangle {
        x: caseACocher.leftPadding
        y: caseACocher.topPadding + (caseACocher.availableHeight - height) / 2
        implicitWidth: Theme.density?.checkSize ?? 0
        implicitHeight: implicitWidth
        radius: Theme.radius?.small ?? 0
        color: etat.fond
        border.width: caseACocher.checked ? 0 : Theme.hairline(QsWindow.window?.devicePixelRatio ?? 1) ?? 0
        border.color: Theme.color?.borderDefault ?? "transparent"

        // La coche dessinée, commune au menu du Deroulant : visible seulement cochée, au sur-accent.
        Coche {
            anchors.fill: parent
            visible: caseACocher.checked
            couleur: etat.texte
        }

        AnneauFocus {
            cible: parent
            montre: caseACocher.visualFocus
            inactif: etat.inactif
        }
    }

    // Le libellé se tient sur le conteneur, hors de la boîte : il prend le texte non sélectionné du même état,
    // ce qui le ternit seulement quand la case est désactivée.
    contentItem: Texte {
        leftPadding: caseACocher.indicator.width + (caseACocher.text ? caseACocher.spacing : 0)
        text: caseACocher.text
        color: Theme.stateColors(etat.role, "none", etat.interaction)?.text ?? "transparent"
        verticalAlignment: Text.AlignVCenter
    }
}
