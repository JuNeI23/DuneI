import QtQuick

// SousPageMasque — sous-page « Réseau masqué » de la page Wi-Fi : la fiche d'un réseau saisi à la main.
// Rôle : donne à FicheNouveau le contrat d'une sous-page de l'application Paramètres (voir ConteneurPage) sans la
// modifier : la fiche enregistre le profil d'un réseau qui ne s'annonce pas ; ajouté ou annulé, la sous-page rend la
// page Wi-Fi, où le nouveau profil paraît dans « Réseaux enregistrés ».
// Entrées : titre ; conteneur, le ConteneurPage, posé par lui ; etat, la source des actions, EtatReseau par défaut.
// Sorties : implicitHeight ; fiche, la FicheNouveau ; fonction atteindre.
// Erreurs : celles de nmcli, sous le formulaire de la fiche, qui reste alors ouverte.
// Dépendances : FicheNouveau, ConteneurPage (revenir), EtatReseau.
Item {
    id: sousPage

    property string titre
    property var conteneur: null
    property var etat: EtatReseau
    readonly property alias fiche: fiche

    implicitHeight: fiche.implicitHeight

    // atteindre — conduit à un réglage de la sous-page, qui n'en déclare aucun à la recherche. Entrée : chemin.
    // Sortie : aucune. Erreurs : aucune. Dépendances : aucune.
    function atteindre(chemin) {}

    FicheNouveau {
        id: fiche
        width: parent.width
        etat: sousPage.etat
        onAjoute: sousPage.conteneur.revenir()
        onAnnule: sousPage.conteneur.revenir()
    }
}
