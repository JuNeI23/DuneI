import QtQuick
import Quickshell
import "../Theme"
import "etiquettes.js" as Etiquettes
import "garde.js" as Garde
import "son.js" as Son

// Pile — logique de la pile de notifications : file d'attente, plafond, remplacements, sorties, et aiguillage entre la
// carte et le panneau (L2-67).
// Rôle : reçoit les notifications, les remplace sur place quand une entrée non sortante porte la même clé
// (etiquettes.js), sinon les met en file ; la file s'écoule, la plus ancienne d'abord, en tête des affichées tant que la
// pile n'est pas retenue et que les affichées non sortantes sont moins de Theme.notifications.plafond. Toute sortie
// passe par le signal closed de la notification : en file, l'entrée est retirée et détruite ; affichée, elle devient
// sortante, libère sa place aussitôt, et la vue appelle oublier à la fin de son animation de sortie.
// Aiguillage (garde.js) : une notification gardée dont la minuterie arrive à son terme n'est pas fermée ; elle passe
// à l'attente (le panneau), suivie et vivante, et sa carte sort par la même animation. Une notification non gardée
// est expirée comme avant. Sous « ne pas déranger », une notification non critique ne s'affiche pas : gardée, elle va
// droit à l'attente, sinon elle est expirée aussitôt. Un clic sur la carte ou sur une de ses actions traite la
// notification : elle n'entre pas dans l'attente. Une notification qui remplace une entrée de l'attente (même clé, ou
// mise à jour sur place) la retire de l'attente et repasse en carte si elle est affichable : elle ne compte jamais
// deux fois. Après un rechargement de la coque, une notification que l'attente précédente tenait y retourne sans
// repasser en carte.
// Voix (L2-68, son.js) : chaque nouvelle notification, chaque remplacement par clé et chaque mise à jour sur place est
// jugé par Son.voix ; s'il doit sonner, la pile émet sonner(voix). Une mise à jour est jugée avec l'âge et l'urgence
// de la version remplacée. Une notification réémise après un rechargement de la coque (lastGeneration) ne sonne pas.
// Les tableaux sont réaffectés à chaque changement, jamais modifiés sur place, pour qu'un ScriptModel voie la différence.
// Entrées : retenue (plein écran : la file ne s'écoule plus et les minuteries s'arrêtent) ; nePasDeranger et retirees
// (identifiants des applications retirées), liés par le Centre à EtatNotifications ; verrou, fabrique du verrou
// qui retient la notification d'une entrée jusqu'à sa destruction (RetainableLock par défaut, remplacé dans l'essai
// dont les notifications factices ne sont pas Retainable) ; pleinEcran et sonActif, liés par le Centre ; salve et
// renouvellement, en ms, liés à Theme.son.
// Sorties : affichees (Entree, plus récente en tête, sortantes comprises), file (Entree, ordre d'arrivée), attente
// (Attente : les notifications gardées qui attendent dans le panneau) ; signal sonner(voix), « arrivee » ou « urgence » ;
// dernierSon, instant du dernier son émis en ms (-Infinity avant le premier).
// Erreurs : sans jetons chargés, le plafond vaut 0 et tout reste en file jusqu'à leur chargement.
// Dépendances : Entree, Attente, etiquettes.js, garde.js, son.js, Theme.notifications.plafond, Theme.son.
Scope {
    id: pile

    property bool retenue: false
    property bool nePasDeranger: false
    property var retirees: []
    readonly property Attente attente: enAttente
    property var affichees: []
    property var file: []
    property Component verrou: Component {
        RetainableLock { locked: true }
    }
    readonly property int plafond: Theme.notifications?.plafond ?? 0
    property bool pleinEcran: false
    property bool sonActif: true
    property int salve: Theme.son?.salve ?? 0
    property int renouvellement: Theme.son?.renouvellement ?? 0
    property real dernierSon: -Infinity

    signal sonner(string voix)

    onRetenueChanged: ecouler()
    onPlafondChanged: ecouler()

    Component {
        id: fabrique
        Entree {}
    }

    Attente {
        id: enAttente
        verrou: pile.verrou
        onRenouvelee: (a, precedente) => pile.reprendre(a, precedente)
    }

    // recevoir — prend en charge une nouvelle notification.
    // Entrée : n, objet à l'interface de Notification. Sortie : aucune ; n est suivie (tracked), puis, dans l'ordre :
    // retourne à l'attente si celle de la génération précédente de la coque la tenait ; fait expirer l'entrée de
    // l'attente de même clé, qu'elle remplace ; remplace la notification d'une entrée non sortante de même clé ; sous
    // « ne pas déranger », sans être critique, entre dans l'attente si elle est gardée, expire sinon ; à défaut, entre
    // en file. Hors de la génération précédente, sa voix est jugée (entendre) : comme une mise à jour de la version
// qu'elle remplace par clé, ou comme une nouvelle. Erreurs : aucune.
// Dépendances : Etiquettes.cle, Garde, attente, presenter, entendre, Entree.renouveler.
    function recevoir(n) {
        n.tracked = true
        const cle = Etiquettes.cle(n.appName, n.hints)
        if (n.lastGeneration && attente.connue(n.id)) return void attente.ajouter(n, cle, new Date())
        const remplacee = attente.parCle(cle)
        const precedente = remplacee ? {age: Date.now() - remplacee.arrivee.getTime(), urgence: remplacee.urgenceConnue}
                                     : null
        remplacee?.notification.expire()
        const cible = cle === "" ? undefined : affichees.concat(file).find(e => !e.sortante && e.cle === cle)
        if (cible) {
            const ancienne = cible.notification
            cible.notification = n
            ancienne.expire()
            return void cible.renouveler()
        }
        if (!n.lastGeneration) entendre(n, precedente)
        if (Garde.affichable(n, nePasDeranger)) presenter(n, cle)
        else if (Garde.gardee(n, retirees)) attente.ajouter(n, cle, new Date())
        else n.expire()
    }

    // presenter — met une notification suivie en file, pour qu'elle s'affiche en carte.
    // Entrées : n ; cle, sa clé de remplacement. Sortie : aucune. Erreurs : aucune.
    // Dépendances : fabrique, ecouler, fermer, echoir.
    function presenter(n, cle) {
        const e = fabrique.createObject(pile, {notification: n, cle: cle, verrou: pile.verrou,
                                                retenue: Qt.binding(() => pile.retenue)})
        e.fermee.connect(() => fermer(e))
        e.echue.connect(() => echoir(e))
        e.renouvelee.connect(p => entendre(e.notification, p))
        file = file.concat([e])
        ecouler()
    }

    // echoir — fin de la minuterie d'une carte : gardée (jugée à cet instant), la notification passe à l'attente sans
    // être fermée et sa carte sort ; sinon elle est expirée. Entrée : e. Sortie : aucune. Erreurs : aucune.
    // Dépendances : Garde.gardee, Attente.ajouter, fermer, Notification.expire.
    function echoir(e) {
        if (!Garde.gardee(e.notification, retirees)) return e.notification.expire()
        attente.ajouter(e.notification, e.cle, e.arrivee)
        fermer(e)
    }

    // reprendre — mise à jour sur place de la notification d'une entrée de l'attente (remplacement par replaces_id) :
    // affichable, elle quitte l'attente et repasse en carte ; sinon elle y reste, à l'heure présente. Une mise à jour
    // émet un signal par propriété changée : les suivants trouvent l'entrée déjà reprise et sont ignorés.
    // Entrées : a, l'Attendue ; precedente, {age, urgence} de la version remplacée, pour juger sa voix.
    // Sortie : aucune. Erreurs : aucune. Dépendances : Garde.affichable, Attente.oublier, presenter, entendre.
    function reprendre(a, precedente) {
        if (!attente.entrees.includes(a) || a.sortante) return
        entendre(a.notification, precedente)
        if (!Garde.affichable(a.notification, nePasDeranger)) return void (a.arrivee = new Date())
        const n = a.notification, cle = a.cle
        attente.oublier(a)
        presenter(n, cle)
    }

    // entendre — juge la voix d'une notification et la fait entendre s'il y a lieu (L2-68).
    // Entrées : n ; precedente, null pour une nouvelle notification, {age, urgence} de la version remplacée sinon.
    // Sortie : aucune ; si Son.voix rend une voix, signal sonner(voix) et dernierSon à l'instant présent.
    // Erreurs : aucune. Dépendances : Son.voix.
    function entendre(n, precedente) {
        const maintenant = Date.now()
        const voix = Son.voix(n, {active: sonActif, nePasDeranger: nePasDeranger, pleinEcran: pleinEcran,
                                  retirees: retirees, maintenant: maintenant, dernierSon: dernierSon,
                                  precedente: precedente, salve: salve, renouvellement: renouvellement})
        if (voix === "") return
        dernierSon = maintenant
        sonner(voix)
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
