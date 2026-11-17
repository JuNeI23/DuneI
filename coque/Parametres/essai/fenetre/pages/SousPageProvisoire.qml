import QtQuick
import "../Theme"
import "../Composants"
import "../Parametres"

// SousPageProvisoire — sous-page factice, pour éprouver la pile du conteneur de page.
// Rôle : un titre et une carte de rangées factices assez longue pour défiler ; le conteneur pose au-dessus d'elle
// la rangée de retour vers la page mère. Elle suit le contrat d'une page, et y ajoute titre, que le conteneur lit
// pour nommer le retour d'une sous-page ouverte depuis celle-ci.
// Entrées : titre ; conteneur, le ConteneurPage qui la porte, posé par lui.
// Sorties : implicitHeight ; fonction atteindre.
// Erreurs : aucune. Dépendances : Carte, ReglageLigne, Texte, Theme (space, color).
// Elle vit sous la coque d'essai de la coquille, avec PageProvisoire.
Item {
    id: sousPage

    property string titre
    property var conteneur: null

    implicitHeight: colonne.implicitHeight

    // atteindre — conduit à un réglage de la sous-page ; celle-ci, factice, n'en porte aucun. Entrée : chemin.
    // Sortie : aucune. Erreurs : aucune. Dépendances : aucune.
    function atteindre(chemin) {}

    Column {
        id: colonne
        width: parent.width
        spacing: Theme.space?.sectionGap ?? 0

        Texte { text: sousPage.titre; echelon: 4; moyen: true; color: Theme.color?.textEmphasis ?? "transparent" }
        Carte {
            width: parent.width
            Repeater {
                model: 24
                ReglageLigne { required property int index; titre: "Profil provisoire " + (index + 1) }
            }
        }
    }
}
