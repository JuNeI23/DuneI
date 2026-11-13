import QtQuick
import Quickshell
import "../Theme"
import "etiquettes.js" as Etiquettes

// Entree — une notification tenue par la pile, avec sa minuterie d'expiration.
// Rôle : porte la notification courante (remplaçable sur place par la pile), sa clé de remplacement et son état
// (affichée, survolée, retenue, sortante). La minuterie ne tourne que si l'entrée est affichée, ni survolée, ni
// retenue, ni sortante, et que sa durée est positive ; chaque arrêt garde le temps restant, chaque reprise repart de
// lui. À son terme, le signal echue est émis ; la pile y répond par expire(). Une mise à jour du résumé ou du corps de
// la notification courante réarme le compte à la durée pleine.
// Entrées : notification (objet à l'interface de Quickshell.Services.Notifications.Notification), arrivee, cle,
// affichee (posée par la pile), survolee (écrite par la carte), retenue (liée par la pile), sortante (posée par la
// pile). Sorties : restant (ms, lecture seule pour les autres), duree, signaux echue() et fermee(raison).
// Erreurs : sans jetons chargés, la durée par défaut vaut 0 et une notification au délai par défaut n'expire pas avant
// leur chargement. Dépendances : Theme.notifications.duree, etiquettes.js.
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

    onActiveChanged: active ? lancer() : suspendre()
    onDureeChanged: rearmer()
    Component.onCompleted: rearmer()

    Timer {
        id: minuterie
        onTriggered: { entree.restant = 0; entree.echue() }
    }

    // La notification courante seule : après un remplacement, la fermeture de l'ancienne ne retrouve plus l'entrée.
    Connections {
        target: entree.notification
        function onSummaryChanged() { entree.rearmer() }
        function onBodyChanged() { entree.rearmer() }
        function onClosed(raison) { entree.fermee(raison) }
    }
}
