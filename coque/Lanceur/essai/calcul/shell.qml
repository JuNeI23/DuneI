import QtQuick
import Quickshell
import Quickshell.Io

// Coque d'essai du calcul du lanceur, sans aucune fenêtre ni prise du clavier.
// Rôle : charge Calcul (actif en permanence) et l'expose par IPC (cible « essai ») pour tests/test_lanceur.py
// (CalculTest).
// Entrées : commandes IPC demander <saisie> et etat. Sortie : etat rend {expression, valeur, disponible} en JSON.
// Erreurs : aucune. Dépendances : quickshell ≥ 0.3 (Quickshell.Io), Calcul.qml et calcul.js (liens essai/calcul/,
// car Quickshell ne suit pas les imports hors du dossier de la coque).
ShellRoot {
    // Component.onCompleted — signale que la coque d'essai est prête.
    // Entrées : aucune. Sortie : la ligne « essai : prêt » dans le journal. Erreurs : aucune. Dépendances : console.
    Component.onCompleted: console.log("essai : prêt")

    Calcul {
        id: calcul
        actif: true
    }

    IpcHandler {
        target: "essai"

        // demander — soumet une saisie au calcul.
        // Entrée : saisie. Sortie : aucune. Erreurs : aucune. Dépendances : Calcul.demander.
        function demander(saisie: string): void { calcul.demander(saisie) }

        // etat — état courant du calcul.
        // Entrées : aucune. Sortie : {expression, valeur, disponible} en JSON. Erreurs : aucune. Dépendances : Calcul.
        function etat(): string {
            return JSON.stringify({ expression: calcul.expression, valeur: calcul.valeur, disponible: calcul.disponible })
        }
    }
}
