import QtQuick
import Quickshell
import Quickshell.Io
import "energie.js" as Energie

// Coque d'essai de la logique de l'énergie, sans aucune fenêtre.
// Rôle : expose par IPC (cible « energie ») les fonctions pures de energie.js, pour que tests/test_energie.py les éprouve
// dans un vrai Quickshell.
// Entrées : commande IPC appeler <fonction> <{"args": [...]} en JSON>. Sortie : le résultat encodé en JSON, ou
// « erreur : <message> » si la fonction lève. Erreurs : nom de fonction inconnu, JSON invalide (même forme de
// retour). Dépendances : quickshell ≥ 0.3 (Quickshell.Io), energie.js (lien essai/energie.js, car Quickshell ne suit pas
// les imports hors du dossier de la coque).
ShellRoot {
    Component.onCompleted: console.log("energie : prêt")

    IpcHandler {
        target: "energie"

        // appeler — appelle une fonction exportée de energie.js.
        // Entrées : fonction, son nom ; argumentsJson, un objet JSON {"args": [...]}.
        // Sortie : le résultat en JSON, ou « erreur : <message> ». Erreurs : voir ci-dessus. Dépendances : Energie.
        function appeler(fonction: string, argumentsJson: string): string {
            try {
                return JSON.stringify(Energie[fonction](...JSON.parse(argumentsJson).args))
            } catch (e) {
                return "erreur : " + e.message
            }
        }
    }
}
