import QtQuick

// FausseNotification — notification factice à l'interface de Quickshell.Services.Notifications.Notification.
// Rôle : permet d'éprouver la pile sans serveur ni bus D-Bus. Comme Quickshell : expire() ferme avec la raison 1,
// dismiss() avec la raison 2, une action d'une notification non résidente la ferme (raison 2) après son invocation,
// une fermeture par l'application émet la raison 3 ; une notification fermée n'est plus suivie (tracked faux).
// Comme un objet Retainable, elle est détruite dès la fin des réactions à closed, sauf si un verrou (FauxVerrou) la
// retient : elle l'est alors au retrait du dernier verrou.
// Chaque appel reçu est signalé par appel(« id:expire », « id:dismiss », « id:invoke:<identifiant> »).
// Entrées : id, appName, summary, body, urgency (0 basse, 1 normale, 2 critique, comme NotificationUrgency),
// expireTimeout (ms), hints, resident, image, appIcon.
// Sorties : actions (une action « default » ; poserActions la remplace), signaux closed(raison), appel(texte) et detruite(). Erreurs : aucune.
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
    // Nombre de verrous posés par FauxVerrou ; fermee vaut vrai une fois closed émis.
    property int verrous: 0
    property bool fermee: false
    property string image: ""
    property string appIcon: ""
    property list<QtObject> actions: [
        Action { identifier: "default"; text: "Ouvrir" }
    ]

    // Fabrique des actions de poserActions ; QtObject n'a pas de propriété par défaut pour la porter en enfant.
    property Component fabriqueAction: Component { Action {} }

    signal closed(int reason)
    signal appel(string texte)
    // Émis à la destruction, pour que l'essai sache qu'elle a eu lieu.
    signal detruite()

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

    // fermer — ferme la notification si elle est suivie, puis la détruit si aucun verrou ne la retient.
    // Entrée : raison. Sortie : aucune. Erreurs : aucune. Dépendances : liberer.
    function fermer(raison) {
        if (!tracked) return
        tracked = false
        closed(raison)
        fermee = true
        liberer()
    }

    // liberer — détruit la notification fermée que plus aucun verrou ne retient. Entrées, sortie, erreurs : aucune.
    function liberer() { if (fermee && verrous === 0) destroy() }

    Component.onDestruction: detruite()

    // poserActions — remplace les actions, dans l'ordre donné.
    // Entrée : paires, tableau de [identifiant, texte]. Sortie : aucune. Erreurs : aucune. Dépendances : fabriqueAction.
    function poserActions(paires) {
        actions = paires.map(p => fabriqueAction.createObject(fausse, {identifier: p[0], text: p[1]}))
    }

    // expire — expiration demandée par la coque : journalisée, puis fermeture (raison 1).
    function expire() { appel(id + ":expire"); fermer(1) }

    // dismiss — renvoi demandé par la coque : journalisé, puis fermeture (raison 2).
    function dismiss() { appel(id + ":dismiss"); fermer(2) }
}
