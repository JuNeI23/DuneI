import QtQuick
import "../Theme"
import "../Composants"

// SousPageProfils — sous-page « Réseaux enregistrés » de la page Wi-Fi : tous les profils Wi-Fi, hors de portée
// compris.
// Rôle : reprend la section « Réseaux connus » de l'ancienne fenêtre (ConnusWifi) en sous-page de l'application
// Paramètres : un titre, puis la carte des profils (GroupeProfils : chacun un DepliantReseau, un seul déplié à la
// fois, ses réglages, ses réglages avancés et son pied « Rejoindre » ou « Se déconnecter », « Oublier ce réseau »).
// Le réseau joint vient en tête, puis les autres profils. Sans profil, une phrase le dit. Le conteneur de page pose
// au-dessus la rangée de retour « ‹ Wi-Fi ». Elle suit le contrat d'une sous-page (voir ConteneurPage).
// Entrées : titre ; conteneur, le ConteneurPage, posé par lui ; page, la PageWifi qui l'a ouverte, dont elle lit
// enregistres (les rangées des profils), etat (la source de l'état et des actions) et factures, qu'elle complète à
// chaque profil lu.
// Sorties : implicitHeight ; groupe, le GroupeProfils ; fonction atteindre.
// Erreurs : celles de chaque ProfilReseau, sous ses réglages.
// Dépendances : GroupeProfils, Texte, Theme (space, color), PageWifi.
Item {
    id: sousPage

    property string titre
    property var conteneur: null
    required property var page
    readonly property alias groupe: groupe

    implicitHeight: colonne.implicitHeight

    // atteindre — conduit à un réglage de la sous-page, qui n'en déclare aucun à la recherche. Entrée : chemin.
    // Sortie : aucune. Erreurs : aucune. Dépendances : aucune.
    function atteindre(chemin) {}

    Column {
        id: colonne
        width: parent.width
        spacing: Theme.space?.sectionGap ?? 0

        Texte { text: sousPage.titre; echelon: 4; moyen: true; color: Theme.color?.textEmphasis ?? "transparent" }
        GroupeProfils {
            id: groupe
            width: parent.width
            visible: sousPage.page.enregistres.length > 0
            profils: sousPage.page.enregistres
            panneau: sousPage.page
            etat: sousPage.page.etat
        }
        Texte {
            visible: !groupe.visible
            text: "Aucun réseau enregistré."
            color: Theme.color?.textSecondary ?? "transparent"
        }
    }
}
