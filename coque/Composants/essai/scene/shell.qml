//@ pragma IconTheme DuneI
//@ pragma Env QSG_DISTANCEFIELD_ANTIALIASING=gray
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "Theme"
import "Composants"
import "Lanceur"

// Coque d'essai du socle Scene (L2-23), dans la vraie session Wayland, sans jamais prendre le clavier.
// Rôle : déclare un Scene dont le cadre est un rectangle de 200 × 100, sans clavier exclusif, dont l'exécution est
// remplacée par une ligne de journal (rien n'est exécuté pour de bon) ; charge aussi le singleton Lanceur, privé de
// même du clavier et de l'exécution, pour l'essai de la famille « attention ». tests/test_scene.py la pilote ; elle
// sert aussi aux captures de la montée et du fondu. Elle sert la cible « notifications », dont l'état « ne pas
// déranger » vaut toujours « true ».
// Entrées : DUNEI_TOKENS_DIR et DUNEI_ETAT_DIR (jetons, thème et relevé d'usage de l'essai) ; IPC « essai » : pret,
// ouvrir, fermer, executer, etat. Sorties : « essai : prêt » au démarrage ; « essai : exécuté <id> » à chaque action
// de la scène (« essai : exécuté lanceur <genre> » pour le lanceur) ; « essai : fenêtre construite » à chaque
// construction de la fenêtre de la scène ; « essai : calque retiré » quand Hyprland retire un calque dunei-attention
// (closelayer), pour que les essais vérifient qu'une action ne part qu'après ce retrait.
// Erreurs : celles de Theme, de la scène et du lanceur, dans le journal.
// Dépendances : quickshell ≥ 0.3 (IpcHandler, Hyprland.rawEvent), Scene, Lanceur, Theme ; liens essai/scene/Theme,
// Composants, Lanceur, Applications, Barre et Parametres, car Quickshell ne suit pas les imports hors du dossier de la
// coque.
ShellRoot {
    id: essai

    Scene {
        id: scene
        clavierExclusif: false
        executeur: a => console.log("essai : exécuté " + a)
        cadre: Component {
            Rectangle {
                width: 200
                height: 100
                radius: Theme.radius?.window ?? 0
                color: Theme.color?.accent ?? "transparent"
            }
        }

        // onFenetreChanged — journalise chaque construction de la fenêtre, pour vérifier qu'une réouverture pendant
        // la sortie la reprend. Entrées : aucune. Sortie : la ligne « essai : fenêtre construite » quand fenetre
        // devient non nulle. Erreurs : aucune. Dépendances : scene.fenetre.
        onFenetreChanged: if (fenetre) console.log("essai : fenêtre construite")
    }

    // Component.onCompleted — retire le clavier au lanceur, détourne son exécution et signale que la coque est prête.
    // Entrées : aucune. Sortie : la ligne « essai : prêt ». Erreurs : aucune. Dépendances : Lanceur, console.
    Component.onCompleted: {
        Lanceur.clavierExclusif = false
        Lanceur.executeur = a => console.log("essai : exécuté lanceur " + a.genre)
        console.log("essai : prêt")
    }

    // onRawEvent — journalise le retrait d'un calque d'attention. Entrée : e, l'événement brut de Hyprland (name,
    // data). Sortie : la ligne « essai : calque retiré » pour closelayer>>dunei-attention, rien pour un autre
    // événement. Erreurs : aucune. Dépendances : Hyprland.rawEvent.
    Connections {
        target: Hyprland
        function onRawEvent(e) { if (e.name === "closelayer" && e.data === "dunei-attention") console.log("essai : calque retiré") }
    }

    IpcHandler {
        target: "essai"

        // pret — vrai une fois les jetons et le mouvement chargés. Sortie : « true » ou « false ».
        function pret(): string { return String(Theme.ready && Theme.motion !== null) }

        // ouvrir, fermer — ouvrent ou ferment la scène. Sortie : aucune. Erreurs : aucune. Dépendances : scene.ouvert.
        function ouvrir(): void { scene.ouvert = true }
        function fermer(): void { scene.ouvert = false }

        // executer — ferme la scène en faisant exécuter une action (voir Scene.executer). Entrée : id, l'action, une
        // simple chaîne ici. Sortie : aucune. Erreurs : aucune. Dépendances : scene.executer.
        function executer(id: string): void { scene.executer(id) }

        // etat — état de la scène. Entrées : aucune. Sortie : JSON {ouvert, present, fenetre (vrai si construite),
        // sortant, differee (l'action en attente, ou null)}. Erreurs : aucune. Dépendances : scene.
        function etat(): string {
            return JSON.stringify({ ouvert: scene.ouvert, present: scene.present, fenetre: scene.fenetre !== null,
                                    sortant: scene.sortant, differee: scene.differee })
        }
    }

    IpcHandler {
        target: "notifications"

        // nePasDeranger — faux état de « ne pas déranger ». Entrées : aucune. Sortie : « true ». Erreurs : aucune.
        // Dépendances : aucune.
        function nePasDeranger(): string { return "true" }
    }
}
