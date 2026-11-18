import QtQuick
import Quickshell
import "garde.js" as Garde

// Attente — logique du panneau des notifications (L2-67) : les notifications gardées, qui attendent d'être traitées.
// Rôle : tient les notifications que la pile lui confie (carte effacée sans clic, ou carte retenue par « ne pas
// déranger ») ; chacune reste suivie par le serveur. Une entrée en sort quand elle est ouverte, quand une de ses
// actions est déclenchée, quand elle est écartée, ou quand son application la ferme : toute sortie passe par le signal
// closed de la notification. Si une vue montre l'attente (montree), l'entrée fermée devient sortante, cesse de
// compter aussitôt, et la vue appelle oublier à la fin de son animation de sortie ; sans vue, elle est retirée et
// détruite aussitôt. Le tableau est réaffecté à chaque changement, jamais modifié sur place.
// Entrées : montree, vrai tant qu'une vue est montée (à son démontage, les sortantes sont oubliées) ; verrou, fabrique du verrou des entrées (RetainableLock par
// défaut, remplacé dans l'essai) ; connus, identifiants des notifications que l'attente de la génération précédente
// de la coque tenait (posés par MemoireAttente ; voir connue).
// Sorties : entrees (Attendue, plus récente en tête, sortantes comprises) ; vivantes, les entrées non sortantes ;
// nombre, leur compte, celui que porte la cloche ; critique, vrai si l'une d'elles est critique ; groupes, les
// vivantes rangées par application (garde.js, grouper) ; signal renouvelee(a, precedente), quand la notification d'une
// entrée est mise à jour sur place ({age, urgence} de la version remplacée, voir Attendue.renouveler) : la pile décide alors de la remontrer en carte.
// Rechargement de la coque : connus est posé par MemoireAttente, qui tient les identifiants des vivantes d'une
// génération à l'autre ; la pile y reconnaît les notifications qui retournent au panneau sans repasser en carte.
// Erreurs : aucune. Dépendances : Attendue, garde.js.
Scope {
    id: attente

    property var entrees: []
    property bool montree: false
    property var connus: []
    property Component verrou: Component {
        RetainableLock { locked: true }
    }
    readonly property var vivantes: entrees.filter(a => !a.sortante)
    readonly property int nombre: vivantes.length
    readonly property bool critique: vivantes.some(a => a.notification.urgency === 2)
    readonly property var groupes: Garde.grouper(vivantes)

    signal renouvelee(var a, var precedente)

    // Plus aucune vue : les sortantes, dont aucune ligne n'achèvera le repli, sont oubliées aussitôt.
    onMontreeChanged: if (!montree) entrees.filter(a => a.sortante).forEach(oublier)

    Component {
        id: fabrique
        Attendue {}
    }

    // ajouter — fait entrer une notification suivie dans l'attente, en tête.
    // Entrées : n, objet à l'interface de Notification ; cle, sa clé de remplacement ; arrivee, son heure d'arrivée.
    // Sortie : l'Attendue créée. Erreurs : aucune. Dépendances : fabrique, fermer.
    function ajouter(n, cle, arrivee) {
        const a = fabrique.createObject(attente, {notification: n, cle: cle, arrivee: arrivee, verrou: attente.verrou})
        a.fermee.connect(() => fermer(a))
        a.renouvelee.connect(p => attente.renouvelee(a, p))
        entrees = [a].concat(entrees)
        return a
    }

    // fermer — suite de la fermeture d'une notification, quelle qu'en soit la raison.
    // Entrée : a, l'entrée dont la notification est fermée. Sortie : aucune ; montrée, elle devient sortante ; sinon
    // elle est oubliée. Erreurs : aucune. Dépendances : oublier.
    function fermer(a) {
        if (a.sortante) return
        if (!montree) return oublier(a)
        a.sortante = true
        entrees = entrees.slice()
    }

    // oublier — retire une entrée et la détruit, sans fermer sa notification : fin de l'animation de sortie d'une
    // sortante, ou reprise par la pile d'une notification qui repasse en carte ou qu'une autre remplace.
    // Entrée : a. Sortie : aucune. Erreurs : aucune. Dépendances : aucune.
    function oublier(a) {
        entrees = entrees.filter(x => x !== a)
        a.destroy()
    }

    // parCle — entrée vivante qui porte une clé de remplacement. Entrée : cle. Sortie : l'Attendue, ou undefined si
    // la clé est vide ou portée par aucune. Erreurs : aucune. Dépendances : vivantes.
    function parCle(cle) { return cle === "" ? undefined : vivantes.find(a => a.cle === cle) }

    // connue — vrai si l'attente de la génération précédente de la coque tenait cette notification.
    // Entrée : id, l'identifiant de la notification, stable d'une génération à l'autre. Sortie : booléen.
    // Erreurs : aucune. Dépendances : connus.
    function connue(id) { return connus.includes(id) }

    // agir — déclenche une action d'une entrée, puis écarte sa notification si elle est encore suivie (notification
    // résidente, que l'action ne ferme pas) ; une entrée sortante est ignorée. Entrées : a ; action, objet à
    // l'interface de NotificationAction. Sortie : aucune. Erreurs : aucune.
    // Dépendances : NotificationAction.invoke, Notification.dismiss.
    function agir(a, action) {
        if (a.sortante) return
        const n = a.notification
        action.invoke()
        if (n.resident && n.tracked) n.dismiss()
    }

    // ouvrir — clic sur une entrée : son action « default », celle de l'application ou l'« Ouvrir » de DuneI (L2-69),
    // sinon un simple écart. Entrée : a. Sortie : aucune. Erreurs : aucune.
    // Dépendances : agir, ecarter, EtatNotifications.actions.
    function ouvrir(a) {
        const defaut = EtatNotifications.actions(a.notification).find(x => x.identifier === "default")
        defaut ? agir(a, defaut) : ecarter(a)
    }

    // ecarter — écarte une entrée ; une entrée sortante est ignorée. Entrée : a. Sortie : aucune. Erreurs : aucune.
    // Dépendances : Notification.dismiss.
    function ecarter(a) { if (!a.sortante) a.notification.dismiss() }

    // ecarterGroupe — écarte toutes les entrées d'une application. Entrée : identifiant (garde.js, identifiant).
    // Sortie : aucune. Erreurs : aucune. Dépendances : ecarter, vivantes.
    function ecarterGroupe(identifiant) {
        vivantes.filter(a => Garde.identifiant(a.notification) === identifiant).forEach(ecarter)
    }

    // toutEcarter — écarte toutes les entrées. Entrées, sortie, erreurs : aucune. Dépendances : ecarter, vivantes.
    function toutEcarter() { vivantes.forEach(ecarter) }
}
