import QtQuick
import QtQuick.Layouts
import "../Theme"
import "../Composants"
import "../Composants/etats.js" as Etats
import "nmcli.js" as Nmcli

// PageWifi — page de l'onglet Wi-Fi de la fenêtre Réseau (direction D4, ordre de L2-65).
// Rôle : de haut en bas, le titre « Wi-Fi » et l'interrupteur de la radio (TitrePage) ; radio coupée, la ligne
// « Wi-Fi désactivé » ; le champ de recherche (Recherche), qui filtre par nom les trois listes ; le réseau joint, dans
// son groupe, en DepliantReseau détaillé ouvert à l'ouverture de la page (débits, courbe, tuiles, réglages et pied,
// dont « Réglages avancés… » qui ouvre la sous-page ; aucune logique nmcli n'est dupliquée ici) ; « Autres réseaux »,
// avec l'action « Rechercher » alignée sur le bord droit des cartes, les réseaux à portée et sans profil, puis « Autre
// réseau… » en dernière ligne ; enfin les « Réseaux connus » (ConnusWifi), repliés. Les listes viennent de
// Nmcli.partager ; radio coupée, aucun réseau n'est tenu pour à portée. Déconnecté, le groupe du réseau joint
// disparaît et « Autres réseaux » remonte sous la recherche.
// Autres réseaux : chacun porte son IconeSignal (force et cadenas), à la même taille que celles des réseaux connus. Un
// clic rejoint un réseau ouvert (« Connexion… » et l'Activite sur la rangée) ; sur un réseau sécurisé, il déplie sous
// la rangée le BlocSecret (partagé avec le popover), qu'un second clic replie. Un connectionFailed déplie la rangée
// avec « Mot de passe refusé. Vérifiez-le et réessayez. » (secrets absents, refusés, délai d'authentification, client
// déconnecté) ou « Connexion impossible. », comme le popover. Comme lui, l'ordre est figé tant qu'une rangée est
// dépliée, pour ne perdre ni la saisie ni l'erreur. « Rechercher » (accent autonome, plaque de survol arrondie)
// relance « nmcli device wifi rescan » ; l'Activite et « Recherche… » la remplacent jusqu'au retour de la liste, au
// plus motion.delays.scan.
// Balayage : le balayage Wi-Fi est demandé par etat.rechercheFenetre : elle n'y touche plus, c'est le PanneauReseau qui
// la pose pour toute la vie de la fenêtre ; le popover écrit etat.recherche, une autre propriété : EtatReseau balaye
// tant que l'une des deux est vraie, si bien que la fermeture du popover ne coupe pas la demande de la fenêtre, ni
// l'inverse (voir EtatReseau.balayage).
// Clavier : toutes les rangées cliquables sont des Ligne, et « Rechercher » prend la tabulation, Entrée et Espace avec
// le même contour de focus (tabulation, Entrée, Espace, contour de focus, plaque de survol : bible, « Clavier » et
// « Survol »). Interrupteur : bible, « Interrupteur ». Champ de recherche : bible, « Champ de recherche ». Formes :
// jetons Theme.reglages seuls (bible, « Formes »).
// Entrées : panneau, le PanneauReseau (rangees, factures, ouvrirProfil, ouvrirNouveau) ; etat, la source de l'état et
// des actions, EtatReseau par défaut.
// Sorties : filtre, la saisie de la recherche ; listes, le résultat de Nmcli.partager ({joint, autres, connus}) ;
// joint, la rangée du profil Wi-Fi actif retenue par le filtre (null sans elle) ; connuOuvert, l'uuid du réseau connu
// déplié (un seul) ; connusOuverts, vrai si l'utilisateur a ouvert la section des réseaux connus ; ordre, les noms
// des autres réseaux dans l'ordre affiché ; deplie, le nom de la rangée dépliée ; erreur, le message sous son champ ;
// balayage, vrai pendant la recherche relancée ; depliant, le DepliantReseau du réseau joint (null sans lui).
// Erreurs : un échec nmcli des réglages s'affiche dans le dépliant concerné ; un réseau qui quitte le balayage est
// masqué et ne peut plus être choisi.
// Dépendances : TitrePage, Recherche, Section, Groupe, Ligne, DepliantReseau, IconeSignal, ConnusWifi, BlocSecret,
// Jonction, Interrupteur, Activite, Icone, Texte, Theme (reglages, space, color, icons, motion, density, radius, focus),
// nmcli.js (partager), etats.js, PanneauReseau, EtatReseau.
ColumnLayout {
    id: page

    required property var panneau
    property var etat: EtatReseau

    property alias filtre: recherche.text
    readonly property var listes: Nmcli.partager(panneau.rangees, etat.radio ? presents : [], filtre)
    readonly property var joint: listes.joint
    property alias connuOuvert: connus.connuOuvert
    property alias connusOuverts: connus.ouverts
    readonly property var depliant: chargeurJoint.item
    // Logique de connexion partagée avec le popover (voir Jonction) ; ordre garde les noms des réseaux disponibles
    // triés.
    property alias presents: jonction.presents
    property alias deplie: jonction.deplie
    property alias erreur: jonction.erreur
    property alias enCours: jonction.enCours
    property var ordre: []
    // Le bloc de mot de passe actuellement déplié, null sans lui (tenu par le bloc lui-même).
    property Item bloc: null
    property bool balayage: false
    readonly property real cote: Theme.space?.scale[2] ?? 0

    spacing: 0


    // trier — fige l'ordre des autres réseaux (listes.autres, déjà triés et filtrés) ; rien ne change tant qu'une
    // rangée de mot de passe est dépliée, pour ne perdre ni la saisie ni le message d'erreur. L'ordre n'est
    // réaffecté que si les noms diffèrent, pour que le focus clavier et le survol traversent un balayage.
    // Entrées : aucune. Sortie : aucune. Erreurs : aucune. Dépendances : listes, deplie.
    function trier() {
        if (deplie !== "") return
        const noms = listes.autres.map(r => r.name)
        if (noms.join("\n") !== ordre.join("\n")) ordre = noms
    }
    onDeplieChanged: trier()
    onListesChanged: trier()
    // Page cachée (autre onglet ou sous-page, la page restant vivante) : aucun secret ne survit, ni le mot de passe
    // lu et révélé du dépliant du réseau joint, ni celui saisi dans un bloc déplié.
    onVisibleChanged: if (!visible) {
        depliant?.corps?.profil.masquerSecret()
        deplie = ""
        erreur = ""
    }
    Component.onCompleted: trier()

    // montrer — déplie un réseau dans la page et y fait défiler : le dépliant du réseau joint s'il s'agit du joint
    // (ouvert), sinon le réseau connu (section des réseaux connus ouverte, connuOuvert à son uuid). Demandé par le
    // panneau pour un profil demandé (« Détails… » du popover, réseau ajouté). Entrée : uuid, le profil. Sortie :
    // aucune ; le défilement suit la mise en page (aMontrer) tant que la hauteur de la page change, pendant au plus
    // une seconde, et cesse dès que l'utilisateur fait défiler. Erreurs : aucune ; un uuid absent des listes ne
    // déplie ni ne défile rien. Dépendances : joint, depliant, connusOuverts, connuOuvert, defiler, finMontrer.
    function montrer(uuid) {
        if (joint?.uuid === uuid) { if (depliant) depliant.ouvert = true }
        else { connusOuverts = true; connuOuvert = uuid }
        aMontrer = uuid
        finMontrer.restart()
        Qt.callLater(defiler)
    }

    // defiler — fait défiler la page jusqu'au réseau à montrer. Entrées : aucune. Sortie : aucune. Erreurs : aucune ;
    // sans réseau à montrer ou sans son dépliant, ne fait rien. Dépendances : aMontrer, chercher, panneau.defilement.
    function defiler() {
        const cible = aMontrer === "" ? null : chercher(page, "depliant:" + aMontrer)
        if (!cible) return
        const d = panneau.defilement
        d.contentY = Math.max(0, Math.min(cible.mapToItem(d.contentItem, 0, 0).y - (Theme.space?.blockGap ?? 0),
                                          d.contentHeight - d.height))
    }

    // Réseau à montrer, vide au repos ; la page suit les changements de hauteur du défilement (ouverture de la fenêtre,
    // de la section, du dépliant) jusqu'à la fin de la borne ou au premier geste de l'utilisateur.
    property string aMontrer: ""
    Timer { id: finMontrer; interval: 1000; onTriggered: page.aMontrer = "" }
    Connections {
        target: page.panneau.defilement
        function onContentHeightChanged() { page.defiler() }
        function onMovementStarted() { page.aMontrer = "" }
    }

    // chercher — premier descendant visuel d'un objectName, en profondeur. Entrées : racine, Item ; nom. Sortie :
    // l'Item, ou null. Erreurs : aucune. Dépendances : aucune.
    function chercher(racine, nom) {
        for (const e of racine.children) {
            if (e.objectName === nom) return e
            const r = chercher(e, nom)
            if (r) return r
        }
        return null
    }

    // rechercher — relance « nmcli device wifi rescan » et montre l'Activite jusqu'au retour de la liste, au plus
    // finBalayage.interval (motion.delays.scan). Entrées : aucune. Sortie : aucune. Erreurs : aucune.
    // Dépendances : etat.executer, finBalayage.
    function rechercher() {
        balayage = true
        if (finBalayage.interval > 0) finBalayage.restart()
        etat.executer(["device", "wifi", "rescan"])
    }

    // Logique de connexion ; un refus révèle le mot de passe saisi dans le bloc déplié, comme le popover.
    Jonction {
        id: jonction
        etat: page.etat
        onRefuse: if (page.bloc) page.bloc.secret.revele = true
    }
    Connections {
        target: page.etat
        function onReseauxChanged() {
            page.balayage = false
            finBalayage.stop()
            jonction.actualiser()
        }
    }
    // Retour d'une sous-page de l'onglet Wi-Fi : la page restant vivante, le profil du dépliant du réseau joint est relu,
    // car « Réglages avancés… » a pu changer la connexion automatique, la priorité, la facturation ou l'IPv4.
    Connections {
        target: page.panneau
        function onSousPageChanged() { if (page.panneau.sousPage === "" && page.panneau.onglet === "wifi") page.depliant?.corps?.profil.lire() }
    }
    // Borne du retour visuel de la recherche quand le balayage ne change pas la liste ; armée par le seul clic.
    Timer { id: finBalayage; interval: Theme.motion?.delays?.scan ?? 0; onTriggered: page.balayage = false }

    TitrePage {
        objectName: "titre"
        text: "Wi-Fi"
        Interrupteur {
            objectName: "radio"
            checked: page.etat.radio
            onToggled: { page.etat.allumer(checked); checked = Qt.binding(() => page.etat.radio) }
        }
    }

    Texte {
        objectName: "desactive"
        visible: !page.etat.radio
        Layout.leftMargin: Theme.space?.scale[0] ?? 0
        text: "Wi-Fi désactivé"
        color: Theme.color?.textSecondary ?? "transparent"
    }
    Recherche {
        id: recherche
        objectName: "recherche"
        Layout.fillWidth: true
        Layout.topMargin: Theme.space?.scale[2] ?? 0
        placeholderText: "Rechercher un réseau"
    }

    Section { visible: chargeurJoint.active; text: "Réseau joint" }
    // Le dépliant du réseau joint, sur la carte de son groupe.
    Groupe {
        visible: chargeurJoint.active
        Loader {
            id: chargeurJoint
            objectName: "joint"
            active: page.etat.radio && page.joint !== null
            visible: active
            Layout.fillWidth: true
            sourceComponent: DepliantReseau {
                width: chargeurJoint.width
                detaille: true
                ouvert: true
                portee: true
                etat: page.etat
                rangee: page.joint
                onBasculer: ouvert = !ouvert
                onAvances: uuid => page.panneau.ouvrirProfil(uuid)
                onRelu: (u, p) => page.panneau.factures = Object.assign({}, page.panneau.factures, {[u]: p.facture})
            }
        }
    }

    // Autres réseaux : le titre, puis « Rechercher » ou l'Activite pendant le balayage, dont la plaque de survol
    // s'aligne sur le bord droit des cartes.
    RowLayout {
        objectName: "autres"
        visible: page.etat.radio
        Layout.fillWidth: true
        Section { Layout.fillWidth: true; Layout.alignment: Qt.AlignBottom; text: "Autres réseaux" }
        Item {
            Layout.alignment: Qt.AlignBottom
            Layout.bottomMargin: (Theme.space?.scale[0] ?? 0) / 2
            implicitWidth: Math.max(relance.implicitWidth, attente.implicitWidth)
            implicitHeight: Theme.density?.controlHeight ?? 0
            Row {
                id: attente
                objectName: "attente"
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: page.balayage
                spacing: Theme.space?.scale[1] ?? 0
                Texte { anchors.verticalCenter: parent.verticalCenter; text: "Recherche…"; echelon: 0; color: Theme.color?.textTertiary ?? "transparent" }
                Activite { objectName: "activiteRecherche"; anchors.verticalCenter: parent.verticalCenter }
            }
            Rectangle {
                id: relance
                objectName: "rechercher"
                visible: !page.balayage
                anchors.right: parent.right
                implicitWidth: rangRelance.implicitWidth + 2 * page.cote
                height: parent.height
                radius: Theme.radius?.control ?? 0
                // Clavier (bible, « Clavier ») : Tab l'atteint, Entrée et Espace l'activent ; le contour de focus
                // n'apparaît que pour le focus venu du clavier (un clic ne prend pas le focus).
                activeFocusOnTab: visible
                Keys.onPressed: event => {
                    event.accepted = [Qt.Key_Return, Qt.Key_Enter, Qt.Key_Space].includes(event.key)
                    if (event.accepted) relance.clique()
                }
                Rectangle {
                    readonly property real decalage: Theme.focus?.rowOffset ?? 0
                    anchors.fill: parent
                    anchors.margins: -decalage
                    radius: relance.radius + decalage
                    visible: relance.activeFocus
                    color: "transparent"
                    border.width: Theme.focus?.width ?? 0
                    border.color: Theme.focus?.color ?? "transparent"
                }
                color: survolRelance.hovered ? Theme.stateColors(Etats.herite(relance, "dnRole", "surfaceWindow"), "none", tapeRelance.pressed ? "pressed" : "hover")?.fill ?? "transparent" : "transparent"
                signal clique()
                onClique: page.rechercher()
                Row {
                    id: rangRelance
                    anchors.centerIn: parent
                    spacing: Theme.space?.scale[1] ?? 0
                    Icone { anchors.verticalCenter: parent.verticalCenter; nom: "view-refresh"; taille: Theme.icons?.sizes.dense ?? 0; couleur: Theme.color?.accentStandalone ?? "transparent" }
                    Texte { anchors.verticalCenter: parent.verticalCenter; text: "Rechercher"; echelon: 0; moyen: true; color: Theme.color?.accentStandalone ?? "transparent" }
                }
                HoverHandler { id: survolRelance; cursorShape: Qt.PointingHandCursor }
                TapHandler { id: tapeRelance; onTapped: relance.clique() }
            }
        }
    }
    Groupe {
        objectName: "disponibles"
        visible: page.etat.radio
        Repeater {
            model: page.ordre

            ColumnLayout {
                id: dispo
                required property string modelData
                required property int index
                readonly property var r: page.presents.find(x => x.name === modelData) ?? null
                readonly property bool ouverte: page.deplie === modelData
                readonly property bool enConnexion: r !== null && r === page.enCours
                objectName: "reseau:" + modelData
                visible: r !== null
                Layout.fillWidth: true
                spacing: 0

                Ligne {
                    objectName: "ligne"
                    filet: page.ordre.slice(0, dispo.index).some(n => jonction.present(page.presents.find(x => x.name === n)))
                    tete: Component {
                        Item {
                            implicitWidth: Theme.reglages?.medallion ?? 0
                            implicitHeight: implicitWidth
                            IconeSignal {
                                anchors.centerIn: parent
                                force: Math.round((dispo.r?.signalStrength ?? 0) * 100)
                                securise: jonction.securise(dispo.r)
                            }
                        }
                    }
                    libelle: dispo.modelData
                    aide: dispo.enConnexion ? "Connexion…" : ""
                    cliquable: true
                    onClique: jonction.choisir(dispo.r)
                    Activite { visible: dispo.enConnexion }
                }
                Loader {
                    objectName: "bloc"
                    active: dispo.ouverte
                    visible: active
                    Layout.fillWidth: true
                    Layout.leftMargin: Theme.reglages?.textColumn ?? 0
                    Layout.rightMargin: page.cote
                    sourceComponent: BlocSecret {
                        id: blocSecret
                        erreur: page.erreur
                        occupe: dispo.enConnexion
                        // Comme le popover, un refus montre le mot de passe saisi.
                        Component.onCompleted: { page.bloc = blocSecret; if (page.erreur !== "") secret.revele = true }
                        Component.onDestruction: if (page.bloc === blocSecret) page.bloc = null
                        onRejoindre: jonction.rejoindre(secret.text)
                        onAnnuler: { jonction.deplie = ""; jonction.erreur = "" }
                    }
                }
            }
        }
        // Réseau caché (FicheNouveau), en dernière ligne des autres réseaux.
        Ligne {
            objectName: "autre"
            filet: page.ordre.some(n => jonction.present(page.presents.find(x => x.name === n)))
            icone: "list-add"
            libelle: "Autre réseau…"
            cliquable: true
            onClique: page.panneau.ouvrirNouveau()
        }
    }

    ConnusWifi {
        id: connus
        connus: page.listes.connus
        filtre: page.filtre
        panneau: page.panneau
        etat: page.etat
    }
}
