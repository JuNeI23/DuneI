import QtQuick
import QtQuick.Layouts
import Quickshell.Networking
import "../Theme"
import "../Composants"
import "../Barre/icones.js" as Icones
import "nmcli.js" as Nmcli

// PopoverReseau — popover du réseau, ancré sous l'indicateur réseau de la barre (L2-11).
// Rôle : un Overlay contextuel, construit à l'ouverture et détruit à la fermeture (D80), qui porte, de haut en bas :
// l'état (pastille, nom du réseau, « Connecté », « Connecté sans internet », « Portail de connexion » ou « Partage
// du téléphone », adresse IPv4 copiable) ; derrière un portail captif, « Ouvrir la page de connexion » ;
// l'interrupteur Wi-Fi ; la liste des réseaux à proximité (le réseau joint en tête, puis les connus, puis la force
// décroissante ; cadenas si sécurisé, coche sur le réseau joint) avec le bouton de nouvelle recherche ; sous un
// réseau sécurisé inconnu, ou après un échec de connexion, la ligne de mot de passe dépliée ; « Autre réseau… »
// (réseau caché : nom et mot de passe) ; « Réglages réseau… », qui demande la fenêtre Réseau. Sans carte Wi-Fi, ni
// interrupteur, ni liste, ni « Autre réseau… » : seulement l'état filaire. Tant qu'il est ouvert, il demande le
// balayage Wi-Fi (etat.recherche), rendu à faux à la fermeture comme à la destruction d'un popover ouvert ; ouvert
// derrière un portail, il demande un contrôle de connectivité ponctuel (etat.verifier). La liste ne se retrie pas
// tant qu'une ligne de mot de passe est dépliée, pour ne pas en perdre la saisie. Une connexion suivie
// (enCours) appartient au panneau : fermé, il est détruit, et un connectionFailed tardif ne rouvre rien.
// Entrées : ancre, l'indicateur de la barre ; ouvert, à affecter (voir Overlay) ; associees, voir Overlay ; etat,
// la source de l'état et des actions, EtatReseau par défaut (la coque d'essai y met un factice).
// Sorties : ferme(), voir Overlay ; panneau, le contenu construit, null fermé, lu par les essais.
// Erreurs : un échec de nmcli (« Autre réseau… ») s'affiche sous le champ ; un connectionFailed déplie la ligne
// de mot de passe avec « Mot de passe refusé » (raison d'authentification) ou « Connexion impossible ». Le texte
// d'un mot de passe ne passe jamais au journal.
// Dépendances : Overlay (famille contextuel), Rangee, Interrupteur, Bouton, Champ, ChampSecret, Separateur, Icone,
// Texte, Coche, Theme, EtatReseau, nmcli.js (trierReseaux, resume), icones.js (iconeReseau), Quickshell.Networking
// (ConnectionFailReason, WifiSecurityType, par l'état).
// Cotes : surface de 350 px de large comme la maquette (panneau de 342 px dans le retrait de l'Overlay) ; contenu à
// space.scale[2] (12) du bord du panneau, rangées sur toute sa largeur ; rangées de 32 px ; pastille d'état de
// 36 px.
Overlay {
    id: popover

    property var etat: EtatReseau
    // Écrit par le panneau seul, à sa construction et à sa destruction.
    property Item panneau: null

    famille: "contextuel"
    // À l'ouverture derrière un portail, un contrôle de connectivité ponctuel (aucun minuteur) : la page de connexion
    // a pu être validée depuis la dernière ouverture.
    onOuvertChanged: {
        etat.recherche = ouvert
        if (ouvert && etat.connectivite === "portal") etat.verifier()
    }
    // Seul un popover ouvert rend le balayage : la destruction d'un popover fermé (écran débranché) ne coupe pas
    // celui d'un popover ouvert ailleurs.
    Component.onDestruction: if (ouvert) etat.recherche = false

    // BoutonIcone — bouton réduit à une icône, sans fond, comme les boutons d'outil de macOS.
    // Rôle : icône au texte secondaire, au texte primaire survolée ; le clic émet clique().
    // Entrées : nom, l'icône. Sorties : signal clique(). Erreurs : aucune. Dépendances : Icone, Theme.
    component BoutonIcone: Item {
        id: boutonIcone
        property string nom
        signal clique()
        implicitWidth: Theme.density?.controlHeight ?? 0
        implicitHeight: implicitWidth

        Icone {
            anchors.centerIn: parent
            nom: boutonIcone.nom
            taille: Theme.icons?.sizes.dense ?? 0
            couleur: (survol.hovered ? Theme.color?.textPrimary : Theme.color?.textSecondary) ?? "transparent"
        }
        HoverHandler { id: survol }
        TapHandler { onTapped: boutonIcone.clique() }
    }

    // Bloc — ligne de mot de passe dépliée : en-tête, nom (réseau caché seulement), mot de passe, erreur, boutons.
    // Rôle : cadre au fond du panneau, au filet subtil, comme la maquette ; il prend le focus à sa construction.
    // Entrées : nom, le réseau visé (vide pour un réseau caché) ; erreur, message affiché sous le champ.
    // Sorties : champNom, secret (ChampSecret) ; signaux rejoindre() et annuler(). Erreurs : aucune.
    // Dépendances : Champ, ChampSecret, Bouton, Texte, Theme.
    component Bloc: Rectangle {
        id: bloc
        property string nom
        property string erreur
        readonly property alias champNom: champNom
        readonly property alias secret: secret
        readonly property real marge: Theme.space?.scale[1] ?? 0
        signal rejoindre()
        signal annuler()

        implicitHeight: colonne.implicitHeight + 2 * marge
        radius: Theme.radius?.control ?? 0
        color: Theme.color?.surfacePanel ?? "transparent"
        border.width: Theme.hairline(1) ?? 0
        border.color: Theme.color?.borderSubtle ?? "transparent"
        Component.onCompleted: (nom === "" ? champNom : secret).forceActiveFocus()

        ColumnLayout {
            id: colonne
            x: bloc.marge
            y: bloc.marge
            width: bloc.width - 2 * bloc.marge
            spacing: Theme.space?.scale[1] ?? 0

            RowLayout {
                spacing: 0
                Texte { visible: bloc.nom !== ""; text: bloc.nom; echelon: 1; moyen: true; elide: Text.ElideRight; Layout.maximumWidth: colonne.width / 2 }
                Texte {
                    Layout.fillWidth: true
                    text: bloc.nom === "" ? "Réseau caché : saisissez son nom et son mot de passe." : " · réseau protégé"
                    echelon: 1
                    color: Theme.color?.textSecondary ?? "transparent"
                    elide: Text.ElideRight
                }
            }
            Champ { id: champNom; visible: bloc.nom === ""; Layout.fillWidth: true; placeholderText: "Nom du réseau"; onAccepted: secret.forceActiveFocus() }
            ChampSecret { id: secret; Layout.fillWidth: true; placeholderText: "Mot de passe"; onAccepted: bloc.rejoindre() }
            Texte {
                visible: bloc.erreur !== ""
                Layout.fillWidth: true
                text: bloc.erreur
                echelon: 1
                wrapMode: Text.Wrap
                color: Theme.color?.error ?? "transparent"
            }
            RowLayout {
                Layout.alignment: Qt.AlignRight
                spacing: Theme.space?.scale[1] ?? 0
                Bouton { text: "Annuler"; onClicked: bloc.annuler() }
                Bouton { text: "Rejoindre"; principal: true; onClicked: bloc.rejoindre() }
            }
        }
    }

    FocusScope {
        id: panneau

        readonly property real marge: Theme.space?.scale[2] ?? 0
        readonly property real hauteurLigne: (Theme.density?.controlHeight ?? 0) + (Theme.space?.scale[0] ?? 0)
        readonly property var etat: popover.etat
        readonly property var resume: Nmcli.resume(etat)
        readonly property bool listeVisible: etat.carte && etat.radio
        // Réseaux triés, figés jusqu'au prochain changement de la liste ou du réseau joint : un tri lié suivrait
        // chaque variation de force et reconstruirait les rangées sous le pointeur et sous la saisie.
        property var reseaux: []
        // Réseaux présents au dernier balayage, suivis même liste figée : un réseau de la liste figée qui n'y figure
        // plus est masqué et ne peut plus être choisi ni rejoint (son WifiNetwork peut avoir été détruit).
        property var presents: Array.from(etat.reseaux ?? [])
        // Nom du réseau dont la ligne de mot de passe est dépliée, « <autre> » pour un réseau caché, vide sinon.
        property string deplie: ""
        property string erreur: ""
        property var enCours: null
        property Item bloc: null
        property bool copie: false

        focus: true
        implicitWidth: 342
        implicitHeight: colonne.implicitHeight + 2 * (Theme.space?.scale[1] ?? 0)
        Component.onCompleted: { trier(); popover.panneau = panneau }
        Component.onDestruction: if (popover.panneau === panneau) popover.panneau = null

        // trier — fige l'ordre de la liste des réseaux. Tant qu'une ligne de mot de passe est dépliée, sous un
        // réseau ou sous « Autre réseau… » (qui gèle aussi le tri, par simplicité, bien que sa ligne soit hors du
        // Repeater), rien ne change : remplacer le modèle du Repeater détruirait la ligne, et avec elle la saisie et
        // le message d'erreur ; le tri reprend dès qu'elle se replie. Entrées : aucune. Sortie : aucune. Erreurs : aucune.
        // Dépendances : nmcli.js (trierReseaux), etat.reseaux, deplie.
        function trier(): void { if (deplie === "") reseaux = Nmcli.trierReseaux(Array.from(etat.reseaux ?? [])) }
        onDeplieChanged: trier()

        // present — le réseau figure-t-il encore au balayage ? Entrée : r, un réseau, éventuellement null (objet
        // détruit). Sortie : bool. Erreurs : aucune. Dépendances : presents.
        function present(r): bool { return !!r && presents.includes(r) }

        // replierAbsent — replie la ligne dépliée si son réseau a quitté le balayage ; le repli relance le tri.
        // Entrées : aucune. Sortie : aucune. Erreurs : aucune. Dépendances : deplie, presents.
        function replierAbsent(): void {
            if (deplie !== "" && deplie !== "<autre>" && !presents.some(r => r.name === deplie)) {
                deplie = ""
                erreur = ""
            }
        }

        // securise — un réseau demande-t-il un mot de passe ? Entrée : r, un réseau. Sortie : vrai sauf ouvert,
        // OWE ou sécurité inconnue (essayés sans secret). Erreurs : aucune. Dépendances : WifiSecurityType.
        function securise(r): bool {
            return ![WifiSecurityType.Owe, WifiSecurityType.Open, WifiSecurityType.Unknown].includes(r?.security)
        }

        // choisir — clic sur un réseau : rien s'il est joint ; connexion directe s'il est connu ou ouvert ; sinon
        // déplie (ou replie) sa ligne de mot de passe. Entrée : r, le réseau. Sortie : aucune. Erreurs : un réseau
        // qui n'est plus au balayage est ignoré ; un échec arrive par connectionFailed (voir Connections).
        // Dépendances : present, securise, enCours, deplie.
        function choisir(r): void {
            if (!present(r) || r.connected) return
            erreur = ""
            if (r.known || !securise(r)) {
                deplie = ""
                enCours = r
                r.connect()
            } else deplie = deplie === r.name ? "" : r.name
        }

        // rejoindre — valide la ligne dépliée : connectWithPsk pour un réseau de la liste ; pour un réseau caché,
        // « nmcli device wifi connect <nom> [password <mdp>] hidden yes » par etat.executer, dont l'échec s'affiche
        // sous le champ. Entrées : aucune. Sortie : aucune. Erreurs : nom caché vide, rien n'est lancé ; réseau qui
        // n'est plus au balayage, la ligne se replie. Dépendances : bloc, presents, etat.executer.
        function rejoindre(): void {
            if (!bloc) return
            const mdp = bloc.secret.text
            erreur = ""
            if (deplie === "<autre>") {
                const nom = bloc.champNom.text
                if (nom === "") return
                const args = ["device", "wifi", "connect", nom, ...(mdp ? ["password", mdp] : []), "hidden", "yes"]
                // Le panneau peut être détruit avant la fin de nmcli : il n'y a alors plus rien à afficher.
                etat.executer(args, (code, sortie) => {
                    try { if (code === 0) deplie = ""; else erreur = sortie.trim() || "Connexion impossible." } catch (e) {}
                })
            } else {
                enCours = presents.find(r => r.name === deplie) ?? null
                if (enCours) enCours.connectWithPsk(mdp)
                else deplie = ""
            }
        }

        // echec — connectionFailed du réseau suivi : déplie sa ligne avec le message de la raison, secret révélé
        // comme sur la maquette. Entrée : raison, ConnectionFailReason : secrets absents ou refusés, client
        // déconnecté, échec ou délai d'authentification donnent « Mot de passe refusé », les autres « Connexion
        // impossible ». Sortie : aucune. Erreurs : aucune. Dépendances : enCours, bloc, ConnectionFailReason.
        function echec(raison): void {
            const refus = [ConnectionFailReason.NoSecrets, ConnectionFailReason.WifiClientDisconnected,
                           ConnectionFailReason.WifiClientFailed, ConnectionFailReason.WifiAuthTimeout]
            deplie = enCours.name
            enCours = null
            erreur = refus.includes(raison) ? "Mot de passe refusé. Vérifiez-le et réessayez." : "Connexion impossible."
            if (bloc) bloc.secret.revele = true
        }

        // iconeSignal — icône de force d'un réseau de la liste, aux mêmes paliers que la barre.
        // Entrée : force, de 0 à 1. Sortie : nom « network-wireless-signal-… ». Erreurs : aucune.
        // Dépendances : icones.js (iconeReseau).
        function iconeSignal(force: real): string {
            return Icones.iconeReseau({ carte: true, radio: true, connecte: true, connectivite: "full", force })
        }

        // fermer — referme le popover après une action qui ouvre autre chose. Entrées : aucune. Sortie : aucune.
        function fermer(): void { popover.ouvert = false }

        Connections {
            target: panneau.enCours
            function onConnectionFailed(raison) { panneau.echec(raison) }
            function onConnectedChanged() { if (panneau.enCours?.connected) { panneau.deplie = ""; panneau.enCours = null } }
        }
        Connections {
            target: panneau.etat
            function onReseauxChanged() {
                panneau.presents = Array.from(panneau.etat.reseaux ?? [])
                panneau.replierAbsent()
                panneau.trier()
            }
            function onNomActifChanged() { panneau.trier() }
        }
        Timer { id: copieFinie; interval: 1500; onTriggered: panneau.copie = false }

        ColumnLayout {
            id: colonne
            y: Theme.space?.scale[1] ?? 0
            width: panneau.width
            spacing: Theme.space?.scale[0] ?? 0

            // En-tête : pastille, titre, état, adresse.
            RowLayout {
                Layout.leftMargin: panneau.marge
                Layout.rightMargin: panneau.marge
                Layout.bottomMargin: Theme.space?.scale[0] ?? 0
                spacing: Theme.space?.scale[2] ?? 0

                Rectangle {
                    Layout.alignment: Qt.AlignTop
                    implicitWidth: (Theme.density?.controlHeight ?? 0) + (Theme.space?.scale[1] ?? 0)
                    implicitHeight: implicitWidth
                    radius: width / 2
                    color: (panneau.resume.alerte ? Theme.color?.warning : Theme.color?.accent) ?? "transparent"
                    Icone {
                        anchors.centerIn: parent
                        nom: panneau.resume.alerte ? "dialog-warning" : panneau.etat.icone
                        couleur: Theme.color?.onAccent ?? "transparent"
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    Texte { Layout.fillWidth: true; text: panneau.resume.titre; echelon: 3; moyen: true; elide: Text.ElideRight; color: Theme.color?.textEmphasis ?? "transparent" }
                    Texte {
                        Layout.fillWidth: true
                        text: panneau.resume.etat
                        echelon: 1
                        color: (panneau.resume.alerte ? Theme.color?.warning : Theme.color?.textSecondary) ?? "transparent"
                    }
                    // Adresse IPv4 en police à chasse fixe, copiable ; la coche confirme la copie un instant.
                    Rectangle {
                        visible: panneau.etat.connecte && panneau.etat.ip4.length > 0
                        Layout.topMargin: Theme.space?.scale[1] ?? 0
                        implicitWidth: ligneIp.implicitWidth + 2 * (Theme.space?.scale[1] ?? 0)
                        implicitHeight: (Theme.density?.controlHeight ?? 0) - 2
                        radius: Theme.radius?.control ?? 0
                        color: Theme.color?.controlRaised ?? "transparent"
                        border.width: Theme.hairline(1) ?? 0
                        border.color: Theme.color?.borderSubtle ?? "transparent"
                        Row {
                            id: ligneIp
                            anchors.centerIn: parent
                            spacing: Theme.space?.scale[0] ?? 0
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: (panneau.etat.ip4[0] ?? "").split("/")[0]
                                font: Qt.font({ family: Theme.typo?.mono ?? "monospace", pixelSize: Theme.typo?.scale[1] ?? 12 })
                                color: Theme.color?.textPrimary ?? "transparent"
                            }
                            Item {
                                anchors.verticalCenter: parent.verticalCenter
                                implicitWidth: copier.implicitWidth
                                implicitHeight: copier.implicitHeight
                                BoutonIcone {
                                    id: copier
                                    visible: !panneau.copie
                                    implicitWidth: (Theme.icons?.sizes.dense ?? 0) + (Theme.space?.scale[0] ?? 0)
                                    nom: "edit-copy"
                                    onClique: { panneau.etat.copierIp(); panneau.copie = true; copieFinie.restart() }
                                }
                                Coche {
                                    visible: panneau.copie
                                    anchors.centerIn: parent
                                    width: Theme.icons?.sizes.dense ?? 0
                                    height: width
                                    couleur: Theme.color?.success ?? "transparent"
                                }
                            }
                        }
                    }
                }
            }

            // Portail captif : la page de connexion s'ouvre dans le navigateur, et la connectivité est revérifiée.
            Rectangle {
                visible: panneau.etat.connectivite === "portal"
                Layout.fillWidth: true
                Layout.leftMargin: Theme.space?.scale[1] ?? 0
                Layout.rightMargin: Layout.leftMargin
                implicitHeight: lignePortail.implicitHeight + 2 * (Theme.space?.scale[1] ?? 0)
                radius: Theme.radius?.control ?? 0
                color: Theme.color?.surfacePanel ?? "transparent"
                border.width: Theme.hairline(1) ?? 0
                border.color: Theme.color?.borderSubtle ?? "transparent"
                ColumnLayout {
                    id: lignePortail
                    anchors.centerIn: parent
                    width: parent.width - 2 * (Theme.space?.scale[1] ?? 0)
                    spacing: Theme.space?.scale[1] ?? 0
                    Texte { Layout.fillWidth: true; text: "Cette connexion demande une page de connexion."; echelon: 1; wrapMode: Text.Wrap }
                    Bouton {
                        Layout.alignment: Qt.AlignRight
                        icone: "web-browser"
                        text: "Ouvrir la page de connexion"
                        principal: true
                        onClicked: { panneau.etat.ouvrirPortail(); panneau.fermer() }
                    }
                }
            }

            // Interrupteur de la radio : il suit la radio réelle après chaque bascule.
            RowLayout {
                visible: panneau.etat.carte
                Layout.leftMargin: panneau.marge
                Layout.rightMargin: panneau.marge
                Texte { Layout.fillWidth: true; text: "Wi-Fi"; moyen: true }
                Interrupteur {
                    objectName: "interrupteur"
                    checked: panneau.etat.radio
                    onToggled: { panneau.etat.allumer(checked); checked = Qt.binding(() => panneau.etat.radio) }
                }
            }

            Separateur { visible: panneau.listeVisible; Layout.fillWidth: true; Layout.topMargin: Theme.space?.scale[0] ?? 0 }

            RowLayout {
                visible: panneau.listeVisible
                Layout.leftMargin: panneau.marge
                Layout.rightMargin: Theme.space?.scale[1] ?? 0
                Texte { Layout.fillWidth: true; text: "RÉSEAUX À PROXIMITÉ"; echelon: 0; moyen: true; color: Theme.color?.textTertiary ?? "transparent" }
                BoutonIcone { nom: "view-refresh"; onClique: panneau.etat.executer(["device", "wifi", "rescan"]) }
            }

            Flickable {
                visible: panneau.listeVisible
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(contentHeight, 8 * panneau.hauteurLigne)
                contentHeight: lignes.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: lignes
                    width: parent.width

                    Repeater {
                        model: panneau.listeVisible ? panneau.reseaux : []

                        delegate: Column {
                            id: ligne
                            required property var modelData
                            required property int index
                            // Lectures sûres : le WifiNetwork d'une liste figée peut avoir été détruit (null).
                            readonly property string nom: modelData?.name ?? ""
                            readonly property bool joint: modelData?.connected ?? false
                            width: lignes.width
                            visible: panneau.present(modelData)

                            Rangee {
                                index: ligne.index
                                width: parent.width
                                implicitHeight: panneau.hauteurLigne
                                hoverEnabled: true
                                icone: panneau.iconeSignal(ligne.modelData?.signalStrength ?? 0)
                                text: ligne.nom
                                accentue: ligne.joint
                                onActive: panneau.choisir(ligne.modelData)
                                suffixe: Component {
                                    Row {
                                        spacing: Theme.space?.scale[1] ?? 0
                                        Icone {
                                            visible: panneau.securise(ligne.modelData)
                                            nom: "network-wireless-encrypted"
                                            taille: Theme.icons?.sizes.dense ?? 0
                                            couleur: Theme.color?.textTertiary ?? "transparent"
                                        }
                                        Coche {
                                            visible: ligne.joint
                                            width: Theme.icons?.sizes.dense ?? 0
                                            height: width
                                            couleur: Theme.color?.accentStandalone ?? "transparent"
                                        }
                                    }
                                }
                            }
                            Loader {
                                active: panneau.deplie === ligne.nom
                                visible: active
                                x: Theme.space?.scale[1] ?? 0
                                width: parent.width - 2 * x
                                sourceComponent: blocMdp
                            }
                        }
                    }
                }
            }

            Separateur { Layout.fillWidth: true; Layout.topMargin: Theme.space?.scale[0] ?? 0 }

            Rangee {
                index: 0
                visible: panneau.listeVisible
                Layout.fillWidth: true
                implicitHeight: panneau.hauteurLigne
                hoverEnabled: true
                icone: "list-add"
                text: "Autre réseau…"
                onActive: { panneau.erreur = ""; panneau.deplie = panneau.deplie === "<autre>" ? "" : "<autre>" }
            }
            Loader {
                active: panneau.deplie === "<autre>"
                visible: active
                Layout.fillWidth: true
                Layout.leftMargin: Theme.space?.scale[1] ?? 0
                Layout.rightMargin: Layout.leftMargin
                sourceComponent: blocMdp
            }
            Rangee {
                index: 0
                Layout.fillWidth: true
                implicitHeight: panneau.hauteurLigne
                hoverEnabled: true
                icone: "emblem-system"
                text: "Réglages réseau…"
                onActive: { panneau.etat.fenetre = true; panneau.fermer() }
                suffixe: Component {
                    Icone { nom: "go-next"; taille: Theme.icons?.sizes.dense ?? 0; couleur: Theme.color?.textTertiary ?? "transparent" }
                }
            }
        }

        // Ligne de mot de passe : une seule à la fois, rattachée au panneau pour rejoindre() et echec().
        Component {
            id: blocMdp
            Bloc {
                id: blocCree
                nom: panneau.deplie === "<autre>" ? "" : panneau.deplie
                erreur: panneau.erreur
                onRejoindre: panneau.rejoindre()
                onAnnuler: { panneau.deplie = ""; panneau.erreur = "" }
                Component.onCompleted: panneau.bloc = blocCree
                Component.onDestruction: if (panneau.bloc === blocCree) panneau.bloc = null
            }
        }
    }
}
