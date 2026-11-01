import QtQuick
import QtQuick.Layouts
import "../Theme"
import "../Composants"

// CarteAdresses — section « Adresses » : les adresses de l'appareil lu par EtatReseau, en lecture seule et copiables.
// Rôle : partagée par PageWifi (réseau joint) et PageFilaire (profil filaire actif) : le titre, puis une carte (D4)
// d'une rangée par champ non vide, chaque valeur d'un champ multiple (IPv4, DNS, IPv6) sur sa propre ligne, calée à
// droite, tronquée au milieu si elle dépasse la largeur libre, et la rangée grandit avec elles (Valeur : un clic la copie), précédée de la méthode IPv4 quand on la donne. Les
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
                {titre: "Configuration IPv4", valeurs: [racine.methode], copiable: false},
                {titre: "Adresse IPv4", valeurs: racine.etat.ip4, copiable: true},
                {titre: "Passerelle", valeurs: [racine.etat.passerelle], copiable: true},
                {titre: "DNS", valeurs: racine.etat.dns, copiable: true},
                {titre: "IPv6", valeurs: racine.etat.ip6, copiable: true},
            ].map(a => Object.assign(a, {valeurs: a.valeurs.filter(v => v !== "")})).filter(a => a.valeurs.length > 0)

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
                    id: reglage
                    readonly property var champ: modelData
                    titre: champ.titre
                    // Chaque valeur d'un champ multiple (plusieurs IPv6, plusieurs DNS) a sa ligne, calée à droite,
                    // tronquée au milieu en dernier recours ; la rangée grandit avec elles.
                    Texte { visible: !reglage.champ.copiable; text: reglage.champ.valeurs[0]; color: Theme.color?.textSecondary ?? "transparent" }
                    ColumnLayout {
                        visible: reglage.champ.copiable
                        spacing: Theme.space?.scale[0] ?? 0
                        Repeater {
                            model: reglage.champ.valeurs
                            Valeur {
                                required property string modelData
                                objectName: "valeur:" + reglage.champ.titre
                                Layout.alignment: Qt.AlignRight
                                text: modelData
                                largeurMax: reglage.largeurLibre
                                couleur: Theme.color?.textSecondary ?? "transparent"
                            }
                        }
                    }
                }
            }
        }
    }
}
