import QtQuick
import QtQuick.Layouts
import "../Theme"
import "../Composants"

// PageFilaire — page de l'onglet Filaire de la fenêtre Réseau (direction D4, L2-65).
// Rôle : le titre « Filaire », puis « Ethernet » : la rangée de tête de l'appareil (médaillon, nom de l'interface et
// état du câble, « Connecté », « Câble débranché » ou « Aucune carte »), son adresse matérielle en Valeur copiable
// quand elle est connue et que le dépliant ne la porte pas, puis, pour la connexion filaire active, un DepliantReseau
// détaillé, ouvert à l'ouverture de la page, comme le réseau joint de la page Wi-Fi : débits et courbe, tuiles
// (Adresse IP, Routeur, DNS, Débit du lien, Adresse matérielle ; « Connecté depuis » seulement si la sonde la connaît),
// réglages Connexion automatique et Priorité, pied « Réglages avancés… » (sous-page) et « Oublier ce réseau ». Sans
// carte, ou câble débranché, il n'y a pas de dépliant et la page reste en l'état. Vient ensuite « Profils » (les autres
// profils filaires enregistrés, GroupeProfils, chacun ouvrant sa sous-page « ‹ Filaire » ; « Aucun profil filaire. »
// sans profil, et la section disparaît quand le seul profil est l'actif). Aucune logique nmcli n'est dupliquée ici.
// Clavier : les profils sont des Ligne cliquables (tabulation, Entrée, Espace, contour de focus : bible, « Clavier »).
// Entrées : panneau, le PanneauReseau (rangees, ouvrirProfil) ; etat, la source de l'état, EtatReseau par défaut
// (filaire, carteFilaire, appareilFilaire, appareil, et ce que lisent les tuiles).
// Sorties : actif, la rangée du profil filaire actif (null sans lui) ; nomAppareil, le nom de l'interface filaire, vide
// sans carte ; adresseMaterielle, l'adresse matérielle de l'appareil filaire, vide si elle est inconnue ; etatCable,
// l'état affiché ; ouvert, vrai si le dépliant est ouvert ; depliant, le DepliantReseau (null sans lui) ; montrer(uuid),
// qui déplie le profil actif demandé.
// Erreurs : celles du ProfilReseau, sous ses réglages ; aucune propre à la page.
// Dépendances : TitrePage, Section, Groupe, Ligne, Valeur, GroupeProfils, DepliantReseau, Texte, Theme, PanneauReseau,
// EtatReseau.
ColumnLayout {
    id: page

    required property var panneau
    property var etat: EtatReseau

    readonly property var actif: panneau.rangees.find(r => !r.wifi && r.actif) ?? null
    readonly property string nomAppareil: etat.appareilFilaire?.name ?? (etat.filaire ? etat.appareil : "")
    readonly property string adresseMaterielle: etat.appareilFilaire?.address ?? ""
    readonly property string etatCable: etat.filaire ? "Connecté" : etat.carteFilaire ? "Câble débranché" : "Aucune carte"
    // Le dépliant n'existe que pour une connexion filaire réellement active (câble branché).
    readonly property bool deplie: etat.filaire && actif !== null
    readonly property alias depliant: depliant
    property bool ouvert: true

    spacing: 0

    // montrer — déplie le dépliant du profil filaire actif demandé. Entrée : uuid, le profil. Sortie : vrai si c'est
    // le profil actif, que la page déplie ; faux sinon (l'appelant ouvre alors sa sous-page). Erreurs : aucune.
    // Dépendances : actif, deplie, ouvert.
    function montrer(uuid) {
        if (!deplie || actif.uuid !== uuid) return false
        ouvert = true
        return true
    }

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
            visible: page.adresseMaterielle !== "" && !page.deplie
            libelle: "Adresse matérielle"
            Valeur { text: page.adresseMaterielle }
        }
        DepliantReseau {
            id: depliant
            visible: page.deplie
            Layout.fillWidth: true
            detaille: true
            // Sans connexion active, le dépliant reste replié : rien n'est chargé ni lu.
            ouvert: page.ouvert && page.deplie
            portee: true
            etat: page.etat
            rangee: page.actif
            onBasculer: page.ouvert = !page.ouvert
            onAvances: uuid => page.panneau.ouvrirProfil(uuid)
        }
    }

    Section { visible: profils.profils.length > 0; text: "Profils" }
    GroupeProfils {
        id: profils
        panneau: page.panneau
        type: "Filaire"
        exclu: page.deplie ? page.actif.uuid : ""
        visible: profils.profils.length > 0
    }
    Texte {
        visible: page.panneau.rangees.every(r => r.groupe !== "Filaire")
        Layout.topMargin: Theme.space?.scale[2] ?? 0
        Layout.leftMargin: Theme.space?.scale[0] ?? 0
        text: "Aucun profil filaire."
        color: Theme.color?.textSecondary ?? "transparent"
    }
}
