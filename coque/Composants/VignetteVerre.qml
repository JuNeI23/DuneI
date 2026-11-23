import QtQuick
import "../Theme"

// VignetteVerre — vignette en « verre » : un carré arrondi teinté, son glyphe dans la teinte (pages de réglages,
// menu de déconnexion). Nommée ainsi pour ne pas masquer la Vignette locale de la Galerie, qui importe Composants.
// Rôle : peint, de bas en haut, le fond d'une carte, la teinte mêlée à ce fond, un halo de la teinte parti du coin
// haut gauche, un reflet clair tombant du bord haut, un liseré d'un pixel, puis le glyphe. Les quatre intensités
// viennent de Theme.material.thumb, qui change avec le moment : la nuit donne un verre givré (teinte mêlée et reflet,
// sans halo), le jour un verre à halo (halo et liseré marqués, sans teinte mêlée). Une couche d'intensité nulle n'est
// pas peinte. Aucune couleur n'est calculée : chaque couche est un aplat ou un dégradé d'une couleur du thème, dont
// seule l'opacité est réglée. En mode neutre, le verre est gris : ni teinte mêlée ni halo, le reflet seul, le fond
// d'une commande éteinte (color.controlOff, qui vaut thumb.ground la nuit et un gris plus sombre le jour), un liseré
// au blanc des reflets la nuit et à color.borderDefault le jour, le glyphe en color.textSecondary. Tout passage d'un
// état à l'autre s'anime : les couleurs par ColorSpring, chacun visant un jeton, et l'extinction de la teinte et du
// halo par un Ressort de fondu ; à la création et au changement de thème, tout se pose sans animation, si bien qu'une
// vignette dont l'état ne change pas (pages de réglages) est peinte comme avant.
// Entrées : glyphe, nom freedesktop de l'icône ; teinte, indice dans Theme.color.categorical ; couleurTeinte, couleur
// de teinte explicite, un jeton (Theme.color.accent, Theme.color.error…), qui l'emporte sur teinte, null par défaut ;
// neutre, vrai pour le verre gris, faux par défaut ; pleine, variante pleine du glyphe (vrai par défaut) ou
// variante bold de Phosphor (faux) ; taille, côté en pixels, reglages.thumb par défaut ; tailleGlyphe, côté du
// glyphe, reglages.thumbGlyph par défaut ; rayon, rayon des coins, radius.control par défaut.
// Sorties : couleur, la teinte résolue (couleurTeinte, sinon categorical[teinte], transparente si l'indice est
// inconnu), non animée ; icone, l'Icone du glyphe.
// Erreurs : aucune ; avant le chargement des tokens, la vignette est vide et de taille nulle.
// Dépendances : Lueur (dégradés radiaux), Icone, ColorSpring, Ressort, Theme (material.thumb, material.highlight,
// color.categorical, color.controlOff, color.borderDefault, color.textSecondary, reglages, radius).
// Jetons : le fond est thumb.ground (surfaceRaised la nuit, surfaceWindow le jour) ; le reflet est au blanc des
// reflets (material.highlight) ; le liseré prend ce blanc la nuit et la teinte le jour (thumb.edgeTinted) ; centres
// et portées des deux dégradés viennent de thumb (sheenCenter, sheenReach, haloCenter, haloReach), en parts du côté.
Item {
    id: vignette

    property string glyphe
    property int teinte: 0
    property var couleurTeinte: null
    property bool neutre: false
    property bool pleine: true
    property real taille: Theme.reglages?.thumb ?? 0
    property real tailleGlyphe: Theme.reglages?.thumbGlyph ?? 0
    property real rayon: Theme.radius?.control ?? 0
    readonly property color couleur: couleurTeinte ?? Theme.color?.categorical[teinte] ?? "transparent"
    readonly property var verre: Theme.material?.thumb
    readonly property alias icone: icone

    // Ressorts de l'état : chaque ColorSpring vise un jeton, jamais la valeur d'un autre ressort ; part vaut 1 en
    // couleur et 0 en neutre, et règle l'opacité de la teinte mêlée et du halo.
    ColorSpring { id: teinteAnimee; target: vignette.couleur }
    ColorSpring {
        id: fond
        target: (vignette.neutre ? Theme.color?.controlOff : vignette.verre?.ground) ?? "transparent"
    }
    ColorSpring {
        id: lisere
        target: (!vignette.verre?.edgeTinted ? Theme.material?.highlight
                 : vignette.neutre ? Theme.color?.borderDefault : vignette.couleur) ?? "transparent"
    }
    ColorSpring {
        id: encre
        target: (vignette.neutre ? Theme.color?.textSecondary : vignette.couleur) ?? "transparent"
    }
    Ressort { id: part; transition: "state"; nature: "fondu"; cible: vignette.neutre ? 0 : 1 }

    implicitWidth: taille
    implicitHeight: taille
    width: taille
    height: taille

    Rectangle { anchors.fill: parent; radius: vignette.rayon; color: fond.value }
    Rectangle {
        anchors.fill: parent
        radius: vignette.rayon
        color: teinteAnimee.value
        opacity: (vignette.verre?.tint ?? 0) * part.value
        visible: opacity > 0
    }

    // Halo et reflet : deux dégradés radiaux centrés sur le bord haut, qui s'éteignent avant le bord bas.
    Lueur {
        anchors.fill: parent
        rayon: vignette.rayon
        teinte: teinteAnimee.value
        centre: vignette.verre?.haloCenter ?? 0
        portee: (vignette.verre?.haloReach ?? 0) * vignette.taille
        opacity: (vignette.verre?.halo ?? 0) * part.value
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
        border.color: lisere.value
        opacity: vignette.verre?.edge ?? 0
    }

    Icone {
        id: icone
        anchors.centerIn: parent
        nom: vignette.glyphe
        pleine: vignette.pleine
        taille: vignette.tailleGlyphe
        couleur: encre.value
    }
}
