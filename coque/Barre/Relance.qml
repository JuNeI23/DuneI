import QtQuick
import Quickshell.Io

// Relance — processus résident qui relance une lecture ponctuelle à chacune de ses lignes.
// Rôle : motif commun de Vpn et de Notifications. Un processus de surveillance (nmcli monitor, dbus-monitor)
// émet une ligne à chaque changement ; chaque ligne relance une commande de lecture dont la sortie complète est
// publiée par le signal lu. Une lecture initiale a lieu au démarrage. Si la surveillance meurt (NetworkManager
// ou dunst relancé, outil absent), elle est relancée une seconde plus tard par une minuterie à un coup, sans
// tourner en boucle serrée.
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

    // Une lecture n'est lancée que si la précédente est finie : les lignes en rafale ne s'empilent pas.
    Process {
        id: lecteur
        command: racine.lecture
        stdout: StdioCollector { onStreamFinished: racine.lu(text) }
    }

    Process {
        id: veilleur
        command: racine.surveille
        stdout: SplitParser { onRead: if (!lecteur.running) lecteur.running = true }
        onRunningChanged: if (running) racine.relances++
        onExited: if (racine.actif) delai.start()
    }

    // Minuterie à un coup : attend une seconde avant de relancer la surveillance.
    Timer {
        id: delai
        interval: 1000
        repeat: false
        onTriggered: if (racine.actif) veilleur.running = true
    }

    // Démarre ou arrête tout selon actif ; lecture initiale au démarrage.
    onActifChanged: {
        if (actif) { lecteur.running = true; veilleur.running = true } else { delai.stop(); veilleur.running = false }
    }
    Component.onCompleted: if (actif) { lecteur.running = true; veilleur.running = true }
}
