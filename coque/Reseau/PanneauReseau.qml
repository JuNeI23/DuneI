import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "../Theme"
import "../Composants"
import "nmcli.js" as Nmcli
import "../Barre/icones.js" as Icones

// PanneauReseau — panneau Réseau : une barre latérale à trois onglets (Wi-Fi, Filaire, VPN) et une pile de pages à
// droite, page d'onglet puis sous-page d'un profil (L2-11, direction D4).
// Rôle : un Item sans fenêtre, que FenetreReseau pose dans sa FloatingWindow et que l'écran de réglages (L5-01)
// reprendra tel quel comme premier panneau. À gauche, une colonne surfacePanel pleine hauteur, collée au bord, large
// de layout.sidebarDefault, en verre à l'opacité glass.sidebar (bible, « Formes », D136) ; à droite, le fond
// surfaceWindow opaque du contenu, peint par le panneau lui-même ; les pastilles de la
// fenêtre (bible, « Pastilles de fenêtre ») se posent à son sommet, dans la hauteur enTete réservée. Dessous, les trois
// onglets de reglages.tabHeight : médaillon (à l'accent pour l'onglet choisi), nom en échelon 2 (graisse moyenne pour
// l'onglet choisi) et état en échelon 0 au texte secondaire (Wi-Fi : réseau joint, « Désactivé » ou « Non connecté » ;
// Filaire : « Connecté », « Câble débranché » ou « Aucune carte » ; VPN : « Connecté » ou « Non connecté »). La barre
// est une colonne de navigation (Liste.navigation, bible, « Sélectionné inactif ») : l'onglet choisi prend la plaque
// neutre controlRaised et un nom en graisse moyenne, jamais le fond d'accent ; les flèches haut et bas passent d'un
// onglet à l'autre, et le contour de focus (bible, « Focus clavier ») n'orne que la rangée courante, jamais un anneau.
// À droite, une zone qui défile, en retrait de space.blockGap, porte la page de l'onglet (PageWifi, PageFilaire,
// PageVpn) ; une sous-page la remplace : la rangée de retour « ‹ Wi-Fi » (ou le nom de l'onglet courant), puis la
// FicheProfil du profil (sousPage = son uuid) ou la FicheNouveau (sousPage = « nouveau »). Changer d'onglet, ouvrir une
// sous-page ou revenir remet le défilement en haut ; Échap, tant qu'une sous-page est ouverte, revient à la page
// d'onglet. La FicheProfil (« Réglages avancés » : IPv4 et détail, les réglages courants étant dans le dépliant du
// réseau) n'existe que sous sa sous-page. Le profil demandé (etat.profilDemande, posé par ajoute après la création
// d'un profil ; le popover, lui, le vide) ouvre sa sous-page et choisit son onglet (Wi-Fi pour un profil
// 802-11-wireless, Filaire pour un profil ethernet) ; une demande faite fenêtre ouverte est suivie aussitôt, et toute
// demande est consommée (remise à vide) dès que son profil est lu.
// Sans demande, la fenêtre s'ouvre sur la page de l'onglet Wi-Fi. Le panneau demande le balayage Wi-Fi
// (etat.rechercheFenetre) pour toute la vie de la fenêtre et le rend à sa destruction ; changer d'onglet ou de
// sous-page n'y touche jamais. La facturation de chaque profil Wi-Fi est lue d'un seul processus quand la liste des
// profils change, puis tenue à jour par les lectures de la fiche ; aucun minuteur. Seule la page de l'onglet affiché à
// l'ouverture est construite (Wi-Fi par défaut) : les pages Filaire et VPN le sont au premier choix de leur onglet,
// puis gardées (L2-65, ouverture plus rapide).
// Entrées : etat, la source de l'état et des actions, EtatReseau par défaut ; onglet, « wifi » (défaut), « filaire » ou
// « vpn » ; sousPage, l'uuid du profil ouvert, « nouveau » pour la fiche d'un autre réseau, vide pour la page d'onglet
// ; enTete, hauteur réservée en haut de la barre latérale pour les pastilles d'une fenêtre, 0 par défaut.
// Sorties : onglets, [{cle, nom, etat, icone}] des trois onglets ; rangees, les profils (nmcli.profilsFenetre) ; fiche,
// la FicheProfil ouverte, null sinon ; nouvelle, la FicheNouveau ouverte, null sinon ; defilement, le Flickable des
// pages ; liste, la Liste des onglets ; pageWifi, pageFilaire, pageVpn, les trois pages d'onglet : la page Wi-Fi
// existe dès l'ouverture, les deux autres valent null tant que leur onglet n'a pas été choisi, puis restent les mêmes
// objets (seule leur visibilité change d'un onglet à l'autre) ; factures, uuid → facturation lue. Fonctions :
// choisirOnglet, ouvrirProfil, ouvrirNouveau, retour, ajoute, remplir.
// Erreurs : un échec de la lecture des factures laisse les icônes Wi-Fi ordinaires ; une sous-page dont le profil
// disparaît (supprimé ailleurs) se referme.
// Dépendances : EtatReseau (profils, reseaux, facture, profilDemande, radio, carte, reseauActif, force, connectivite,
// filaire, carteFilaire, vpnActif), PageWifi, PageFilaire, PageVpn, FicheProfil, FicheNouveau, nmcli.js
// (profilsFenetre, lireFactures), Liste, Rangee, Medaillon, Bouton, Surface, Texte, icones.js, Theme, Quickshell.Io
// (Process, StdioCollector). Cotes : colonne pleine hauteur de largeur layout.sidebarDefault, sans rayon propre (les coins
// de gauche sont ceux de la fenêtre, arrondis par le compositeur) ; onglets de reglages.tabHeight (48), séparés de
// space.scale[0] (4) ; pages en retrait de space.blockGap (24) de la zone qui défile.
Item {
    id: panneau

    // Le panneau lui-même, pour les pages dont la propriété panneau masque l'identifiant du même nom.
    readonly property Item soi: panneau
    property var etat: EtatReseau
    property string onglet: "wifi"
    property string sousPage: ""
    property real enTete: 0
    property var factures: ({})
    readonly property var rangees: Nmcli.profilsFenetre(etat.profils, etat.reseaux.map(r => r.name), factures, etat.facture)
    readonly property var onglets: [
        {cle: "wifi", nom: "Wi-Fi", icone: Icones.iconeReseau({carte: etat.carte, radio: etat.radio, filaire: false,
            connecte: etat.reseauActif !== null, connectivite: etat.connectivite, facture: etat.facture, force: etat.force})
            || "network-wireless-offline",
         etat: !etat.radio ? "Désactivé" : etat.reseauActif ? etat.reseauActif.name : "Non connecté"},
        {cle: "filaire", nom: "Filaire", icone: etat.filaire ? "network-wired" : "network-wired-disconnected",
         etat: etat.filaire ? "Connecté" : etat.carteFilaire ? "Câble débranché" : "Aucune carte"},
        {cle: "vpn", nom: "VPN", icone: etat.vpnActif ? "network-vpn" : "network-vpn-disabled",
         etat: etat.vpnActif ? "Connecté" : "Non connecté"}
    ]
    readonly property string nomOnglet: onglets.find(o => o.cle === onglet)?.nom ?? ""
    readonly property bool sousPageProfil: sousPage !== "" && sousPage !== "nouveau"
    readonly property var fiche: chargeurFiche.item
    readonly property var nouvelle: chargeurNouveau.item
    readonly property alias defilement: defilement
    readonly property alias liste: liste
    readonly property alias pageWifi: pageWifi
    readonly property var pageFilaire: chargeurFilaire.item
    readonly property var pageVpn: chargeurVpn.item
    // Uuid des profils Wi-Fi : la facturation est relue quand cette liste change, et seulement alors.
    readonly property string cleFactures: rangees.filter(r => r.wifi).map(r => r.uuid).join(" ")

    // choisirOnglet — affiche la page d'un onglet, en refermant toute sous-page. Entrée : cle, « wifi », « filaire »
    // ou « vpn ». Sortie : aucune. Erreurs : aucune. Dépendances : onglet, retour.
    function choisirOnglet(cle) { if (cle === onglet) retour(); else onglet = cle }

    // ouvrirProfil — ouvre la sous-page d'un profil. Entrée : uuid. Sortie : aucune. Erreurs : un uuid inconnu
    // referme aussitôt la sous-page à la lecture suivante (remplir). Dépendances : sousPage.
    function ouvrirProfil(uuid) { sousPage = uuid }

    // ouvrirNouveau — ouvre la fiche « Nouveau réseau » (« Autre réseau… »). Entrées : aucune. Sortie : aucune.
    // Erreurs : aucune. Dépendances : sousPage.
    function ouvrirNouveau() { sousPage = "nouveau" }

    // retour — revient de la sous-page à la page d'onglet. Entrées : aucune. Sortie : aucune. Erreurs : aucune.
    // Dépendances : sousPage.
    function retour() { sousPage = "" }

    // ajoute — referme la fiche « Nouveau réseau » et demande le profil créé, dont la sous-page s'ouvre dès que la
    // lecture des profils le montre. Entrées : uuid, celui que nmcli a donné (vide s'il manque) ; nom, le nom du
    // profil. Sortie : aucune. Erreurs : aucune. Dépendances : etat.profilDemande, retour, remplir.
    function ajoute(uuid, nom) {
        retour()
        etat.profilDemande = uuid || nom
        remplir()
    }

    // remplir — ouvre la sous-page du profil demandé par etat.profilDemande (uuid ou nom) s'il figure parmi les
    // rangées, après avoir choisi son onglet, puis consomme la demande ; referme une sous-page dont le profil n'existe
    // plus. Entrées : aucune. Sortie : aucune. Erreurs : aucune ; une demande dont le profil n'est pas (encore) lu
    // attend la lecture suivante. Dépendances : rangees, etat.profilDemande, choisirOnglet, ouvrirProfil.
    function remplir() {
        const demande = etat.profilDemande === "" ? null
            : rangees.find(r => r.uuid === etat.profilDemande || r.nom === etat.profilDemande)
        if (demande) {
            choisirOnglet(demande.wifi ? "wifi" : "filaire")
            ouvrirProfil(demande.uuid)
            etat.profilDemande = ""
        } else if (sousPageProfil && rangees.length > 0 && !rangees.some(r => r.uuid === sousPage)) retour()
    }

    // Un seul gestionnaire pour tout changement d'onglet : la sous-page se referme, le défilement remonte et la rangée
    // courante de la barre suit (l'onglet a pu changer autrement qu'au clic, par une demande de profil).
    onOngletChanged: {
        sousPage = ""
        defilement.contentY = 0
        liste.currentIndex = onglets.findIndex(o => o.cle === onglet)
    }
    onSousPageChanged: defilement.contentY = 0
    onRangeesChanged: remplir()
    Connections {
        target: panneau.etat
        function onProfilDemandeChanged() { panneau.remplir() }
    }
    // Vrai quand la clé a changé pendant une lecture de la facturation : celle-ci est relancée à sa fin (onRunningChanged
    // de lectureFactures) au lieu de perdre le changement.
    property bool facturesAttendues: false
    onCleFacturesChanged: if (cleFactures !== "") { if (lectureFactures.running) facturesAttendues = true; else lectureFactures.running = true }
    // Échap quitte la sous-page ; sans sous-page, la touche poursuit son chemin.
    Keys.onEscapePressed: event => {
        event.accepted = sousPage !== ""
        retour()
    }

    // La liste reçoit le focus à l'ouverture, pour les flèches, sans montrer le contour de focus : il n'appartient
    // qu'au focus venu du clavier (Liste.focusClavier). Le focus peut arriver, voire revenir, à l'activation de la
    // fenêtre (par exemple quand le popover qui l'a ouverte rend le focus) : tant qu'aucune touche n'a été frappée
    // dans la fenêtre (clavierUtilise), chaque arrivée du focus sur la liste est donc effacée au passage. Les touches
    // que la liste consomme (flèches) lui sont relayées par Keys.forwardTo, les autres remontent jusqu'au panneau.
    property bool clavierUtilise: false
    Keys.onPressed: event => { clavierUtilise = true; event.accepted = false }
    Item { id: capteurTouches; Keys.onPressed: event => { panneau.clavierUtilise = true; event.accepted = false } }
    Component.onCompleted: { remplir(); liste.forceActiveFocus(); demandeBalayage = true }
    // Fermer la fenêtre rend le balayage et efface toute demande de profil restée sans suite, pour que la prochaine
    // ouverture montre la page de l'onglet Wi-Fi.
    Component.onDestruction: { etat.rechercheFenetre = false; etat.profilDemande = "" }

    // Balayage Wi-Fi : demandé à etat.rechercheFenetre pour toute la vie du panneau, donc de la fenêtre, quel que soit
    // l'onglet ou la sous-page, et rendu à sa destruction. L'écriture de scannerEnabled occupant le fil graphique
    // (environ une demi-seconde à la mesure de 7a, de 2 à 15 ms à celle de L2-06 sur caladan, D116), elle suit la
    // première image de la fenêtre (frameSwapped), qu'elle ne retarde pas ; sans fenêtre, elle est immédiate.
    property bool demandeBalayage: false
    Connections {
        target: panneau.demandeBalayage ? panneau.Window.window : null
        function onFrameSwapped() {
            panneau.demandeBalayage = false
            panneau.etat.rechercheFenetre = true
        }
    }
    onDemandeBalayageChanged: if (demandeBalayage && !Window.window) { demandeBalayage = false; etat.rechercheFenetre = true }
    Connections {
        target: liste
        function onActiveFocusChanged() {
            if (liste.activeFocus && !panneau.clavierUtilise) liste.focusClavier = false
        }
    }

    ListModel {
        id: modele
        ListElement { cle: "wifi" }
        ListElement { cle: "filaire" }
        ListElement { cle: "vpn" }
    }

    // Facturation des profils Wi-Fi, une ligne « uuid:valeur » par profil, d'un seul processus.
    Process {
        id: lectureFactures
        command: ["sh", "-c", 'for u; do printf "%s:" "$u"; nmcli -g connection.metered connection show "$u"; done',
                  "sh", ...panneau.cleFactures.split(" ")]
        stdout: StdioCollector { onStreamFinished: panneau.factures = Nmcli.lireFactures(text) }
        onRunningChanged: if (!running && panneau.facturesAttendues) { panneau.facturesAttendues = false; running = true }
    }

    // Fond du contenu, à droite de la colonne : surfaceWindow opaque (D136).
    Surface {
        x: Theme.layout?.sidebarDefault ?? 0
        width: parent.width - x
        height: parent.height
    }

    // Colonne de la barre latérale (bible, « Formes », D136) : surfacePanel pleine hauteur, en verre flouté par le
    // compositeur à l'opacité glass.sidebar (0,90 le jour, opaque la nuit).
    Surface {
        id: plateau
        role: "surfacePanel"
        verre: true
        cleVerre: "sidebar"
        width: Theme.layout?.sidebarDefault ?? 0
        height: parent.height

        Liste {
            id: liste
            x: Theme.space?.scale[1] ?? 0
            y: Math.max(panneau.enTete - plateau.y, 0) + (Theme.space?.scale[2] ?? 0)
            width: parent.width - 2 * x
            height: count * (Theme.reglages?.tabHeight ?? 0) + (count - 1) * spacing
            spacing: Theme.space?.scale[0] ?? 0
            interactive: false
            model: modele
            selectionSuitCourant: false
            // Colonne de navigation : l'onglet choisi prend la plaque neutre et un nom en graisse moyenne, jamais le
            // fond d'accent.
            navigation: true
            Keys.forwardTo: [capteurTouches]
            // Au clavier, la sélection suit les flèches, comme une barre latérale de macOS.
            onCurrentIndexChanged: if (focusClavier && currentIndex >= 0 && modele.get(currentIndex).cle !== panneau.onglet)
                panneau.choisirOnglet(modele.get(currentIndex).cle)

            delegate: Rangee {
                id: rangee
                required property string cle
                readonly property var resume: panneau.onglets.find(o => o.cle === cle)

                implicitHeight: Theme.reglages?.tabHeight ?? 0
                selectionnee: cle === panneau.onglet
                onActive: panneau.choisirOnglet(cle)

                contentItem: RowLayout {
                    spacing: Theme.space?.scale[1] ?? 0
                    Medaillon { nom: rangee.resume.icone; actif: rangee.selectionnee }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Texte { Layout.fillWidth: true; text: rangee.resume.nom; moyen: rangee.gras; elide: Text.ElideRight; color: rangee.etat.texte }
                        Texte {
                            Layout.fillWidth: true
                            text: rangee.resume.etat
                            echelon: 0
                            elide: Text.ElideRight
                            color: Theme.color?.textSecondary ?? "transparent"
                        }
                    }
                }
            }
        }
    }

    Flickable {
        id: defilement
        x: Theme.layout?.sidebarDefault ?? 0
        width: parent.width - x
        height: parent.height
        clip: true
        contentHeight: pages.implicitHeight + 2 * (Theme.space?.blockGap ?? 0)
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: pages
            x: Theme.space?.blockGap ?? 0
            y: x
            width: defilement.width - 2 * x
            spacing: Theme.space?.scale[1] ?? 0

            // Retour de la sous-page, nommé d'après l'onglet courant.
            Bouton {
                objectName: "retour"
                visible: panneau.sousPage !== ""
                text: "‹ " + panneau.nomOnglet
                onClicked: panneau.retour()
            }

            // La page Wi-Fi est construite à l'ouverture ; Filaire et VPN le sont au premier choix de leur onglet, puis
            // gardées : un changement d'onglet n'en bascule que la visibilité. Une page masquée ne pèse pas dans la pile.
            PageWifi {
                id: pageWifi
                visible: panneau.sousPage === "" && panneau.onglet === "wifi"
                Layout.fillWidth: true
                panneau: soi
                etat: panneau.etat
            }
            Loader {
                id: chargeurFilaire
                active: panneau.onglet === "filaire" || item !== null
                visible: panneau.sousPage === "" && panneau.onglet === "filaire"
                Layout.fillWidth: true
                sourceComponent: PageFilaire {
                    width: chargeurFilaire.width
                    panneau: soi
                    etat: panneau.etat
                }
            }
            Loader {
                id: chargeurVpn
                active: panneau.onglet === "vpn" || item !== null
                visible: panneau.sousPage === "" && panneau.onglet === "vpn"
                Layout.fillWidth: true
                sourceComponent: PageVpn {
                    width: chargeurVpn.width
                    panneau: soi
                    etat: panneau.etat
                }
            }
            Loader {
                id: chargeurFiche
                active: panneau.sousPageProfil
                visible: active
                Layout.fillWidth: true
                sourceComponent: FicheProfil {
                    width: chargeurFiche.width
                    uuid: panneau.sousPage
                    rangee: panneau.rangees.find(r => r.uuid === panneau.sousPage) ?? null
                    etat: panneau.etat
                    onRelu: (u, p) => panneau.factures = Object.assign({}, panneau.factures, {[u]: p.facture})
                }
            }
            Loader {
                id: chargeurNouveau
                active: panneau.sousPage === "nouveau"
                visible: active
                Layout.fillWidth: true
                sourceComponent: FicheNouveau {
                    width: chargeurNouveau.width
                    etat: panneau.etat
                    onAjoute: (uuid, nom) => panneau.ajoute(uuid, nom)
                    onAnnule: panneau.retour()
                }
            }
        }
    }
}
