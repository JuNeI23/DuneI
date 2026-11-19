import QtQuick
import Quickshell
import Quickshell.Io
import "lanceur.js" as Logique

// Coque d'essai de la logique du lanceur, sans aucune fenêtre.
// Rôle : expose par IPC (cible « essai ») les fonctions pures de lanceur.js, pour que tests/test_lanceur.py
// (LogiqueTest) les éprouve dans un vrai Quickshell.
// Entrées : commande IPC appeler <fonction> <{"args": [...]} en JSON>. Sortie : le résultat encodé en JSON, ou
// « erreur : <message> » si la fonction lève. Erreurs : nom de fonction inconnu, JSON invalide (même forme de
// retour). Dépendances : quickshell ≥ 0.3 (Quickshell.Io), lanceur.js (lien essai/logique/lanceur.js, car
// Quickshell ne suit pas les imports hors du dossier de la coque) et MemoireLanceur (lien du même ordre).
// Commande IPC noter <clé> : note un lancement dans lanceur.json de DUNEI_ETAT_DIR.
ShellRoot {
    // Component.onCompleted — signale que la coque d'essai est prête.
    // Entrées : aucune. Sortie : la ligne « essai : prêt » dans le journal, que les tests attendent.
    // Erreurs : aucune. Dépendances : console.
    Component.onCompleted: console.log("essai : prêt")

    MemoireLanceur { id: memoire }

    IpcHandler {
        target: "essai"

        // appeler — appelle une fonction exportée de lanceur.js.
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

        // noter — note un lancement dans le relevé d'usage de l'essai.
        // Entrée : cle, la clé du résultat. Sortie : le relevé encodé en JSON. Erreurs : aucune.
        // Dépendances : MemoireLanceur.
        function noter(cle: string): string {
            memoire.noter(cle)
            return JSON.stringify(memoire.usage)
        }
    }
}
