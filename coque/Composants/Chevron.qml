import QtQuick
import QtQuick.Shapes

// Chevron — chevron dessiné de la coque : vers le haut, vers le bas, ou le double chevron haut-bas de macOS.
// Rôle : trace un ou deux chevrons par un chemin vectoriel (QtQuick.Shapes, extrémités et jonctions arrondies),
// pour le stepper du Compteur (un chevron par demi-bouton) et pour le Deroulant (le double chevron d'un bouton
// contextuel de macOS, conception, § 7.10). Le glyphe se dessine dans le plus grand carré centré dans l'élément ;
// ses points et son trait sont des fractions du côté c de ce carré, et non des cotes : un chevron seul occupe la
// moitié centrale de la largeur et un quart de la hauteur ; le double chevron, plus étroit (deux cinquièmes de la
// largeur, un cinquième de la hauteur chacun), pose ses chevrons à trois et sept dixièmes de la hauteur, si bien
// qu'un cinquième du côté les sépare et qu'ils ne se lisent pas comme un losange ; le trait vaut un dixième du
// côté.
// Entrées : sens, "haut", "bas" ou "double", "haut" par défaut ; couleur, couleur du trait, transparente par
// défaut ; width et height, la zone où le glyphe se centre.
// Sorties : objectName « chevron », par lequel les essais le retrouvent.
// Erreurs : aucune ; un sens inconnu dessine le chevron haut ; une zone nulle ne dessine rien.
// Dépendances : QtQuick.Shapes (moteur CurveRenderer, lissé sans multiéchantillonnage).
Shape {
    id: chevron

    property string sens: "haut"
    property color couleur: "transparent"
    readonly property real c: Math.min(width, height)
    readonly property bool jumele: sens === "double"
    // Origine du carré centré, demi-hauteur et demi-largeur d'un chevron.
    readonly property real x0: (width - c) / 2
    readonly property real y0: (height - c) / 2
    readonly property real a: jumele ? c / 10 : c / 8
    readonly property real l: jumele ? c / 5 : c / 4

    objectName: "chevron"
    preferredRendererType: Shape.CurveRenderer

    // Trait — un chevron de sommet (c / 2, centre ± a) et de demi-largeur l, pointé vers le haut si pointe vaut -1,
    // vers le bas si elle vaut 1. Composant en ligne : il ne lit que ses propriétés et l'élément chevron passé en
    // entrée. Entrées : forme, le Chevron qui le porte ; centre, ordonnée du milieu du chevron dans le carré ; pointe,
    // -1 ou 1. Sortie : un ShapePath. Erreurs : aucune. Dépendances : ShapePath, PathLine.
    component Trait: ShapePath {
        required property Item forme
        required property real centre
        required property int pointe

        strokeColor: forme.couleur
        strokeWidth: forme.c / 10
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap
        joinStyle: ShapePath.RoundJoin
        startX: forme.x0 + forme.c / 2 - forme.l; startY: forme.y0 + centre - pointe * forme.a
        PathLine { x: forme.x0 + forme.c / 2; y: forme.y0 + centre + pointe * forme.a }
        PathLine { x: forme.x0 + forme.c / 2 + forme.l; y: forme.y0 + centre - pointe * forme.a }
    }

    Trait {
        forme: chevron
        centre: chevron.jumele ? chevron.c * 3 / 10 : chevron.c / 2
        pointe: chevron.sens === "bas" ? 1 : -1
    }

    // Le second trait, chevron bas du double chevron, n'est peint que pour ce sens.
    Trait {
        forme: chevron
        centre: chevron.c * 7 / 10
        pointe: 1
        strokeColor: chevron.jumele ? chevron.couleur : "transparent"
    }
}
