import QtQuick
import QtQuick.Layouts
import "../Theme"
import "../Composants"

// ConnusWifi — section « Réseaux connus » de la page Wi-Fi, posée en fin de page (L2-65).
// Rôle : une section dépliable (Depliable, bible « Section dépliable ») « Réseaux connus », suivie de leur nombre en
// texte tertiaire, repliée par défaut ; dépliée, la carte des réseaux connus (GroupeProfils : chacun un
// DepliantReseau non détaillé, un seul déplié à la fois, un clic sur sa tête ne faisant que le déplier, « Rejoindre »
// au pied d'un réseau à portée). Tant qu'un filtre est saisi, la section s'ouvre d'elle-même ; vidé, elle reprend
// l'état choisi par l'utilisateur.
// Entrées : connus, les rangées de Nmcli.partager().connus (uuid, nom, portee, force, security) ; filtre, la saisie de la
// recherche ; panneau, le PanneauReseau (ouvrirProfil, factures) ; etat, la source de l'état et des actions,
// EtatReseau par défaut.
// Sorties : ouverts, vrai si l'utilisateur a ouvert la section ; connuOuvert, l'uuid du réseau déplié, vide sinon ;
// entete, l'en-tête de la Depliable, lu par les essais.
// Erreurs : celles de chaque ProfilReseau, sous ses réglages.
// Dépendances : Depliable, GroupeProfils, Texte, Theme (space, color), EtatReseau.
ColumnLayout {
    id: section

    required property var connus
    required property var panneau
    property string filtre
    property var etat: EtatReseau
    property bool ouverts: false
    property alias connuOuvert: groupe.ouvert
    readonly property bool montre: ouverts || filtre !== ""
    readonly property alias entete: pli.entete

    objectName: "connus"
    visible: connus.length > 0
    Layout.fillWidth: true
    spacing: 0

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
    GroupeProfils {
        id: groupe
        objectName: "groupeConnus"
        visible: section.montre
        profils: section.connus
        panneau: section.panneau
        etat: section.etat
    }
}
