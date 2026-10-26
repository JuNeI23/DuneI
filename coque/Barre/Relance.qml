import QtQuick
import Quickshell.Io

// Relance — processus résident qui relance une lecture ponctuelle à chacune de ses lignes.
// Rôle : motif commun de Vpn et de Notifications. Un processus de surveillance (nmcli monitor, dbus-monitor)
// émet une ligne à chaque changement ; chaque ligne relance une commande de lecture dont la sortie complète est
// publiée par le signal lu. Une lecture initiale a lieu au démarrage et après chaque relance de la surveillance ;
// une ligne reçue pendant une lecture en provoque une seconde juste après. Si la surveillance meurt
// (NetworkManager ou dunst relancé, outil absent), elle est relancée une seconde plus tard par une minuterie à
// un coup, sans tourner en boucle serrée.
// Entrées : surveille, commande du processus résident (propriété, pour qu'un test injecte une commande
// factice) ; lecture, commande de la lecture ponctuelle ; actif, vrai par défaut, suspend tout si faux.
// Sorties : signal lu(texte), sortie standard de la lecture ; propriété relances, nombre de démarrages de la
// surveillance (utile aux tests).
// Erreurs : un outil absent ou une commande qui échoue ne produit aucun lu et relance la surveillance sans fin
// à la cadence d'une seconde ; rien n'est journalisé de plus que ce que Quickshell journalise.
// Dépendances : Quickshell.Io (Process, SplitParser, StdioCollector).
Item {
    id: racine

    property var surveille: []
    property var lecture: []
    property bool actif: true
    property int relances: 0

    signal lu(string texte)

    // true quand une ligne est arrivée pendant une lecture : la lecture est refaite dès qu'elle se termine.
    property bool relire: false

    // lire — demande une lecture ponctuelle. Rôle : lance la lecture, ou, si l'une est en cours, note qu'il
    // faudra la refaire pour ne perdre aucune ligne. Entrées : aucune. Sortie : aucune. Erreurs : aucune.
    // Dépendances : lecteur.
    function lire() {
        if (lecteur.running) relire = true; else lecteur.running = true
    }

    // demarrer — lecture (initiale ou après relance de la surveillance), puis démarrage de la surveillance.
    // Entrées : aucune. Sortie : aucune. Erreurs : aucune. Dépendances : lire, veilleur.
    function demarrer() {
        lire()
        veilleur.running = true
    }

    Process {
        id: lecteur
        command: racine.lecture
        stdout: StdioCollector { onStreamFinished: racine.lu(text) }
        onExited: if (racine.relire) { racine.relire = false; running = true }
    }

    Process {
        id: veilleur
        command: racine.surveille
        stdout: SplitParser { onRead: racine.lire() }
        onRunningChanged: if (running) racine.relances++
        onExited: if (racine.actif) delai.start()
    }

    // Minuterie à un coup : attend une seconde avant de relancer la surveillance.
    Timer {
        id: delai
        interval: 1000
        repeat: false
        onTriggered: if (racine.actif) racine.demarrer()
    }

    onActifChanged: {
        if (actif) demarrer(); else { delai.stop(); veilleur.running = false }
    }
    Component.onCompleted: if (actif) demarrer()
}
