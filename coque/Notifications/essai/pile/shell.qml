import QtQuick
import Quickshell
import Quickshell.Io
import "Theme"
import "Notifications"
import "Notifications/essai"

// Coque d'essai de la pile de notifications, sans fenêtre ni serveur de notifications.
// Rôle : crée des FausseNotification sur commande IPC et les remet à Pile ; pilote la retenue, le survol, le clic,
// les actions, l'oubli, la fermeture par l'application et la mise à jour sur place ; rend l'état de la pile et le
// journal des appels reçus par les notifications. tests/test_notifications.py (PileTest) la pilote.
// Entrées : DUNEI_TOKENS_DIR, lu par Theme (durée par défaut ramenée par le test).
// Sortie : « essai : prêt » au démarrage ; voir l'IpcHandler. Erreurs : celles de Theme, dans le journal.
// Les notifications factices ne sont pas Retainable : la pile reçoit FauxVerrou à la place de RetainableLock.
// Dépendances : quickshell ≥ 0.3 (IpcHandler), Pile, FausseNotification, FauxVerrou, liens Theme et Notifications.
ShellRoot {
    id: essai

    property int suivant: 1
    property var notifications: ({})
    property var journal: []
    // Identifiants des notifications factices détruites.
    property var detruites: []

    Component.onCompleted: console.info("essai : prêt")

    Pile {
        id: pile
        verrou: Component { FauxVerrou {} }
    }

    Component {
        id: fabrique
        FausseNotification {}
    }

    // entree — entrée de la pile qui tient une notification. Entrée : id. Sortie : Entree ou undefined.
    // Erreurs : aucune. Dépendances : pile.
    function entree(id) {
        return pile.affichees.concat(pile.file).find(e => e.notification && e.notification.id === id)
    }

    IpcHandler {
        target: "essai"

        // pret — vrai une fois les jetons chargés. Sortie : « true » ou « false ». Dépendances : Theme.
        function pret(): string { return String(Theme.notifications !== undefined) }

        // creer — crée une notification factice et la remet à la pile.
        // Entrées : app, resume, corps, delai (ms, expireTimeout), etiquette (x-dunst-stack-tag, « » pour aucune).
        // Sortie : l'identifiant de la notification. Erreurs : aucune. Dépendances : fabrique, pile.
        function creer(app: string, resume: string, corps: string, delai: int, etiquette: string): string {
            const id = essai.suivant++
            const n = fabrique.createObject(essai, {id: id, appName: app, summary: resume, body: corps,
                expireTimeout: delai, hints: etiquette === "" ? {} : {"x-dunst-stack-tag": etiquette}})
            n.appel.connect(t => essai.journal = essai.journal.concat([t]))
            n.detruite.connect(() => essai.detruites = essai.detruites.concat([id]))
            essai.notifications[id] = n
            pile.recevoir(n)
            return String(id)
        }

        // residente — rend une notification résidente. Entrée : id. Sortie : aucune.
        function residente(id: int): void { essai.notifications[id].resident = true }

        // retenir — pose la retenue de la pile. Entrée : v. Sortie : aucune.
        function retenir(v: bool): void { pile.retenue = v }

        // survoler — pose le survol de l'entrée qui tient la notification. Entrées : id, v. Sortie : aucune.
        function survoler(id: int, v: bool): void { essai.entree(id).survolee = v }

        // cliquer, oublier — clic sur la carte, oubli après sa sortie. Entrée : id. Sortie : aucune.
        function cliquer(id: int): void { pile.cliquer(essai.entree(id)) }
        function oublier(id: int): void { pile.oublier(essai.entree(id)) }

        // agir — déclenche une action. Entrées : id ; action, identifiant de l'action. Sortie : aucune.
        function agir(id: int, action: string): void {
            const e = essai.entree(id)
            pile.agir(e, e.notification.actions.find(a => a.identifier === action))
        }

        // fermerParApp — fermeture demandée par l'application (CloseNotification, raison 3). Entrée : id.
        function fermerParApp(id: int): void { essai.notifications[id].fermer(3) }

        // renommer — mise à jour sur place du résumé. Entrées : id, resume. Sortie : aucune.
        function renommer(id: int, resume: string): void { essai.notifications[id].summary = resume }

        // resume — résumé montré par l'entrée qui tient la notification. Entrée : id. Sortie : texte.
        function resume(id: int): string { return essai.entree(id).notification.summary }

        // existe — vrai si la notification n'est pas encore détruite. Entrée : id. Sortie : « true » ou « false ».
        function existe(id: int): string { return String(!essai.detruites.includes(id)) }

        // etat — « affichees: id,… (s pour sortante) | file: id,… ». Sortie : texte. Dépendances : pile.
        function etat(): string {
            return "affichees: " + pile.affichees.map(e => e.notification.id + (e.sortante ? "s" : "")).join(",")
                + " | file: " + pile.file.map(e => e.notification.id).join(",")
        }

        // appels — journal des appels reçus par les notifications, séparés par des virgules. Sortie : texte.
        function appels(): string { return essai.journal.join(",") }
    }
}
