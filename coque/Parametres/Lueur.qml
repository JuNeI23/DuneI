import QtQuick
import QtQuick.Shapes

// Lueur — lueur d'une couleur du thème, partie d'un point du bord haut et éteinte à une portée donnée.
// Rôle : remplit un rectangle arrondi d'un dégradé radial, de la couleur pleine au centre au transparent à la
// portée ; l'intensité se règle par l'opacité de l'élément, lue dans un jeton par l'appelant, si bien qu'aucune
// couleur n'est calculée. Sert au halo et au reflet des vignettes et à la lueur des cartes d'en-tête.
// Entrées : teinte, couleur du centre ; centre, abscisse du centre en fraction de la largeur (0 : coin haut gauche) ;
// portee, rayon du dégradé en pixels ; rayon, rayon des coins du rectangle rempli, 0 par défaut ; opacity, l'intensité.
// Sorties : aucune.
// Erreurs : aucune ; une lueur d'opacité nulle n'est pas peinte.
// Dépendances : QtQuick.Shapes (RadialGradient, PathRectangle de Qt 6.8 et plus, moteur CurveRenderer).
Shape {
    id: lueur

    required property color teinte
    required property real portee
    property real centre: 0
    property real rayon: 0

    visible: opacity > 0
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
        strokeWidth: -1
        fillGradient: RadialGradient {
            centerX: lueur.centre * lueur.width; centerY: 0
            focalX: centerX; focalY: 0
            centerRadius: lueur.portee
            GradientStop { position: 0; color: lueur.teinte }
            GradientStop { position: 1; color: "transparent" }
        }
        PathRectangle { width: lueur.width; height: lueur.height; radius: lueur.rayon }
    }
}
