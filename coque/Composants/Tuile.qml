import QtQuick
import QtQuick.Layouts
import "../Theme"

// Tuile — cellule d'une grille de réglages et de mesures : un libellé discret, puis le contenu dessous.
// Rôle : aligne sur une grille de trois colonnes (un GridLayout) des valeurs de nature différente, texte, champ ou
// interrupteur, sous un même libellé en texte tertiaire, à l'échelon 0 de la typographie ; largeur l'étend sur deux
// colonnes.
// Entrées : libelle, le texte du libellé ; largeur, le nombre de colonnes occupées, 1 ou 2 (1 par défaut) ; contenu,
// propriété par défaut : les éléments déclarés dans la Tuile, posés en colonne sous le libellé.
// Sorties : Layout.columnSpan égal à largeur et Layout.fillWidth, pour que la grille répartisse les colonnes ; etiquette
// (objectName « etiquette »), le Texte du libellé, lu par les essais.
// Erreurs : aucune ; avant le chargement des tokens, la couleur du libellé est transparente.
// Dépendances : QtQuick.Layouts, Theme (color), Texte.
Column {
    id: tuile

    property string libelle
    property int largeur: 1
    default property alias contenu: zone.data
    readonly property alias etiquette: etiquette

    Layout.columnSpan: largeur
    Layout.fillWidth: true

    Texte {
        id: etiquette
        objectName: "etiquette"
        width: parent.width
        text: tuile.libelle
        echelon: 0
        color: Theme.color?.textTertiary ?? "transparent"
    }

    Column { id: zone; width: parent.width }
}
