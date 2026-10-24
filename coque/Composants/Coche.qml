import QtQuick
import QtQuick.Shapes

// Coche — coche dessinée de la coque, à la manière de macOS, partagée par la Case et le menu du Deroulant.
// Rôle : trace la coche par un chemin vectoriel (QtQuick.Shapes, extrémités et jonctions arrondies), et non par
// une icône du thème, dont la coche ne convient pas (conception, § 7.10). Le tracé est en deux segments, du quart
// gauche au creux puis du creux au coin haut droit, et son trait vaut un huitième du côté (2 px pour 16). Le
// glyphe appartient au contrôle et ne se règle pas par instance : ses points et son trait sont des fractions du
// côté du carré qu'on lui donne, qui le suivent d'une densité à l'autre, et non des cotes.
// Entrées : couleur, couleur du trait, transparente par défaut ; width et height, le carré où la coche se dessine
// (le côté retenu est width) ; visible.
// Sorties : couleur, lue par les essais ; objectName « glyphe », par lequel la coque d'essai la retrouve.
// Erreurs : aucune ; un côté nul ne dessine rien.
// Dépendances : QtQuick.Shapes (moteur CurveRenderer, lissé sans multiéchantillonnage).
Shape {
    id: coche

    property color couleur: "transparent"
    readonly property real c: width

    objectName: "glyphe"
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
