import QtQuick
import Quickshell
import Quickshell.Io
import "audio.js" as Audio

// Coque d'essai de la logique de l'audio, sans aucune fenêtre.
// Rôle : expose par IPC (cible « audio ») les fonctions pures de audio.js, pour que tests/test_audio.py les éprouve
// dans un vrai Quickshell.
// Entrées : commande IPC appeler <fonction> <{"args": [...]} en JSON>. Sortie : le résultat encodé en JSON, ou
// « erreur : <message> » si la fonction lève. Erreurs : nom de fonction inconnu, JSON invalide (même forme de
// retour). Dépendances : quickshell ≥ 0.3 (Quickshell.Io), audio.js (lien essai/audio.js, car Quickshell ne suit pas
// les imports hors du dossier de la coque).
ShellRoot {
    Component.onCompleted: console.log("audio : prêt")

    IpcHandler {
        target: "audio"

        // appeler — appelle une fonction exportée de audio.js.
        // Entrées : fonction, son nom ; argumentsJson, un objet JSON {"args": [...]}.
        // Sortie : le résultat en JSON, ou « erreur : <message> ». Erreurs : voir ci-dessus. Dépendances : Audio.
        function appeler(fonction: string, argumentsJson: string): string {
            try {
                return JSON.stringify(Audio[fonction](...JSON.parse(argumentsJson).args))
            } catch (e) {
                return "erreur : " + e.message
            }
        }
    }
}
