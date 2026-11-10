import QtQuick
import QtQuick.Layouts
import "../Theme"
import "../Composants"

// GroupeProfils — carte de profils enregistrés, chacun en DepliantReseau non détaillé, un seul déplié à la fois (L2-65).
// Rôle : une carte où chaque profil est un DepliantReseau replié (ses seuls réglages et son pied, rien n'étant lu
// tant qu'il est replié), séparé du précédent par un filet. Un clic sur une tête ne fait que la déplier et replie
// l'autre ; « Rejoindre », au pied d'un profil à portée, lance sa connexion (ProfilReseau.connecter) ; ses
// « Réglages avancés » se déplient dans son dépliant (D155). Le modèle est la liste des uuids, réaffectée seulement quand elle change : une
// relecture des profils ou un balayage ne recrée ni ne relit le dépliant ouvert. Employée par ConnusWifi (réseaux
// connus de la page Wi-Fi) et par PageFilaire (section « Profils »).
// Entrées : profils, les rangées à montrer (uuid, nom, icone, actif, wifi, appareil, portee ; force et security pour
// un réseau Wi-Fi à portée) ; panneau, le PanneauReseau (factures) ; etat, la source de l'état et des
// actions, EtatReseau par défaut ; ouvert, l'uuid du profil déplié, vide sinon (écrit par le clic sur une tête). Les
// rangées s'appellent profils : le nom rangees est celui des enfants de Carte.
// Sorties : ouvert ; uuids, les uuids montrés, dans l'ordre.
// Erreurs : celles de chaque ProfilReseau, sous ses réglages ; une carte sans rangée est vide.
// Dépendances : Groupe, DepliantReseau, Separateur, Theme (reglages, space), PanneauReseau, EtatReseau.
Groupe {
    id: racine

    required property var profils
    required property var panneau
    property var etat: EtatReseau
    property string ouvert: ""
    property var uuids: []

    // garder — réaffecte uuids si la liste des profils a changé. Entrées : aucune. Sortie : aucune.
    // Erreurs : aucune. Dépendances : profils, uuids.
    function garder() {
        const u = profils.map(r => r.uuid)
        if (u.join("\n") !== uuids.join("\n")) uuids = u
    }
    onProfilsChanged: garder()
    Component.onCompleted: garder()

    Repeater {
        model: racine.uuids

        ColumnLayout {
            id: profil
            required property string modelData
            required property int index
            Layout.fillWidth: true
            spacing: 0

            Separateur {
                visible: profil.index > 0
                Layout.fillWidth: true
                retraitGauche: Theme.reglages?.textColumn ?? 0
                retraitDroit: Theme.space?.scale[3] ?? 0
            }
            DepliantReseau {
                rangee: racine.profils.find(r => r.uuid === profil.modelData) ?? null
                portee: rangee?.portee ?? false
                ouvert: racine.ouvert === profil.modelData
                etat: racine.etat
                onBasculer: racine.ouvert = ouvert ? "" : profil.modelData
                onRelu: (u, p) => racine.panneau.factures = Object.assign({}, racine.panneau.factures, {[u]: p.facture})
            }
        }
    }
}
