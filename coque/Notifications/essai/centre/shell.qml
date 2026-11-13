//@ pragma IconTheme DuneI
import QtQuick
import Quickshell
import Quickshell.Io
import "Theme"
import "Notifications"

// Coque d'essai du serveur et de la vue de la pile, sous la plateforme offscreen et dans un bus D-Bus privé.
// Rôle : lance le vrai Centre (NotificationServer, RetainableLock) et l'Empilement des cartes dans une fenêtre jamais
// montrée (la plateforme offscreen n'a pas de PanelWindow : FenetreNotifications n'y est pas instanciée, son
// Empilement l'est à sa place et fait oublier les entrées sorties comme elle). Retenue réglable par IPC ; durée par
// défaut ramenée par le test. tests/test_notifications.py (CentreTest) la lance sous dbus-run-session et la pilote.
// Entrées : DUNEI_TOKENS_DIR, lu par Theme ; QT_QPA_PLATFORM, posé à offscreen par le test ; DBUS_SESSION_BUS_ADDRESS,
// le bus privé de dbus-run-session.
// Sortie : « essai : prêt » au démarrage ; voir l'IpcHandler. Erreurs : celles de Theme et du serveur, dans le journal.
// Dépendances : quickshell ≥ 0.3 (IpcHandler, FloatingWindow, Quickshell.Services.Notifications), Centre,
// Empilement, liens Theme, Composants et Notifications ; thème d'icônes DuneI.
ShellRoot {
    id: essai

    // Résumés passés par les affichées, une fois chacun ; figee retient les sorties au lieu de les oublier.
    property var vues: []
    property bool figee: false
    property var retenues: []

    Component.onCompleted: console.info("essai : prêt")

    Centre {
        id: centre
        retenue: false
    }

    Connections {
        target: centre.pile
        function onAfficheesChanged() {
            const nouveaux = centre.pile.affichees.map(e => e.notification?.summary ?? "")
                .filter(r => r !== "" && !essai.vues.includes(r))
            if (nouveaux.length) essai.vues = essai.vues.concat(nouveaux)
        }
    }

    FloatingWindow {
        implicitWidth: 500
        implicitHeight: 1000
        color: "transparent"

        // Écarté de l'origine, où se tient le pointeur virtuel de la plateforme offscreen : il survolerait une carte.
        Empilement {
            id: empilement
            x: 60
            y: 60
            width: largeurUtile
            height: 900
            pile: centre.pile
            onPartie: entree => essai.figee ? essai.retenues = essai.retenues.concat([entree])
                                            : centre.pile.oublier(entree)
        }
    }

    // trouver — entrée affichée dont la notification porte un résumé. Entrée : resume. Sortie : Entree ou undefined.
    // Erreurs : aucune. Dépendances : centre.
    function trouver(resume) { return centre.pile.affichees.find(e => e.notification?.summary === resume) }

    IpcHandler {
        target: "essai"

        // pret — vrai une fois les jetons chargés. Sortie : « true » ou « false ». Dépendances : Theme.
        function pret(): string { return String(Theme.notifications !== undefined) }

        // etat — JSON [affichées (plus récente en tête, suffixe « ~s » pour une sortante), file (ordre d'arrivée)],
        // par résumé. Sortie : texte. Dépendances : centre.
        function etat(): string {
            const resume = e => (e.notification?.summary ?? "") + (e.sortante ? "~s" : "")
            return JSON.stringify([centre.pile.affichees.map(resume), centre.pile.file.map(resume)])
        }

        // vues — JSON des résumés passés par les affichées. Sortie : texte.
        function vues(): string { return JSON.stringify(essai.vues) }

        // delai — expireTimeout reçu d'une notification affichée. Entrée : resume. Sortie : texte, « » si absente.
        function delai(resume: string): string { return String(essai.trouver(resume)?.notification.expireTimeout ?? "") }

        // retenir — pose la retenue (plein écran simulé). Entrée : v. Sortie : aucune.
        function retenir(v: bool): void { centre.retenue = v }

        // figer — retient les cartes sorties au lieu de les oublier ; à faux, oublie celles retenues.
        // Entrée : v. Sortie : aucune. Dépendances : centre.
        function figer(v: bool): void {
            essai.figee = v
            if (v) return
            essai.retenues.forEach(e => centre.pile.oublier(e))
            essai.retenues = []
        }

        // agir — déclenche une action d'une notification affichée, comme un clic sur son libellé.
        // Entrées : resume ; identifiant, celui de l'action. Sortie : aucune. Dépendances : centre.pile.agir.
        function agir(resume: string, identifiant: string): void {
            const e = essai.trouver(resume)
            centre.pile.agir(e, Array.from(e.notification.actions).find(a => a.identifier === identifiant))
        }

        // cliquer — clic sur la carte d'une notification affichée. Entrée : resume. Sortie : aucune.
        // Dépendances : trouver, centre.pile.cliquer.
        function cliquer(resume: string): void { centre.pile.cliquer(essai.trouver(resume)) }

        // survoler — pose le survol de l'entrée d'une notification affichée, comme le ferait le pointeur.
        // Entrées : resume, v. Sortie : aucune. Dépendances : trouver.
        function survoler(resume: string, v: bool): void { essai.trouver(resume).survolee = v }

        // cartes — JSON {n, boite: [x, y, l, h], largeur, hauteur, debord} : cartes posées, boîte du masque, taille
        // de l'empilement et débord de l'ombre réservé au-dessus des cartes. Sortie : texte. Dépendances : empilement.
        function cartes(): string {
            const b = empilement.boite
            return JSON.stringify({n: empilement.cartes, boite: [b.x, b.y, b.width, b.height],
                                   largeur: empilement.width, hauteur: empilement.height, debord: empilement.debord})
        }
    }
}
