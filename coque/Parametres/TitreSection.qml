import QtQuick
import "../Theme"
import "../Composants"

// TitreSection — titre d'une section d'une page de réglages, au-dessus de sa carte.
// Rôle : donne aux pages de l'application Paramètres le même titre de section que la liste de la page Wi-Fi, qui
// dessine le sien dans les en-têtes de sa vue : échelon 1, graisse moyenne, accent autonome, aligné sur le retrait
// des cartes.
// Entrées : text, le titre.
// Sorties : celles de Texte.
// Erreurs : aucune ; avant le chargement des tokens, les retraits sont nuls et la couleur transparente.
// Dépendances : Texte, Theme (space, color).
// Cotes : space.scale[3] au-dessus, space.scale[1] au-dessous, space.scale[0] à gauche.
Texte {
    leftPadding: Theme.space?.scale[0] ?? 0
    topPadding: Theme.space?.scale[3] ?? 0
    bottomPadding: Theme.space?.scale[1] ?? 0
    echelon: 1
    moyen: true
    color: Theme.color?.accentStandalone ?? "transparent"
}
