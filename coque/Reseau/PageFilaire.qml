import QtQuick
import QtQuick.Layouts
import "../Theme"
import "../Composants"

// PageFilaire — page de l'onglet Filaire de la fenêtre Réseau (direction D4).
// Rôle : le titre « Filaire », puis trois cartes : « Ethernet » (la rangée de tête de l'appareil : médaillon, nom de
// l'interface et état du câble, « Connecté », « Câble débranché » ou « Aucune carte » ; puis son adresse
// matérielle en Valeur copiable, quand elle est connue), « Profils » (les profils filaires enregistrés, GroupeProfils,
// chacun ouvrant sa sous-page « ‹ Filaire » ; « Aucun profil filaire. » sans profil) et, pour le profil filaire actif,
// « Adresses » en lecture seule et copiables (CarteAdresses, seulement si l'appareil du profil est celui qu'EtatReseau
// lit). Aucune logique nmcli ici : les réglages d'un profil sont dans sa sous-page (FicheProfil).
// Clavier : les profils sont des Ligne cliquables (tabulation, Entrée, Espace, contour de focus : bible, « Clavier »).
// Entrées : panneau, le PanneauReseau (rangees, ouvrirProfil) ; etat, la source de l'état, EtatReseau par défaut
// (filaire, carteFilaire, appareilFilaire, appareil).
// Sorties : actif, la rangée du profil filaire actif (null sans lui) ; nomAppareil, le nom de l'interface filaire,
// vide sans carte ; adresseMaterielle, l'adresse matérielle de l'appareil filaire, vide si elle est inconnue ;
// etatCable, l'état affiché. Erreurs : aucune. Dépendances : TitrePage, Section, Groupe, Ligne, Valeur, GroupeProfils,
// CarteAdresses, Texte, Theme, PanneauReseau, EtatReseau.
ColumnLayout {
    id: page

    required property var panneau
    property var etat: EtatReseau

    readonly property var actif: panneau.rangees.find(r => !r.wifi && r.actif) ?? null
    readonly property string nomAppareil: etat.appareilFilaire?.name ?? (etat.filaire ? etat.appareil : "")
    readonly property string adresseMaterielle: etat.appareilFilaire?.address ?? ""
    readonly property string etatCable: etat.filaire ? "Connecté" : etat.carteFilaire ? "Câble débranché" : "Aucune carte"

    spacing: 0

    TitrePage { text: "Filaire" }

    Section { text: "Ethernet" }
    Groupe {
        objectName: "ethernet"
        Ligne {
            objectName: "appareil"
            filet: false
            hauteur: Theme.reglages?.rowLead ?? 0
            icone: page.etat.filaire ? "network-wired" : "network-wired-disconnected"
            iconeActive: page.etat.filaire
            libelle: page.nomAppareil !== "" ? `Ethernet (${page.nomAppareil})` : "Ethernet"
            aide: page.etatCable
        }
        Ligne {
            objectName: "materiel"
            visible: page.adresseMaterielle !== ""
            libelle: "Adresse matérielle"
            Valeur { text: page.adresseMaterielle }
        }
    }

    Section { visible: profils.profils.length > 0; text: "Profils" }
    GroupeProfils { id: profils; panneau: page.panneau; type: "Filaire"; visible: profils.profils.length > 0 }
    Texte {
        visible: profils.profils.length === 0
        Layout.topMargin: Theme.space?.scale[2] ?? 0
        Layout.leftMargin: Theme.space?.scale[0] ?? 0
        text: "Aucun profil filaire."
        color: Theme.color?.textSecondary ?? "transparent"
    }

    CarteAdresses { etat: page.etat; rangee: page.actif }
}
