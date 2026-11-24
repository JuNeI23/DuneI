//@ pragma IconTheme DuneI
//@ pragma Env QSG_DISTANCEFIELD_ANTIALIASING=gray
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "Theme"
import "Lanceur"
import "Deconnexion"

// Coque d'essai du menu de déconnexion (L2-23), dans la vraie session Wayland, sans jamais prendre le clavier ni rien
// exécuter pour de bon.
// Rôle : charge les singletons Deconnexion et Lanceur (ce dernier pour l'essai de la famille « attention »), leur
// retire le clavier exclusif (les touches passent par les IPC « deconnexion » et « lanceur ») et remplace leur
// exécution par une ligne de journal : aucune vraie veille, extinction, déconnexion ni aucun verrouillage. La fenêtre
// du menu reçoit un masque d'entrée vide : le pointeur réel n'y entre pas, le survol est simulé par l'IPC.
// tests/test_deconnexion.py (ControleurTest) la pilote ; elle sert aussi aux captures du menu. Elle sert la cible
// « notifications », dont l'état « ne pas déranger » vaut toujours « true ».
// Entrées : DUNEI_TOKENS_DIR et DUNEI_ETAT_DIR (jetons, thème et relevé d'usage de l'essai) ; IPC « essai » : pret,
// survoler (survol simulé), cliquerAuDessus (clic simulé sur le voile), libelle (libellé rendu d'un bouton),
// lancerFactice (journal des échecs du Process).
// Sorties : « essai : prêt » au démarrage ; « essai : exécuté <id> » à chaque action du menu (« essai : exécuté
// lanceur <genre> » pour le lanceur) ; « essai : fenêtre construite » à chaque construction de la fenêtre du menu ;
// « essai : calque retiré » quand Hyprland retire le calque du menu (closelayer de Deconnexion.espace), pour que
// les essais vérifient qu'une action ne part qu'après ce retrait.
// Erreurs : celles de Theme, du menu et du lanceur, dans le journal.
// Dépendances : quickshell ≥ 0.3 (IpcHandler, Hyprland.rawEvent), Deconnexion, Lanceur, Theme ; liens
// essai/fenetre/Theme, Composants, Lanceur, Applications, Barre, Parametres et Deconnexion, car Quickshell ne suit pas
// les imports hors du dossier de la coque.
ShellRoot {
    id: essai

    // Component.onCompleted — retire le clavier, détourne l'exécution et signale que la coque est prête.
    // Entrées : aucune. Sortie : la ligne « essai : prêt ». Erreurs : aucune. Dépendances : Deconnexion, Lanceur,
    // console.
    Component.onCompleted: {
        Deconnexion.clavierExclusif = false
        Deconnexion.executeur = a => console.log("essai : exécuté " + a.id)
        Lanceur.clavierExclusif = false
        Lanceur.executeur = a => console.log("essai : exécuté lanceur " + a.genre)
        console.log("essai : prêt")
    }

    // onRawEvent — journalise le retrait d'un calque d'attention. Entrée : e, l'événement brut de Hyprland (name,
    // data). Sortie : la ligne « essai : calque retiré » pour closelayer>><Deconnexion.espace>, rien pour un autre
    // événement. Erreurs : aucune. Dépendances : Hyprland.rawEvent, Deconnexion.espace.
    Connections {
        target: Hyprland
        function onRawEvent(e) { if (e.name === "closelayer" && e.data === Deconnexion.espace) console.log("essai : calque retiré") }
    }

    // Masque d'entrée vide, posé sur la fenêtre du menu de l'essai : le vrai pointeur de Nicolas, immobile au
    // centre de l'écran, ne la survole jamais, et seuls les points de l'IPC survoler atteignent le cadre.
    Region { id: sansPointeur }

    // onFenetreChanged — retire le pointeur réel de chaque fenêtre du menu construite et la journalise, pour vérifier
    // qu'un ouvrir sur un menu déjà ouvert la reprend. Entrées : aucune. Sortie : mask de la fenêtre remplacé par
    // sansPointeur (la liaison du menu réel est rompue dans l'essai seulement) ; la ligne « essai : fenêtre
    // construite » quand la fenêtre devient non nulle. Erreurs : aucune. Dépendances : Deconnexion.fenetre (mask),
    // sansPointeur.
    Connections {
        target: Deconnexion
        function onFenetreChanged() {
            if (!Deconnexion.fenetre) return
            Deconnexion.fenetre.mask = sansPointeur
            console.log("essai : fenêtre construite")
        }
    }

    IpcHandler {
        target: "essai"

        // pret — vrai une fois les jetons et le mouvement chargés. Sortie : « true » ou « false ».
        function pret(): string { return String(Theme.ready && Theme.motion !== null) }

        // survoler — pousse un point du pointeur au gestionnaire de survol du menu, au centre du bouton i décalé de
        // (dx, dy), comme le ferait son HoverHandler. Entrées : i, rang du bouton ; dx, dy, décalage en pixels.
        // Sortie : « ok », ou « sans cadre » si la fenêtre du menu n'est pas construite. Erreurs : aucune.
        // Dépendances : Deconnexion.fenetre.cadre (boutons, pointeur).
        function survoler(i: int, dx: real, dy: real): string {
            const c = Deconnexion.fenetre?.cadre, b = c?.boutons.itemAt(i)
            if (!b) return "sans cadre"
            c.pointeur(b.mapToItem(null, b.width / 2 + dx, b.height / 2 + dy))
            return "ok"
        }

        // cliquerAuDessus — simule un clic sur le voile, d pixels au-dessus du bord haut du bouton i à sa taille de
        // repos, au milieu de sa largeur, comme le ferait le MouseArea du voile. Entrées : i, rang du bouton ; d,
        // distance en pixels. Sortie : « ok », ou « sans cadre » si la fenêtre du menu n'est pas construite ; le menu
        // se ferme si le point tombe hors du cadre. Erreurs : aucune. Dépendances : Deconnexion.fenetre (cadre,
        // cliquerVoile).
        function cliquerAuDessus(i: int, d: real): string {
            const f = Deconnexion.fenetre, b = f?.cadre?.boutons.itemAt(i)
            if (!b) return "sans cadre"
            const p = b.mapToItem(null, b.width / 2, b.height / 2)
            f.cliquerVoile(p.x, p.y - b.height / 2 - d)
            return "ok"
        }

        // libelle — libellé peint par le bouton i (« Confirmer » s'il est armé). Entrée : i, rang du bouton.
        // Sortie : le texte, ou « » sans cadre. Erreurs : aucune. Dépendances : Deconnexion.fenetre.cadre (boutons).
        function libelle(i: int): string { return Deconnexion.fenetre?.cadre?.boutons.itemAt(i)?.peint ?? "" }

        // lancerFactice — lance pour de bon, par Deconnexion.lancer, une commande inoffensive, pour éprouver le journal
        // des échecs du Process : jamais une action du menu. Entrées : id, identifiant journalisé ; programme, la
        // commande sans argument (« false », ou un nom introuvable). Sortie : aucune ; le journal reçoit l'échec.
        // Erreurs : aucune. Dépendances : Deconnexion.lancer.
        function lancerFactice(id: string, programme: string): void { Deconnexion.lancer({ id: id, commande: [programme] }) }
    }

    IpcHandler {
        target: "notifications"

        // nePasDeranger — faux état de « ne pas déranger ». Entrées : aucune. Sortie : « true ». Erreurs : aucune.
        // Dépendances : aucune.
        function nePasDeranger(): string { return "true" }
    }
}
