import QtQuick
import QtQuick.Shapes
import QtQuick.Templates as T
import Quickshell
import "../Theme"

// Radio — bouton radio de la coque : un disque suivi de son libellé, exclusif dans son groupe.
// Rôle : habille le gabarit sans style T.RadioButton (conception, § 7.1), à la forme de macOS (§ 7.10), sous les
// règles de la case. Le disque prend le fond de son Etat, un cran au-dessus du conteneur ; décoché, il est cerné
// d'un filet d'un pixel physique à color.borderDefault ; coché, il est sélectionné : l'accent, ou l'accent sans
// chroma sous le modificateur inactive (§ 7.5), sans filet, et un point central au sur-accent. Le point est
// l'indice non coloré (bible, annexe E) ; il est dessiné par un tracé vectoriel (QtQuick.Shapes), comme la coche
// de la case, et ne se règle pas par instance. L'anneau de focus, rond, entoure le disque sur visualFocus ; un
// clic ne vole pas le focus d'un champ (focusPolicy Qt.TabFocus, § 7.3). Chaque radio est un arrêt de
// tabulation, comme une case.
// Exclusivité : autoExclusive, vrai par défaut dans Qt, rend exclusifs les radios qui partagent un même parent ;
// cocher l'un décoche les autres, et un clic sur le radio coché le laisse coché. Pour des radios dispersés dans
// plusieurs parents, ou mêlés à d'autres boutons, on les déclare dans un ButtonGroup (QtQuick.Controls) par
// ButtonGroup.group.
// Entrées : text, checked, autoExclusive et le reste de l'API de T.RadioButton.
// Sorties : etat, l'Etat du disque (rôle, interaction, sélection, couleurs) ; point, diamètre du point central.
// Erreurs : aucune ; avant le chargement des tokens, les cotes sont nulles et les couleurs transparentes.
// Dépendances : QtQuick.Templates, QtQuick.Shapes (moteur CurveRenderer, lissé sans multiéchantillonnage),
// Quickshell (propriété attachée QsWindow : rapport de pixels de la fenêtre, pour le filet ; 1 hors de toute
// fenêtre), Theme (density, space, color, hairline), Etat, AnneauFocus, Texte.
// Cotes : disque de density.checkSize, point de density.radioDot, filet Theme.hairline ; écart entre le disque
// et le libellé space.scale[1] (8).
T.RadioButton {
    id: radio

    readonly property alias etat: etat
    readonly property real point: Theme.density?.radioDot ?? 0

    focusPolicy: Qt.TabFocus
    implicitWidth: implicitContentWidth + leftPadding + rightPadding
    implicitHeight: Math.max(Theme.density?.controlHeight ?? 0, implicitIndicatorHeight + topPadding + bottomPadding)
    spacing: Theme.space?.scale[1] ?? 0

    Etat {
        id: etat
        controle: radio
        selectionne: radio.checked
    }

    indicator: Rectangle {
        x: radio.leftPadding
        y: radio.topPadding + (radio.availableHeight - height) / 2
        implicitWidth: Theme.density?.checkSize ?? 0
        implicitHeight: implicitWidth
        radius: width / 2
        color: etat.fond
        border.width: radio.checked ? 0 : Theme.hairline(QsWindow.window?.devicePixelRatio ?? 1) ?? 0
        border.color: Theme.color?.borderDefault ?? "transparent"

        // Le point central, un disque plein tracé en un arc complet autour du centre du disque.
        Shape {
            id: rond

            readonly property color couleur: etat.texte

            objectName: "glyphe"
            anchors.fill: parent
            visible: radio.checked
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeColor: "transparent"
                fillColor: rond.couleur
                PathAngleArc {
                    centerX: rond.width / 2
                    centerY: rond.height / 2
                    radiusX: radio.point / 2
                    radiusY: radiusX
                    sweepAngle: 360
                }
            }
        }

        AnneauFocus {
            cible: parent
            montre: radio.visualFocus
            inactif: etat.inactif
        }
    }

    // Le libellé se tient sur le conteneur, hors du disque : il prend le texte non sélectionné du même état, ce
    // qui le ternit seulement quand le radio est désactivé.
    contentItem: Texte {
        leftPadding: radio.indicator.width + (radio.text ? radio.spacing : 0)
        text: radio.text
        color: etat.texteNeutre
        verticalAlignment: Text.AlignVCenter
    }
}
