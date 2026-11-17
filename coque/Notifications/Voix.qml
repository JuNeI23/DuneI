pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../Theme"
import "son.js" as Son

// Voix — lecture des sons des notifications (L2-68).
// Rôle : fait entendre une voix, Arrivée ou Urgence, en lançant pw-play (son.js, commande) sur le fichier que nomment
// les jetons Theme.son, au volume de EtatNotifications.volumeSon. Chaque son a son propre processus : un son n'en
// coupe aucun autre. Rien n'attend la fin d'une lecture.
// Entrées : DUNEI_PW_PLAY, l'exécutable de lecture à la place de pw-play (posée par les essais, pour qu'aucun test ne
// fasse de bruit). Sorties : aucune.
// Fonctions : jouer.
// Erreurs : un lecteur introuvable ou une lecture en échec (code non nul) ne bloque rien ; le premier échec de la
// session est journalisé par console.warn, les suivants ne le sont plus.
// Dépendances : Quickshell (Singleton, env), Quickshell.Io (Process), Theme.son, EtatNotifications, son.js.
Singleton {
    id: voix

    readonly property string lecteur: Quickshell.env("DUNEI_PW_PLAY") || "pw-play"
    property bool averti: false

    // jouer — fait entendre une voix. Entrée : nom, « arrivee » ou « urgence ». Sortie : aucune ; un nom sans fichier
    // dans les jetons ne joue rien. Erreurs : voir echouer, appelée par le processus. Dépendances : Son.commande,
    // Theme.son, lecture.
    function jouer(nom) {
        const fichier = Theme.son?.[nom]
        if (!fichier) return
        const commande = Son.commande(fichier, EtatNotifications.volumeSon)
        commande[0] = lecteur
        lecture.createObject(voix, {command: commande}).running = true
    }

    // echouer — suite d'une lecture manquée : journalise le premier échec de la session, puis détruit le processus.
    // Entrées : p, le processus ; raison, texte. Sortie : aucune. Erreurs : aucune. Dépendances : averti.
    function echouer(p, raison) {
        if (!averti) console.warn("voix des notifications injouable (" + raison + ")")
        averti = true
        p.destroy()
    }

    Component {
        id: lecture
        // Le lancement est asynchrone : un lecteur introuvable fait retomber running sans que started soit émis.
        Process {
            id: processus
            property bool parti: false
            onStarted: parti = true
            onRunningChanged: if (!running && !parti) voix.echouer(processus, "lecteur introuvable : " + command[0])
            onExited: code => code === 0 ? processus.destroy() : voix.echouer(processus, "code " + code)
        }
    }
}
