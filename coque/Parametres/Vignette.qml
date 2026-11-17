import QtQuick
import "../Theme"
import "../Composants"

// Vignette — vignette en « verre » d'une page de réglages : un carré arrondi teinté, son glyphe dans la teinte.
// Rôle : peint, de bas en haut, le fond d'une carte, la teinte mêlée à ce fond, un halo de la teinte parti du coin
// haut gauche, un reflet clair tombant du bord haut, un liseré d'un pixel, puis le glyphe. Les quatre intensités
// viennent de Theme.material.thumb, qui change avec le moment : la nuit donne un verre givré (teinte mêlée et reflet,
// sans halo), le jour un verre à halo (halo et liseré marqués, sans teinte mêlée). Une couche d'intensité nulle n'est
// pas peinte. Aucune couleur n'est calculée : chaque couche est un aplat ou un dégradé d'une couleur du thème, dont
// seule l'opacité est réglée.
// Entrées : glyphe, nom freedesktop de l'icône ; teinte, indice dans Theme.color.categorical ; taille, côté en
// pixels, reglages.thumb par défaut ; tailleGlyphe, côté du glyphe, reglages.thumbGlyph par défaut ; rayon, rayon des
// coins, radius.control par défaut.
// Sorties : couleur, la teinte résolue, transparente si l'indice est inconnu ; icone, l'Icone du glyphe.
// Erreurs : aucune ; avant le chargement des tokens, la vignette est vide et de taille nulle.
// Dépendances : Lueur (dégradés radiaux), Icone, Theme (material.thumb, material.highlight, color.categorical,
// reglages, radius).
// Jetons : le fond est thumb.ground (surfaceRaised la nuit, surfaceWindow le jour) ; le reflet est au blanc des
// reflets (material.highlight) ; le liseré prend ce blanc la nuit et la teinte le jour (thumb.edgeTinted) ; centres
// et portées des deux dégradés viennent de thumb (sheenCenter, sheenReach, haloCenter, haloReach), en parts du côté.
Item {
    id: vignette

    property string glyphe
    property int teinte: 0
    property real taille: Theme.reglages?.thumb ?? 0
    property real tailleGlyphe: Theme.reglages?.thumbGlyph ?? 0
    property real rayon: Theme.radius?.control ?? 0
    readonly property color couleur: Theme.color?.categorical[teinte] ?? "transparent"
    readonly property var verre: Theme.material?.thumb
    readonly property alias icone: icone

    implicitWidth: taille
    implicitHeight: taille
    width: taille
    height: taille

    Rectangle { anchors.fill: parent; radius: vignette.rayon; color: vignette.verre?.ground ?? "transparent" }
    Rectangle {
        anchors.fill: parent
        radius: vignette.rayon
        color: vignette.couleur
        opacity: vignette.verre?.tint ?? 0
        visible: opacity > 0
    }

    // Halo et reflet : deux dégradés radiaux centrés sur le bord haut, qui s'éteignent avant le bord bas.
    Lueur {
        anchors.fill: parent
        rayon: vignette.rayon
        teinte: vignette.couleur
        centre: vignette.verre?.haloCenter ?? 0
        portee: (vignette.verre?.haloReach ?? 0) * vignette.taille
        opacity: vignette.verre?.halo ?? 0
    }
    Lueur {
        anchors.fill: parent
        rayon: vignette.rayon
        teinte: Theme.material?.highlight ?? "transparent"
        centre: vignette.verre?.sheenCenter ?? 0
        portee: (vignette.verre?.sheenReach ?? 0) * vignette.taille
        opacity: vignette.verre?.sheen ?? 0
    }

    Rectangle {
        anchors.fill: parent
        radius: vignette.rayon
        color: "transparent"
        border.width: 1
        border.color: (vignette.verre?.edgeTinted ? vignette.couleur : Theme.material?.highlight) ?? "transparent"
        opacity: vignette.verre?.edge ?? 0
    }

    Icone {
        id: icone
        anchors.centerIn: parent
        nom: vignette.glyphe
        pleine: true
        taille: vignette.tailleGlyphe
        couleur: vignette.couleur
    }
}
