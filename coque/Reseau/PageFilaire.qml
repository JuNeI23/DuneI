import QtQuick
import QtQuick.Layouts
import "../Theme"
import "../Composants"
import "../Parametres"
import "nmcli.js" as Nmcli

// PageFilaire — page Filaire de l'application Paramètres (fiche du 14 novembre 2026, section 7).
// Rôle : reprend le contenu de la page Filaire de l'ancienne fenêtre, dans la disposition de l'application. De haut en
// bas : la carte d'en-tête (EnTetePage : vignette, « Filaire », puis l'appareil et l'état du câble, « Connecté »,
// « Câble débranché » ou « Aucune carte ») ; « Ethernet » : l'adresse matérielle en Valeur copiable quand elle est
// connue et que le dépliant ne la porte pas, puis, pour la connexion filaire active, un DepliantReseau détaillé,
// ouvert à l'ouverture de la page, comme le réseau joint de la page Wi-Fi (débits et courbe, tuiles, réglages
// Connexion automatique et Priorité, « Réglages avancés », pied « Se déconnecter » et « Oublier ce réseau ») ;
// « Profils » : les autres profils filaires enregistrés (GroupeProfils : un DepliantReseau non détaillé chacun, un
// seul déplié à la fois, « Rejoindre » quand le câble est branché). Sans carte, ou câble débranché, le dépliant est
// masqué et replié, et rien n'y est chargé ; sans carte ni adresse, la section « Ethernet » disparaît. Sans profil,
// « Aucun profil filaire. » ; la section « Profils » disparaît quand le seul profil est l'actif. Aucune logique nmcli
// n'est dupliquée ici.
// Clavier : les têtes des dépliants sont des Ligne cliquables (tabulation, Entrée, Espace : bible, « Clavier ») ;
// atteintes au clavier, elles portent la plaque du curseur (L2-73).
// Contrat de page (voir ConteneurPage) : conteneur, atteindre, implicitHeight.
// Entrées : conteneur, le ConteneurPage, posé par lui ; etat, la source de l'état, EtatReseau par défaut (profils,
// filaire, carteFilaire, appareilFilaire et son lien hasLink, appareil, et ce que lisent les tuiles).
// Sorties : rangees, les rangées des profils filaires (Nmcli.profilsFenetre) ; factures, uuid → facturation lue des
// profils dépliés, que GroupeProfils complète ; actif, la rangée du profil filaire actif (null sans lui) ;
// nomAppareil, le nom de l'interface filaire, vide sans carte ; libelleAppareil, « Ethernet » suivi de l'interface ;
// adresseMaterielle, l'adresse matérielle de l'appareil filaire, vide si elle est inconnue ; etatCable, l'état
// affiché ; deplie, vrai si le dépliant de la connexion active existe ; ouvert, vrai s'il est ouvert ; depliant, le
// DepliantReseau ; branchable, vrai si le câble est branché ; autres, les rangées de la section « Profils » ;
// profilOuvert, l'uuid du profil déplié dans « Profils », vide sinon ; enTete, l'EnTetePage.
// Fonctions : atteindre, montrer.
// Erreurs : celles du ProfilReseau, sous ses réglages ; aucune propre à la page.
// Dépendances : EnTetePage, TitreSection, Registre, ConteneurPage (Parametres) ; Groupe, Ligne, Valeur, GroupeProfils,
// DepliantReseau, Texte, Theme, nmcli.js (profilsFenetre), EtatReseau (appareilFilaire.hasLink, de
// Quickshell.Networking).
Item {
    id: page

    property var conteneur: null
    property var etat: EtatReseau
    property var factures: ({})
    property bool ouvert: true

    readonly property var inscription: Registre.page("filaire")
    readonly property var rangees: Nmcli.profilsFenetre(etat.profils ?? [], [], factures, false).filter(r => !r.wifi)
    readonly property var actif: rangees.find(r => r.actif) ?? null
    readonly property string nomAppareil: etat.appareilFilaire?.name ?? (etat.filaire ? etat.appareil : "")
    readonly property string libelleAppareil: nomAppareil !== "" ? `Ethernet (${nomAppareil})` : "Ethernet"
    readonly property string adresseMaterielle: etat.appareilFilaire?.address ?? ""
    readonly property string etatCable: etat.filaire ? "Connecté" : etat.carteFilaire ? "Câble débranché" : "Aucune carte"
    // Le dépliant n'existe que pour une connexion filaire réellement active (câble branché).
    readonly property bool deplie: !!etat.filaire && actif !== null
    // Un profil inactif est branchable quand l'appareil filaire a un lien (câble branché) : son pied porte « Rejoindre ».
    readonly property bool branchable: etat.appareilFilaire?.hasLink ?? false
    // Les profils de la section « Profils » : tous les filaires, sauf celui du dépliant de tête.
    readonly property var autres: rangees.filter(r => !(deplie && r.uuid === actif.uuid))
        .map(r => Object.assign({}, r, {portee: branchable}))
    property alias profilOuvert: profils.ouvert
    readonly property alias depliant: depliant
    readonly property alias enTete: enTete

    implicitHeight: colonne.implicitHeight

    // atteindre — conduit à un réglage de la page : la carte « Ethernet », la section « Profils », ou l'en-tête pour
    // toute autre ancre. Entrée : chemin, ancre au format de recherche.js (la page, puis « ethernet » ou « profils »).
    // Sortie : aucune. Erreurs : aucune ; une section masquée renvoie à l'en-tête. Dépendances : conteneur (montrer).
    function atteindre(chemin) {
        const cible = chemin[1] === "ethernet" ? ethernet : chemin[1] === "profils" ? profils : null
        conteneur.montrer(cible?.visible ? cible : enTete)
    }

    // montrer — déplie le dépliant du profil filaire demandé : celui de la connexion active, ou celui de la section
    // « Profils » (un seul déplié, D155). Entrée : uuid, le profil. Sortie : vrai si la page porte ce profil et l'a
    // déplié ; faux sinon. Erreurs : aucune. Dépendances : actif, deplie, ouvert, autres, profilOuvert.
    function montrer(uuid) {
        if (deplie && actif.uuid === uuid) ouvert = true
        else if (autres.some(r => r.uuid === uuid)) profilOuvert = uuid
        else return false
        return true
    }

    Column {
        id: colonne
        width: parent.width

        EnTetePage {
            id: enTete
            objectName: "enTete"
            width: parent.width
            glyphe: page.inscription?.glyphe ?? ""
            teinte: page.inscription?.teinte ?? 0
            titre: page.inscription?.libelle ?? ""
            etat: page.libelleAppareil + " · " + page.etatCable
        }

        TitreSection { visible: ethernet.visible; text: "Ethernet" }
        Groupe {
            id: ethernet
            objectName: "ethernet"
            width: parent.width
            garde: 0
            visible: materiel.visible || page.deplie
            Ligne {
                id: materiel
                objectName: "materiel"
                filet: false
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

        TitreSection { visible: profils.visible; text: "Profils" }
        GroupeProfils {
            id: profils
            objectName: "profils"
            width: parent.width
            visible: page.autres.length > 0
            profils: page.autres
            panneau: page
            etat: page.etat
        }
        Texte {
            visible: page.rangees.length === 0
            leftPadding: Theme.space?.scale[0] ?? 0
            topPadding: Theme.space?.scale[2] ?? 0
            text: "Aucun profil filaire."
            color: Theme.color?.textSecondary ?? "transparent"
        }
    }
}
