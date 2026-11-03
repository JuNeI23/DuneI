pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire
import "bluetooth.js" as Bt

// EtatBluetooth — état et actions du Bluetooth pour la coque, adossés à Quickshell.Bluetooth (L2-14).
// Rôle : lit l'adaptateur par défaut et ses appareils, compose la ligne d'état de l'en-tête, et porte les actions du
// popover. L'appairage d'un nouvel appareil passe par l'exécutable dunei-bluetooth-appairer (fiche 0.3, objectif 10) :
// Pair() de Quickshell n'enregistre aucun agent, ce que BlueZ refuse, et ne choisit pas le transport. L'exécutable,
// lancé ici et non dans le popover pour survivre à sa fermeture, appaire avec un agent et le transport voulu
// (bluetooth.js, transport), marque de confiance et connecte ; la recherche du popover se suspend pendant ce temps,
// car BlueZ fusionne les filtres de ses clients. Le popover lit ce singleton par sa propriété etat, que la coque
// d'essai remplace par un factice aux mêmes noms.
// Entrées : recherche, en écriture : vrai demande la recherche des appareils voisins (discovering), faux la rend ;
// commandeAppairage, la commande lancée avec l'adresse et le transport (« dunei-bluetooth-appairer » par défaut,
// remplacée par la coque d'essai).
// Sorties : disponible, vrai si un adaptateur existe ; allume ; recherche ; rechercheVoulue, la recherche demandée
// hors appairage en cours ; enRecherche, vrai tant que l'adaptateur recherche ; appareils, les BluetoothDevice de
// l'adaptateur ; connecte, le premier appareil connecté, ou null ; resumeTexte, la ligne d'état de l'en-tête
// (bluetooth.js, resume) ; noeuds, les noms des nœuds PipeWire ; pret(appareil), la connexion telle que l'utilisateur
// l'entend (audio monté pour un appareil audio) ; appairages, adresse → vrai tant que son appairage est en cours ; signaux
// appairageLance(adresse) et echec(adresse, message).
// Erreurs : echec(adresse, « Appairage impossible ») si l'exécutable sort en 1 ou autrement (refus, appareil à code,
// hors de portée) ; echec(adresse, « Connexion impossible ») s'il sort en 2, ou si une connexion demandée revient à
// l'état déconnecté.
// Dépendances : Quickshell (Singleton, Instantiator), Quickshell.Io (Process), Quickshell.Bluetooth (Bluetooth,
// BluetoothDeviceState), Quickshell.Services.Pipewire (Pipewire.nodes), bluetooth.js (resume, transport,
// estConnecte, audioPret), dunei-bluetooth-appairer (config/bin).
Singleton {
    id: etat

    readonly property var adaptateur: Bluetooth.defaultAdapter
    readonly property bool disponible: adaptateur !== null
    readonly property bool allume: adaptateur?.enabled ?? false
    property bool recherche: false
    readonly property bool enRecherche: adaptateur?.discovering ?? false
    readonly property var appareils: adaptateur?.devices.values ?? []
    // Noms des nœuds PipeWire, lus sans liaison (PwNode.name), pour savoir si l'audio d'un appareil est monté.
    readonly property var noeuds: Array.from(Pipewire.nodes.values ?? []).map(n => n?.name ?? "")
    readonly property var connecte: appareils.find(a => pret(a)) ?? null
    readonly property string resumeTexte: Bt.resume(allume, connecte ? {
        nom: connecte.name, batterie: connecte.batteryAvailable ? connecte.battery : null } : null)
    property var commandeAppairage: ["dunei-bluetooth-appairer"]
    signal appairageLance(string adresse)
    signal echec(string adresse, string message)

    // Adresses des appairages en cours (réaffecté à chaque changement, pour notifier le popover) et des connexions
    // demandées, suivies jusqu'à leur issue.
    property var appairages: ({})
    property var connexions: ({})
    readonly property bool rechercheVoulue: recherche && Object.keys(appairages).length === 0

    // La recherche suit la demande tant que la radio est allumée ; une radio rallumée pendant l'ouverture la reprend.
    onRechercheVoulueChanged: suivreRecherche()
    onAllumeChanged: suivreRecherche()

    // suivreRecherche — accorde discovering à la demande de recherche, suspendue pendant un appairage.
    // Entrées : aucune. Sortie : aucune. Erreurs : aucune ; sans adaptateur ou radio coupée, rien n'est fait.
    // Dépendances : adaptateur, allume, rechercheVoulue.
    function suivreRecherche(): void {
        if (adaptateur && allume && adaptateur.discovering !== rechercheVoulue) adaptateur.discovering = rechercheVoulue
    }

    // pret — connexion telle que l'utilisateur l'entend (bluetooth.js, estConnecte) : un appareil audio n'est prêt que
    // si PipeWire a sa sortie. Entrée : a, un BluetoothDevice. Sortie : vrai ou faux. Erreurs : aucune.
    // Dépendances : noeuds, bluetooth.js (estConnecte, audioPret).
    function pret(a): bool {
        return !!a && Bt.estConnecte(a.connected, a.icon, Bt.audioPret(noeuds, a.address))
    }

    // allumer — allume ou coupe la radio. Entrées : actif. Sortie : aucune. Erreurs : sans adaptateur, rien.
    // Dépendances : adaptateur.
    function allumer(actif: bool): void {
        if (adaptateur) adaptateur.enabled = actif
    }

    // basculer — déconnecte un appareil prêt, connecte les autres : un appareil audio relié sans audio (liaison LE
    // seule, recette du 2026-11-03) reçoit connect(), qui monte ses profils, sans suivi puisqu'il est déjà « Connected ».
    // Une connexion depuis l'état déconnecté est suivie par connexions ; une déconnexion voulue efface ce suivi : elle
    // n'est jamais un échec.
    // Entrées : appareil, un BluetoothDevice. Sortie : aucune. Erreurs : voir echec. Dépendances : connexions.
    function basculer(appareil): void {
        if (pret(appareil)) {
            delete connexions[appareil.address]
            return appareil.disconnect()
        }
        if (!appareil.connected) connexions[appareil.address] = true
        appareil.connect()
    }

    // appairer — lance l'exécutable d'appairage pour un appareil voisin, avec le transport de son type.
    // Entrées : appareil, un BluetoothDevice non appairé. Sortie : aucune. Erreurs : voir echec ; un appareil dont
    // l'appairage est déjà en cours est ignoré (un second clic).
    // Dépendances : appairages, commandeAppairage, fabriqueAppairage, bluetooth.js (transport).
    function appairer(appareil): void {
        const adresse = appareil.address
        if (appairages[adresse]) return
        appairages = Object.assign({}, appairages, { [adresse]: true })
        fabriqueAppairage.createObject(etat, { adresse, command: commandeAppairage.concat([adresse, Bt.transport(appareil.icon)]) })
        appairageLance(adresse)
    }

    // finAppairage — issue de l'exécutable : l'adresse quitte les appairages en cours, et un code non nul devient un
    // echec. Entrées : adresse ; code, le code de sortie. Sortie : aucune. Erreurs : voir echec.
    // Dépendances : appairages.
    function finAppairage(adresse: string, code: int): void {
        const reste = Object.assign({}, appairages)
        delete reste[adresse]
        appairages = reste
        if (code !== 0) echec(adresse, code === 2 ? "Connexion impossible" : "Appairage impossible")
    }

    // Un processus par appairage, détruit à sa sortie.
    Component {
        id: fabriqueAppairage
        Process {
            property string adresse
            running: true
            onExited: (code, statut) => { etat.finAppairage(adresse, code); destroy() }
        }
    }

    // oublier — retire un appareil appairé (forget). Entrées : appareil. Sortie : aucune. Erreurs : aucune.
    // Dépendances : aucune.
    function oublier(appareil): void {
        appareil.forget()
    }

    // suiviEtat — l'état de connexion d'un appareil change : une connexion demandée aboutit, ou échoue
    // (echec(« Connexion impossible ») si l'appareil revient à l'état déconnecté).
    // Entrées : a, l'appareil. Sortie : aucune. Erreurs : voir echec. Dépendances : connexions.
    function suiviEtat(a): void {
        if (!connexions[a.address]) return
        if (a.state === BluetoothDeviceState.Connected) delete connexions[a.address]
        else if (a.state === BluetoothDeviceState.Disconnected) {
            delete connexions[a.address]
            echec(a.address, "Connexion impossible")
        }
    }

    // Suivi de chaque appareil : issue d'une connexion demandée.
    Instantiator {
        model: etat.appareils
        delegate: Connections {
            required property var modelData
            target: modelData
            function onStateChanged() { etat.suiviEtat(modelData) }
        }
    }
}
