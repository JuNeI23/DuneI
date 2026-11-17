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
// Sorties : signaux fermee(raison) et renouvelee().
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

    signal fermee(int raison)
    signal renouvelee()

    Component.onCompleted: verrou?.createObject(attendue, {object: Qt.binding(() => attendue.notification)})

    Connections {
        target: attendue.notification
        function onSummaryChanged() { attendue.renouvelee() }
        function onBodyChanged() { attendue.renouvelee() }
        function onAppNameChanged() { attendue.renouvelee() }
        function onAppIconChanged() { attendue.renouvelee() }
        function onImageChanged() { attendue.renouvelee() }
        function onUrgencyChanged() { attendue.renouvelee() }
        function onExpireTimeoutChanged() { attendue.renouvelee() }
        function onActionsChanged() { attendue.renouvelee() }
        function onHintsChanged() { attendue.renouvelee() }
        function onClosed(raison) { attendue.fermee(raison) }
    }
}
