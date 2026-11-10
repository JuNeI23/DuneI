import QtQuick
import "../Theme"

// Medaillon — icône dans un carré arrondi, tête d'une rangée de réglage de la fenêtre Réseau.
// Rôle : actif, c'est la sélection de la bible (« Sélectionné actif : fond d'accent, texte sur-accent, icône en
// variante pleine ») : fond color.accent, glyphe color.onAccent en variante pleine. Inactif, c'est la sélection
// neutre d'un conteneur (bible, « Sélectionné inactif », comme Etat.selectionNeutre) : fond du rôle controlRaised
// au repos, glyphe au texte secondaire. Formes : côté reglages.medallion, rayon radius.panel, glyphe
// reglages.medallionGlyph. Aucune couleur n'est calculée : tout vient des rôles de Theme. Le fond et le glyphe
// rejoignent leurs couleurs en fondu, par deux ColorSpring au ressort des états : un onglet de la colonne de la
// fenêtre Réseau qu'on choisit ou qu'on quitte change de couleur sans à-coup (Recette 1 de L2-65, D157) ; la variante
// pleine du glyphe, elle, se pose d'un coup.
// Entrées : nom, icône freedesktop ; actif, faux par défaut.
// Sorties : fond et glyphe, les couleurs peintes, lues par les essais. Erreurs : aucune ; avant le chargement des tokens, le médaillon est nul et transparent.
// Dépendances : Icone, Theme (reglages, radius.panel, color, stateColors, ColorSpring).
Rectangle {
    id: medaillon

    property string nom
    property bool actif: false
    readonly property color fond: fondu.value
    readonly property color glyphe: fonduGlyphe.value

    width: Theme.reglages?.medallion ?? 0
    height: width
    radius: Theme.radius?.panel ?? 0
    color: fond

    Icone {
        anchors.centerIn: parent
        nom: medaillon.nom
        pleine: medaillon.actif
        taille: Theme.reglages?.medallionGlyph ?? 0
        couleur: medaillon.glyphe
    }

    // Les ressorts suivent l'icône : elle reste le premier enfant, que la coque d'essai lit ainsi.
    ColorSpring {
        id: fondu
        target: (medaillon.actif ? Theme.color?.accent : Theme.stateColors("controlRaised", "none", "rest")?.fill) ?? "transparent"
    }
    ColorSpring {
        id: fonduGlyphe
        target: (medaillon.actif ? Theme.color?.onAccent : Theme.color?.textSecondary) ?? "transparent"
    }
}
