import QtQuick
import "../Theme"
import "../Deconnexion"

// Logo — logo de la distribution, à gauche de la barre.
// Rôle : affiche l'image Theme.bureau.logo (chemin absolu des jetons), recolorée comme le texte.
// Un clic bascule le menu de déconnexion (Deconnexion.basculer) ; le logo porte l'état ouvert du menu.
// Entrées : aucune ; la taille de l'icône est fixée à Theme.icons.sizes.default. Sorties : aucune.
// Erreurs : sans jeton, l'élément est invisible.
// Dépendances : ElementBarre, Theme (bureau.logo), Deconnexion (ouvert, basculer).
ElementBarre {
    cliquable: true
    ouvert: Deconnexion.ouvert
    onClicked: Deconnexion.basculer()
    taille: Theme.icons?.sizes.default ?? 0
    source: Theme.bureau?.logo ? "file://" + Theme.bureau.logo : ""
}
