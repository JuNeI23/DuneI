import QtQuick
import Quickshell
import Quickshell.Io
import "bluetooth.js" as Bt
import "Bluetooth"
import Quickshell.Bluetooth

// Coque d'essai de la logique du Bluetooth, sans aucune fenêtre.
// Rôle : expose par IPC (cible « bluetooth ») les fonctions pures de bluetooth.js, pour que tests/test_bluetooth.py
// les éprouve dans un vrai Quickshell, et la ligne d'état du singleton EtatBluetooth réel (lien essai/Bluetooth).
// Entrées : commande IPC appeler <fonction> <{"args": [...]} en JSON>. Sortie : le résultat encodé en JSON, ou
// « erreur : <message> » si la fonction lève. Erreurs : nom de fonction inconnu, JSON invalide (même forme de
// retour). Dépendances : quickshell ≥ 0.3 (Quickshell.Io), bluetooth.js (lien essai/bluetooth.js, car Quickshell ne
// suit pas les imports hors du dossier de la coque).
ShellRoot {
    id: racine
    Component.onCompleted: console.log("bluetooth : prêt")

    // Appareil factice pour les scénarios du singleton : ses appels sont relevés dans appels.
    component FauxAppareil: QtObject {
        property string name: "Factice"
        property string address
        property bool paired: false
        property bool connected: false
        property bool pairing: false
        property bool trusted: false
        property int state: BluetoothDeviceState.Disconnected
        property var appels: []
        function pair() { appels = appels.concat(["pair"]); pairing = true }
        function connect() { appels = appels.concat(["connect"]) }
        function disconnect() { appels = appels.concat(["disconnect"]); connected = false; state = BluetoothDeviceState.Disconnected }
        function forget() { appels = appels.concat(["forget"]) }
    }
    Component { id: fabrique; FauxAppareil {} }
    // Échecs émis par le singleton, relevés pour les scénarios.
    property var echecs: []
    Connections {
        target: EtatBluetooth
        function onEchec(adresse, message) { racine.echecs = racine.echecs.concat([adresse + " " + message]) }
    }

    IpcHandler {
        target: "bluetooth"

        // scenario — joue un scénario du suivi d'EtatBluetooth sur un appareil factice neuf, puis rend en JSON
        // {appels, trusted, echecs}. Entrée : cle, « appaireDejaConnecte » (appairage abouti sur un appareil déjà
        // connecté, puis déconnexion voulue) ou « doubleAppairage » (deux appairages coup sur coup).
        // Erreurs : un scénario inconnu rend les valeurs de l'appareil intact. Dépendances : EtatBluetooth, fabrique.
        function scenario(cle: string): string {
            racine.echecs = []
            const a = fabrique.createObject(racine, { address: cle })
            if (cle === "appaireDejaConnecte") {
                EtatBluetooth.appairer(a)
                a.pairing = false; a.paired = true; a.connected = true; a.state = BluetoothDeviceState.Connected
                EtatBluetooth.suiviApparie(a)
                EtatBluetooth.suiviEtat(a)
                EtatBluetooth.basculer(a)
                EtatBluetooth.suiviEtat(a)
            } else if (cle === "doubleAppairage") {
                EtatBluetooth.appairer(a)
                EtatBluetooth.appairer(a)
            }
            const r = JSON.stringify({ appels: a.appels, trusted: a.trusted, echecs: racine.echecs })
            a.destroy()
            return r
        }

        // resume — rend la ligne d'état du vrai singleton EtatBluetooth, preuve qu'il se charge sur cette machine.
        // Entrées : aucune. Sortie : resumeTexte. Erreurs : aucune. Dépendances : EtatBluetooth.
        function resume(): string { return EtatBluetooth.resumeTexte }

        // appeler — appelle une fonction exportée de bluetooth.js.
        // Entrées : fonction, son nom ; argumentsJson, un objet JSON {"args": [...]}.
        // Sortie : le résultat en JSON, ou « erreur : <message> ». Erreurs : voir ci-dessus. Dépendances : Bt.
        function appeler(fonction: string, argumentsJson: string): string {
            try {
                return JSON.stringify(Bt[fonction](...JSON.parse(argumentsJson).args))
            } catch (e) {
                return "erreur : " + e.message
            }
        }
    }
}
