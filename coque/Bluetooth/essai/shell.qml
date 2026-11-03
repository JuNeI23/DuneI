import QtQuick
import Quickshell
import Quickshell.Io
import "bluetooth.js" as Bt
import "Bluetooth"

// Coque d'essai de la logique du Bluetooth, sans aucune fenêtre.
// Rôle : expose par IPC (cible « bluetooth ») les fonctions pures de bluetooth.js, pour que tests/test_bluetooth.py
// les éprouve dans un vrai Quickshell, et la ligne d'état du singleton EtatBluetooth réel (lien essai/Bluetooth).
// Entrées : commande IPC appeler <fonction> <{"args": [...]} en JSON>. Sortie : le résultat encodé en JSON, ou
// « erreur : <message> » si la fonction lève. Erreurs : nom de fonction inconnu, JSON invalide (même forme de
// retour). Dépendances : quickshell ≥ 0.3 (Quickshell.Io), bluetooth.js (lien essai/bluetooth.js, car Quickshell ne
// suit pas les imports hors du dossier de la coque).
ShellRoot {
    Component.onCompleted: console.log("bluetooth : prêt")

    IpcHandler {
        target: "bluetooth"

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
