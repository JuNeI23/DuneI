pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Networking
import "Reseau"

// EtatFaux — état factice du réseau pour la coque d'essai de la page Wi-Fi : aucune action ne touche le réseau réel.
// Rôle : tient la place d'EtatReseau auprès de la PageWifi du banc (PageBanc.qml la lui passe). Il porte les
// propriétés et les fonctions d'EtatReseau que lisent la page, ses rangées et le dépliant du réseau joint ; ses
// réseaux sont des objets factices qui journalisent leurs appels (connect, connectWithPsk avec la seule longueur du
// mot de passe) ; executer journalise ses arguments et rend un profil fixe, au tour suivant comme un vrai processus ; la mémoire des réseaux vus facturés est
// la vraie MemoireFactures, écrite dans le dossier de l'essai (DUNEI_ETAT_DIR) et non dans l'état de la coque.
// Réseaux : « Wifi_TRIADES » joint ; deux profils à portée, dont le partage de connexion « Telephone_Essai » ; un
// profil hors de portée, « Cafe » ; neuf réseaux sans profil, dont deux ouverts.
// Entrées : DUNEI_ETAT_DIR, le dossier où la mémoire est écrite (reseau.json), lu par MemoireFactures.
// Sorties : les propriétés d'EtatReseau lues par la page ; tous, les réseaux factices ; journal « essai : … ».
// Fonctions : reseau, joindre, allumer, executer, demanderSonde.
// Erreurs : aucune. Dépendances : Quickshell (Singleton, env), Quickshell.Networking (WifiSecurityType),
// MemoireFactures.
Singleton {
    id: faux

    property bool carte: true
    property bool radio: true
    property bool filaire: false
    property bool carteFilaire: true
    property string connectivite: "full"
    property string nomActif: "Wifi_TRIADES"
    property bool facture: false
    property string appareil: "wlan0"
    property var ip4: ["192.168.1.42/24"]
    property var ip6: ["fe80::1/64"]
    property string passerelle: "192.168.1.1"
    property var dns: ["192.168.1.1"]
    property string mac: "A4:C3:F0:5B:1E:72"
    property bool recherche: false
    property bool rechercheFenetre: false
    property var reseaux: []
    property var debits: ({rx: Array.from({length: 60}, (_, i) => 900000 + 700000 * Math.sin(i / 5)),
                           tx: Array.from({length: 60}, (_, i) => 200000 + 90000 * Math.cos(i / 7))})
    property var signalDbm: -52
    property var connecteDepuis: 11460
    property var canal: 36
    property var frequence: 5180
    property int sondeurs: 0
    property var profils: [
        {nom: "Wifi_TRIADES", uuid: "wifi-1", type: "802-11-wireless", appareil: "wlan0", actif: true},
        {nom: "Telephone_Essai", uuid: "hotspot-1", type: "802-11-wireless", appareil: "", actif: false},
        {nom: "Livebox-A3F2", uuid: "livebox-1", type: "802-11-wireless", appareil: "", actif: false},
        {nom: "Cafe", uuid: "cafe-1", type: "802-11-wireless", appareil: "", actif: false},
        {nom: "Bureau", uuid: "filaire-1", type: "802-3-ethernet", appareil: "", actif: false}
    ]
    property var tous: []
    readonly property var facturesVues: memoire.noms

    // Réseau factice : les membres de WifiNetwork que lisent la page et la Jonction.
    component FauxReseau: QtObject {
        property string name
        property real signalStrength
        property bool connected: false
        property bool known: false
        property int security: WifiSecurityType.Wpa2Psk
        signal connectionFailed(int reason)
        function connect() { console.info("essai : connect " + name) }
        function disconnect() { console.info("essai : disconnect " + name) }
        function connectWithPsk(psk) { console.info("essai : connectWithPsk " + name + " " + psk.length) }
    }
    Component { id: fabrique; FauxReseau {} }
    MemoireFactures { id: memoire; etat: faux }

    // reseau — réseau factice par son nom. Entrée : nom. Sortie : l'objet, ou undefined. Erreurs : aucune.
    // Dépendances : tous.
    function reseau(nom) { return tous.find(r => r.name === nom) }

    // joindre — le réseau nommé devient le réseau joint, comme le rapporte NetworkManager : son objet passe à
    // connected (ce qui fait réussir la Jonction qui le suit), puis la lecture des profils le donne pour actif, en lui
    // créant un profil s'il n'en avait pas. Entrée : nom. Sortie : aucune. Erreurs : aucune ; un nom inconnu ne laisse
    // aucun réseau joint. Dépendances : tous, profils.
    function joindre(nom) {
        tous.forEach(r => { r.connected = r.name === nom; if (r.connected) r.known = true })
        nomActif = nom
        const connus = profils.some(p => p.nom === nom) ? profils
            : profils.concat({nom, uuid: "nouveau-1", type: "802-11-wireless", appareil: "", actif: false})
        profils = connus.map(p => p.type !== "802-11-wireless" ? p
            : Object.assign({}, p, {actif: p.nom === nom, appareil: p.nom === nom ? "wlan0" : ""}))
    }

    // allumer — allume ou coupe la radio factice, en journalisant le geste. Entrée : actif. Sortie : aucune.
    // Erreurs : aucune. Dépendances : aucune.
    function allumer(actif) {
        console.info("essai : allumer " + actif)
        radio = actif
    }

    // executer — tient la place de « nmcli » : journalise les arguments et rend un profil fixe à une lecture.
    // Entrées : args, tableau d'arguments ; fin, fonction(code, sortie), facultative. Sortie : aucune.
    // Erreurs : aucune. Dépendances : aucune.
    function executer(args, fin) {
        console.info("essai : executer " + JSON.stringify(args))
        if (args[0] === "-t" && args.includes("show"))
            Qt.callLater(() => fin?.(0, "connection.autoconnect:yes\nconnection.autoconnect-priority:5\nconnection.metered:unknown\nipv4.method:auto\nipv4.addresses:\nipv4.gateway:\nipv4.dns:\n802-11-wireless.ssid:Wifi_TRIADES\n802-11-wireless-security.key-mgmt:wpa-psk\n"))
    }

    // demanderSonde — compte les demandeurs de la sonde, sans rien relever. Entrée : actif. Sortie : aucune.
    // Erreurs : aucune. Dépendances : sondeurs.
    function demanderSonde(actif) { sondeurs = Math.max(0, sondeurs + (actif ? 1 : -1)) }

    // peupler — ajoute des réseaux factices sans profil, pour éprouver la page sur une longue liste (mesure de
    // fluidité). Entrée : n, leur nombre. Sortie : aucune. Erreurs : aucune. Dépendances : fabrique, tous, reseaux.
    function peupler(n) {
        tous = tous.concat(Array.from({length: n}, (_, i) =>
            fabrique.createObject(faux, {name: "Voisin_" + (i + 1), signalStrength: 0.2 + 0.5 * (i % 7) / 7})))
        reseaux = tous.slice()
    }

    // agiter — rejoue un balayage qui se termine : pendant une seconde, toutes les 20 ms, le signal d'un réseau change
    // et la liste est rendue, comme le fait NetworkManager réseau par réseau (mesure de fluidité). Entrées : aucune.
    // Sortie : aucune. Erreurs : aucune. Dépendances : agitation, tous, reseaux.
    function agiter() { agitation.pas = 0; agitation.start() }
    Timer {
        id: agitation
        property int pas: 0
        interval: 20
        repeat: true
        onTriggered: {
            faux.tous[pas % faux.tous.length].signalStrength = (pas * 37 % 100) / 100
            faux.reseaux = faux.tous.slice()
            if (++pas === 50) stop()
        }
    }

    Component.onCompleted: {
        const c = (name, signalStrength, autres) => fabrique.createObject(faux, Object.assign({name, signalStrength}, autres))
        tous = [c("Wifi_TRIADES", 0.9, {connected: true, known: true}), c("Telephone_Essai", 0.6, {known: true}),
                c("Livebox-A3F2", 0.4, {known: true}), c("Freebox-5C21B0", 0.85), c("eduroam", 0.7),
                c("SFR_WiFi_Fon", 0.65, {security: WifiSecurityType.Open}), c("Bbox-7F3A", 0.5),
                c("DIRECT-HP-Envy", 0.45), c("Livebox-99C0", 0.42), c("TP-Link_4E2", 0.2),
                c("Orange-Invite", 0.15, {security: WifiSecurityType.Open}), c("NETGEAR-21", 0.1)]
        reseaux = tous.slice()
    }
}
