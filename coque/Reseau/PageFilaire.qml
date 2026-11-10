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
// réglages Connexion automatique et Priorité, la section « Réglages avancés » (D155), le pied « Se déconnecter » et
// « Oublier ce réseau » ; les tuiles de la page se réduisent à Adresse IP, Routeur et Connecté depuis (D156). Sans
// carte, ou câble débranché, le dépliant est masqué et replié, rien n'y est chargé, et la page reste en l'état. Vient
// ensuite « Profils » (fiche, cas complémentaire 8) : les autres profils filaires enregistrés, comme les réseaux connus
// de la page Wi-Fi (GroupeProfils) : chacun un DepliantReseau non détaillé, un seul déplié à la fois, avec Connexion
// automatique, Priorité, « Réglages avancés » et le pied « Oublier ce réseau », et « Rejoindre » quand le câble est
// branché ; « Aucun profil filaire. » sans profil, et la section disparaît quand le seul profil est l'actif. Aucune
// logique nmcli n'est dupliquée ici.
// Clavier : les têtes des dépliants sont des Ligne cliquables (tabulation, Entrée, Espace, contour de focus : bible,
// « Clavier »).
// Entrées : panneau, le PanneauReseau (rangees, factures) ; etat, la source de l'état, EtatReseau par
// défaut (filaire, carteFilaire, appareilFilaire et son lien hasLink, appareil, et ce que lisent les tuiles).
// Sorties : actif, la rangée du profil filaire actif (null sans lui) ; nomAppareil, le nom de l'interface filaire, vide
// sans carte ; adresseMaterielle, l'adresse matérielle de l'appareil filaire, vide si elle est inconnue ; etatCable,
// l'état affiché ; ouvert, vrai si le dépliant est ouvert ; depliant, le DepliantReseau ; branchable, vrai si le câble
// est branché ; autres, les rangées de la section « Profils » ; profilOuvert, l'uuid du profil déplié dans « Profils »,
// vide sinon ; montrer(uuid), qui déplie le profil demandé.
// Erreurs : celles du ProfilReseau, sous ses réglages ; aucune propre à la page.
// Dépendances : TitrePage, Section, Groupe, Ligne, Valeur, GroupeProfils, DepliantReseau, Texte, Theme, PanneauReseau,
// EtatReseau (appareilFilaire.hasLink, de Quickshell.Networking).
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
    // Un profil inactif est branchable quand l'appareil filaire a un lien (câble branché) : son pied porte « Rejoindre ».
    readonly property bool branchable: etat.appareilFilaire?.hasLink ?? false
    // Les profils de la section « Profils » : tous les filaires, sauf celui du dépliant de tête.
    readonly property var autres: panneau.rangees.filter(r => r.groupe === "Filaire" && !(deplie && r.uuid === actif.uuid))
        .map(r => Object.assign({}, r, {portee: branchable}))
    property alias profilOuvert: profils.ouvert
    readonly property alias depliant: depliant
    property bool ouvert: true

    spacing: 0

    // montrer — déplie le dépliant du profil filaire demandé : celui de la connexion active, ou celui de la section
    // « Profils » (un seul déplié, D155 : il n'y a plus de sous-page de profil). Entrée : uuid, le profil. Sortie : vrai
    // si la page porte ce profil et l'a déplié ; faux sinon. Erreurs : aucune. Dépendances : actif, deplie, ouvert,
    // autres, profilOuvert.
    function montrer(uuid) {
        if (deplie && actif.uuid === uuid) ouvert = true
        else if (autres.some(r => r.uuid === uuid)) profilOuvert = uuid
        else return false
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
        }
    }

    Section { visible: page.autres.length > 0; text: "Profils" }
    GroupeProfils {
        id: profils
        objectName: "profils"
        visible: page.autres.length > 0
        profils: page.autres
        panneau: page.panneau
        etat: page.etat
    }
    Texte {
        visible: page.panneau.rangees.every(r => r.groupe !== "Filaire")
        Layout.topMargin: Theme.space?.scale[2] ?? 0
        Layout.leftMargin: Theme.space?.scale[0] ?? 0
        text: "Aucun profil filaire."
        color: Theme.color?.textSecondary ?? "transparent"
    }
}
