import QtQuick
import Quickshell
import Quickshell.Io
import "Theme"
import "Verrou"

// Coque d'essai de la saisie du verrou (L2-22), sans fenêtre, sur des piles PAM factices.
// Rôle : charge Saisie sur le dossier de piles DUNEI_ESSAI_PAM (jamais /etc/pam.d) et la pilote par l'IPC « essai »
// pour tests/test_verrou.py (SaisieTest). Elle compte les succès et les secousses.
// Entrées : DUNEI_TOKENS_DIR, DUNEI_ESSAI_PAM ; IPC « essai » : pret(bool), pile(nom), delais(repos, message, garde),
// taper(texte), entree(), retour(), echap(), etat() (JSON {points, ouvert, verifie, message, reussis, secousses}).
// Sorties : « essai : prêt » au démarrage. Erreurs : celles de Theme et de Saisie, dans le journal.
// Dépendances : quickshell ≥ 0.3 (IpcHandler), Saisie, Theme ; liens essai/saisie/ vers les modules de la coque.
ShellRoot {
    id: essai

    property int reussis: 0
    property int secousses: 0

    Saisie {
        id: saisie
        dossierPile: Quickshell.env("DUNEI_ESSAI_PAM")
        pile: "succes"
        onReussi: essai.reussis++
        onSecoue: essai.secousses++
    }

    // Component.onCompleted — signale la coque prête. Entrées, sortie : la ligne « essai : prêt ». Erreurs : aucune.
    Component.onCompleted: console.log("essai : prêt")

    IpcHandler {
        target: "essai"

        // pret — dit si le verrou est acquis. Entrée : oui. Sortie : aucune.
        function pret(oui: bool): void { saisie.pret = oui }
        // pile — choisit la pile PAM factice. Entrée : nom. Sortie : aucune.
        function pile(nom: string): void { saisie.pile = nom }
        // delais — écrase les délais d'essai, en ms. Entrées : repos, message, garde. Sortie : aucune.
        function delais(repos: int, message: int, garde: int): void {
            saisie.repos = repos; saisie.dureeMessage = message; saisie.garde = garde
        }
        // taper — frappe chaque caractère du texte. Entrée : texte. Sortie : aucune.
        function taper(texte: string): void { for (const c of Array.from(texte)) saisie.touche(0, c) }
        // entree, retour, echap — frappe la touche nommée. Entrées, sortie : aucune.
        function entree(): void { saisie.touche(Qt.Key_Return, "\r") }
        function retour(): void { saisie.touche(Qt.Key_Backspace, "\b") }
        function echap(): void { saisie.touche(Qt.Key_Escape, "\u001b") }
        // etat — l'état de la saisie et les compteurs. Sortie : JSON.
        function etat(): string {
            return JSON.stringify({ points: saisie.points, ouvert: saisie.ouvert, verifie: saisie.verifie,
                                    message: saisie.message, reussis: essai.reussis, secousses: essai.secousses })
        }
    }
}
