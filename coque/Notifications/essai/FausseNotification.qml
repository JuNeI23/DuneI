import QtQuick

// FausseNotification — notification factice à l'interface de Quickshell.Services.Notifications.Notification.
// Rôle : permet d'éprouver la pile sans serveur ni bus D-Bus. Comme Quickshell : expire() ferme avec la raison 1,
// dismiss() avec la raison 2, une action d'une notification non résidente la ferme (raison 2) après son invocation,
// une fermeture par l'application émet la raison 3 ; une notification fermée n'est plus suivie (tracked faux).
// Chaque appel reçu est signalé par appel(« id:expire », « id:dismiss », « id:invoke:<identifiant> »).
// Entrées : id, appName, summary, body, urgency, expireTimeout (ms), hints, resident, image, appIcon.
// Sorties : actions (une action « default »), signaux closed(raison) et appel(texte). Erreurs : aucune.
// Dépendances : aucune ; coque d'essai seulement.
QtObject {
    id: fausse

    property int id: 0
    property string appName: ""
    property string summary: ""
    property string body: ""
    property int urgency: 1
    property real expireTimeout: -1
    property var hints: ({})
    property bool resident: false
    property bool tracked: false
    property string image: ""
    property string appIcon: ""
    property list<QtObject> actions: [
        Action { identifier: "default"; text: "Ouvrir" }
    ]

    signal closed(int reason)
    signal appel(string texte)

    // Action factice : invoke() est journalisé, puis ferme la notification si elle n'est pas résidente.
    component Action: QtObject {
        property string identifier
        property string text
        // invoke — déclenche l'action. Entrées, sortie, erreurs : aucune. Dépendances : fausse.
        function invoke() {
            fausse.appel(fausse.id + ":invoke:" + identifier)
            if (!fausse.resident) fausse.fermer(2)
        }
    }

    // fermer — ferme la notification si elle est suivie. Entrée : raison. Sortie : aucune. Erreurs : aucune.
    function fermer(raison) {
        if (!tracked) return
        tracked = false
        closed(raison)
    }

    // expire — expiration demandée par la coque : journalisée, puis fermeture (raison 1).
    function expire() { appel(id + ":expire"); fermer(1) }

    // dismiss — renvoi demandé par la coque : journalisé, puis fermeture (raison 2).
    function dismiss() { appel(id + ":dismiss"); fermer(2) }
}
