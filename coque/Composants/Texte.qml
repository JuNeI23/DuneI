import QtQuick
import "../Theme"

// Texte — texte de la coque dans la typographie des tokens.
// Rôle : pose la police d'interface, la taille d'un échelon de l'échelle typographique et la graisse ; la
// couleur revient au parent (un contrôle lui passe Etat.texte), le texte primaire par défaut.
// Entrées : echelon, indice dans Theme.typo.scale, 2 par défaut (la taille de base) ; moyen, graisse
// weightMedium au lieu de weightRegular ; text, color et les autres propriétés de Text.
// Sorties : celles de Text.
// Erreurs : aucune ; avant le chargement des tokens, police, taille et graisse restent celles de
// l'application et la couleur est transparente.
// Dépendances : Theme (police, color). Import : "../Theme", le même singleton que celui de la coque.
Text {
    id: texte

    property int echelon: 2
    property bool moyen: false

    font: Theme.police(echelon, moyen)
    color: Theme.color?.textPrimary ?? "transparent"
}
