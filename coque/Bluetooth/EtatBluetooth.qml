pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Bluetooth
import "bluetooth.js" as Bt

// EtatBluetooth — état et actions du Bluetooth pour la coque, adossés à Quickshell.Bluetooth (L2-14).
// Rôle : lit l'adaptateur par défaut et ses appareils, compose la ligne d'état de l'en-tête, et porte les actions du
// popover. L'appairage d'un nouvel appareil s'enchaîne ici, et non dans le popover, pour survivre à sa fermeture :
// pair(), puis, dès que l'appareil est appairé, trusted (il se reconnectera seul) et connect(). Le popover lit ce
// singleton par sa propriété etat, que la coque d'essai remplace par un factice aux mêmes noms.
// Entrées : recherche, en écriture : vrai demande la recherche des appareils voisins (discovering), faux la rend.
// Sorties : disponible, vrai si un adaptateur existe ; allume ; recherche ; enRecherche, vrai tant que l'adaptateur
// recherche ; appareils, les BluetoothDevice de l'adaptateur ; connecte, le premier appareil connecté, ou null ;
// resumeTexte, la ligne d'état de l'en-tête (bluetooth.js, resume) ; signal echec(adresse, message).
// Erreurs : echec(adresse, « Appairage impossible ») si l'appairage retombe sans aboutir (appareil à code, hors de
// portée, refus) ; echec(adresse, « Connexion impossible ») si une connexion demandée revient à l'état déconnecté.
// Dépendances : Quickshell (Singleton, Instantiator), Quickshell.Bluetooth (Bluetooth, BluetoothDeviceState),
// bluetooth.js (resume).
Singleton {
    id: etat

    readonly property var adaptateur: Bluetooth.defaultAdapter
    readonly property bool disponible: adaptateur !== null
    readonly property bool allume: adaptateur?.enabled ?? false
    property bool recherche: false
    readonly property bool enRecherche: adaptateur?.discovering ?? false
    readonly property var appareils: adaptateur?.devices.values ?? []
    readonly property var connecte: appareils.find(a => a.connected) ?? null
    readonly property string resumeTexte: Bt.resume(allume, connecte ? {
        nom: connecte.name, batterie: connecte.batteryAvailable ? connecte.battery : null } : null)
    signal echec(string adresse, string message)

    // Adresses des appairages lancés par appairer() et des connexions demandées, suivies jusqu'à leur issue.
    property var appairages: ({})
    property var connexions: ({})

    // La recherche suit la demande tant que la radio est allumée ; une radio rallumée pendant l'ouverture la reprend.
    onRechercheChanged: suivreRecherche()
    onAllumeChanged: suivreRecherche()

    // suivreRecherche — accorde discovering à la demande de recherche.
    // Entrées : aucune. Sortie : aucune. Erreurs : aucune ; sans adaptateur ou radio coupée, rien n'est fait.
    // Dépendances : adaptateur, allume, recherche.
    function suivreRecherche(): void {
        if (adaptateur && allume && adaptateur.discovering !== recherche) adaptateur.discovering = recherche
    }

    // allumer — allume ou coupe la radio. Entrées : actif. Sortie : aucune. Erreurs : sans adaptateur, rien.
    // Dépendances : adaptateur.
    function allumer(actif: bool): void {
        if (adaptateur) adaptateur.enabled = actif
    }

    // basculer — déconnecte un appareil connecté, connecte un appareil déconnecté (suivi par connexions).
    // Entrées : appareil, un BluetoothDevice. Sortie : aucune. Erreurs : voir echec. Dépendances : connexions.
    function basculer(appareil): void {
        if (appareil.connected) return appareil.disconnect()
        connexions[appareil.address] = true
        appareil.connect()
    }

    // appairer — lance l'appairage d'un appareil voisin ; la suite (confiance, connexion) vient de son suivi.
    // Entrées : appareil, un BluetoothDevice non appairé. Sortie : aucune. Erreurs : voir echec.
    // Dépendances : appairages.
    function appairer(appareil): void {
        appairages[appareil.address] = true
        appareil.pair()
    }

    // oublier — retire un appareil appairé (forget). Entrées : appareil. Sortie : aucune. Erreurs : aucune.
    // Dépendances : aucune.
    function oublier(appareil): void {
        appareil.forget()
    }

    // Suivi de chaque appareil : issue d'un appairage lancé et d'une connexion demandée.
    Instantiator {
        model: etat.appareils
        delegate: Connections {
            required property var modelData
            target: modelData

            function onPairedChanged() {
                const a = modelData
                if (!a.paired || !etat.appairages[a.address]) return
                delete etat.appairages[a.address]
                a.trusted = true
                etat.connexions[a.address] = true
                a.connect()
            }
            // L'ordre des signaux pairing et paired n'est pas garanti : l'échec se constate au tour suivant.
            function onPairingChanged() {
                const a = modelData
                if (!a.pairing) Qt.callLater(() => {
                    if (a.pairing || a.paired || !etat.appairages[a.address]) return
                    delete etat.appairages[a.address]
                    etat.echec(a.address, "Appairage impossible")
                })
            }
            function onStateChanged() {
                const a = modelData
                if (!etat.connexions[a.address]) return
                if (a.state === BluetoothDeviceState.Connected) delete etat.connexions[a.address]
                else if (a.state === BluetoothDeviceState.Disconnected) {
                    delete etat.connexions[a.address]
                    etat.echec(a.address, "Connexion impossible")
                }
            }
        }
    }
}
