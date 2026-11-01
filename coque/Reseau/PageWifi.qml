import QtQuick
import QtQuick.Layouts
import "../Theme"
import "../Composants"

// PageWifi — page de l'onglet Wi-Fi de la fenêtre Réseau.
// Rôle : le titre « Wi-Fi », puis les profils Wi-Fi enregistrés (GroupeProfils), chacun ouvrant sa sous-page, et la
// rangée « Autre réseau… » qui ouvre la fiche d'un nouveau réseau (panneau.ouvrirNouveau). C'est une page minimale :
// le réseau joint, les réseaux disponibles et les adresses y viendront.
// Entrées : panneau, le PanneauReseau ; etat, la source de l'état, EtatReseau par défaut. Sortie : aucune.
// Erreurs : aucune. Dépendances : TitrePage, GroupeProfils, Ligne, PanneauReseau.
ColumnLayout {
    id: page

    required property var panneau
    property var etat: EtatReseau

    spacing: 0

    TitrePage { text: "Wi-Fi" }
    GroupeProfils {
        panneau: page.panneau
        type: "Wi-Fi"
        Ligne {
            filet: page.panneau.rangees.some(r => r.groupe === "Wi-Fi")
            icone: "list-add"
            libelle: "Autre réseau…"
            cliquable: true
            onClique: page.panneau.ouvrirNouveau()
        }
    }
}
