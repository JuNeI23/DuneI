import QtQuick
import Quickshell.Widgets
import "../Theme"
import "etats.js" as Etats

// Medaillon — icône dans un carré arrondi, tête d'une rangée de réglage de la fenêtre Réseau.
// Rôle : actif, c'est la sélection de la bible (« Sélectionné actif : fond d'accent, texte sur-accent, icône en
// variante pleine ») : fond color.accent, glyphe color.onAccent en variante pleine. Inactif, c'est la sélection
// neutre d'un conteneur (bible, « Sélectionné inactif », comme Etat.selectionNeutre) : fond du rôle controlRaised
// au repos, glyphe au texte secondaire. Formes : côté reglages.medallion, rayon radius.panel, glyphe
// reglages.medallionGlyph. Aucune couleur n'est calculée : tout vient des rôles de Theme. Le fond et le glyphe
// rejoignent leurs couleurs en fondu, par deux ColorSpring au ressort des états : un onglet de la colonne de la
// fenêtre Réseau qu'on choisit ou qu'on quitte change de couleur sans à-coup (Recette 1 de L2-65, D157) ; la variante
// pleine du glyphe, elle, se pose d'un coup.
// Relief « Doux » (application Paramètres) : sous un ancêtre qui déclare dnRelief, le médaillon actif porte un reflet
// léger, un dégradé du blanc des reflets (material.highlight) tombant du bord haut et éteint avant le bas, à
// l'opacité material.medallionSheen, à la part material.medallionSheenReach de la hauteur ; aucun halo. Ailleurs, le médaillon reste un aplat.
// Icône en couleur (lanceur, L2-16) : si image est posée, l'image en couleur, aux deux tiers du côté (68 %, maquette
// du lanceur v3), remplace le glyphe ; refletRepos pose le reflet du relief « Doux » même au repos, comme les
// médaillons du lanceur, qui ne sont jamais actifs (la plaque d'accent dit la sélection).
// Entrées : nom, icône freedesktop ; actif, faux par défaut ; image, url d'une icône en couleur, vide par défaut ;
// tailleGlyphe, côté du glyphe, reglages.medallionGlyph par défaut ; refletRepos, faux par défaut.
// Sorties : fond et glyphe, les couleurs peintes, lues par les essais.
// Erreurs : aucune ; avant le chargement des tokens, le médaillon est nul et transparent.
// Dépendances : Icone, Quickshell.Widgets (IconImage), Theme (reglages, radius.panel, color, stateColors, material,
// ColorSpring), etats.js (herite).
Rectangle {
    id: medaillon

    property string nom
    property bool actif: false
    property url image
    property int tailleGlyphe: Theme.reglages?.medallionGlyph ?? 0
    property bool refletRepos: false
    readonly property color fond: fondu.value
    readonly property color glyphe: fonduGlyphe.value

    width: Theme.reglages?.medallion ?? 0
    height: width
    radius: Theme.radius?.panel ?? 0
    color: fond

    Icone {
        anchors.centerIn: parent
        z: 1
        nom: medaillon.nom
        visible: medaillon.image == ""
        pleine: medaillon.actif
        taille: medaillon.tailleGlyphe
        couleur: medaillon.glyphe
    }

    // Les ressorts suivent l'icône : elle reste le premier enfant, que la coque d'essai lit ainsi.
    ColorSpring {
        id: fondu
        target: (medaillon.actif ? Theme.color?.accent
            : Theme.stateColors("controlRaised", "none", "rest")?.fill) ?? "transparent"
    }
    ColorSpring {
        id: fonduGlyphe
        target: (medaillon.actif ? Theme.color?.onAccent : Theme.color?.textSecondary) ?? "transparent"
    }
    // Reflet du relief « Doux », peint sur le fond et sous le glyphe, que son z garde au-dessus.
    Rectangle {
        anchors.fill: parent
        visible: (medaillon.actif || medaillon.refletRepos) && Etats.herite(medaillon, "dnRelief", false)
        radius: parent.radius
        opacity: Theme.material?.medallionSheen ?? 0
        gradient: Gradient {
            GradientStop { position: 0; color: Theme.material?.highlight ?? "transparent" }
            GradientStop { position: Theme.material?.medallionSheenReach ?? 0; color: "transparent" }
        }
    }
    // Icône en couleur, au-dessus du reflet.
    IconImage {
        anchors.centerIn: parent
        z: 1
        visible: medaillon.image != ""
        source: medaillon.image
        implicitSize: Math.round(medaillon.width * 0.68)
        asynchronous: true
    }
}
