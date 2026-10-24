import QtQuick
import "../Theme"

// AnneauFocus — anneau de focus clavier tracé autour d'un contrôle.
// Rôle : dessine un contour de Theme.focus.width à Theme.focus.offset à l'extérieur de la cible, au rayon de
// la cible augmenté de l'offset, sans fond ; il ne déplace ni ne redimensionne la cible. Le contrôle le lie à
// visualFocus (activeFocus pour un champ) ; les rangées n'en ont jamais (conception, § 7.3).
// Entrées : cible, élément entouré, parent ou frère de l'anneau (contrainte des ancres) ; montre, anneau
// visible ; inactif, modificateur inactive, qui passe l'anneau en focus.colorMuted.
// Sorties : aucune autre que celles de Rectangle.
// Erreurs : aucune ; une cible sans radius compte un rayon nul ; avant le chargement des tokens, le contour
// est nul et transparent.
// Dépendances : Theme (focus). Import : "../Theme", le même singleton que celui de la coque.
Rectangle {
    id: anneau

    required property Item cible
    property bool montre: false
    property bool inactif: false
    readonly property real decalage: Theme.focus?.offset ?? 0

    visible: montre
    anchors.fill: cible
    anchors.margins: -decalage
    radius: (cible.radius ?? 0) + decalage
    color: "transparent"
    border.width: Theme.focus?.width ?? 0
    border.color: (inactif ? Theme.focus?.colorMuted : Theme.focus?.color) ?? "transparent"
}
