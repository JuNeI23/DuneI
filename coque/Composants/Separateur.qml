import QtQuick
import QtQuick.Window
import "../Theme"

// Separateur — filet de séparation de la coque, horizontal par défaut.
// Rôle : trace une arête d'un pixel physique (Theme.hairline) à la couleur color.borderSubtle, pour séparer
// deux groupes de contrôles sans les déplacer ni les redimensionner.
// Entrées : vertical, vrai pour un filet vertical ; la longueur est laissée à l'appelant (width ou height,
// ancres, Layout).
// Sorties : epaisseur, épaisseur du filet, égale à implicitHeight (horizontal) ou à implicitWidth (vertical).
// Erreurs : aucune ; avant le chargement des tokens, l'épaisseur est nulle et la couleur transparente.
// Dépendances : QtQuick.Window (Screen.devicePixelRatio), Theme (hairline, color).
Rectangle {
    id: separateur

    property bool vertical: false
    readonly property real epaisseur: Theme.hairline(Screen.devicePixelRatio) ?? 0

    implicitWidth: vertical ? epaisseur : 0
    implicitHeight: vertical ? 0 : epaisseur
    color: Theme.color?.borderSubtle ?? "transparent"
}
