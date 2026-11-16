import QtQuick
import Quickshell
import Quickshell.Io
import "recherche.js" as Recherche

// Coque d'essai du module Parametres, sans aucune fenêtre.
// Rôle : expose par IPC (cible « parametres ») les fonctions pures de recherche.js, pour que
// tests/test_parametres.py les éprouve dans un vrai Quickshell.
// Entrées : commande IPC appeler <fonction> <{"args": [...]} en JSON>. Sortie : le résultat encodé en JSON, ou
// « erreur : <message> » si la fonction lève. Erreurs : nom de fonction inconnu, JSON invalide (même forme de
// retour). Dépendances : quickshell ≥ 0.3 (Quickshell.Io), recherche.js (lien essai/recherche.js, car Quickshell
// ne suit pas les imports hors du dossier de la coque).
ShellRoot {
    Component.onCompleted: console.log("parametres : prêt")

    IpcHandler {
        target: "parametres"

        // appeler — appelle une fonction exportée de recherche.js.
        // Entrées : fonction, son nom ; argumentsJson, un objet JSON {"args": [...]} (un tableau nu serait
        // déformé par la ligne de commande de qs ipc).
        // Sortie : le résultat en JSON, ou « erreur : <message> ». Erreurs : voir ci-dessus.
        // Dépendances : Recherche.
        function appeler(fonction: string, argumentsJson: string): string {
            try {
                return JSON.stringify(Recherche[fonction](...JSON.parse(argumentsJson).args))
            } catch (e) {
                return "erreur : " + e.message
            }
        }
    }
}
