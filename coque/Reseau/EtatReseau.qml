pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import "nmcli.js" as Nmcli
import "../Barre"
import "../Barre/icones.js" as Icones

// EtatReseau — source unique de l'état du réseau pour toute la coque.
// Rôle : réunit Quickshell.Networking (radio, cartes, réseau joint, lien filaire, connectivité) et une lecture nmcli
// (adresse, passerelle, DNS, facturation, profils, VPN) relancée par un seul « nmcli monitor » ; l'indicateur, le
// popover, la fenêtre et les notifications lisent tous ce singleton. Aucun minuteur au repos : la lecture ne s'exécute
// qu'au démarrage et en réponse à une ligne du moniteur. Entrées (réglables) : surveille et lecture, commandes du
// moniteur et de la lecture (remplaçables par un test) ; actif, suspend le moniteur si faux ; recherche, vrai tant
// qu'un popover demande un balayage Wi-Fi, et rechercheFenetre, vrai pendant toute la vie de la fenêtre Réseau (posé
// par son PanneauReseau après la première image, rendu à sa destruction), quel que soit l'onglet : deux demandeurs,
// deux propriétés, si bien que la fermeture de l'un ne coupe pas le balayage que l'autre réclame encore ; fenetre, vrai
// pour demander la fenêtre Réseau (posé par « Réglages réseau… » du popover, lu par la fenêtre) ; profilDemande, uuid
// ou nom du profil que la fenêtre doit montrer (posé par le seul PanneauReseau.ajoute, à la création d'un profil,
// consommé et remis à vide par le panneau qui le sélectionne ; le popover le vide en ouvrant la fenêtre, et la
// fermeture de la fenêtre le vide aussi), vide par défaut. Sorties (lecture seule) : veille (vrai de la ligne
// « asleep » du moniteur jusqu'à l'état suivant), carte, radio, filaire, carteFilaire (vrai si une carte filaire
// existe, branchée ou non : l'onglet Filaire distingue « Câble débranché » de « Aucune carte »), appareilFilaire (le
// premier appareil filaire de Quickshell.Networking, avec son nom et son adresse matérielle, ou null sans carte
// filaire), connecte, connectivite (« unknown », « none », « portal », « limited » ou « full »), reseauActif
// (WifiNetwork ou null), nomActif, force (0 à 1), facture, appareil (l'interface dont la lecture donne les adresses :
// le filaire actif, sinon le Wi-Fi), ip4, ip6, passerelle, dns, mac (adresse matérielle de l'appareil actif), profils,
// vpnActif, icone, reseaux (WifiNetwork de toutes les cartes, non triés) ; relances, nombre de démarrages du moniteur.
// Fonctions : relire, verifier, executer, allumer, ouvrirPortail, demanderSonde (sonde à la demande : sondeurs,
// racineCompteurs, debits, signalDbm, connecteDepuis ; un minuteur d'une seconde seulement tant qu'un demandeur existe).
// Erreurs : sans nmcli ou sans NetworkManager, les valeurs nmcli restent vides et le moniteur est relancé toutes les
// secondes (voir Relance) ; la sortie d'une lecture partielle est lue au mieux.
// Dépendances : Relance, nmcli.js, icones.js, Quickshell.Networking, Quickshell.Io.
Singleton {
    id: etat

    property alias surveille: relance.surveille
    property alias lecture: relance.lecture
    property alias actif: relance.actif
    property alias relances: relance.relances
    property bool recherche: false
    property bool rechercheFenetre: false
    // Vrai tant qu'un demandeur au moins réclame le balayage : seule valeur reportée sur les cartes.
    readonly property bool balayage: recherche || rechercheFenetre
    property bool fenetre: false
    property string profilDemande: ""
    // Nombre de processus nmcli de executer encore vivants (utile aux tests).
    property int processus: 0
    // Vrai tant que NetworkManager est endormi (la machine est en veille) ; tiré des lignes du moniteur.
    property bool veille: false

    readonly property var appareils: Array.from(Networking.devices.values)
    readonly property var cartes: appareils.filter(d => d.type === DeviceType.Wifi)
    readonly property bool radio: Networking.wifiEnabled
    readonly property var deduit: Nmcli.etatAppareils(appareils, DeviceType.Wifi, DeviceType.Wired)
    readonly property bool carte: deduit.carte
    readonly property bool filaire: deduit.filaire
    readonly property bool carteFilaire: appareils.some(d => d.type === DeviceType.Wired)
    readonly property var appareilFilaire: appareils.find(d => d.type === DeviceType.Wired) ?? null
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

    // Sonde à la demande (voir demanderSonde) : demandeurs, dossier des compteurs du noyau, débits en octets par
    // seconde (60 échantillons, le plus récent en dernier), signal en dBm et durée de connexion en secondes (null
    // quand l'interface ne répond pas).
    property int sondeurs: 0
    property string racineCompteurs: "/sys/class/net"
    property var debits: ({rx: Array(60).fill(0), tx: Array(60).fill(0)})
    property var signalDbm: null
    property var connecteDepuis: null
    readonly property bool sondeActive: sondeurs > 0 && appareil !== ""

    readonly property string icone: Icones.iconeReseau({carte, radio, filaire, connecte, connectivite, facture, force})

    // relire — demande une lecture nmcli. Rôle : rafraîchit les valeurs nmcli sans attendre le moniteur.
    // Entrées : aucune. Sortie : aucune. Erreurs : aucune. Dépendances : relance.
    function relire() { relance.lire() }

    // verifier — demande à NetworkManager un contrôle de connectivité immédiat.
    // Entrées : aucune. Sortie : aucune. Erreurs : sans contrôle disponible, ne fait rien.
    // Dépendances : Quickshell.Networking.
    function verifier() { if (Networking.canCheckConnectivity) Networking.checkConnectivity() }

    // executer — lance nmcli avec les arguments donnés, puis relit l'état.
    // Entrées : args, tableau d'arguments (sans « nmcli ») ; fin, fonction(code, sortie) appelée à la fin.
    // Sortie : aucune ; fin, facultative, reçoit le code de sortie et la sortie standard (code 0) ou la sortie d'erreur
    // (sinon) ; qu'elle manque ou lève, l'état est relu et le processus détruit.
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

    // appliquerRecherche — reporte balayage (recherche ou rechercheFenetre) sur le balayage de chaque carte Wi-Fi.
    // Une carte n'est écrite que si sa valeur diffère, car une écriture de scannerEnabled, même sans effet, occupe
    // le fil graphique : environ une demi-seconde à la mesure de 7a, mais de 2 à 15 ms à la mesure de L2-06 (D116),
    // relevée sur la machine caladan seulement, donc à confirmer ailleurs.
    // Entrées : aucune. Sortie : aucune. Erreurs : aucune. Dépendances : cartes, balayage.
    function appliquerRecherche() { cartes.forEach(c => { if (c.scannerEnabled !== balayage) c.scannerEnabled = balayage }) }
    onBalayageChanged: appliquerRecherche()
    onCartesChanged: appliquerRecherche()

    // demanderSonde — ajoute ou retire un demandeur de la sonde, qui ne tourne que tant qu'il en reste un.
    // Entrée : actif, vrai pour demander, faux pour retirer sa demande. Sortie : aucune. Erreurs : aucune (le compte
    // ne descend jamais sous zéro). Dépendances : sondeurs.
    function demanderSonde(actif) { sondeurs = Math.max(0, sondeurs + (actif ? 1 : -1)) }

    // sonder — publie un relevé de la sonde : deux compteurs d'octets, une ligne « -- », puis « iw station dump ».
    // Entrée : texte, sortie du relevé. Sortie : aucune ; décale les débits d'un pas si les compteurs sont lisibles
    // et qu'un relevé précédent existe, sinon la courbe se fige ; signalDbm et connecteDepuis valent null sans station.
    // Erreurs : aucune. Dépendances : nmcli.js (lireStation, debit), releve.
    function sonder(texte) {
        const [compteurs, station] = texte.split("\n--\n")
        const c = compteurs.trim().split("\n").map(Number)
        const maintenant = Date.now()
        const lu = Nmcli.lireStation(station ?? "")
        signalDbm = lu.dbm
        connecteDepuis = lu.duree
        if (c.length !== 2 || c.some(isNaN)) { releve.precedent = null; return }
        const avant = releve.precedent
        releve.precedent = {rx: c[0], tx: c[1], t: maintenant}
        if (avant) debits = {rx: [...debits.rx.slice(1), Nmcli.debit(avant.rx, c[0], maintenant - avant.t)],
                             tx: [...debits.tx.slice(1), Nmcli.debit(avant.tx, c[1], maintenant - avant.t)]}
    }

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

    // lireVeille — met veille à jour d'après une ligne du moniteur « NetworkManager is now in the '<état>' state ».
    // Entrée : texte, une ligne du moniteur (en anglais : la surveillance impose LC_ALL=C). Sortie : aucune.
    // Erreurs : une autre ligne est ignorée. Dépendances : aucune.
    function lireVeille(texte) {
        const m = /is now in the '([^']*)' state/.exec(texte)
        if (m) veille = m[1] === "asleep"
    }

    Relance {
        id: relance
        surveille: ["nmcli", "monitor"]
        environnement: ({LC_ALL: "C"})
        onLigne: texte => etat.lireVeille(texte)
        // Active en premier lieu l'appareil filaire s'il existe, sinon le Wi-Fi, pour la section IP.
        lecture: ["sh", "-c", `a=$(nmcli -t -f TYPE,DEVICE connection show --active)
            printf '%s\\n--\\n' "$a"
            d=$(printf '%s\\n' "$a" | awk -F: '$1=="802-3-ethernet"{e=$2} $1=="802-11-wireless"{w=$2} END{print e?e:w}')
            [ -n "$d" ] && nmcli -t -f GENERAL.DEVICE,IP4.ADDRESS,IP4.GATEWAY,IP4.DNS,IP6.ADDRESS,GENERAL.HWADDR,GENERAL.METERED device show "$d"
            printf '%s\\n' --
            nmcli -t -f NAME,UUID,TYPE,DEVICE,ACTIVE connection show`]
        onLu: texte => etat.lu(texte)
    }

    // Minuteur de la sonde : un relevé par seconde, seulement tant que quelqu'un le demande et qu'un appareil existe.
    // À l'arrêt, le relevé précédent et les mesures de station sont oubliés pour que la reprise ne mesure pas l'écart.
    Timer {
        id: minuteurSonde
        interval: 1000
        repeat: true
        running: etat.sondeActive
        triggeredOnStart: true
        onTriggered: if (!releve.running) releve.running = true
        onRunningChanged: if (!running) { releve.precedent = null; etat.signalDbm = null; etat.connecteDepuis = null }
    }

    // Un seul relevé à la fois : compteurs du noyau, puis iw ; les erreurs des deux sont écartées (interface perdue).
    Process {
        id: releve
        property var precedent: null
        command: ["sh", "-c", 'cat "$1/$2/rx_bytes" "$1/$2/tx_bytes" 2>/dev/null; echo --; iw dev "$2" station dump 2>/dev/null',
                  "sh", etat.racineCompteurs, etat.appareil]
        stdout: StdioCollector { id: releveSortie }
        onExited: etat.sondeActive && etat.sonder(releveSortie.text)
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
