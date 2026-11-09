import QtQuick
import QtQuick.Layouts
import "../Theme"
import "../Composants"

// ConnusWifi — section « Réseaux connus » de la page Wi-Fi, posée en fin de page (L2-65).
// Rôle : une section dépliable (Depliable, bible « Section dépliable ») « Réseaux connus », suivie de leur nombre en
// texte tertiaire, repliée par défaut ; dépliée, une carte où chaque réseau connu est un DepliantReseau non détaillé
// (ses seuls réglages et son pied, rien n'étant lu tant qu'il est replié), séparé du précédent par un filet. Un seul
// réseau connu est déplié à la fois. Un clic sur sa tête ne fait que le déplier ; « Rejoindre », au pied d'un réseau à
// portée, lance la connexion de son profil (ProfilReseau.connecter). Tant qu'un filtre est saisi, la section s'ouvre
// d'elle-même ; vidé, elle reprend l'état choisi par l'utilisateur. Le modèle est la liste des uuids, réaffectée
// seulement quand elle change : un balayage ne recrée ni ne relit le dépliant ouvert.
// Entrées : connus, les rangées de Nmcli.partager().connus (uuid, nom, portee, force) ; filtre, la saisie de la
// recherche ; panneau, le PanneauReseau (ouvrirProfil, factures) ; etat, la source de l'état et des actions,
// EtatReseau par défaut.
// Sorties : ouverts, vrai si l'utilisateur a ouvert la section ; connuOuvert, l'uuid du réseau déplié, vide sinon ;
// entete, l'en-tête de la Depliable, lu par les essais.
// Erreurs : celles de chaque ProfilReseau, sous ses réglages.
// Dépendances : Depliable, Groupe, DepliantReseau, Separateur, Texte, Theme (reglages, space, color), EtatReseau.
ColumnLayout {
    id: section

    required property var connus
    required property var panneau
    property string filtre
    property var etat: EtatReseau
    property bool ouverts: false
    property string connuOuvert: ""
    property var uuids: []
    readonly property bool montre: ouverts || filtre !== ""
    readonly property alias entete: pli.entete

    objectName: "connus"
    visible: connus.length > 0
    Layout.fillWidth: true
    spacing: 0

    // garder — réaffecte uuids si la liste des réseaux connus a changé. Entrées : aucune. Sortie : aucune.
    // Erreurs : aucune. Dépendances : connus, uuids.
    function garder() {
        const u = connus.map(r => r.uuid)
        if (u.join("\n") !== uuids.join("\n")) uuids = u
    }
    onConnusChanged: garder()
    Component.onCompleted: garder()

    Item {
        Layout.fillWidth: true
        Layout.topMargin: Theme.space?.scale[2] ?? 0
        implicitHeight: pli.implicitHeight
        Depliable {
            id: pli
            text: "Réseaux connus"
            ouvert: section.montre
            // Le clic de l'en-tête affecte ouvert : le choix de l'utilisateur est gardé, puis la liaison rétablie.
            onOuvertChanged: if (ouvert !== section.montre) {
                section.ouverts = ouvert
                ouvert = Qt.binding(() => section.montre)
            }
        }
        Texte {
            objectName: "compte"
            x: pli.entete.width
            y: (pli.entete.height - height) / 2
            text: section.connus.length
            color: Theme.color?.textTertiary ?? "transparent"
        }
    }
    Groupe {
        objectName: "groupeConnus"
        visible: section.montre
        Repeater {
            model: section.uuids

            ColumnLayout {
                id: connu
                required property string modelData
                required property int index
                Layout.fillWidth: true
                spacing: 0

                Separateur {
                    visible: connu.index > 0
                    Layout.fillWidth: true
                    retraitGauche: Theme.reglages?.textColumn ?? 0
                    retraitDroit: Theme.space?.scale[3] ?? 0
                }
                DepliantReseau {
                    rangee: section.connus.find(r => r.uuid === connu.modelData) ?? null
                    portee: rangee?.portee ?? false
                    ouvert: section.connuOuvert === connu.modelData
                    etat: section.etat
                    onBasculer: section.connuOuvert = ouvert ? "" : connu.modelData
                    onAvances: uuid => section.panneau.ouvrirProfil(uuid)
                    onRelu: (u, p) => section.panneau.factures = Object.assign({}, section.panneau.factures, {[u]: p.facture})
                }
            }
        }
    }
}
