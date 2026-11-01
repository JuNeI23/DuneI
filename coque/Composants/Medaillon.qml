import QtQuick
import "../Theme"

// Medaillon — icône dans un carré arrondi, tête d'une rangée de réglage de la fenêtre Réseau.
// Rôle : actif, c'est la sélection de la bible (« Sélectionné actif : fond d'accent, texte sur-accent, icône en
// variante pleine ») : fond color.accent, glyphe color.onAccent en variante pleine. Inactif, c'est la sélection
// neutre d'un conteneur (bible, « Sélectionné inactif », comme Etat.selectionNeutre) : fond du rôle controlRaised
// au repos, glyphe au texte secondaire. Formes : côté reglages.medallion, rayon radius.panel, glyphe
// reglages.medallionGlyph. Aucune couleur n'est calculée : tout vient des rôles de Theme.
// Entrées : nom, icône freedesktop ; actif, faux par défaut.
// Sorties : aucune. Erreurs : aucune ; avant le chargement des tokens, le médaillon est nul et transparent.
// Dépendances : Icone, Theme (reglages, radius.panel, color, stateColors).
Rectangle {
    id: medaillon

    property string nom
    property bool actif: false

    width: Theme.reglages?.medallion ?? 0
    height: width
    radius: Theme.radius?.panel ?? 0
    color: (actif ? Theme.color?.accent : Theme.stateColors("controlRaised", "none", "rest")?.fill) ?? "transparent"

    Icone {
        anchors.centerIn: parent
        nom: medaillon.nom
        pleine: medaillon.actif
        taille: Theme.reglages?.medallionGlyph ?? 0
        couleur: (medaillon.actif ? Theme.color?.onAccent : Theme.color?.textSecondary) ?? "transparent"
    }
}
