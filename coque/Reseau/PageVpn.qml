import QtQuick
import QtQuick.Layouts
import "../Theme"
import "../Composants"
import "nmcli.js" as Nmcli

// PageVpn — page de l'onglet VPN de la fenêtre Réseau (version minimale).
// Rôle : le titre « VPN », puis la carte « Connexions » : une Ligne par profil de type vpn ou wireguard (médaillon
// network-vpn, à l'accent quand la connexion est active ; nom ; type en aide, « WireGuard » ou « VPN ») et, à droite,
// un Interrupteur qui monte ou descend la connexion. L'interrupteur suit l'état réel lu par EtatReseau : après chaque
// action, la liaison est rétablie, si bien qu'un refus le remet à sa place et que l'erreur de nmcli paraît sous la
// rangée, à la couleur d'erreur. Sans profil : « Aucune connexion VPN. » et une ligne d'aide qui annonce que l'ajout
// d'une connexion viendra plus tard (import, identifiants et sous-page : backlog L2-51).
// Commandes : « nmcli -w 30 connection up uuid <uuid> » et « nmcli -w 10 connection down uuid <uuid> ». Ni --ask ni
// agent de secrets : une connexion qui réclame un mot de passe échoue aussitôt (« Secrets were required, but not
// provided ») au lieu d'attendre un terminal, et -w borne l'attente ; aucun secret n'est lu, écrit ni journalisé.
// Clavier : chaque interrupteur s'atteint à la tabulation et bascule à Espace, avec le contour de focus de la bible
// (« Clavier » et « Interrupteur »).
// Entrées : panneau, le PanneauReseau ; etat, la source de l'état, EtatReseau par défaut (profils, executer).
// Sorties : connexions, les VPN lus (nmcli.js, vpns) ; enCours, les actions non terminées (uuid → état voulu) ;
// erreurs, objet uuid → message de nmcli pour les refus affichés.
// Erreurs : un échec de nmcli se montre sous la rangée et remet l'interrupteur à l'état réel.
// Dépendances : TitrePage, Section, Groupe, Ligne, Interrupteur, Texte, Theme, nmcli.js, EtatReseau.
ColumnLayout {
    id: page

    required property var panneau
    property var etat: EtatReseau

    readonly property var connexions: Nmcli.vpns(etat.profils)
    // Les uuid des connexions, remplacés seulement quand la liste change : les rangées (et le focus du clavier)
    // survivent aux relectures de l'état, qui renouvellent le tableau des profils à chaque fois.
    property var uuids: []
    property var erreurs: ({})
    // Les actions en cours : uuid → état voulu. Pendant ce temps l'interrupteur de la rangée est inactif et montre
    // l'état voulu.
    property var enCours: ({})
    onConnexionsChanged: {
        const u = connexions.map(c => c.uuid)
        if (JSON.stringify(u) !== JSON.stringify(uuids)) uuids = u
    }
    Component.onCompleted: uuids = connexions.map(c => c.uuid)
    // Garde des réponses de nmcli : marquée morte à la destruction, pour qu'un retour tardif après la fermeture de la
    // fenêtre n'écrive plus rien.
    property var garde: ({mort: false})
    Component.onDestruction: garde.mort = true

    spacing: 0

    // basculer — monte ou descend une connexion VPN. Entrées : uuid, celui de la connexion ; voulu, vrai pour la
    // monter. Sortie : aucune ; enCours[uuid] vaut voulu jusqu'à la fin de nmcli (une seconde demande pour la même
    // connexion est ignorée), puis l'interrupteur suit l'état réel ; erreurs[uuid] reçoit le message de nmcli en cas
    // de refus (« La connexion a échoué. » si nmcli n'en donne aucun) et est effacé sinon.
    // Erreurs : un code non nul garde le message ; une réponse arrivée après la destruction de la page est ignorée
    // (garde). Dépendances : etat.executer.
    function basculer(uuid, voulu) {
        if (uuid in enCours) return
        const e = Object.assign({}, erreurs); delete e[uuid]; erreurs = e
        enCours = Object.assign({}, enCours, {[uuid]: voulu})
        const g = garde
        etat.executer(voulu ? ["-w", "30", "connection", "up", "uuid", uuid] : ["-w", "10", "connection", "down", "uuid", uuid],
            (code, sortie) => {
                if (g.mort) return
                if (code !== 0) erreurs = Object.assign({}, erreurs, {[uuid]: sortie.trim() || "La connexion a échoué."})
                const r = Object.assign({}, enCours); delete r[uuid]; enCours = r
            })
    }

    TitrePage { text: "VPN" }

    Section { visible: page.connexions.length > 0; text: "Connexions" }
    Groupe {
        visible: page.connexions.length > 0
        Repeater {
            model: page.uuids
            delegate: Ligne {
                required property string modelData
                required property int index
                readonly property var c: page.connexions.find(x => x.uuid === modelData) ?? ({nom: "", type: "", actif: false})
                objectName: "vpn"
                filet: index > 0
                icone: "network-vpn"
                iconeActive: c.actif
                libelle: c.nom
                aide: c.type
                erreur: page.erreurs[modelData] ?? ""
                Interrupteur {
                    objectName: "interrupteur"
                    enabled: !(modelData in page.enCours)
                    checked: page.enCours[modelData] ?? c.actif
                    onToggled: { page.basculer(modelData, checked); checked = Qt.binding(() => page.enCours[modelData] ?? c.actif) }
                }
            }
        }
    }
    Texte {
        visible: page.connexions.length === 0
        Layout.topMargin: Theme.space?.scale[2] ?? 0
        Layout.leftMargin: Theme.space?.scale[0] ?? 0
        text: "Aucune connexion VPN."
        color: Theme.color?.textSecondary ?? "transparent"
    }
    Texte {
        visible: page.connexions.length === 0
        Layout.leftMargin: Theme.space?.scale[0] ?? 0
        text: "L'ajout d'une connexion VPN viendra plus tard."
        echelon: 0
        color: Theme.color?.textSecondary ?? "transparent"
    }
}
