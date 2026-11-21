import QtQuick
import Quickshell
import Quickshell.Io
import "selecteur.js" as Logique

// Coque d'essai de la logique du sélecteur de fenêtres, sans aucune fenêtre.
// Rôle : expose par IPC (cible « essai ») les fonctions pures de selecteur.js, pour que tests/test_selecteur.py
// (LogiqueTest) les éprouve dans un vrai Quickshell.
// Entrées : commande IPC appeler <fonction> <{"args": [...]} en JSON>. Sortie : le résultat encodé en JSON, ou
// « erreur : <message> » si la fonction lève. Erreurs : nom de fonction inconnu, JSON invalide (même forme de
// retour). Dépendances : quickshell ≥ 0.3 et selecteur.js (lien essai/logique/, car Quickshell ne suit pas les
// imports hors du dossier de la coque).
ShellRoot {
    // Component.onCompleted — signale que la coque d'essai est prête.
    // Entrées : aucune. Sortie : la ligne « essai : prêt » dans le journal, que les tests attendent.
    // Erreurs : aucune. Dépendances : console.
    Component.onCompleted: console.log("essai : prêt")

    IpcHandler {
        target: "essai"

        // appeler — appelle une fonction exportée de selecteur.js.
        // Entrées : fonction, son nom ; argumentsJson, un objet JSON {"args": [...]} (un tableau nu serait déformé
        // par la ligne de commande de qs ipc). Sortie : le résultat en JSON, ou « erreur : <message> ».
        // Erreurs : voir ci-dessus. Dépendances : Logique.
        function appeler(fonction: string, argumentsJson: string): string {
            try {
                return JSON.stringify(Logique[fonction](...JSON.parse(argumentsJson).args))
            } catch (e) {
                return "erreur : " + e.message
            }
        }
    }
}
