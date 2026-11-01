import QtQuick
import QtQuick.Layouts
import "../Theme"
import "../Composants"

// PageFilaire — page de l'onglet Filaire de la fenêtre Réseau.
// Rôle : le titre « Filaire », puis les profils filaires enregistrés (GroupeProfils), chacun ouvrant sa sous-page ;
// « Aucun profil filaire. » sans profil. C'est une page minimale : l'état de la carte et ses réglages y viendront.
// Entrées : panneau, le PanneauReseau ; etat, la source de l'état, EtatReseau par défaut. Sortie : aucune.
// Erreurs : aucune. Dépendances : TitrePage, GroupeProfils, Texte, PanneauReseau.
ColumnLayout {
    id: page

    required property var panneau
    property var etat: EtatReseau

    spacing: 0

    TitrePage { text: "Filaire" }
    GroupeProfils { id: profils; panneau: page.panneau; type: "Filaire"; visible: profils.profils.length > 0 }
    Texte {
        visible: profils.profils.length === 0
        text: "Aucun profil filaire."
        color: Theme.color?.textSecondary ?? "transparent"
    }
}
