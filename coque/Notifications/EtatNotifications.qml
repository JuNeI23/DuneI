pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// EtatNotifications — état persistant des notifications, partagé par la coque entière (L2-67).
// Rôle : porte « ne pas déranger », la liste des applications retirées du panneau et les réglages de la voix (L2-68),
// lus par la pile (affichage des cartes, garde, voix), la cloche (glyphe), le panneau (bascule, « Ne plus garder »),
// la lecture des sons (Voix) et la page Notifications de Paramètres.
// L'état survit au rechargement de la coque et au redémarrage : il est tenu dans un fichier JSON de la coque,
// {"nePasDeranger": bool, "retirees": [identifiants], "son": bool, "volumeSon": 0 à 100}, écrit à chaque changement ;
// un fichier antérieur à L2-68, sans « son » ni « volumeSon », prend leurs valeurs par défaut (vrai, 100). Il s'expose aussi par l'IPC de la
// coque (cible « notifications »), pour un futur raccourci clavier.
// Entrées : chemin, le fichier de l'état, notifications.json dans le dossier d'état de la coque (Quickshell.stateDir)
// par défaut, ou dans celui que nomme la variable DUNEI_ETAT_DIR (posée par les essais, pour qu'une coque d'essai
// n'écrive jamais dans l'état de la session).
// Sorties : nePasDeranger ; retirees, identifiants (garde.js, identifiant) des applications retirées ; icone, le
// glyphe de l'état, cloche barrée sous « ne pas déranger », cloche sinon, lu par la cloche de la barre et la
// bascule du panneau (D182) ; son, la voix des notifications activée ; volumeSon, son volume relatif au système, de 0
// à 100.
// Fonctions : basculer, poser, retirer, remettre, poserSon, poserVolume. IPC : nePasDeranger, basculerNePasDeranger,
// son, volumeSon.
// Erreurs : aucune ; un fichier absent ou illisible donne les valeurs par défaut, et il est créé ou réécrit à la
// première modification.
// Dépendances : Quickshell (Singleton, env, stateDir), Quickshell.Io (FileView, JsonAdapter, IpcHandler).
Singleton {
    id: etat

    property string chemin: (Quickshell.env("DUNEI_ETAT_DIR") || Quickshell.stateDir) + "/notifications.json"
    readonly property bool nePasDeranger: adaptateur.nePasDeranger
    readonly property var retirees: adaptateur.retirees
    readonly property bool son: adaptateur.son
    readonly property int volumeSon: adaptateur.volumeSon
    readonly property string icone: nePasDeranger ? "notifications-disabled" : "preferences-system-notifications"

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

    // poserSon — active ou coupe la voix des notifications. Entrée : v, l'état voulu. Sortie : aucune ; le fichier est
    // écrit si l'état change. Erreurs : aucune. Dépendances : adaptateur.
    function poserSon(v) { adaptateur.son = v }

    // poserVolume — pose le volume de la voix. Entrée : v, en pour cent. Sortie : aucune ; la valeur est bornée entre 0
    // et 100, puis écrite si elle change. Erreurs : aucune. Dépendances : adaptateur.
    function poserVolume(v) { adaptateur.volumeSon = Math.max(0, Math.min(100, Math.round(v))) }

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
            property bool son: true
            property int volumeSon: 100
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

        // son, volumeSon — lecture des réglages de la voix. Entrées : aucune. Sortie : « true » ou « false » ; le
        // volume en pour cent. Erreurs : aucune. Dépendances : etat.
        function son(): string { return String(etat.son) }
        function volumeSon(): string { return String(etat.volumeSon) }
    }
}
