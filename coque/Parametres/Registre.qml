pragma Singleton
import QtQuick
import Quickshell

// Registre — liste déclarative des pages de l'application Paramètres.
// Rôle : seule source de la barre latérale, du conteneur de page et de la recherche. Ajouter une page revient à
// ajouter ici une entrée et à écrire son fichier ; la coquille ne change pas.
// Entrées : aucune.
// Sorties : pages, liste ordonnée de { id, identifiant de la page ; groupe, titre du groupe de la barre latérale ;
// libelle, nom montré ; glyphe, nom freedesktop de l'icône ; teinte, indice dans Theme.color.categorical ;
// composant, URL du fichier de la page (contrat : voir ConteneurPage) ; index, ses réglages recherchables, au format
// de recherche.js : { page, chemin: [string], libelle, motsCles: [string], exige: string } } ; index, l'union des
// index de toutes les pages. Fonction : page.
// Erreurs : aucune.
// Dépendances : Quickshell (Singleton) ; les fichiers de page nommés par composant.
// Provisoire : les trois pages sont des pages factices (Provisoire*.qml) et leurs index ne nomment que des réglages
// factices ; les pages Wi-Fi, Filaire et VPN les remplacent en changeant ici composant et index.
Singleton {
    readonly property var pages: [
        { id: "wifi", groupe: "Réseau", libelle: "Wi-Fi", glyphe: "network-wireless-signal-excellent", teinte: 3,
          composant: Qt.resolvedUrl("ProvisoireWifi.qml"), index: [
            { page: "wifi", chemin: ["wifi", "masque"], libelle: "Réseau masqué", motsCles: ["caché", "SSID"], exige: "" },
            { page: "wifi", chemin: ["wifi", "enregistres"], libelle: "Réseaux enregistrés", motsCles: ["profils", "connus"], exige: "" }
          ] },
        { id: "filaire", groupe: "Réseau", libelle: "Filaire", glyphe: "network-wired", teinte: 2,
          composant: Qt.resolvedUrl("ProvisoireFilaire.qml"), index: [
            { page: "filaire", chemin: ["filaire", "mac"], libelle: "Adresse MAC", motsCles: ["matérielle", "ethernet"], exige: "" }
          ] },
        { id: "vpn", groupe: "Réseau", libelle: "VPN", glyphe: "network-vpn", teinte: 1,
          composant: Qt.resolvedUrl("ProvisoireVpn.qml"), index: [
            { page: "vpn", chemin: ["vpn", "demarrage"], libelle: "Connexion au démarrage", motsCles: ["automatique"], exige: "" }
          ] }
    ]
    readonly property var index: [].concat(...pages.map(p => p.index))

    // page — entrée du registre d'un identifiant. Entrée : id, identifiant de page. Sortie : l'entrée, ou undefined
    // si aucune page ne porte cet identifiant. Erreurs : aucune. Dépendances : pages.
    function page(id) { return pages.find(p => p.id === id) }
}
