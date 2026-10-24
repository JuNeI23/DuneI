import QtQuick
import "../Theme"

// Recherche — champ de recherche de la coque, à la manière de macOS.
// Rôle : un Champ en pilule (conception, § 7.10), dont il reprend tout le comportement (fond enfoncé, filet, texte
// indicatif, curseur de texte) : seuls le rayon et les retraits changent. Une loupe system-search se tient à gauche, à
// la couleur du texte indicatif ; à droite, le bouton d'effacement edit-clear, au texte secondaire, n'est visible que
// s'il y a du texte et l'efface au clic, sans être un arrêt de tabulation. Désactivé, les deux icônes prennent la
// couleur désactivée du texte. Échap efface le texte s'il y en a ; sur un champ vide, la touche n'est pas consommée et
// remonte au parent (un Overlay la prend pour se fermer).
// Entrées : text, placeholderText (« Rechercher » par défaut) et le reste de l'API de Champ.
// Sorties : celles de Champ ; loupe et effacer, les deux Icone, lues par les essais.
// Erreurs : aucune ; avant le chargement des tokens, les cotes sont nulles et les icônes invisibles.
// Dépendances : Champ, Icone, Theme (space, icons, color).
// Cotes : rayon de la moitié de la hauteur ; icônes de icons.sizes.dense, à space.scale[1] (8) des bords ; le texte
// commence à space.scale[0] (4) de la loupe, et finit à la même distance du bouton d'effacement.
Champ {
    id: recherche

    readonly property alias loupe: loupe
    readonly property alias effacer: effacer
    readonly property real marge: Theme.space?.scale[1] ?? 0

    rayon: height / 2
    leftPadding: marge + loupe.taille + (Theme.space?.scale[0] ?? 0)
    rightPadding: leftPadding
    placeholderText: "Rechercher"
    Keys.onEscapePressed: event => {
        event.accepted = length > 0
        clear()
    }

    Icone {
        id: loupe
        x: recherche.marge
        anchors.verticalCenter: parent.verticalCenter
        nom: "system-search"
        taille: Theme.icons?.sizes.dense ?? 0
        couleur: recherche.placeholderTextColor
    }

    Icone {
        id: effacer
        x: recherche.width - recherche.marge - taille
        anchors.verticalCenter: parent.verticalCenter
        nom: "edit-clear"
        taille: Theme.icons?.sizes.dense ?? 0
        couleur: recherche.enabled ? Theme.color?.textSecondary ?? "transparent" : recherche.etat.texte
        visible: recherche.length > 0

        // Saisie exclusive dès l'appui : le clic n'atteint pas le champ, qui ne déplace pas son curseur.
        TapHandler {
            gesturePolicy: TapHandler.ReleaseWithinBounds
            onTapped: recherche.clear()
        }
    }
}
