import QtQuick
import Quickshell
import "../Theme"
import "etiquettes.js" as Etiquettes

// Entree — une notification tenue par la pile, avec sa minuterie d'expiration.
// Rôle : porte la notification courante (remplaçable sur place par la pile), sa clé de remplacement et son état
// (affichée, survolée, retenue, sortante). La minuterie ne tourne que si l'entrée est affichée, ni survolée, ni
// retenue, ni sortante, et que sa durée est positive ; chaque arrêt garde le temps restant, chaque reprise repart de
// lui. À son terme, le signal echue est émis ; la pile y répond par expire(). Un remplacement (renouveler) remet
// l'heure d'arrivée à l'instant présent et le compte à la durée pleine : la pile l'appelle pour un remplacement par
// étiquette, et l'entrée elle-même à tout changement d'une propriété de la notification courante, puisque le serveur
// de Quickshell met à jour sur place une notification remplacée par replaces_id sans émettre de signal propre.
// Limite : un remplacement strictement identique (mêmes propriétés, mêmes indices) ne change aucune propriété et
// n'est donc pas vu ; notify-send joint toujours l'indice sender-pid, qui diffère d'un envoi à l'autre.
// Entrées : notification (objet à l'interface de Quickshell.Services.Notifications.Notification), arrivee, cle,
// affichee (posée par la pile), survolee (écrite par la carte), retenue (liée par la pile), sortante (posée par la
// pile). Sorties : restant (ms, lecture seule pour les autres), duree, signaux echue() et fermee(raison).
// Erreurs : sans jetons chargés, la durée par défaut vaut 0 et une notification au délai par défaut n'expire pas avant
// leur chargement. Dépendances : Theme.notifications.duree, etiquettes.js, verrou (posé par la pile).
// Durée de vie : une Notification de Quickshell est Retainable et détruite dès la fin des réactions à closed ;
// l'entrée la retient par un verrou (RetainableLock dans la coque) jusqu'à sa propre destruction, à oublier ou au
// retrait de la file, pour que la carte sortante garde son contenu pendant l'animation de sortie. Le verrou suit la
// notification courante : après un remplacement, l'ancienne est relâchée.
Scope {
    id: entree

    property QtObject notification
    property date arrivee: new Date()
    property string cle: ""
    property bool affichee: false
    property bool survolee: false
    property bool retenue: false
    property bool sortante: false
    property int restant: 0
    // Fabrique du verrou qui retient la notification courante ; il reçoit object lié à notification.
    property Component verrou

    readonly property int duree: Etiquettes.duree(notification ? notification.expireTimeout : -1,
                                                  Theme.notifications?.duree ?? 0)
    readonly property bool active: affichee && !survolee && !retenue && !sortante && duree > 0
    // Instant monotone (ms) de la dernière reprise de la minuterie.
    property real depart: 0

    signal echue()
    signal fermee(int raison)

    // lancer — reprend la minuterie avec le temps restant ; sans temps restant (durée pas encore connue), rien.
    // Entrées : aucune. Sortie : aucune. Erreurs : aucune. Dépendances : minuterie.
    function lancer() {
        if (restant <= 0) return
        depart = Date.now(); minuterie.interval = restant; minuterie.restart()
    }

    // suspendre — arrête la minuterie et garde le temps qu'il lui restait. Entrées, sortie, erreurs : aucune.
    // Dépendances : minuterie.
    function suspendre() {
        if (!minuterie.running) return
        restant = Math.max(1, restant - (Date.now() - depart)); minuterie.stop()
    }

    // rearmer — remet le compte à la durée pleine, et la minuterie en marche si l'entrée est active.
    // Entrées, sortie, erreurs : aucune. Dépendances : lancer, minuterie.
    function rearmer() {
        minuterie.stop(); restant = duree
        if (active) lancer()
    }

    // renouveler — suite d'un remplacement : l'heure d'arrivée devient l'instant présent et le compte est réarmé.
    // Entrées, sortie, erreurs : aucune. Dépendances : rearmer.
    function renouveler() { arrivee = new Date(); rearmer() }

    onActiveChanged: active ? lancer() : suspendre()
    onDureeChanged: rearmer()
    Component.onCompleted: {
        verrou?.createObject(entree, {object: Qt.binding(() => entree.notification)})
        rearmer()
    }

    Timer {
        id: minuterie
        onTriggered: { entree.restant = 0; entree.echue() }
    }

    // La notification courante seule : après un remplacement, la fermeture de l'ancienne ne retrouve plus l'entrée.
    // Tout changement reçu est un remplacement par replaces_id.
    Connections {
        target: entree.notification
        function onSummaryChanged() { entree.renouveler() }
        function onBodyChanged() { entree.renouveler() }
        function onAppNameChanged() { entree.renouveler() }
        function onAppIconChanged() { entree.renouveler() }
        function onImageChanged() { entree.renouveler() }
        function onUrgencyChanged() { entree.renouveler() }
        function onExpireTimeoutChanged() { entree.renouveler() }
        function onActionsChanged() { entree.renouveler() }
        function onHintsChanged() { entree.renouveler() }
        function onClosed(raison) { entree.fermee(raison) }
    }
}
