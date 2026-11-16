pragma Singleton
import QtQuick
import Quickshell

// Registre — liste déclarative des pages de l'application Paramètres.
// Rôle : seule source de la barre latérale, du conteneur de page et de la recherche. Ajouter une page revient à
// ajouter ici une entrée et à écrire son fichier ; la coquille ne change pas.
// Entrées : pages, remplaçable par une coque d'essai, qui éprouve ainsi la coquille sur des pages factices sans lire
// le réseau de la machine.
// Sorties : pages, liste ordonnée de { id, identifiant de la page ; groupe, titre du groupe de la barre latérale ;
// libelle, nom montré ; glyphe, nom freedesktop de l'icône ; teinte, indice dans Theme.color.categorical ;
// composant, URL du fichier de la page (contrat : voir ConteneurPage) ; index, ses réglages recherchables, au format
// de recherche.js : { page, chemin: [string], libelle, motsCles: [string], exige: string } } ; index, l'union des
// index de toutes les pages. Fonction : page.
// Erreurs : aucune.
// Dépendances : Quickshell (Singleton) ; les fichiers de page nommés par composant.
// Pages du réseau : PageWifi, PageFilaire et PageVpn du module Reseau, nommées par leur URL (aucun import : le
// registre ne charge rien). L'index de la page Wi-Fi déclare l'interrupteur, le réseau joint et ses tuiles (proposés
// seulement quand un réseau est joint : exige « joint »), les réseaux enregistrés et le réseau masqué ; celui de la
// page Filaire, la carte « Ethernet » et les profils ; celui de la page VPN, ses connexions. Chaque page suit ces
// ancres dans sa fonction atteindre.
Singleton {
    property var pages: [
        { id: "wifi", groupe: "Réseau", libelle: "Wi-Fi", glyphe: "network-wireless-signal-excellent", teinte: 3,
          composant: Qt.resolvedUrl("../Reseau/PageWifi.qml"), index: [
            { page: "wifi", chemin: ["wifi", "radio"], libelle: "Wi-Fi", motsCles: ["sans fil", "activer", "désactiver", "radio"], exige: "" },
            { page: "wifi", chemin: ["wifi", "joint"], libelle: "Réseau joint", motsCles: ["connecté", "déconnecter", "oublier", "mot de passe", "débit"], exige: "joint" },
            { page: "wifi", chemin: ["wifi", "joint", "ip"], libelle: "Adresse IP", motsCles: ["IPv4", "réseau local"], exige: "joint" },
            { page: "wifi", chemin: ["wifi", "joint", "routeur"], libelle: "Routeur", motsCles: ["passerelle", "box"], exige: "joint" },
            { page: "wifi", chemin: ["wifi", "joint", "depuis"], libelle: "Connecté depuis", motsCles: ["durée"], exige: "joint" },
            { page: "wifi", chemin: ["wifi", "enregistres"], libelle: "Réseaux enregistrés", motsCles: ["profils", "connus"], exige: "" },
            { page: "wifi", chemin: ["wifi", "masque"], libelle: "Réseau masqué", motsCles: ["caché", "SSID"], exige: "" }
          ] },
        { id: "filaire", groupe: "Réseau", libelle: "Filaire", glyphe: "network-wired", teinte: 2,
          composant: Qt.resolvedUrl("../Reseau/PageFilaire.qml"), index: [
            { page: "filaire", chemin: ["filaire", "ethernet"], libelle: "Ethernet", motsCles: ["câble", "adresse matérielle", "MAC", "débit"], exige: "" },
            { page: "filaire", chemin: ["filaire", "profils"], libelle: "Profils filaires", motsCles: ["enregistrés", "connexion automatique", "priorité"], exige: "" }
          ] },
        { id: "vpn", groupe: "Réseau", libelle: "VPN", glyphe: "network-vpn", teinte: 1,
          composant: Qt.resolvedUrl("../Reseau/PageVpn.qml"), index: [
            { page: "vpn", chemin: ["vpn", "connexions"], libelle: "Connexions VPN", motsCles: ["tunnel", "WireGuard", "OpenVPN"], exige: "" }
          ] }
    ]
    readonly property var index: [].concat(...pages.map(p => p.index))

    // page — entrée du registre d'un identifiant. Entrée : id, identifiant de page. Sortie : l'entrée, ou undefined
    // si aucune page ne porte cet identifiant. Erreurs : aucune. Dépendances : pages.
    function page(id) { return pages.find(p => p.id === id) }
}
