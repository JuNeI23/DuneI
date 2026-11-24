//@ pragma IconTheme DuneI
//@ pragma Env QSG_DISTANCEFIELD_ANTIALIASING=gray
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "Theme"
import "Lanceur"

// Coque d'essai de la fenêtre du lanceur (L2-16), dans la vraie session Wayland, sans jamais prendre le clavier.
// Rôle : charge le singleton Lanceur, lui retire le clavier exclusif (clavierExclusif faux : la saisie et les touches
// passent par l'IPC « lanceur », taper et touche), remplace son exécution par une ligne de journal (rien n'est lancé,
// amené ni éteint), et relève les largeurs prises par le cadre, comme coque/Notifications/essai/fenetre relève les
// hauteurs de sa forme. tests/test_lanceur.py (FenetreTest) la pilote ; elle sert aussi aux captures contre la
// maquette. Elle sert la cible « notifications », dont l'état « ne pas déranger » vaut toujours « true ».
// Entrées : DUNEI_TOKENS_DIR et DUNEI_ETAT_DIR (jetons, thème et relevé d'usage de l'essai) ; IPC « essai » :
// injecter, marquer, largeurs, evenement, pret. Sorties : « essai : prêt » au démarrage ; « essai : exécuté <genre>
// <cible> » à chaque action ; « essai : calque retiré » quand Hyprland retire le calque du lanceur,
// dunei-attention-lanceur (closelayer), pour que les essais vérifient qu'une action ne part qu'après ce retrait.
// Erreurs : celles de Theme et du lanceur, dans le journal.
// Dépendances : quickshell ≥ 0.3 (IpcHandler, Hyprland.rawEvent), Lanceur, Theme ; liens essai/fenetre/Theme,
// Composants, Applications, Parametres, Barre et Lanceur, car Quickshell ne suit pas les imports hors du dossier de la
// coque.
ShellRoot {
    id: essai

    // Largeurs prises par le cadre depuis le dernier appel à marquer.
    property var largeurs: []

    // Component.onCompleted — retire le clavier, détourne l'exécution et signale que la coque est prête.
    // Entrées : aucune. Sortie : la ligne « essai : prêt ». Erreurs : aucune. Dépendances : Lanceur, console.
    Component.onCompleted: {
        Lanceur.clavierExclusif = false
        Lanceur.executeur = a => console.log("essai : exécuté " + a.genre + " " + a.cible)
        console.log("essai : prêt")
    }

    // onWidthChanged — relève chaque largeur du cadre de la fenêtre ouverte. Entrées : aucune. Sortie : largeurs.
    // Erreurs : aucune. Dépendances : Lanceur.fenetre.
    Connections {
        target: Lanceur.fenetre?.cadre ?? null
        function onWidthChanged() { essai.largeurs = essai.largeurs.concat([Lanceur.fenetre.cadre.width]) }
    }

    // onRawEvent — journalise le retrait d'un calque d'attention. Entrée : e, l'événement Hyprland. Sortie : la ligne
    // « essai : calque retiré ». Erreurs : aucune. Dépendances : Hyprland.rawEvent.
    Connections {
        target: Hyprland
        function onRawEvent(e) { if (e.name === "closelayer" && e.data === Lanceur.espace) console.log("essai : calque retiré") }
    }

    IpcHandler {
        target: "essai"

        // pret — vrai une fois les jetons et le mouvement chargés. Sortie : « true » ou « false ».
        function pret(): string { return String(Theme.ready && Theme.motion !== null) }

        // injecter — remplace des entrées des sources du lanceur. Entrée : json, objet dont chaque clé (entrees,
        // fenetres, cheminRoles, ipc) nomme une propriété de Sources. Sortie : aucune. Erreurs : aucune.
        // Dépendances : Lanceur.sources.
        function injecter(json: string): void {
            const d = JSON.parse(json)
            for (const cle in d) Lanceur.sources[cle] = d[cle]
        }

        // marquer — vide le relevé des largeurs. Sortie : aucune.
        function marquer(): void { essai.largeurs = [] }

        // largeurs — relevé des largeurs du cadre depuis marquer. Sortie : tableau JSON.
        function largeurs(): string { return JSON.stringify(essai.largeurs) }

        // evenement — simule un événement brut de Hyprland reçu par la scène du lanceur, tant que sa fenêtre existe.
        // Entrées : nom, le nom de l'événement ; donnee, sa donnée. Sortie : « ok », ou « absent » sans fenêtre.
        // Erreurs : aucune. Dépendances : Lanceur.fenetre (FenetreScene.scene), Scene.surEvenement.
        function evenement(nom: string, donnee: string): string {
            if (!Lanceur.fenetre) return "absent"
            Lanceur.fenetre.scene.surEvenement(nom, donnee)
            return "ok"
        }
    }

    IpcHandler {
        target: "notifications"

        // nePasDeranger — faux état de « ne pas déranger ». Entrées : aucune. Sortie : « true ». Erreurs : aucune.
        // Dépendances : aucune.
        function nePasDeranger(): string { return "true" }
    }
}
