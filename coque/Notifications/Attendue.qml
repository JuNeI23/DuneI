import QtQuick
import Quickshell

// Attendue — une notification en attente dans le panneau (L2-67).
// Rôle : porte une notification gardée dont la carte s'est effacée, ou que « ne pas déranger » a retenue : elle reste
// suivie par le serveur, donc ses actions restent utilisables, jusqu'à ce qu'elle soit ouverte, écartée ou fermée par
// son application. Elle relaie la fermeture de sa notification (fermee) et toute mise à jour sur place (renouvelee :
// le serveur de Quickshell met à jour une notification remplacée par replaces_id sans émettre de signal propre, comme
// pour Entree).
// Entrées : notification (objet à l'interface de Quickshell.Services.Notifications.Notification), cle (clé de
// remplacement, etiquettes.js), arrivee, sortante (posée par l'attente : fermée, encore montrée le temps de son
// animation de sortie), verrou (fabrique posée par l'attente).
// Sorties : signaux fermee(raison) et renouvelee(precedente) ; urgenceConnue, instantané de l'urgence, comme Entree.
// Erreurs : aucune. Dépendances : verrou (RetainableLock dans la coque).
// Durée de vie : comme Entree, l'attendue retient sa notification par un verrou jusqu'à sa propre destruction, pour
// que l'entrée sortante garde son contenu pendant l'animation de sortie.
Scope {
    id: attendue

    property QtObject notification
    property string cle: ""
    property date arrivee: new Date()
    property bool sortante: false
    property Component verrou
    property int urgenceConnue: -1
    // Version remplacée par la mise à jour en cours, en attente de son annonce (voir renouveler).
    property var _remplacee: null

    signal fermee(int raison)
    signal renouvelee(var precedente)

    // renouveler — suite d'une mise à jour sur place : lit la version remplacée au premier signal, puis l'annonce une
    // fois la mise à jour finie (Qt.callLater), comme Entree. L'heure d'arrivée est remise par la pile
    // (Pile.reprendre). Entrées : aucune. Sortie : signal renouvelee({age, urgence}), en ms, par annoncer.
    // Erreurs : aucune. Dépendances : urgenceConnue, annoncer.
    function renouveler() {
        if (_remplacee !== null) return
        _remplacee = {age: Date.now() - arrivee.getTime(), urgence: urgenceConnue}
        Qt.callLater(annoncer)
    }

    // annoncer — fin d'une mise à jour : prend la nouvelle urgence et annonce la version remplacée. Entrées : aucune.
    // Sortie : signal renouvelee. Erreurs : aucune. Dépendances : _remplacee, urgenceConnue.
    function annoncer() {
        const precedente = _remplacee
        _remplacee = null
        urgenceConnue = notification?.urgency ?? -1
        renouvelee(precedente)
    }

    Component.onCompleted: {
        verrou?.createObject(attendue, {object: Qt.binding(() => attendue.notification)})
        urgenceConnue = notification?.urgency ?? -1
    }

    Connections {
        target: attendue.notification
        function onSummaryChanged() { attendue.renouveler() }
        function onBodyChanged() { attendue.renouveler() }
        function onAppNameChanged() { attendue.renouveler() }
        function onAppIconChanged() { attendue.renouveler() }
        function onImageChanged() { attendue.renouveler() }
        function onUrgencyChanged() { attendue.renouveler() }
        function onExpireTimeoutChanged() { attendue.renouveler() }
        function onActionsChanged() { attendue.renouveler() }
        function onHintsChanged() { attendue.renouveler() }
        function onClosed(raison) { attendue.fermee(raison) }
    }
}
