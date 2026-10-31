import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import "../Theme"
import "../Composants"

// Encoche — forme de la presqu'île : l'encoche continue qui descend du bord haut de l'écran (variante D de la
// planche forme.html), peinte dans la matière E3 de la coque.
// Rôle : trace, à partir de quatre dimensions, un bord haut plein sur toute la largeur ; de chaque côté, une cubique
// qui part tangente au bord haut et plonge dans le flanc du corps ; un flanc vertical ; un angle bas continu (une
// cubique tangente au flanc et au bas, plus douce qu'un quart de cercle) ; le bas du corps. Le tracé remplit la
// matière E3 (Materiau rendu en texture : reflet tramé, liserés d'un pixel physique, verre le jour) et la même
// silhouette, floutée, donne l'ombre portée : reflet, liserés et ombre épousent la courbe, évasements compris.
// Le tracé est une liaison : changer largeurCorps ou hauteur le redessine sans autre intervention (étirement par
// ressorts, conception § 5). Rien ne s'anime de soi-même : la texture et le flou ne se recalculent qu'au changement.
// Entrées : largeurCorps, largeur du corps sans les évasements, 0 par défaut ; hauteur, evasement, rayon, lus dans
//           Theme.tokens.presquile par défaut (28, 13 et 10 px logiques) ; verre, vrai pour la forme d'une fenêtre de
//           coque, que le compositeur floute, vrai par défaut comme les autres surfaces de coque.
// Sorties : implicitWidth, largeurCorps + 2 × evasement ; implicitHeight, hauteur ; corps, rectangle du corps sans
//           les évasements, masque de saisie de la surface ; trace, tracé SVG de la forme, lu par les essais ; marge,
//           débord de l'ombre sur les côtés et le bas (portée plus décalage, 0 sans ombre), à réserver dans la
//           fenêtre qui porte la forme.
// Géométrie : sur la planche (132 × 34, évasement 13, rayon 10), l'évasement est la cubique 0 0 → 13 12, de
//           poignées 8 0 et 12 3 : ses ordonnées et abscisses sont des fractions de l'évasement (8, 12 et 3
//           treizièmes, creux de 12 treizièmes). L'angle bas s'étend sur 1,4 × rayon (14), de poignées 9/14 et 10/14
//           de son étendue : ces rapports redonnent exactement le tracé validé (tests/test_presquile.py). L'étendue
//           de l'angle est bornée par la moitié du corps et par la hauteur sous le creux, pour qu'une forme étroite
//           ou basse reste fermée.
// Erreurs : aucune ; avant le chargement des tokens, les dimensions sont nulles et rien n'est peint.
// Dépendances : QtQuick.Shapes (ShapePath.fillItem, Qt 6.8 et plus), QtQuick.Effects (MultiEffect), Theme (tokens,
//               elevation, material), Materiau (niveau e3).
Item {
    id: encoche

    property real largeurCorps: 0
    property real hauteur: Theme.tokens?.presquile?.hauteur ?? 0
    property real evasement: Theme.tokens?.presquile?.evasement ?? 0
    property real rayon: Theme.tokens?.presquile?.rayon ?? 0
    property bool verre: true
    readonly property Item corps: corps
    readonly property bool ombree: !!Theme.elevation?.e3?.shadow
    readonly property real marge: ombree
        ? (Theme.material?.shadowBlur ?? 0) + Math.abs(Theme.material?.shadowOffsetY ?? 0) : 0
    readonly property string trace: tracer(largeurCorps, hauteur, evasement, rayon)

    implicitWidth: largeurCorps + 2 * evasement
    implicitHeight: hauteur

    // tracer — tracé SVG de l'encoche continue, du coin haut gauche, dans le sens des aiguilles d'une montre.
    // Entrées : l, largeur du corps ; h, hauteur ; e, évasement ; r, rayon des angles du bas (px logiques).
    // Sortie : chaîne de chemin SVG (M, H, C, V, Z), en px logiques depuis le coin haut gauche de l'encoche.
    // Erreurs : aucune ; des dimensions nulles donnent un tracé vide de surface. Dépendances : aucune.
    function tracer(l: real, h: real, e: real, r: real): string {
        const w = l + 2 * e, creux = 12 * e / 13, a = Math.max(0, Math.min(1.4 * r, l / 2, h - creux))
        return `M0 0 H${w} C${w - 8 * e / 13} 0 ${w - 12 * e / 13} ${3 * e / 13} ${w - e} ${creux} V${h - a} `
            + `C${w - e} ${h - 5 * a / 14} ${w - e - 4 * a / 14} ${h} ${w - e - a} ${h} H${e + a} `
            + `C${e + 4 * a / 14} ${h} ${e} ${h - 5 * a / 14} ${e} ${h - a} V${creux} `
            + `C${12 * e / 13} ${3 * e / 13} ${8 * e / 13} 0 0 0 Z`
    }

    Item {
        id: corps
        x: encoche.evasement
        width: encoche.largeurCorps
        height: encoche.hauteur
    }

    // Matière E3 sur tout le rectangle de l'encoche, rendue en texture et jamais montrée telle quelle : la forme
    // s'en remplit. Son opacité de verre n'entre pas dans la texture ; la forme la reprend.
    Materiau {
        id: matiere
        anchors.fill: parent
        niveau: "e3"
        verre: encoche.verre
        visible: false
        layer.enabled: true
    }

    // Silhouette de l'ombre : la forme pleine, de la teinte d'ombrage, que l'effet floute et décale.
    Shape {
        id: silhouette
        anchors.fill: parent
        visible: false
        layer.enabled: true
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeWidth: -1
            fillColor: Theme.material?.shade ?? "transparent"
            PathSvg { path: encoche.trace }
        }
    }

    // Ombre portée, des jetons de l'ombre flottante (OmbreElevation). Le flou de MultiEffect ne porte qu'à environ la
    // moitié de blurMax : le doubler redonne, mesuré sur capture, le profil de RectangularShadow à la même portée.
    MultiEffect {
        anchors.fill: parent
        source: silhouette
        visible: encoche.ombree
        blurEnabled: true
        blur: 1
        blurMax: 2 * (Theme.material?.shadowBlur ?? 0)
        autoPaddingEnabled: true
        transform: Translate { y: Theme.material?.shadowOffsetY ?? 0 }
    }

    // La forme visible : le tracé rempli de la texture de la matière, à l'opacité du verre.
    Shape {
        anchors.fill: parent
        opacity: matiere.opacite
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeWidth: -1
            fillItem: matiere
            PathSvg { path: encoche.trace }
        }
    }
}
