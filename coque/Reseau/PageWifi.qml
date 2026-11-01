import QtQuick
import QtQuick.Layouts
import Quickshell.Networking
import "../Theme"
import "../Composants"
import "../Barre/icones.js" as Icones
import "nmcli.js" as Nmcli

// PageWifi — page de l'onglet Wi-Fi de la fenêtre Réseau (direction D4).
// Rôle : le titre « Wi-Fi » avec l'interrupteur de la radio, puis, radio allumée, quatre cartes : le réseau joint
// (la FicheProfil en mode résumé, qui porte la rangée de tête, le mot de passe à l'œil, la connexion automatique, la
// priorité, la facturation et « Détails… » ; aucune logique nmcli n'est dupliquée ici), les réseaux disponibles,
// les profils enregistrés hors de portée suivis d'« Autre réseau… », et les adresses du réseau joint en lecture
// seule, copiables (Valeur). Radio coupée : le titre et la carte des profils enregistrés seuls.
// Réseaux disponibles : ceux d'etat.reseaux, triés par Nmcli.trierReseaux, sans le réseau joint. Un clic rejoint
// un réseau connu ou ouvert (« Connexion… » et l'Activite sur la rangée) ; sur un réseau inconnu et sécurisé, il
// déplie sous la rangée le BlocSecret (partagé avec le popover), qu'un second clic replie. Un connectionFailed
// déplie la rangée avec « Mot de passe refusé. Vérifiez-le et réessayez. » (secrets absents, refusés, délai
// d'authentification, client déconnecté) ou « Connexion impossible. », comme le popover. Comme lui, l'ordre est figé
// tant qu'une rangée est dépliée, pour ne perdre ni la saisie ni l'erreur. « Rechercher » (accent autonome, plaque
// de survol arrondie) relance « nmcli device wifi rescan » ; l'Activite et « Recherche… » la remplacent jusqu'au
// retour de la liste, au plus motion.delays.scan.
// Balayage : tant que la page est visible dans une fenêtre visible, elle demande le balayage Wi-Fi par
// etat.rechercheFenetre, qu'elle rend à faux à sa destruction ; le popover
// écrit etat.recherche, une autre propriété : EtatReseau balaye tant que l'une des deux est vraie, si bien que la
// fermeture du popover ne coupe pas la demande de la fenêtre, ni l'inverse (voir EtatReseau.balayage).
// Clavier : toutes les rangées cliquables sont des Ligne (tabulation, Entrée, Espace, contour de focus, plaque de
// survol : bible, « Clavier » et « Survol »). Interrupteur : bible, « Interrupteur ». Priorité : Compteur (bible,
// « Compteur »). Formes : jetons Theme.reglages seuls (bible, « Formes »).
// Entrées : panneau, le PanneauReseau (rangees, factures, ouvrirProfil, ouvrirNouveau) ; etat, la source de l'état
// et des actions, EtatReseau par défaut.
// Sorties : joint, la rangée du profil Wi-Fi actif (null sans lui) ; hors, les rangées des profils enregistrés hors
// de portée ; ordre, les noms des réseaux disponibles dans l'ordre affiché ; deplie, le nom de la rangée dépliée ;
// erreur, le message sous son champ ; balayage, vrai pendant la recherche relancée ; fiche, la FicheProfil résumée
// du réseau joint (null sans elle).
// Erreurs : un échec nmcli du résumé s'affiche dans la carte du réseau joint (FicheProfil) ; un réseau qui quitte le
// balayage est masqué et ne peut plus être choisi.
// Dépendances : TitrePage, Section, Groupe, Ligne, FicheProfil, BlocSecret, Interrupteur, Activite, Icone, Texte,
// Valeur, ReglageLigne, Separateur, Carte, Theme (reglages, space, color, icons, motion), nmcli.js (trierReseaux),
// icones.js (iconeReseau), Quickshell.Networking (WifiSecurityType, ConnectionFailReason), PanneauReseau, EtatReseau.
ColumnLayout {
    id: page

    required property var panneau
    property var etat: EtatReseau

    readonly property var joint: panneau.rangees.find(r => r.wifi && r.actif) ?? null
    readonly property var hors: panneau.rangees.filter(r => r.wifi && !r.actif && r.etat === "Hors de portée")
    readonly property var fiche: chargeurJoint.item
    // Réseaux présents au dernier balayage, suivis même liste figée ; ordre en garde les noms triés.
    property var presents: Array.from(etat.reseaux ?? [])
    property var ordre: []
    property string deplie: ""
    property string erreur: ""
    property var enCours: null
    property bool balayage: false
    readonly property real cote: Theme.space?.scale[2] ?? 0

    spacing: 0

    // Demande de balayage de la fenêtre : vrai tant que la page est visible dans une fenêtre visible ; rendue à sa
    // valeur initiale (faux) à la destruction de la page.
    Binding {
        target: page.etat
        property: "rechercheFenetre"
        value: page.visible && (page.Window.window?.visible ?? false)
        restoreMode: Binding.RestoreNone
    }
    // La Binding ne rend pas la valeur à la destruction : la page libère elle-même sa demande.
    Component.onDestruction: etat.rechercheFenetre = false

    // trier — fige l'ordre des réseaux disponibles : le réseau joint en est exclu ; rien ne change tant qu'une
    // rangée de mot de passe est dépliée, pour ne perdre ni la saisie ni le message d'erreur.
    // Entrées : aucune. Sortie : aucune. Erreurs : aucune. Dépendances : nmcli.js (trierReseaux), presents, deplie.
    function trier() {
        if (deplie === "") ordre = Nmcli.trierReseaux(presents.filter(r => !r.connected)).map(r => r.name)
    }
    onDeplieChanged: trier()
    Component.onCompleted: trier()

    // present — le réseau figure-t-il encore au balayage ? Entrée : r, un réseau, éventuellement null. Sortie : bool.
    // Erreurs : aucune. Dépendances : presents.
    function present(r) { return !!r && presents.includes(r) }

    // securise — un réseau demande-t-il un mot de passe ? Entrée : r, un réseau. Sortie : vrai sauf ouvert, OWE ou
    // sécurité inconnue (essayés sans secret). Erreurs : aucune. Dépendances : WifiSecurityType.
    function securise(r) {
        return ![WifiSecurityType.Owe, WifiSecurityType.Open, WifiSecurityType.Unknown].includes(r?.security)
    }

    // iconeSignal — icône de force d'un réseau, aux mêmes paliers que la barre. Entrée : force, de 0 à 1.
    // Sortie : nom « network-wireless-signal-… ». Erreurs : aucune. Dépendances : icones.js (iconeReseau).
    function iconeSignal(force) {
        return Icones.iconeReseau({carte: true, radio: true, connecte: true, connectivite: "full", force})
    }

    // choisir — clic sur un réseau : un réseau connu ou ouvert se rejoint ; un autre déplie (ou replie) son mot de
    // passe ; un réseau déjà en cours de connexion est ignoré. Entrée : r, le réseau. Sortie : aucune.
    // Erreurs : un réseau qui a quitté le balayage est ignoré ; un échec arrive par connectionFailed.
    // Dépendances : present, securise, deplie, enCours.
    function choisir(r) {
        if (!present(r) || r === enCours) return
        erreur = ""
        if (r.known || !securise(r)) {
            deplie = ""
            enCours = r
            r.connect()
        } else deplie = deplie === r.name ? "" : r.name
    }

    // rejoindre — rejoint le réseau déplié avec le mot de passe saisi (connectWithPsk) ; la rangée reste dépliée
    // pendant la connexion, qui la replie à son succès. Entrée : secret, le mot de passe, jamais journalisé.
    // Sortie : aucune. Erreurs : un réseau qui a quitté le balayage replie la rangée. Dépendances : presents.
    function rejoindre(secret) {
        const r = presents.find(x => x.name === deplie) ?? null
        if (!r) {
            deplie = ""
            return
        }
        erreur = ""
        enCours = r
        r.connectWithPsk(secret)
    }

    // echec — connectionFailed du réseau suivi : déplie sa rangée avec le message de la raison. Entrée : raison,
    // ConnectionFailReason. Sortie : aucune. Erreurs : aucune. Dépendances : enCours, ConnectionFailReason.
    function echec(raison) {
        const refus = [ConnectionFailReason.NoSecrets, ConnectionFailReason.WifiClientDisconnected,
                       ConnectionFailReason.WifiClientFailed, ConnectionFailReason.WifiAuthTimeout]
        deplie = enCours.name
        enCours = null
        erreur = refus.includes(raison) ? "Mot de passe refusé. Vérifiez-le et réessayez." : "Connexion impossible."
    }

    // rechercher — relance « nmcli device wifi rescan » et montre l'Activite jusqu'au retour de la liste, au plus
    // finBalayage.interval (motion.delays.scan). Entrées : aucune. Sortie : aucune. Erreurs : aucune.
    // Dépendances : etat.executer, finBalayage.
    function rechercher() {
        balayage = true
        if (finBalayage.interval > 0) finBalayage.restart()
        etat.executer(["device", "wifi", "rescan"])
    }

    Connections {
        target: page.enCours
        function onConnectionFailed(raison) { page.echec(raison) }
        function onConnectedChanged() { if (page.enCours?.connected) { page.deplie = ""; page.enCours = null } }
    }
    Connections {
        target: page.etat
        function onReseauxChanged() {
            page.balayage = false
            finBalayage.stop()
            page.presents = Array.from(page.etat.reseaux ?? [])
            if (page.deplie !== "" && !page.presents.some(r => r.name === page.deplie)) {
                page.deplie = ""
                page.erreur = ""
            }
            page.trier()
        }
        // Le réseau joint a changé : il quitte la liste, et l'ancien y revient.
        function onNomActifChanged() { page.trier() }
    }
    // Borne du retour visuel de la recherche quand le balayage ne change pas la liste ; armée par le seul clic.
    Timer { id: finBalayage; interval: Theme.motion?.delays?.scan ?? 0; onTriggered: page.balayage = false }

    TitrePage {
        text: "Wi-Fi"
        Interrupteur {
            objectName: "radio"
            checked: page.etat.radio
            onToggled: { page.etat.allumer(checked); checked = Qt.binding(() => page.etat.radio) }
        }
    }

    Section { visible: page.etat.radio && page.joint !== null; text: "Réseau joint" }
    Loader {
        id: chargeurJoint
        objectName: "joint"
        active: page.etat.radio && page.joint !== null
        visible: active
        Layout.fillWidth: true
        sourceComponent: FicheProfil {
            width: chargeurJoint.width
            resume: true
            panneauHote: page.panneau
            etat: page.etat
            uuid: page.joint.uuid
            rangee: page.joint
            onRelu: (u, p) => page.panneau.factures = Object.assign({}, page.panneau.factures, {[u]: p.facture})
        }
    }

    // Réseaux disponibles : le titre, puis « Rechercher » ou l'Activite pendant le balayage.
    RowLayout {
        visible: page.etat.radio
        Layout.fillWidth: true
        Section { Layout.fillWidth: true; Layout.alignment: Qt.AlignBottom; text: "Réseaux disponibles" }
        Item {
            Layout.alignment: Qt.AlignBottom
            Layout.rightMargin: page.cote
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
                radius: height / 2
                color: survolRelance.hovered ? Theme.stateColors("surfaceWindow", "none", tapeRelance.pressed ? "pressed" : "hover")?.fill ?? "transparent" : "transparent"
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
                    filet: page.ordre.slice(0, dispo.index).some(n => page.present(page.presents.find(x => x.name === n)))
                    icone: page.iconeSignal(dispo.r?.signalStrength ?? 0)
                    libelle: dispo.modelData
                    aide: dispo.enConnexion ? "Connexion…" : ""
                    cliquable: true
                    onClique: page.choisir(dispo.r)
                    Activite { visible: dispo.enConnexion }
                    Icone {
                        visible: !dispo.enConnexion && page.securise(dispo.r)
                        nom: "network-wireless-encrypted"
                        taille: Theme.icons?.sizes.dense ?? 0
                        couleur: Theme.color?.textTertiary ?? "transparent"
                    }
                }
                Loader {
                    objectName: "bloc"
                    active: dispo.ouverte
                    visible: active
                    Layout.fillWidth: true
                    Layout.leftMargin: Theme.reglages?.textColumn ?? 0
                    Layout.rightMargin: page.cote
                    sourceComponent: BlocSecret {
                        erreur: page.erreur
                        occupe: dispo.enConnexion
                        // Comme le popover, un refus montre le mot de passe saisi.
                        Component.onCompleted: if (page.erreur !== "") secret.revele = true
                        onRejoindre: page.rejoindre(secret.text)
                        onAnnuler: { page.deplie = ""; page.erreur = "" }
                    }
                }
            }
        }
    }

    // Réseaux enregistrés hors de portée, puis « Autre réseau… ».
    Section { visible: page.hors.length > 0; text: page.etat.radio ? "Enregistrés, hors de portée" : "Réseaux enregistrés" }
    Groupe {
        objectName: "enregistres"
        Repeater {
            model: page.hors

            Ligne {
                required property var modelData
                required property int index
                objectName: "hors:" + modelData.uuid
                filet: index > 0
                icone: "network-wireless-offline"
                libelle: modelData.nom
                aide: "Connexion automatique dès qu'il est à portée"
                cliquable: true
                onClique: page.panneau.ouvrirProfil(modelData.uuid)
            }
        }
        Ligne {
            objectName: "autre"
            filet: page.hors.length > 0
            icone: "list-add"
            libelle: "Autre réseau…"
            cliquable: true
            onClique: page.panneau.ouvrirNouveau()
        }
    }

    // Adresses du réseau joint, en lecture seule ; la méthode IPv4 vient du profil lu par la fiche résumée, et la
    // modification d'une adresse fixe reste dans la sous-page. Une valeur vide n'a pas de rangée.
    Section { visible: page.etat.radio && page.joint !== null; text: "Adresses" }
    Carte {
        objectName: "adresses"
        visible: page.etat.radio && page.joint !== null
        Layout.fillWidth: true
        Repeater {
            model: [
                {titre: "Configuration IPv4", valeur: page.fiche?.profil ? (page.fiche.fixe ? "Fixe" : "Automatique") : "", copiable: false},
                {titre: "Adresse IPv4", valeur: page.etat.ip4.join(", "), copiable: true},
                {titre: "Passerelle", valeur: page.etat.passerelle, copiable: true},
                {titre: "DNS", valeur: page.etat.dns.join(", "), copiable: true},
                {titre: "IPv6", valeur: page.etat.ip6.join(", "), copiable: true},
            ].filter(a => a.valeur !== "")

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
                    titre: modelData.titre
                    Valeur { visible: modelData.copiable; text: modelData.valeur }
                    Texte { visible: !modelData.copiable; text: modelData.valeur; color: Theme.color?.textSecondary ?? "transparent" }
                }
            }
        }
    }
}
