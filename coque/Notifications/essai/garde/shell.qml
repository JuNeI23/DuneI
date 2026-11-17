import QtQuick
import Quickshell
import Quickshell.Io
import "garde.js" as Garde

// Coque d'essai des règles de garde des notifications, sans aucune fenêtre.
// Rôle : expose par IPC (cible « essai ») les fonctions pures de garde.js, pour que tests/test_notifications.py
// (GardeTest) les éprouve dans un vrai Quickshell.
// Entrées : commande IPC appeler <fonction> <{"args": [...]} en JSON>. Sortie : le résultat encodé en JSON, ou
// « erreur : <message> » si la fonction lève. Erreurs : nom de fonction inconnu, JSON invalide (même forme de
// retour). Dépendances : quickshell ≥ 0.3 (Quickshell.Io), garde.js (lien essai/garde/garde.js, car Quickshell ne
// suit pas les imports hors du dossier de la coque).
ShellRoot {
    Component.onCompleted: console.log("essai : prêt")

    IpcHandler {
        target: "essai"

        // appeler — appelle une fonction exportée de garde.js.
        // Entrées : fonction, son nom ; argumentsJson, un objet JSON {"args": [...]} (un tableau nu serait déformé
        // par la ligne de commande de qs ipc). Sortie : le résultat en JSON, ou « erreur : <message> ».
        // Erreurs : voir ci-dessus. Dépendances : Garde.
        function appeler(fonction: string, argumentsJson: string): string {
            try {
                return JSON.stringify(Garde[fonction](...JSON.parse(argumentsJson).args))
            } catch (e) {
                return "erreur : " + e.message
            }
        }
    }
}
