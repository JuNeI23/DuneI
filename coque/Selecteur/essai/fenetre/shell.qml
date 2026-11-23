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
// Le pointeur réel de Nicolas est retiré de chaque fenêtre du sélecteur (masque d'entrée vide) : seuls les points de
// l'IPC pointeur atteignent le cadre.
// Entrées : DUNEI_TOKENS_DIR et DUNEI_ETAT_DIR (jetons, thème et relevé d'usage de l'essai) ; IPC « essai » : pret,
// ouvrir, injecter, vignette, cadre, titre, pointeur, evenement. Sorties : « essai : prêt » au démarrage ; « essai :
// exécuté <genre> <cible> » à chaque action ; « essai : montré après <n> ms » quand le sélecteur se montre, n mesuré
// depuis l'appel à « essai ouvrir » ; « essai : calque retiré » quand Hyprland retire le calque du sélecteur
// (closelayer de Selecteur.espace), pour que les essais vérifient qu'une action ne part qu'après ce retrait.
// Erreurs : celles de Theme, du sélecteur et du lanceur, dans le journal.
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

    // onRawEvent — journalise le retrait du calque du sélecteur. Entrée : e, l'événement brut de Hyprland (name,
    // data). Sortie : la ligne « essai : calque retiré » pour closelayer>><Selecteur.espace>, rien pour un autre
    // événement. Erreurs : aucune. Dépendances : Hyprland.rawEvent, Selecteur.espace.
    Connections {
        target: Hyprland
        function onRawEvent(e) { if (e.name === "closelayer" && e.data === Selecteur.espace) console.log("essai : calque retiré") }
    }

    // Masque d'entrée vide, posé sur chaque fenêtre du sélecteur de l'essai.
    Region { id: sansPointeur }

    // onFenetreChanged — retire le pointeur réel de chaque fenêtre du sélecteur construite. Entrées : aucune.
    // Sortie : mask de la fenêtre remplacé par sansPointeur (la liaison du sélecteur réel est rompue dans l'essai
    // seulement). Erreurs : aucune ; sans fenêtre, rien. Dépendances : Selecteur.fenetre (mask), sansPointeur.
    Connections {
        target: Selecteur
        function onFenetreChanged() { if (Selecteur.fenetre) Selecteur.fenetre.mask = sansPointeur }
    }

    // contient — cherche, parmi les descendants visuels d'un élément, une instance d'un type QML nommé.
    // Entrées : item, l'élément de départ ; nom, le nom du type (« Plaque », « Surface »…). Sortie : vrai si l'élément
    // ou l'un de ses descendants est de ce type, reconnu à son nom imprimé (« Nom(0x…) » ou « Nom_QMLTYPE_n(0x…) »).
    // Erreurs : aucune. Dépendances : aucune.
    function contient(item, nom) {
        return new RegExp("^" + nom + "(_QMLTYPE_\\d+)?\\(").test(String(item)) || Array.from(item.children).some(e => essai.contient(e, nom))
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
        // source d'effet, taille native de la capture), estompe (l'estompe voulue) et echelle (l'échelle animée de la
        // vignette) ; « null » sans fenêtre ou sans vignette à ce rang. Erreurs : aucune.
        // Dépendances : Selecteur.fenetre (cadre.vignettes), VignetteFenetre (capturee, image, vue, estompe, transform).
        function vignette(i: int): string {
            const v = Selecteur.fenetre?.cadre?.vignettes.itemAt(i) ?? null
            return v ? JSON.stringify({ capturee: v.capturee, mipmap: v.image.mipmap,
                texture: [v.image.textureSize.width, v.image.textureSize.height],
                capture: [v.vue.sourceSize.width, v.vue.sourceSize.height],
                estompe: v.estompe, echelle: v.transform[1].xScale }) : "null"
        }

        // cadre — état du cadre du sélecteur ouvert. Entrées : aucune. Sortie : JSON {plaque, surface, ombre (vrai si
        // le cadre porte une C.Plaque, une C.Surface ou une C.OmbreElevation), rangee (abscisse de la rangée dans la
        // fenêtre), vue (sa largeur visible), titre (largeur du titre de la légende), origine ([x, y]), bouge} ;
        // « null » sans fenêtre. Erreurs : une propriété absente du cadre lève, et l'appel ne rend rien.
        // Dépendances : Selecteur.fenetre.cadre (rangee, vue, titre, origine, bouge), contient.
        function cadre(): string {
            const c = Selecteur.fenetre?.cadre ?? null
            return c ? JSON.stringify({ plaque: essai.contient(c, "Plaque"), surface: essai.contient(c, "Surface"),
                ombre: essai.contient(c, "OmbreElevation"), rangee: c.rangee.mapToItem(null, 0, 0).x, vue: c.vue,
                titre: c.titre.width, origine: [c.origine.x, c.origine.y], bouge: c.bouge }) : "null"
        }

        // titre — remplace le titre de la fenêtre choisie dans la liste figée. Entrée : texte. Sortie : « ok », ou
        // « fermé » si le sélecteur est fermé. Erreurs : aucune. Dépendances : Selecteur (ouvert, liste, index).
        function titre(texte: string): string {
            if (!Selecteur.ouvert) return "fermé"
            Selecteur.liste = Selecteur.liste.map((f, i) => i === Selecteur.index ? Object.assign({}, f, { titre: texte }) : f)
            return "ok"
        }

        // pointeur — pousse un point du pointeur au gestionnaire de survol du cadre, comme son HoverHandler. Entrées :
        // x, y, position en coordonnées de la scène. Sortie : « ok », ou « sans cadre » si le cadre n'a pas de
        // gestionnaire pointeur ou si la fenêtre n'est pas construite. Erreurs : aucune.
        // Dépendances : Selecteur.fenetre.cadre (pointeur).
        function pointeur(x: real, y: real): string {
            const c = Selecteur.fenetre?.cadre
            if (typeof c?.pointeur !== "function") return "sans cadre"
            c.pointeur(Qt.point(x, y))
            return "ok"
        }

        // evenement — simule un événement brut de Hyprland reçu par la scène du sélecteur. Entrées : nom, le nom de
        // l'événement ; donnee, sa donnée. Sortie : « ok », ou « sans scène » si la fenêtre n'appartient pas à une
        // Scene. Erreurs : aucune. Dépendances : Selecteur.fenetre.scene (surEvenement).
        function evenement(nom: string, donnee: string): string {
            const s = Selecteur.fenetre?.scene
            if (!s) return "sans scène"
            s.surEvenement(nom, donnee)
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
