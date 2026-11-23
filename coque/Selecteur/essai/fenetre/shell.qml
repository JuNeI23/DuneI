//@ pragma IconTheme DuneI
//@ pragma Env QSG_DISTANCEFIELD_ANTIALIASING=gray
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "Theme"
import "Lanceur"
import "Selecteur"

// Coque d'essai de la fenêtre du sélecteur de fenêtres (L2-17), dans la vraie session Wayland, sans jamais prendre le
// clavier.
// Rôle : charge les singletons Selecteur et Lanceur (ce dernier pour les essais de la famille « attention »), leur
// retire le clavier exclusif (clavierExclusif faux : les touches passent par les IPC « selecteur » et « lanceur »),
// remplace leur exécution par une ligne de journal (rien n'est amené ni lancé) et nourrit le sélecteur de fausses
// fenêtres (IPC injecter). Elle ne déclare pas le raccourci global dunei:selecteur, que tient la coque de session :
// deux clients sur la même paire appid:nom feraient tomber l'un des deux. tests/test_selecteur.py (FenetreTest) la
// pilote ; elle sert aussi aux captures contre le croquis de la fiche. Elle sert la cible « notifications », dont
// l'état « ne pas déranger » vaut toujours « true ».
// Entrées : DUNEI_TOKENS_DIR et DUNEI_ETAT_DIR (jetons, thème et relevé d'usage de l'essai) ; IPC « essai » : pret,
// ouvrir, injecter, vignette. Sorties : « essai : prêt » au démarrage ; « essai : exécuté <genre> <cible> » à chaque action ;
// « essai : montré après <n> ms » quand le sélecteur se montre, n mesuré depuis l'appel à « essai ouvrir » ; « essai : calque
// retiré » quand Hyprland retire un calque dunei-attention (closelayer), pour que les essais vérifient qu'une action
// ne part qu'après ce retrait. Erreurs : celles de Theme, du sélecteur et du lanceur, dans le journal.
// Dépendances : quickshell ≥ 0.3 (IpcHandler, Hyprland.rawEvent), Selecteur, Lanceur, Theme ; liens
// essai/fenetre/Theme, Composants, Applications, Parametres, Barre, Lanceur et Selecteur, car Quickshell ne suit pas
// les imports hors du dossier de la coque.
ShellRoot {
    id: essai

    // Instant de la dernière ouverture du sélecteur, en millisecondes.
    property real ouverture: 0

    // Component.onCompleted — retire le clavier, détourne l'exécution et signale que la coque est prête.
    // Entrées : aucune. Sortie : la ligne « essai : prêt ». Erreurs : aucune. Dépendances : Selecteur, Lanceur, console.
    Component.onCompleted: {
        const journaliser = a => console.log("essai : exécuté " + a.genre + " " + a.cible)
        Selecteur.clavierExclusif = false
        Selecteur.executeur = journaliser
        Lanceur.clavierExclusif = false
        Lanceur.executeur = journaliser
        console.log("essai : prêt")
    }

    // onMontreChanged — mesure le délai entre l'ouverture par l'IPC « essai ouvrir » et l'apparition du sélecteur.
    // Entrées : aucune (Selecteur.montre, devenu vrai ou faux). Sortie : la ligne « essai : montré après <n> ms »,
    // seulement quand montre devient vrai. Erreurs : aucune. Dépendances : Selecteur.montre, essai.ouverture.
    Connections {
        target: Selecteur
        function onMontreChanged() { if (Selecteur.montre) console.log("essai : montré après " + (Date.now() - essai.ouverture) + " ms") }
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

        // ouvrir — note l'instant, puis ouvre le sélecteur par avancer(1) : la mesure part d'avant la construction de
        // la fenêtre, faite dans l'ouverture même. Sortie : aucune. Erreurs : aucune. Dépendances : Selecteur.avancer.
        function ouvrir(): void { essai.ouverture = Date.now(); Selecteur.avancer(1) }

        // injecter — remplace les fenêtres vues par le sélecteur. Entrée : json, objet {fenetres}, tableau de
        // {adresse, classe, titre, bureau, historique, taille} (un tableau nu n'est pas un argument unique pour
        // « qs ipc call »). Sortie : aucune. Erreurs : aucune. Dépendances : Selecteur.source.
        function injecter(json: string): void { Selecteur.source = JSON.parse(json).fenetres }

        // vignette — état de rendu d'une vignette du sélecteur ouvert. Entrée : i, rang de la vignette. Sortie : JSON
        // {capturee, mipmap, texture, capture}, texture et capture en [largeur, hauteur] (taille de la texture de la
        // source d'effet, taille native de la capture) ; « null » sans fenêtre ou sans vignette à ce rang. Erreurs :
        // aucune. Dépendances : Selecteur.fenetre (cadre.vignettes), VignetteFenetre (capturee, image, vue).
        function vignette(i: int): string {
            const v = Selecteur.fenetre?.cadre.vignettes.itemAt(i) ?? null
            return v ? JSON.stringify({ capturee: v.capturee, mipmap: v.image.mipmap,
                texture: [v.image.textureSize.width, v.image.textureSize.height],
                capture: [v.vue.sourceSize.width, v.vue.sourceSize.height] }) : "null"
        }
    }

    IpcHandler {
        target: "notifications"

        // nePasDeranger — faux état de « ne pas déranger ». Entrées : aucune. Sortie : « true ». Erreurs : aucune.
        // Dépendances : aucune.
        function nePasDeranger(): string { return "true" }
    }
}
