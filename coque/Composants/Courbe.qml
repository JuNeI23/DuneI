import QtQuick
import QtQuick.Shapes
import "../Theme"

// Courbe — courbe de séries temporelles de la coque, sans axe ni grille.
// Rôle : trace chaque série en un trait de 1,5 px, de la couleur de la série, sur toute la largeur de l'élément ; les
// échantillons les plus anciens sont à gauche. Une série qui le demande (aire) est remplie sous son trait à 12 %
// d'opacité de sa couleur : l'aire est un second Shape dont on baisse l'opacité (aucune teinte recalculée, les tests
// interdisent Qt.alpha), peint sous le trait. Toutes les séries partagent l'échelle verticale : 0 en bas, maximum en
// haut. Une série de moins de deux échantillons ne trace rien.
// Entrées : series, liste de { valeurs: [nombres], couleur: color, aire: bool } (aire faux par défaut) ; width et height,
// la zone du tracé.
// Sorties : maximum, le plus grand échantillon de toutes les séries, au moins 1 pour que l'échelle ne s'effondre pas ;
// repetiteur, le Repeater des séries, dont chaque élément porte points (les points du trait) et aire, lus par les essais.
// Erreurs : aucune ; un échantillon non numérique est lu comme un zéro dans le tracé et ignoré dans le maximum.
// Dépendances : QtQuick.Shapes (moteur CurveRenderer), Theme (couleurs fournies par l'appelant, jamais en dur ici).
// Cotes : le trait est inscrit dans l'élément (marge d'un demi-trait en haut et en bas) pour n'être jamais rogné.
Item {
    id: courbe

    property var series: []
    readonly property real maximum: series.reduce((m, s) => Math.max(m, ...(s?.valeurs ?? []).map(Number).filter(isFinite)), 1)
    readonly property alias repetiteur: serie
    readonly property real _demi: 0.75

    // points — transforme des valeurs en points du tracé : x réparti sur la largeur, y mis à l'échelle de maximum.
    // Entrées : valeurs, liste de nombres ; ferme, vrai pour fermer le polygone par le bas (aire). Sortie : liste de
    // points, vide sous deux échantillons. Erreurs : aucune. Dépendances : width, height, maximum.
    function points(valeurs: var, ferme: bool): var {
        const n = valeurs?.length ?? 0
        if (n < 2) return []
        const h = height - 2 * _demi
        const p = valeurs.map((v, i) => Qt.point(i * width / (n - 1), _demi + h * (1 - (Number(v) || 0) / maximum)))
        return ferme ? [...p, Qt.point(width, height), Qt.point(0, height)] : p
    }

    Repeater {
        id: serie
        model: courbe.series

        Item {
            id: trace
            required property var modelData
            readonly property var points: courbe.points(modelData?.valeurs, false)
            readonly property bool aire: !!modelData?.aire && points.length > 0
            readonly property alias fond: fond

            anchors.fill: parent

            Shape {
                id: fond
                anchors.fill: parent
                visible: trace.aire
                opacity: 0.12
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeWidth: -1
                    fillColor: modelData?.couleur ?? "transparent"
                    PathPolyline { path: courbe.points(modelData?.valeurs, true) }
                }
            }

            Shape {
                anchors.fill: parent
                visible: trace.points.length > 0
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeWidth: 1.5
                    strokeColor: modelData?.couleur ?? "transparent"
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    joinStyle: ShapePath.RoundJoin
                    PathPolyline { path: trace.points }
                }
            }
        }
    }
}
