import QtQuick
import Quickshell
import Quickshell.Io
import "nmcli.js" as Nmcli

// Coque d'essai de la bibliothèque nmcli.js, sans aucune fenêtre.
// Rôle : expose par IPC (cible « reseau ») les fonctions pures de nmcli.js, pour que tests/test_reseau.py les
// éprouve dans un vrai Quickshell.
// Entrées : commande IPC appeler <fonction> <{"args": [...]} en JSON>. Sortie : le résultat encodé en JSON, ou
// « erreur : <message> » si la fonction lève. Erreurs : nom de fonction inconnu, JSON invalide (même forme de
// retour). Dépendances : quickshell ≥ 0.3 (Quickshell.Io), nmcli.js (lien essai/nmcli.js, car Quickshell ne
// suit pas les imports hors du dossier de la coque).
ShellRoot {
    Component.onCompleted: console.log("reseau : prêt")

    IpcHandler {
        target: "reseau"

        // appeler — appelle une fonction exportée de nmcli.js.
        // Entrées : fonction, son nom ; argumentsJson, un objet JSON {"args": [...]} (un tableau nu serait
        // déformé par la ligne de commande de qs ipc).
        // Sortie : le résultat en JSON, ou « erreur : <message> ». Erreurs : voir ci-dessus.
        // Dépendances : Nmcli.
        function appeler(fonction: string, argumentsJson: string): string {
            try {
                return JSON.stringify(Nmcli[fonction](...JSON.parse(argumentsJson).args))
            } catch (e) {
                return "erreur : " + e.message
            }
        }
    }
}
