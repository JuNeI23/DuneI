import QtQuick
import Quickshell
import "../Theme"

// NotificationsReseau — notifications de connexion établie, perdue, sans internet ou à valider.
// Rôle : suit l'état du réseau de EtatReseau, en déduit un état parmi « etablie », « sans-internet » (connectivité
// limitée), « portail » (portail captif) et « perdue », et n'en notifie le changement qu'après motion.delays.stable
// de stabilité. Le minuteur est à un coup et n'est armé que sur une transition : aucun au repos (D80). Le premier
// état appris, au démarrage de la coque, ne produit aucune notification ; une coupure plus courte que le délai, ou
// une connectivité encore « unknown » (reprise après veille), ne produit rien. L'apprentissage silencieux ne commence
// qu'au premier état réel : appareils connus de Networking et connectivité différente de « unknown ». La veille est
// annoncée par NetworkManager (EtatReseau.veille) : à son entrée l'état appris est oublié et le minuteur arrêté ;
// au réveil l'état est réappris en silence, comme au démarrage, et une coupure ou une reconnexion lente qui suit
// ne produit rien : tant que l'état n'est pas redevenu connecté, « perdue » n'est pas appris. Jamais de
// bascule automatique.
// Entrées (réglables) : connecte, connectivite et nom, par défaut ceux de EtatReseau (remplaçables par un test) ;
// connus, vrai quand Networking a peuplé ses appareils ; veille, vrai pendant la veille de la machine ; commande, fonction(icone, titre, corps) qui rend le tableau d'arguments à lancer (notify-send par défaut, avec
// l'étiquette de pile « reseau », par laquelle le serveur de la coque remplace la notification précédente).
// Sorties (lecture seule) : stable, dernier état notifié ou appris (vide avant le premier) ; armee, vrai tant que
// le minuteur de stabilité court.
// Erreurs : une connectivité « unknown » permanente (contrôle de connectivité désactivé) ne notifie rien, pas même
// une perte de connexion ; sans notify-send, la notification est perdue sans autre effet ; sans mouvement chargé (tokens absents),
// aucun minuteur n'est armé et rien n'est notifié.
// Dépendances : EtatReseau, Theme.motion.delays.stable (par Reseau/Theme), Quickshell.execDetached.
Scope {
    id: notifications

    property bool connecte: EtatReseau.connecte
    property string connectivite: EtatReseau.connectivite
    property string nom: EtatReseau.nomActif
    property bool connus: EtatReseau.appareils.length > 0
    property bool veille: EtatReseau.veille
    property var commande: (icone, titre, corps) => ["notify-send", "-a", "DuneI", "-i", icone,
        "-h", "string:x-dunst-stack-tag:reseau", titre, corps]

    property string stable: ""
    readonly property bool armee: minuteur.running

    // Dernier nom de réseau vu connecté, pour dire quelle connexion vient d'être perdue.
    property string dernierNom: ""
    onNomChanged: if (connecte && nom) dernierNom = nom

    // Délai de stabilité en millisecondes (0 tant que le mouvement n'est pas chargé).
    readonly property int delai: Theme.motion?.delays?.stable ?? 0

    // etat est l'état déduit des entrées ; vide tant que la connectivité d'un réseau joint est inconnue.
    readonly property string etat: !connecte ? "perdue"
        : connectivite === "full" ? "etablie"
        : connectivite === "portal" ? "portail"
        : connectivite === "unknown" ? "" : "sans-internet"

    // Vrai du réveil jusqu'au premier état connecté réappris : « perdue » n'est alors pas appris.
    property bool apresVeille: false
    onVeilleChanged: {
        if (veille) { stable = ""; apresVeille = true }
        armer()
    }
    onStableChanged: if (stable !== "") apresVeille = false

    // armer — arme ou désarme le minuteur de stabilité selon l'état déduit.
    // Rôle : un état déjà stable, inconnu ou en veille désarme ; tant que rien n'est appris, l'apprentissage attend
    // aussi un premier état réel (appareils connus, connectivité connue, et non « perdue » au réveil) ; tout autre
    // état relance le délai.
    // Entrées : aucune. Sortie : aucune. Erreurs : aucune. Dépendances : etat, stable, veille, apresVeille, connus,
    // connectivite, delai, minuteur.
    function armer() {
        const apprenable = connus && connectivite !== "unknown" && !(apresVeille && etat === "perdue")
        if (veille || etat === "" || etat === stable || delai <= 0 || (stable === "" && !apprenable)) minuteur.stop()
        else minuteur.restart()
    }
    onEtatChanged: armer()
    onDelaiChanged: armer()
    onConnusChanged: armer()
    onConnectiviteChanged: armer()

    // notifier — émet la notification d'un état stable.
    // Entrée : etat, l'un des quatre états. Sortie : aucune. Erreurs : sans notify-send, perdue sans effet.
    // Dépendances : commande, nom, dernierNom, EtatReseau.icone, Quickshell.execDetached.
    function notifier(etat) {
        const n = etat === "perdue" ? dernierNom : nom
        const t = {
            etablie: ["Connexion établie", n, EtatReseau.icone],
            "sans-internet": ["Connecté sans internet", n + " ne donne pas accès à internet", "network-wireless-no-route"],
            portail: ["Connexion à valider", n + " demande de passer par sa page d'accueil", "network-wireless-no-route"],
            perdue: ["Connexion perdue", n, "network-wireless-offline"],
        }[etat]
        Quickshell.execDetached(commande(t[2], t[0], t[1]))
    }

    // Minuteur à un coup : à son terme l'état déduit est resté le même, il devient l'état stable ; le premier
    // état appris (stable vide) l'est sans notification.
    Timer {
        id: minuteur
        interval: notifications.delai
        onTriggered: {
            const premier = notifications.stable === ""
            notifications.stable = notifications.etat
            if (!premier) notifications.notifier(notifications.etat)
        }
    }

    Component.onCompleted: armer()
}
