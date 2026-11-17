import QtQuick
import Quickshell
import Quickshell.Io
import "son.js" as Son

// Coque d'essai de la règle de la voix des notifications, sans aucune fenêtre (L2-68).
// Rôle : expose par IPC (cible « essai ») les fonctions pures de son.js, pour que tests/test_notifications.py
// (SonTest) les éprouve dans un vrai Quickshell.
// Entrées : commande IPC appeler <fonction> <{"args": [...]} en JSON>. Sortie : le résultat encodé en JSON, ou
// « erreur : <message> » si la fonction lève. Erreurs : nom de fonction inconnu, JSON invalide (même forme de
// retour). Dépendances : quickshell ≥ 0.3 (Quickshell.Io), son.js et garde.js (liens essai/son/, car Quickshell ne
// suit pas les imports hors du dossier de la coque).
ShellRoot {
    Component.onCompleted: console.log("essai : prêt")

    IpcHandler {
        target: "essai"

        // appeler — appelle une fonction exportée de son.js.
        // Entrées : fonction, son nom ; argumentsJson, un objet JSON {"args": [...]} (un tableau nu serait déformé
        // par la ligne de commande de qs ipc). Sortie : le résultat en JSON, ou « erreur : <message> ».
        // Erreurs : voir ci-dessus. Dépendances : Son.
        function appeler(fonction: string, argumentsJson: string): string {
            try {
                return JSON.stringify(Son[fonction](...JSON.parse(argumentsJson).args))
            } catch (e) {
                return "erreur : " + e.message
            }
        }
    }
}
