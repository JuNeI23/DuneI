import QtQuick
import QtQuick.Templates as T
import "Theme"

// BarreOnglets — barre d'onglets de la planche, qui aligne des Onglet côte à côte.
// Rôle : le gabarit sans style T.TabBar ne fournit aucun élément de contenu, si bien que ses onglets ne
// s'affichent pas ; cette barre leur donne une rangée, partagée en largeurs égales par T.TabBar. Elle ne peint
// rien d'autre : l'accent est sur l'onglet actif, jamais sur la barre (Onglet). T.TabBar est une portée de
// focus, dont l'Onglet lit activeFocus pour choisir entre la sélection active et inactive.
// Entrées : les Onglet déclarés comme enfants ; currentIndex et le reste de l'API de T.TabBar.
// Sorties : currentIndex, l'onglet actif.
// Erreurs : aucune ; avant le chargement des tokens, l'écart entre les onglets est nul.
// Dépendances : QtQuick.Templates (TabBar), Theme (space), Onglet du module Composants comme enfants.
// Place : propre à la planche tant qu'aucune surface de la coque n'a besoin d'onglets ; elle rejoindra le
// module Composants au premier besoin réel.
T.TabBar {
    id: barre

    implicitWidth: contentWidth + leftPadding + rightPadding
    implicitHeight: contentHeight + topPadding + bottomPadding
    spacing: Theme.space?.scale[0] ?? 0

    contentItem: Row {
        spacing: barre.spacing

        Repeater {
            model: barre.contentModel
        }
    }
}
