import QtQuick
import QtQuick.Layouts
import "../Theme"
import "../Composants"

// Groupe — carte de réglages de la fenêtre Réseau : surface de panneau arrondie, au filet subtil, dont les Ligne
// s'empilent.
// Rôle : regroupe les réglages d'une fiche (FicheProfil, FicheNouveau) en une carte, à la manière des réglages de
// macOS.
// Entrées : les Ligne (ou tout autre élément) déclarées comme enfants. Sortie : aucune.
// Erreurs : aucune ; avant le chargement des tokens, rayon et filet sont nuls. Dépendances : Surface, Theme
// (radius.panel, hairline, color.borderSubtle), QtQuick.Layouts.
Surface {
    default property alias lignes: colonne.data
    role: "surfacePanel"
    radius: Theme.radius?.panel ?? 0
    Layout.fillWidth: true
    implicitHeight: colonne.implicitHeight

    ColumnLayout { id: colonne; width: parent.width; spacing: 0 }
    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: "transparent"
        border.width: Theme.hairline(1) ?? 0
        border.color: Theme.color?.borderSubtle ?? "transparent"
    }
}
