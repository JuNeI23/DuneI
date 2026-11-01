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
// lit), précédées de la méthode IPv4 du profil (« Automatique » ou « Fixe »), lue une fois par « nmcli -g
// ipv4.method » au changement de profil actif et au retour de la sous-page de l'onglet. Aucun réglage ici : ils sont
// dans la sous-page (FicheProfil).
// Clavier : les profils sont des Ligne cliquables (tabulation, Entrée, Espace, contour de focus : bible, « Clavier »).
// Entrées : panneau, le PanneauReseau (rangees, ouvrirProfil) ; etat, la source de l'état, EtatReseau par défaut
// (filaire, carteFilaire, appareilFilaire, appareil).
// Sorties : actif, la rangée du profil filaire actif (null sans lui) ; nomAppareil, le nom de l'interface filaire,
// vide sans carte ; adresseMaterielle, l'adresse matérielle de l'appareil filaire, vide si elle est inconnue ;
// etatCable, l'état affiché ; methode, la méthode IPv4 lue du profil actif (vide avant la lecture). Erreurs : un échec
// de la lecture laisse la méthode vide, la rangée est alors omise (EtatReseau.executer). Dépendances : TitrePage, Section, Groupe, Ligne, Valeur, GroupeProfils,
// CarteAdresses, Texte, Theme, PanneauReseau, EtatReseau.
ColumnLayout {
    id: page

    required property var panneau
    property var etat: EtatReseau

    readonly property var actif: panneau.rangees.find(r => !r.wifi && r.actif) ?? null
    readonly property string nomAppareil: etat.appareilFilaire?.name ?? (etat.filaire ? etat.appareil : "")
    readonly property string adresseMaterielle: etat.appareilFilaire?.address ?? ""
    readonly property string etatCable: etat.filaire ? "Connecté" : etat.carteFilaire ? "Câble débranché" : "Aucune carte"

    readonly property string uuidActif: actif?.uuid ?? ""
    property string methode: ""

    spacing: 0

    // lireMethode — lit la méthode IPv4 du profil filaire actif. Entrées : aucune. Sortie : aucune ; methode mise à
    // jour (une réponse tardive pour un autre profil est ignorée). Erreurs : un code non nul vide la méthode.
    // Dépendances : etat.executer.
    function lireMethode() {
        const u = uuidActif
        if (u === "") return void (methode = "")
        etat.executer(["-g", "ipv4.method", "connection", "show", u], (code, sortie) => {
            if (uuidActif !== u) return
            const m = sortie.trim()
            methode = code !== 0 ? "" : m === "manual" ? "Fixe" : m === "auto" ? "Automatique" : ""
        })
    }
    // Relue au changement de profil actif (l'uuid, une chaîne : les relectures de la liste ne la relancent pas) et à
    // la fermeture d'une sous-page de l'onglet Filaire, où la méthode a pu changer ; jamais à un simple changement
    // d'onglet : la page reste vivante et garde sa dernière valeur, relue en place sans retarder son affichage.
    onUuidActifChanged: { methode = ""; lireMethode() }
    Connections {
        target: page.panneau
        function onSousPageChanged() { if (page.panneau.sousPage === "" && page.panneau.onglet === "filaire") page.lireMethode() }
    }
    Component.onCompleted: lireMethode()

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

    CarteAdresses { etat: page.etat; rangee: page.actif; methode: page.methode }
}
