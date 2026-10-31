import QtQuick
import QtQuick.Layouts
import "../Theme"
import "../Composants"

// Section — titre de section d'une fiche de la fenêtre Réseau, en petites capitales, au texte tertiaire.
// Entrées : text et le reste de l'API de Texte. Sortie : aucune. Erreurs : aucune.
// Dépendances : Texte, Theme (space, color), QtQuick.Layouts.
Texte {
    Layout.topMargin: Theme.space?.scale[1] ?? 0
    Layout.leftMargin: Theme.space?.scale[0] ?? 0
    echelon: 0
    moyen: true
    color: Theme.color?.textTertiary ?? "transparent"
}
