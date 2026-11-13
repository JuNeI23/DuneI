import QtQuick
import Quickshell
import "../Theme"
import "etiquettes.js" as Etiquettes

// Pile — logique de la pile de notifications : file d'attente, plafond, remplacements et sorties.
// Rôle : reçoit les notifications, les remplace sur place quand une entrée non sortante porte la même clé
// (etiquettes.js), sinon les met en file ; la file s'écoule, la plus ancienne d'abord, en tête des affichées tant que la
// pile n'est pas retenue et que les affichées non sortantes sont moins de Theme.notifications.plafond. Toute sortie
// passe par le signal closed de la notification : en file, l'entrée est retirée et détruite ; affichée, elle devient
// sortante, libère sa place aussitôt, et la vue appelle oublier à la fin de son animation de sortie.
// Les tableaux sont réaffectés à chaque changement, jamais modifiés sur place, pour qu'un ScriptModel voie la différence.
// Entrées : retenue (plein écran : la file ne s'écoule plus et les minuteries s'arrêtent) ; verrou, fabrique du verrou
// qui retient la notification d'une entrée jusqu'à sa destruction (RetainableLock par défaut, remplacé dans l'essai
// dont les notifications factices ne sont pas Retainable).
// Sorties : affichees (Entree, plus récente en tête, sortantes comprises), file (Entree, ordre d'arrivée).
// Erreurs : sans jetons chargés, le plafond vaut 0 et tout reste en file jusqu'à leur chargement.
// Dépendances : Entree, etiquettes.js, Theme.notifications.plafond.
Scope {
    id: pile

    property bool retenue: false
    property var affichees: []
    property var file: []
    property Component verrou: Component {
        RetainableLock { locked: true }
    }
    readonly property int plafond: Theme.notifications?.plafond ?? 0

    onRetenueChanged: ecouler()
    onPlafondChanged: ecouler()

    Component {
        id: fabrique
        Entree {}
    }

    // recevoir — prend en charge une nouvelle notification.
    // Entrée : n, objet à l'interface de Notification. Sortie : aucune ; n est suivie (tracked), puis remplace la
    // notification d'une entrée non sortante de même clé, ou entre en file. Erreurs : aucune.
    // Dépendances : Etiquettes.cle, fabrique, ecouler, fermer.
    function recevoir(n) {
        n.tracked = true
        const cle = Etiquettes.cle(n.appName, n.hints)
        const cible = cle === "" ? undefined : affichees.concat(file).find(e => !e.sortante && e.cle === cle)
        if (cible) {
            const ancienne = cible.notification
            cible.notification = n
            ancienne.expire()
            cible.renouveler()
            return
        }
        const e = fabrique.createObject(pile, {notification: n, cle: cle, verrou: pile.verrou,
                                                retenue: Qt.binding(() => pile.retenue)})
        e.fermee.connect(() => fermer(e))
        e.echue.connect(() => e.notification.expire())
        file = file.concat([e])
        ecouler()
    }

    // ecouler — fait entrer les plus anciennes de la file en tête des affichées, tant que la place le permet.
    // Entrées, sortie, erreurs : aucune. Dépendances : retenue, plafond.
    function ecouler() {
        while (!retenue && file.length > 0 && affichees.filter(e => !e.sortante).length < plafond) {
            const e = file[0]
            file = file.slice(1)
            e.affichee = true
            affichees = [e].concat(affichees)
        }
    }

    // fermer — suite de la fermeture d'une notification, quelle qu'en soit la raison.
    // Entrée : e, l'entrée dont la notification courante est fermée. Sortie : aucune ; en file, e est retirée et
    // détruite ; affichée, elle devient sortante et la file s'écoule. Erreurs : aucune. Dépendances : ecouler.
    function fermer(e) {
        if (file.includes(e)) {
            file = file.filter(x => x !== e)
            e.destroy()
        } else if (!e.sortante) {
            e.sortante = true
            affichees = affichees.slice()
            ecouler()
        }
    }

    // cliquer — clic sur une carte : la notification est écartée ; une entrée déjà sortante est ignorée.
    // Entrée : e. Sortie : aucune. Erreurs : aucune. Dépendances : Notification.dismiss.
    function cliquer(e) { if (!e.sortante) e.notification.dismiss() }

    // agir — déclenche une action de la notification, puis l'écarte si elle est encore suivie (notification résidente,
    // que l'action ne ferme pas) ; une entrée déjà sortante est ignorée. Entrées : e ; action, objet à l'interface de NotificationAction. Sortie : aucune.
    // Erreurs : aucune. Dépendances : NotificationAction.invoke, Notification.dismiss.
    function agir(e, action) {
        if (e.sortante) return
        const n = e.notification
        action.invoke()
        if (n.resident && n.tracked) n.dismiss()
    }

    // oublier — retire une entrée sortante des affichées, à la fin de son animation de sortie, et la détruit.
    // Entrée : e. Sortie : aucune. Erreurs : aucune. Dépendances : aucune.
    function oublier(e) {
        affichees = affichees.filter(x => x !== e)
        e.destroy()
    }
}
