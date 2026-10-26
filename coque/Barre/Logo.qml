import QtQuick
import "../Theme"

// Logo — logo de la distribution, à gauche de la barre.
// Rôle : affiche l'image Theme.bureau.logo (chemin absolu des jetons), recolorée comme le texte.
// Entrées : aucune. Sorties : aucune. Erreurs : sans jeton, l'élément est invisible.
// Dépendances : ElementBarre, Theme (bureau.logo).
ElementBarre {
    source: Theme.bureau?.logo ? "file://" + Theme.bureau.logo : ""
}
