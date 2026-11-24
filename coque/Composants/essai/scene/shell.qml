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
// ouvrir, fermer, executer, apparition (montée ou apparition depuis le centre), echelle (échelle du cadre), delai
// (délai d'affichage), placer (placement du cadre), fenetresLanceur (fenêtres suivies par le lanceur), espace
// (namespace du calque), evenement (événement de Hyprland simulé), etat.
// Sorties : « essai : prêt » au démarrage ; « essai : exécuté <id> » à chaque action de la scène (« essai : exécuté
// lanceur <genre> » pour le lanceur) ; « essai : fenêtre construite » à chaque construction de la fenêtre de la
// scène ; « essai : calque retiré » quand Hyprland retire le calque de la scène (closelayer de scene.espace), pour
// que les essais vérifient qu'une action ne part qu'après ce retrait.
// Erreurs : celles de Theme, de la scène et du lanceur, dans le journal.
// Dépendances : quickshell ≥ 0.3 (IpcHandler, Hyprland.rawEvent), Scene, Lanceur, Theme ; liens essai/scene/Theme,
// Composants, Lanceur, Applications, Barre, Parametres et Deconnexion, car Quickshell ne suit pas les imports hors du
// dossier de la coque.
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

    // onRawEvent — journalise le retrait du calque de la scène. Entrée : e, l'événement brut de Hyprland (name,
    // data). Sortie : la ligne « essai : calque retiré » pour closelayer>><scene.espace>, rien pour un autre
    // événement. Erreurs : aucune. Dépendances : Hyprland.rawEvent, scene.espace.
    Connections {
        target: Hyprland
        function onRawEvent(e) { if (e.name === "closelayer" && e.data === scene.espace) console.log("essai : calque retiré") }
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

        // apparition — choisit la façon dont le cadre paraît à la prochaine ouverture. Entrée : montee, vrai pour la
        // montée depuis le bas, faux pour l'apparition depuis le centre. Sortie : aucune. Erreurs : aucune.
        // Dépendances : scene.montee.
        function apparition(montee: bool): void { scene.montee = montee }

        // echelle — échelle courante du cadre, portée par le Loader de la fenêtre. Entrées : aucune. Sortie : l'échelle
        // en texte, ou « » si la fenêtre n'est pas construite. Erreurs : aucune. Dépendances : scene.fenetre.cadre.
        function echelle(): string { return String(scene.fenetre?.cadre?.parent?.scale ?? "") }

        // delai — pose le délai d'affichage de la prochaine ouverture. Entrée : ms, en millisecondes. Sortie : aucune.
        // Erreurs : aucune. Dépendances : scene.delai.
        function delai(ms: int): void { scene.delai = ms }

        // espace — pose le namespace du calque de la prochaine ouverture. Entrée : nom, le namespace. Sortie : aucune.
        // Erreurs : aucune. Dépendances : scene.espace.
        function espace(nom: string): void { scene.espace = nom }

        // placer — fournit à la scène une fonction de placement qui pose le haut du cadre à une hauteur fixe.
        // Entrée : haut, en pixels depuis le haut de la fenêtre. Sortie : aucune. Erreurs : aucune. Dépendances :
        // scene.positionner.
        function placer(haut: int): void { scene.positionner = () => haut }

        // evenement — simule un événement brut de Hyprland reçu par la scène. Entrées : nom, le nom de l'événement ;
        // donnee, sa donnée. Sortie : aucune. Erreurs : aucune. Dépendances : scene.surEvenement.
        function evenement(nom: string, donnee: string): void { scene.surEvenement(nom, donnee) }

        // fenetresLanceur — nombre de fenêtres de la session que suivent les sources du lanceur. Entrées : aucune.
        // Sortie : l'entier en texte. Erreurs : aucune. Dépendances : Lanceur.sources.fenetres.
        function fenetresLanceur(): string { return String(Lanceur.sources.fenetres.length) }

        // etat — état de la scène. Entrées : aucune. Sortie : JSON {ouvert, present, fenetre (vrai si construite),
        // sortant, differee (l'action en attente, ou null), montre, opacite (l'opacité que Hyprland applique à la
        // surface de la fenêtre, ou null sans fenêtre), haut (le y du Loader du cadre, ou null sans fenêtre)}. Erreurs : aucune. Dépendances : scene.
        function etat(): string {
            return JSON.stringify({ ouvert: scene.ouvert, present: scene.present, fenetre: scene.fenetre !== null,
                                    sortant: scene.sortant, differee: scene.differee, montre: scene.montre,
                                    opacite: scene.fenetre?.HyprlandWindow.opacity ?? null,
                                    haut: scene.fenetre?.cadre?.parent?.y ?? null })
        }
    }

    IpcHandler {
        target: "notifications"

        // nePasDeranger — faux état de « ne pas déranger ». Entrées : aucune. Sortie : « true ». Erreurs : aucune.
        // Dépendances : aucune.
        function nePasDeranger(): string { return "true" }
    }
}
