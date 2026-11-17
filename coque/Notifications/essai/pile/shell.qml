import QtQuick
import Quickshell
import Quickshell.Io
import "Theme"
import "Notifications"
import "Notifications/essai"

// Coque d'essai de la pile de notifications, sans fenêtre ni serveur de notifications.
// Rôle : crée des FausseNotification sur commande IPC et les remet à Pile ; pilote la retenue, le survol, le clic,
// les actions, l'oubli, la fermeture par l'application et la mise à jour sur place ; rend l'état de la pile et le
// journal des appels reçus par les notifications. Elle porte aussi l'attente (logique du panneau, L2-67) : ajout
// direct, ouverture, action, écart, oubli, et son état. tests/test_notifications.py (PileTest, AttenteTest) la pilote.
// Entrées : DUNEI_TOKENS_DIR, lu par Theme (durée par défaut ramenée par le test).
// Sortie : « essai : prêt » au démarrage ; voir l'IpcHandler. Erreurs : celles de Theme, dans le journal.
// Les notifications factices ne sont pas Retainable : la pile reçoit FauxVerrou à la place de RetainableLock.
// Dépendances : quickshell ≥ 0.3 (IpcHandler), Pile, Attente, FausseNotification, FauxVerrou, liens Theme et
// Notifications.
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

    // L'attente éprouvée : celle de la pile.
    readonly property Attente attente: pile.attente
    // Propriétés posées sur la prochaine notification créée par creer (voir preparer), puis vidées.
    property var prochaines: ({})

    Component {
        id: fabrique
        FausseNotification {}
    }

    // fabriquer — crée une notification factice, journalisée, sans la remettre à personne.
    // Entrée : proprietes, celles de FausseNotification (sans id). Sortie : la notification. Erreurs : aucune.
    // Dépendances : fabrique, journal, detruites.
    function fabriquer(proprietes) {
        const id = essai.suivant++
        const n = fabrique.createObject(essai, Object.assign({id: id}, proprietes))
        n.appel.connect(t => essai.journal = essai.journal.concat([t]))
        n.detruite.connect(() => essai.detruites = essai.detruites.concat([id]))
        essai.notifications[id] = n
        return n
    }

    // attendue — entrée de l'attente qui tient une notification. Entrée : id. Sortie : Attendue ou undefined.
    // Erreurs : aucune. Dépendances : attente.
    function attendue(id) { return attente.entrees.find(a => a.notification && a.notification.id === id) }

    // entree — entrée de la pile qui tient une notification. Entrée : id. Sortie : Entree ou undefined.
    // Erreurs : aucune. Dépendances : pile.
    function entree(id) {
        return pile.affichees.concat(pile.file).find(e => e.notification && e.notification.id === id)
    }

    IpcHandler {
        target: "essai"

        // pret — vrai une fois les jetons chargés. Entrées : aucune. Sortie : « true » ou « false ».
        // Erreurs : aucune. Dépendances : Theme.
        function pret(): string { return String(Theme.notifications !== undefined) }

        // creer — crée une notification factice et la remet à la pile.
        // Entrées : app, resume, corps, delai (ms, expireTimeout), etiquette (x-dunst-stack-tag, « » pour aucune).
        // Sortie : l'identifiant de la notification. Erreurs : aucune. Dépendances : fabrique, pile.
        function creer(app: string, resume: string, corps: string, delai: int, etiquette: string): string {
            const n = essai.fabriquer(Object.assign({appName: app, summary: resume, body: corps, expireTimeout: delai,
                hints: Object.assign(etiquette === "" ? {} : {"x-dunst-stack-tag": etiquette},
                                     essai.prochaines.ephemere ? {transient: true} : {})},
                essai.prochaines.proprietes ?? {}))
            essai.prochaines = ({})
            pile.recevoir(n)
            return String(n.id)
        }

        // preparer — règle la prochaine notification créée par creer, et elle seule.
        // Entrées : urgence (0, 1 ou 2) ; ephemere (indice transient) ; bureau (desktopEntry) ; generation
        // (lastGeneration : réémise après un rechargement). Sortie : aucune. Erreurs : aucune. Dépendances : prochaines.
        function preparer(urgence: int, ephemere: bool, bureau: string, generation: bool): void {
            essai.prochaines = {ephemere: ephemere,
                                proprietes: {urgency: urgence, desktopEntry: bureau, lastGeneration: generation}}
        }

        // deranger — pose « ne pas déranger » sur la pile. Entrée : v. Sortie : aucune. Erreurs : aucune.
        // Dépendances : Pile.nePasDeranger.
        function deranger(v: bool): void { pile.nePasDeranger = v }

        // retirerApp — retire une application : ses notifications ne sont plus gardées. Entrée : identifiant.
        // Sortie : aucune. Erreurs : aucune. Dépendances : Pile.retirees.
        function retirerApp(identifiant: string): void { pile.retirees = pile.retirees.concat([identifiant]) }

        // connaitre — fait passer un identifiant de notification pour tenu par l'attente de la génération
        // précédente. Entrée : id. Sortie : aucune. Erreurs : aucune. Dépendances : Attente.connus.
        function connaitre(id: int): void { essai.attente.connus = essai.attente.connus.concat([id]) }

        // resumeAttendue — résumé montré par l'entrée de l'attente qui tient la notification. Entrée : id.
        // Sortie : texte. Erreurs : TypeError au journal si aucune entrée ne la tient. Dépendances : attendue.
        function resumeAttendue(id: int): string { return essai.attendue(id).notification.summary }

        // attendre — crée une notification factice et l'ajoute directement à l'attente, suivie.
        // Entrées : app ; urgence (0, 1 ou 2). Sortie : l'identifiant de la notification. Erreurs : aucune.
        // Dépendances : fabriquer, Attente.ajouter.
        function attendre(app: string, urgence: int): string {
            const n = essai.fabriquer({appName: app, urgency: urgence, tracked: true})
            essai.attente.ajouter(n, "", new Date())
            return String(n.id)
        }

        // ouvrirAttendue, ecarterAttendue, oublierAttendue — clic sur une entrée du panneau, écart, oubli après sa
        // sortie. Entrée : id. Sortie : aucune. Erreurs : TypeError au journal si aucune entrée ne tient la
        // notification. Dépendances : attendue, Attente.
        function ouvrirAttendue(id: int): void { essai.attente.ouvrir(essai.attendue(id)) }
        function ecarterAttendue(id: int): void { essai.attente.ecarter(essai.attendue(id)) }
        function oublierAttendue(id: int): void { essai.attente.oublier(essai.attendue(id)) }

        // agirAttendue — déclenche une action d'une entrée du panneau. Entrées : id ; action, son identifiant.
        // Sortie : aucune. Erreurs : TypeError au journal si l'entrée ou l'action n'existe pas.
        // Dépendances : attendue, Attente.agir.
        function agirAttendue(id: int, action: string): void {
            const a = essai.attendue(id)
            essai.attente.agir(a, a.notification.actions.find(x => x.identifier === action))
        }

        // ecarterGroupe, toutEcarter — écart d'une application, puis de tout. Entrée : identifiant de l'application.
        // Sortie : aucune. Erreurs : aucune. Dépendances : Attente.
        function ecarterGroupe(identifiant: string): void { essai.attente.ecarterGroupe(identifiant) }
        function toutEcarter(): void { essai.attente.toutEcarter() }

        // montrer — dit à l'attente qu'une vue la montre. Entrée : v. Sortie : aucune. Erreurs : aucune.
        // Dépendances : Attente.montree.
        function montrer(v: bool): void { essai.attente.montree = v }

        // sansAction — retire toutes les actions d'une notification. Entrée : id. Sortie : aucune.
        // Erreurs : TypeError au journal si id ne désigne aucune notification créée. Dépendances : notifications.
        function sansAction(id: int): void { essai.notifications[id].poserActions([]) }

        // etatAttente — « nombre | critique | id,… (s pour sortante) | groupes nom:nombre,… ». Entrées : aucune.
        // Sortie : texte. Erreurs : aucune. Dépendances : attente.
        function etatAttente(): string {
            const a = essai.attente
            return a.nombre + " | " + a.critique + " | "
                + a.entrees.map(e => e.notification.id + (e.sortante ? "s" : "")).join(",") + " | "
                + a.groupes.map(g => g.nom + ":" + g.entrees.length).join(",")
        }

        // residente — rend une notification résidente. Entrée : id. Sortie : aucune.
        // Erreurs : TypeError au journal si id ne désigne aucune notification créée. Dépendances : notifications.
        function residente(id: int): void { essai.notifications[id].resident = true }

        // retenir — pose la retenue de la pile. Entrée : v. Sortie : aucune. Erreurs : aucune. Dépendances : pile.
        function retenir(v: bool): void { pile.retenue = v }

        // survoler — pose le survol de l'entrée qui tient la notification. Entrées : id, v. Sortie : aucune.
        // Erreurs : TypeError au journal si aucune entrée ne tient la notification. Dépendances : entree.
        function survoler(id: int, v: bool): void { essai.entree(id).survolee = v }

        // cliquer, oublier — clic sur la carte, oubli après sa sortie. Entrée : id. Sortie : aucune.
        // Erreurs : TypeError au journal si aucune entrée ne tient la notification.
        // Dépendances : entree, Pile.cliquer, Pile.oublier.
        function cliquer(id: int): void { pile.cliquer(essai.entree(id)) }
        function oublier(id: int): void { pile.oublier(essai.entree(id)) }

        // agir — déclenche une action. Entrées : id ; action, identifiant de l'action. Sortie : aucune.
        // Erreurs : TypeError au journal si aucune entrée ne tient la notification ou si l'action n'existe pas.
        // Dépendances : entree, Pile.agir.
        function agir(id: int, action: string): void {
            const e = essai.entree(id)
            pile.agir(e, e.notification.actions.find(a => a.identifier === action))
        }

        // fermerParApp — fermeture demandée par l'application (CloseNotification, raison 3). Entrée : id.
        // Sortie : aucune. Erreurs : TypeError au journal si id ne désigne aucune notification créée.
        // Dépendances : notifications, FausseNotification.fermer.
        function fermerParApp(id: int): void { essai.notifications[id].fermer(3) }

        // renommer — mise à jour sur place du résumé. Entrées : id, resume. Sortie : aucune.
        // Erreurs : TypeError au journal si id ne désigne aucune notification créée. Dépendances : notifications.
        function renommer(id: int, resume: string): void { essai.notifications[id].summary = resume }

        // resume — résumé montré par l'entrée qui tient la notification. Entrée : id. Sortie : texte.
        // Erreurs : TypeError au journal, et sortie vide, si aucune entrée ne tient la notification.
        // Dépendances : entree.
        function resume(id: int): string { return essai.entree(id).notification.summary }

        // arrivee — heure d'arrivée de l'entrée qui tient la notification, en ms depuis l'époque Unix. Entrée : id.
        // Sortie : texte. Erreurs : TypeError au journal, et sortie vide, si aucune entrée ne tient la notification.
        // Dépendances : entree.
        function arrivee(id: int): string { return String(essai.entree(id).arrivee.getTime()) }

        // existe — vrai si la notification n'est pas encore détruite. Entrée : id. Sortie : « true » ou « false ».
        // Erreurs : aucune. Dépendances : detruites.
        function existe(id: int): string { return String(!essai.detruites.includes(id)) }

        // etat — « affichees: id,… (s pour sortante) | file: id,… ». Entrées : aucune. Sortie : texte.
        // Erreurs : aucune. Dépendances : pile.
        function etat(): string {
            return "affichees: " + pile.affichees.map(e => e.notification.id + (e.sortante ? "s" : "")).join(",")
                + " | file: " + pile.file.map(e => e.notification.id).join(",")
        }

        // appels — journal des appels reçus par les notifications, séparés par des virgules. Entrées : aucune.
        // Sortie : texte. Erreurs : aucune. Dépendances : journal.
        function appels(): string { return essai.journal.join(",") }
    }
}
