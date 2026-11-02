import QtQuick
import QtQuick.Layouts
import "../Theme"
import "../Composants"

// Section — étiquette de carte d'une fiche de la fenêtre Réseau, à l'accent autonome, en graisse moyenne (D4).
// Rôle : titre le groupe qui suit ; la casse est celle du texte donné. Air au-dessus de 20 (scale[3] + scale[0]) et
// au-dessous de 4 (scale[0]) : 20 n'est pas un jeton, c'est la somme de deux ; le 6 de l'essai n'en est pas une,
// le jeton le plus proche est 4. Bible, « Formes » : cotes en jetons seuls.
// Entrées : text et le reste de l'API de Texte. Sortie : aucune. Erreurs : aucune.
// Dépendances : Texte, Theme (space, color), QtQuick.Layouts.
Texte {
    leftPadding: Theme.space?.scale[0] ?? 0
    topPadding: (Theme.space?.scale[3] ?? 0) + (Theme.space?.scale[0] ?? 0)
    bottomPadding: Theme.space?.scale[0] ?? 0
    echelon: 0
    moyen: true
    color: Theme.color?.accentStandalone ?? "transparent"
}
