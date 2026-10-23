import QtQuick
import QtQuick.Shapes
import QtQuick.Templates as T
import Quickshell
import "../Theme"

// Case — case à cocher de la coque : une boîte suivie de son libellé.
// Rôle : habille le gabarit sans style T.CheckBox (conception, § 7.1), à la forme de macOS (§ 7.10). La boîte
// prend le fond de son Etat, un cran au-dessus du conteneur ; décochée, elle est cernée d'un filet d'un pixel
// physique à color.borderDefault, qui la détache du fond ; cochée, elle est sélectionnée : l'accent, ou l'accent
// sans chroma sous le modificateur inactive (§ 7.5), sans filet, et la coche au sur-accent. La coche est
// l'indice non coloré : l'état ne se lit jamais par la couleur seule (bible, annexe E). Elle est dessinée par un
// tracé vectoriel à la manière de macOS (QtQuick.Shapes, extrémités et jonctions arrondies), et non tirée du
// thème d'icônes, dont la coche ne convient pas (§ 7.10). Le glyphe appartient au contrôle et ne se règle pas par
// instance : ses points et l'épaisseur de son trait sont des fractions du côté de la boîte, qui le suivent
// d'une densité à l'autre, et non des cotes. Un état mixte (tiret) viendra par le même moyen. L'anneau de focus
// entoure la boîte, sur visualFocus ; un clic ne vole pas le focus d'un champ (focusPolicy Qt.TabFocus, § 7.3).
// Entrées : text, checked et le reste de l'API de T.CheckBox.
// Sorties : etat, l'Etat de la boîte (rôle, interaction, sélection, couleurs).
// Erreurs : aucune ; avant le chargement des tokens, les cotes sont nulles et les couleurs transparentes.
// Dépendances : QtQuick.Templates, QtQuick.Shapes (moteur CurveRenderer, lissé sans multiéchantillonnage),
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

        // La coche, en deux segments : du quart gauche au creux, puis du creux au coin haut droit. Le trait vaut
        // un huitième du côté (2 px pour une boîte de 16).
        Shape {
            id: coche

            readonly property color couleur: etat.texte
            readonly property real c: width

            objectName: "glyphe"
            anchors.fill: parent
            visible: caseACocher.checked
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeColor: coche.couleur
                strokeWidth: coche.c / 8
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                startX: coche.c * 0.27; startY: coche.c * 0.53
                PathLine { x: coche.c * 0.43; y: coche.c * 0.69 }
                PathLine { x: coche.c * 0.74; y: coche.c * 0.32 }
            }
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
