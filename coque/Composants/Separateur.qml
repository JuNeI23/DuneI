import QtQuick
import Quickshell
import "../Theme"

// Separateur — filet de séparation de la coque, horizontal par défaut.
// Rôle : trace une arête d'un pixel physique (Theme.hairline) à la couleur color.borderSubtle, pour séparer
// deux groupes de contrôles sans les déplacer ni les redimensionner.
// Entrées : vertical, vrai pour un filet vertical ; la longueur est laissée à l'appelant (width ou height,
// ancres, Layout).
// Sorties : epaisseur, épaisseur du filet, égale à implicitHeight (horizontal) ou à implicitWidth (vertical) ;
// dpr, rapport de pixels de la fenêtre qui porte le filet, 1 hors de toute fenêtre.
// Rapport de pixels : il se lit sur la fenêtre (QsWindow.window), jamais sur Screen.devicePixelRatio, qui vaut
// sous Wayland l'échelle entière de la sortie (2 pour une échelle de 1,25) : le filet y tombait à une fraction
// de pixel physique et paraissait ou disparaissait selon sa position.
// Erreurs : aucune ; avant le chargement des tokens, l'épaisseur est nulle et la couleur transparente.
// Dépendances : Quickshell (propriété attachée QsWindow), Theme (hairline, color).
Rectangle {
    id: separateur

    property bool vertical: false
    readonly property real dpr: QsWindow.window?.devicePixelRatio ?? 1
    readonly property real epaisseur: Theme.hairline(dpr) ?? 0

    implicitWidth: vertical ? epaisseur : 0
    implicitHeight: vertical ? 0 : epaisseur
    color: Theme.color?.borderSubtle ?? "transparent"
}
