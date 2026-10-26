import QtQuick
import "../Theme"

// Texte — texte de la coque dans la typographie des tokens.
// Rôle : pose la police d'interface, la taille d'un échelon de l'échelle typographique et la graisse ; la
// couleur revient au parent (un contrôle lui passe Etat.texte), le texte primaire par défaut.
// Entrées : echelon, indice dans Theme.typo.scale, 2 par défaut (la taille de base) ; moyen, graisse
// weightMedium au lieu de weightRegular ; tabulaire,
// faux par défaut, chiffres tabulaires (si les tokens l'autorisent) ; text, color et les autres propriétés de Text.
// Sorties : celles de Text.
// Erreurs : aucune ; avant le chargement des tokens, police, taille et graisse restent celles de
// l'application et la couleur est transparente.
// Dépendances : Theme (police, color). La police se règle par ces entrées, jamais par « font.xxx » sur l'instance,
// qui supplanterait la liaison et ferait retomber le texte sur la police de l'application. Import : "../Theme",
// le même singleton que celui de la coque.
// Rendu : le texte se rend en niveaux de gris, jamais en sous-pixel, faux sur une fenêtre translucide ; ce réglage
// est celui du processus, posé par la directive « //@ pragma Env QSG_DISTANCEFIELD_ANTIALIASING=gray » en tête
// de chaque coque (tests/test_coque_composants.py le vérifie), et vaut aussi pour Champ et Compteur.
Text {
    id: texte

    property int echelon: 2
    property bool moyen: false
    property bool tabulaire: false

    font: Theme.police(echelon, moyen, tabulaire)
    color: Theme.color?.textPrimary ?? "transparent"
}
