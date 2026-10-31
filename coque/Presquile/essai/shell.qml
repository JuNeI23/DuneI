import QtQuick
import Quickshell
import Quickshell.Io
import "Theme"
import "Presquile/bureaux.js" as Bureaux

// Coque d'essai du module Presquile, sans aucune fenêtre.
// Rôle : expose par IPC (cible « presquile ») les fonctions pures de bureaux.js, pour que tests/test_presquile.py
// les éprouve dans un vrai Quickshell. Les tâches suivantes y ajoutent leurs composants et leurs fonctions IPC.
// Entrées : DUNEI_TOKENS_DIR, lu par Theme. Commandes IPC : indexPilule, pasMolette, cibleMolette, lireSpecial,
// commandesClic, commandeBureau (les listes et objets sont rendus en JSON, le reste en texte).
// Sortie : le résultat de chaque appel IPC, sur la sortie de « qs ipc call ». Erreurs : celles de Theme, dans
// le journal. Dépendances : quickshell ≥ 0.3 (Quickshell.Io), modules Theme, Composants et Presquile.
// Import : liens essai/Theme, essai/Composants et essai/Presquile, comme dans les autres coques d'essai.
ShellRoot {
    // Theme est un singleton paresseux : cette lecture le charge, ce qu'attend le setUp de l'essai.
    Component.onCompleted: Theme.tokens

    IpcHandler {
        target: "presquile"

        function indexPilule(idActif: int, nombre: int): int { return Bureaux.indexPilule(idActif, nombre) }
        function pasMolette(cumul: real, delta: real): string { return JSON.stringify(Bureaux.pasMolette(cumul, delta)) }
        function cibleMolette(idActif: int, pas: int, nombre: int): int { return Bureaux.cibleMolette(idActif, pas, nombre) }
        function lireSpecial(donnees: string): string { return Bureaux.lireSpecial(donnees) }
        function commandeBureau(id: int): string { return Bureaux.commandeBureau(id) }
        function commandesClic(id: int, idActif: int, special: string): string {
            return JSON.stringify(Bureaux.commandesClic(id, idActif, special))
        }
    }
}
