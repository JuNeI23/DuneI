//@ pragma IconTheme DuneI
import QtQuick
import Quickshell
import Quickshell.Io
import "Reseau"

// Coque d'essai des notifications de connexion, sous la plateforme offscreen.
// Rôle : instancie NotificationsReseau avec des entrées fixées par le test (connecté, connectivité, nom) au lieu
// de celles de EtatReseau, et une commande factice qui journalise « icône|titre|corps » dans le fichier de la
// variable NOTIF_JOURNAL ; aucune notification réelle n'est émise. tests/test_reseau.py (NotificationsTest) la pilote.
// Entrées : DUNEI_TOKENS_DIR, lu par Theme ; NOTIF_CONNUS=0, appareils d'abord inconnus ; NOTIF_JOURNAL, QT_QPA_PLATFORM et PATH, posés par le test.
// Sortie : « essai : prêt » au démarrage ; voir l'IpcHandler. Erreurs : celles de Theme, dans le journal.
// Dépendances : quickshell ≥ 0.3 (IpcHandler), NotificationsReseau, liens Theme, Composants, Reseau et Barre.
ShellRoot {
    id: essai

    property bool connecte: true
    property string connectivite: "full"
    property string nom: "Maison"
    property bool connus: Quickshell.env("NOTIF_CONNUS") !== "0"
    property double saut: 0

    Component.onCompleted: console.info("essai : prêt")

    NotificationsReseau {
        id: notifications
        connecte: essai.connecte
        connectivite: essai.connectivite
        nom: essai.nom
        connus: essai.connus
        horloge: () => Date.now() + essai.saut
        commande: (icone, titre, corps) => ["sh", "-c", 'printf "%s|%s|%s\\n" "$1" "$2" "$3" >> "$4"', "x",
                                            icone, titre, corps, Quickshell.env("NOTIF_JOURNAL")]
    }

    IpcHandler {
        target: "essai"

        // regler — pose les entrées de l'état du réseau en une fois.
        // Entrées : connecte, « true » ou « false » ; connectivite ; nom. Sortie : aucune. Erreurs : aucune.
        // Dépendances : les propriétés de la racine.
        function regler(connecte: string, connectivite: string, nom: string): void {
            essai.connecte = connecte === "true"; essai.connectivite = connectivite; essai.nom = nom
        }

        // connaitre — déclare les appareils de Networking peuplés. Sortie : aucune. Dépendances : racine.
        function connaitre(): void { essai.connus = true }

        // dormir — avance l'horloge murale injectée de ms millisecondes (simule une suspension). Entrée : ms.
        function dormir(ms: int): void { essai.saut += ms }

        // stable — état stable appris par NotificationsReseau (« » tant qu'aucun n'est appris).
        // Sortie : texte. Erreurs : aucune. Dépendances : notifications.
        function stable(): string { return notifications.stable }

        // armee — vrai si le minuteur de stabilité est en cours. Sortie : « true » ou « false ». Dépendances : notifications.
        function armee(): string { return String(notifications.armee) }
    }
}
