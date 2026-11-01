import QtQuick
import QtQuick.Layouts
import "../Theme"
import "../Composants"

// CarteAdresses — section « Adresses » : les adresses de l'appareil lu par EtatReseau, en lecture seule et copiables.
// Rôle : partagée par PageWifi (réseau joint) et PageFilaire (profil filaire actif) : le titre, puis une carte (D4)
// d'une rangée par valeur non vide (Valeur : un clic la copie), précédée de la méthode IPv4 quand on la donne. Les
// adresses d'EtatReseau sont celles de etat.appareil (le filaire s'il est actif aussi) : la section n'est montrée que
// si l'appareil du profil donné est celui qu'EtatReseau lit, comme le détail de FicheProfil.
// Entrées : etat, la source de l'état, EtatReseau par défaut ; rangee, la rangée du profil actif concerné
// (nmcli.profilsFenetre : appareil), null sans profil ; methode, « Automatique », « Fixe » ou vide si elle n'est pas
// lue encore.
// Sorties : lues, vrai si la section est montrée ; la Carte porte l'objectName « adresses ». Erreurs : aucune.
// Dépendances : Section, Carte, ReglageLigne, Valeur, Separateur, Texte, Theme (reglages, space, color).
ColumnLayout {
    id: racine

    property var etat: EtatReseau
    property var rangee: null
    property string methode: ""
    readonly property bool lues: rangee !== null && rangee.appareil !== "" && rangee.appareil === etat.appareil

    visible: lues
    Layout.fillWidth: true
    spacing: 0

    Section { text: "Adresses" }
    Carte {
        objectName: "adresses"
        Layout.fillWidth: true
        Repeater {
            model: [
                {titre: "Configuration IPv4", valeur: racine.methode, copiable: false},
                {titre: "Adresse IPv4", valeur: racine.etat.ip4.join(", "), copiable: true},
                {titre: "Passerelle", valeur: racine.etat.passerelle, copiable: true},
                {titre: "DNS", valeur: racine.etat.dns.join(", "), copiable: true},
                {titre: "IPv6", valeur: racine.etat.ip6.join(", "), copiable: true},
            ].filter(a => a.valeur !== "")

            ColumnLayout {
                required property var modelData
                required property int index
                Layout.fillWidth: true
                spacing: 0
                Separateur {
                    visible: index > 0
                    Layout.fillWidth: true
                    retraitGauche: Theme.reglages?.textColumn ?? 0
                    retraitDroit: Theme.space?.scale[3] ?? 0
                }
                ReglageLigne {
                    titre: modelData.titre
                    Valeur { objectName: "valeur:" + modelData.titre; visible: modelData.copiable; text: modelData.valeur }
                    Texte { visible: !modelData.copiable; text: modelData.valeur; color: Theme.color?.textSecondary ?? "transparent" }
                }
            }
        }
    }
}
