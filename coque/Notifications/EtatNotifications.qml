pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// EtatNotifications — état persistant des notifications, partagé par la coque entière (L2-67).
// Rôle : porte « ne pas déranger » et la liste des applications retirées du panneau, lus par la pile (affichage des
// cartes, garde), la cloche (glyphe), le panneau (bascule, « Ne plus garder ») et la page Notifications de Paramètres.
// L'état survit au rechargement de la coque et au redémarrage : il est tenu dans un fichier JSON de la coque,
// {"nePasDeranger": bool, "retirees": [identifiants]}, écrit à chaque changement. Il s'expose aussi par l'IPC de la
// coque (cible « notifications »), pour un futur raccourci clavier.
// Entrées : chemin, le fichier de l'état, notifications.json dans le dossier d'état de la coque (Quickshell.stateDir)
// par défaut, ou dans celui que nomme la variable DUNEI_ETAT_DIR (posée par les essais, pour qu'une coque d'essai
// n'écrive jamais dans l'état de la session).
// Sorties : nePasDeranger ; retirees, identifiants (garde.js, identifiant) des applications retirées.
// Fonctions : basculer, poser, retirer, remettre. IPC : nePasDeranger, basculerNePasDeranger.
// Erreurs : aucune ; un fichier absent ou illisible donne les valeurs par défaut, et il est créé ou réécrit à la
// première modification.
// Dépendances : Quickshell (Singleton, env, stateDir), Quickshell.Io (FileView, JsonAdapter, IpcHandler).
Singleton {
    id: etat

    property string chemin: (Quickshell.env("DUNEI_ETAT_DIR") || Quickshell.stateDir) + "/notifications.json"
    readonly property bool nePasDeranger: adaptateur.nePasDeranger
    readonly property var retirees: adaptateur.retirees

    // basculer — inverse « ne pas déranger ». Entrées, sortie, erreurs : aucune. Dépendances : poser.
    function basculer() { poser(!nePasDeranger) }

    // poser — pose « ne pas déranger ». Entrée : v, l'état voulu. Sortie : aucune ; le fichier est écrit si l'état
    // change. Erreurs : aucune. Dépendances : adaptateur.
    function poser(v) { adaptateur.nePasDeranger = v }

    // retirer — retire une application du panneau : ses notifications ne sont plus gardées.
    // Entrée : identifiant de l'application (garde.js, identifiant). Sortie : aucune. Erreurs : aucune ; un
    // identifiant vide (application anonyme) ou déjà retiré ne change rien. Dépendances : adaptateur.
    function retirer(identifiant) {
        if (identifiant !== "" && !retirees.includes(identifiant)) adaptateur.retirees = retirees.concat(identifiant)
    }

    // remettre — remet une application retirée : ses prochaines notifications sont de nouveau gardées.
    // Entrée : identifiant. Sortie : aucune. Erreurs : aucune ; un identifiant absent ne change rien.
    // Dépendances : adaptateur.
    function remettre(identifiant) {
        if (retirees.includes(identifiant)) adaptateur.retirees = retirees.filter(i => i !== identifiant)
    }

    FileView {
        path: etat.chemin
        printErrors: false
        // La lecture est attendue : la pile lit l'état dès la première notification.
        blockLoading: true
        onAdapterUpdated: writeAdapter()
        JsonAdapter {
            id: adaptateur
            property bool nePasDeranger: false
            property list<string> retirees: []
        }
    }

    IpcHandler {
        target: "notifications"

        // nePasDeranger — lecture de l'état. Entrées : aucune. Sortie : « true » ou « false ». Erreurs : aucune.
        // Dépendances : etat.
        function nePasDeranger(): string { return String(etat.nePasDeranger) }

        // basculerNePasDeranger — voir basculer. Entrées : aucune. Sortie : aucune. Erreurs : aucune.
        // Dépendances : etat.basculer.
        function basculerNePasDeranger(): void { etat.basculer() }
    }
}
