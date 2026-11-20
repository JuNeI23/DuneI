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
        // onValeurChanged — journalise chaque valeur publiée, pour que les tests voient aussi les publications brèves.
        // Entrées : aucune. Sortie : la ligne « valeur : <valeur> ». Erreurs : aucune. Dépendances : console.
        onValeurChanged: console.log("valeur : " + valeur)
    }

    IpcHandler {
        target: "essai"

        // demander — soumet une saisie au calcul.
        // Entrée : saisie. Sortie : aucune. Erreurs : aucune. Dépendances : Calcul.demander.
        function demander(saisie: string): void { calcul.demander(saisie) }

        // demanderDeux — soumet deux saisies d'affilée dans le même appel, avant toute réponse de qalc.
        // Entrées : a, b. Sortie : aucune. Erreurs : aucune. Dépendances : Calcul.demander.
        function demanderDeux(a: string, b: string): void { calcul.demander(a); calcul.demander(b) }

        // etat — état courant du calcul.
        // Entrées : aucune. Sortie : {expression, valeur, disponible} en JSON. Erreurs : aucune. Dépendances : Calcul.
        function etat(): string {
            return JSON.stringify({ expression: calcul.expression, valeur: calcul.valeur, disponible: calcul.disponible })
        }
    }
}
