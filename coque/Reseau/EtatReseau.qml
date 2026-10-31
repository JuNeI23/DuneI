pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import "nmcli.js" as Nmcli
import "../Barre"
import "../Barre/icones.js" as Icones

// EtatReseau — source unique de l'état du réseau pour toute la coque.
// Rôle : réunit Quickshell.Networking (radio, cartes, réseau joint, lien filaire, connectivité) et une lecture
// nmcli (adresse, passerelle, DNS, facturation, profils, VPN) relancée par un seul « nmcli monitor » ; l'indicateur,
// le popover, la fenêtre et les notifications lisent tous ce singleton. Aucun minuteur au repos : la lecture ne
// s'exécute qu'au démarrage et en réponse à une ligne du moniteur.
// Entrées (réglables) : surveille et lecture, commandes du moniteur et de la lecture (remplaçables par un test) ;
// actif, suspend le moniteur si faux ; recherche, vrai tant qu'un popover demande un balayage Wi-Fi ; fenetre,
// vrai pour demander la fenêtre Réseau (posé par « Réglages réseau… » du popover, lu par la fenêtre).
// Sorties (lecture seule) : carte, radio, filaire, connecte, connectivite (« unknown », « none », « portal »,
// « limited » ou « full »), reseauActif (WifiNetwork ou null), nomActif, force (0 à 1), facture, appareil
// (l'interface dont la lecture donne les adresses : le filaire actif, sinon le Wi-Fi), ip4, ip6,
// passerelle, dns, mac (adresse matérielle de l'appareil actif), profils, vpnActif, icone, reseaux (WifiNetwork
// de toutes les cartes, non triés) ; relances, nombre de démarrages du moniteur.
// Fonctions : relire, copierIp, verifier, executer, allumer, ouvrirPortail.
// Erreurs : sans nmcli ou sans NetworkManager, les valeurs nmcli restent vides et le moniteur est relancé
// toutes les secondes (voir Relance) ; la sortie d'une lecture partielle est lue au mieux.
// Dépendances : Relance, nmcli.js, icones.js, Quickshell.Networking, Quickshell.Io.
Singleton {
    id: etat

    property alias surveille: relance.surveille
    property alias lecture: relance.lecture
    property alias actif: relance.actif
    property alias relances: relance.relances
    property bool recherche: false
    property bool fenetre: false
    // Nombre de processus nmcli de executer encore vivants (utile aux tests).
    property int processus: 0

    readonly property var appareils: Array.from(Networking.devices.values)
    readonly property var cartes: appareils.filter(d => d.type === DeviceType.Wifi)
    readonly property bool radio: Networking.wifiEnabled
    readonly property var deduit: Nmcli.etatAppareils(appareils, DeviceType.Wifi, DeviceType.Wired)
    readonly property bool carte: deduit.carte
    readonly property bool filaire: deduit.filaire
    readonly property var reseauActif: deduit.reseauActif
    readonly property bool connecte: deduit.connecte
    readonly property string nomActif: deduit.nomActif
    readonly property string connectivite: ({
        [NetworkConnectivity.None]: "none", [NetworkConnectivity.Portal]: "portal",
        [NetworkConnectivity.Limited]: "limited", [NetworkConnectivity.Full]: "full",
    })[Networking.connectivity] ?? "unknown"
    readonly property real force: reseauActif?.signalStrength ?? 0
    readonly property var reseaux: [].concat(...cartes.map(c => Array.from(c.networks.values)))

    // Valeurs de la lecture nmcli (voir lu).
    property bool facture: false
    property string appareil: ""
    property var ip4: []
    property var ip6: []
    property string mac: ""
    property string passerelle: ""
    property var dns: []
    property var profils: []
    property bool vpnActif: false

    readonly property string icone: Icones.iconeReseau({carte, radio, filaire, connecte, connectivite, facture, force})

    // relire — demande une lecture nmcli. Rôle : rafraîchit les valeurs nmcli sans attendre le moniteur.
    // Entrées : aucune. Sortie : aucune. Erreurs : aucune. Dépendances : relance.
    function relire() { relance.lire() }

    // copierIp — copie l'adresse IPv4 du lien actif, sans son préfixe, dans le presse-papiers.
    // Entrées : aucune. Sortie : aucune. Erreurs : sans adresse, ne fait rien. Dépendances : Quickshell.
    function copierIp() { if (ip4.length > 0) Quickshell.clipboardText = ip4[0].split("/")[0] }

    // verifier — demande à NetworkManager un contrôle de connectivité immédiat.
    // Entrées : aucune. Sortie : aucune. Erreurs : sans contrôle disponible, ne fait rien.
    // Dépendances : Quickshell.Networking.
    function verifier() { if (Networking.canCheckConnectivity) Networking.checkConnectivity() }

    // executer — lance nmcli avec les arguments donnés, puis relit l'état.
    // Entrées : args, tableau d'arguments (sans « nmcli ») ; fin, fonction(code, sortie) appelée à la fin.
    // Sortie : aucune ; fin, facultative, reçoit le code de sortie et la sortie standard (code 0) ou la sortie d'erreur (sinon) ; qu'elle manque ou lève, l'état est relu et le processus détruit.
    // Erreurs : un nmcli absent donne un code non nul à fin. Dépendances : fabrique, relire.
    function executer(args, fin) {
        fabrique.createObject(etat, {command: ["nmcli", ...args], fin})
    }

    // allumer — allume ou coupe la radio Wi-Fi.
    // Entrée : actif, vrai pour allumer. Sortie : aucune. Erreurs : radio bloquée par le matériel, sans effet.
    // Dépendances : Quickshell.Networking.
    function allumer(actif) { Networking.wifiEnabled = actif }

    // ouvrirPortail — ouvre la page de connexion d'un portail captif dans le navigateur, puis, à la sortie de
    // xdg-open, demande un contrôle de connectivité. Entrées : aucune. Sortie : aucune.
    // Erreurs : sans xdg-open, seul le contrôle a lieu. Dépendances : portail (Process), verifier.
    function ouvrirPortail() { portail.running = true }

    // appliquerRecherche — reporte recherche sur le balayage de chaque carte Wi-Fi.
    // Entrées : aucune. Sortie : aucune. Erreurs : aucune. Dépendances : cartes, recherche.
    function appliquerRecherche() { cartes.forEach(c => c.scannerEnabled = recherche) }
    onRechercheChanged: appliquerRecherche()
    onCartesChanged: appliquerRecherche()

    // lu — publie la sortie de la lecture unique : trois sections séparées par une ligne « -- » (connexions
    // actives « TYPE,DEVICE », état IP de l'appareil actif, profils). Une section absente se lit comme vide.
    // Entrée : texte, sortie complète. Sortie : aucune. Erreurs : aucune. Dépendances : nmcli.js.
    function lu(texte) {
        const parts = [[], [], []]
        let i = 0
        for (const l of texte.split("\n")) l === "--" ? i = Math.min(i + 1, 2) : parts[i].push(l)
        const [actives, texteAppareil, profilsTexte] = parts.map(p => p.join("\n"))
        const a = Nmcli.lireAppareil(texteAppareil)
        vpnActif = Nmcli.lignes(actives).some(l => ["vpn", "wireguard"].includes(l[0].trim()))
        etat.appareil = a.appareil; ip4 = a.ip4; ip6 = a.ip6; mac = a.mac; passerelle = a.passerelle; dns = a.dns; facture = a.facture
        profils = Nmcli.lireProfils(profilsTexte)
    }

    Relance {
        id: relance
        surveille: ["nmcli", "monitor"]
        // Active en premier lieu l'appareil filaire s'il existe, sinon le Wi-Fi, pour la section IP.
        lecture: ["sh", "-c", `a=$(nmcli -t -f TYPE,DEVICE connection show --active)
            printf '%s\\n--\\n' "$a"
            d=$(printf '%s\\n' "$a" | awk -F: '$1=="802-3-ethernet"{e=$2} $1=="802-11-wireless"{w=$2} END{print e?e:w}')
            [ -n "$d" ] && nmcli -t -f GENERAL.DEVICE,IP4.ADDRESS,IP4.GATEWAY,IP4.DNS,IP6.ADDRESS,GENERAL.HWADDR,GENERAL.METERED device show "$d"
            printf '%s\\n' --
            nmcli -t -f NAME,UUID,TYPE,DEVICE,ACTIVE connection show`]
        onLu: texte => etat.lu(texte)
    }

    // Navigateur sur une page en HTTP simple, que le portail captif intercepte ; xdg-open rend la main dès que le
    // navigateur a reçu l'adresse, et le contrôle suit (seul contrôle de connectivité demandé par la coque).
    Process {
        id: portail
        command: ["xdg-open", "http://ping.archlinux.org"]
        onExited: etat.verifier()
    }

    // Fabrique de processus nmcli à la demande : chacun se détruit à sa sortie.
    Component {
        id: fabrique
        Process {
            property var fin
            running: true
            Component.onCompleted: etat.processus++
            Component.onDestruction: etat.processus--
            stdout: StdioCollector { id: sortie }
            stderr: StdioCollector { id: erreur }
            onExited: code => {
                try { if (fin) fin(code, code === 0 ? sortie.text : erreur.text) }
                finally { try { etat.relire() } finally { destroy() } }
            }
        }
    }
}
