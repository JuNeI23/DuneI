import QtQuick
import QtQuick.Layouts
import Quickshell.Networking
import "../Theme"
import "../Composants"
import "../Barre/icones.js" as Icones
import "nmcli.js" as Nmcli

// PopoverReseau — popover du réseau, ancré sous l'indicateur réseau de la barre (L2-11).
// Rôle : un Overlay contextuel, construit à l'ouverture et détruit à la fermeture (D80), tenu à la marge de tuilage
// des bords de l'écran, qui porte, de haut en bas : l'en-tête, dont la bascule à glyphe allume ou coupe le Wi-Fi
// (accent plein allumée, neutre éteinte), avec le nom du réseau et son état (« Connecté », « Connecté sans
// internet », « Portail de connexion », « Partage du téléphone »…) ; derrière un portail captif, « Ouvrir la page de
// connexion » ; la liste des réseaux à proximité (le réseau joint en tête, puis les connus, puis la force
// décroissante ; cadenas si sécurisé, coche sur le réseau joint) avec le bouton de nouvelle recherche, que
// l'indicateur d'activité remplace tant que le balayage relancé n'a pas rendu sa liste ; « Réglages réseau… », qui
// demande la fenêtre Réseau. Un clic sur le réseau joint déplie sous sa ligne « Se déconnecter » et « Détails… » ;
// un clic sur un réseau sécurisé inconnu, ou un échec de connexion, y déplie la ligne de mot de passe ; un second
// clic replie. Le dépliage et le repli animent la hauteur (transition reveal) ; un réseau en cours de connexion
// montre « Connexion… » et l'indicateur d'activité ; quand l'ordre de la liste change (le réseau rejoint remonte en
// tête), chaque ligne glisse de son ancienne place à la nouvelle (transition reflow). Durées et courbes viennent
// toutes de motion.json, par Ressort. Sans carte Wi-Fi, la bascule est désactivée et la liste absente : seulement
// l'état filaire. Tant qu'il est ouvert, il demande le balayage Wi-Fi (etat.recherche), rendu à faux à la fermeture
// comme à la destruction d'un popover ouvert ; ouvert derrière un portail, il demande un contrôle de connectivité
// ponctuel (etat.verifier). La liste ne se retrie pas tant qu'une ligne de mot de passe est dépliée, pour ne pas en
// perdre la saisie. Une connexion suivie (enCours) appartient au panneau : fermé, il est détruit, et un
// connectionFailed tardif ne rouvre rien.
// Entrées : ancre, l'indicateur de la barre ; ouvert, à affecter (voir Overlay) ; associees, voir Overlay ; etat,
// la source de l'état et des actions, EtatReseau par défaut (la coque d'essai y met un factice).
// Sorties : ferme(), voir Overlay ; panneau, le contenu construit, null fermé, lu par les essais.
// Erreurs : un connectionFailed déplie la ligne de mot de passe avec « Mot de passe refusé » (raison
// d'authentification) ou « Connexion impossible ». Le texte d'un mot de passe ne passe jamais au journal.
// Dépendances : Overlay (famille contextuel), Bascule, Activite, Infobulle, Rangee, Bouton, ChampSecret, Separateur,
// Icone, Texte, Coche, Theme (density, motion par Ressort), Ressort, EtatReseau, nmcli.js (trierReseaux, resume),
// icones.js (iconeReseau), Quickshell.Networking (ConnectionFailReason, ConnectionState, WifiSecurityType).
// Cotes : surface de 350 px de large comme la maquette (panneau de 342 px dans le retrait de l'Overlay) ; contenu à
// space.scale[2] (12) du bord du panneau, rangées sur toute sa largeur ; rangées de 32 px.
// Mouvement réduit : la coque n'a pas encore de bascule (voir Ressort) ; les animations passent toutes par Ressort,
// qui la suivra.
Overlay {
    id: popover

    property var etat: EtatReseau
    // Écrit par le panneau seul, à sa construction et à sa destruction.
    property Item panneau: null

    famille: "contextuel"
    margeEcran: Theme.density?.tilingMargin ?? 0
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

    // Encadre — cadre d'une ligne dépliée, au fond du panneau et au filet subtil, comme la maquette.
    // Rôle : empile son contenu en colonne, en retrait de space.scale[1] (8) de chaque bord. Nommé autrement que
    // le Cadre interne de l'Overlay, dont le popover hérite.
    // Entrées : contenu, propriété par défaut, les éléments de la colonne. Sorties : aucune. Erreurs : aucune.
    // Dépendances : Theme.
    component Encadre: Rectangle {
        id: cadre
        default property alias contenu: colonneCadre.data
        readonly property real marge: Theme.space?.scale[1] ?? 0

        implicitHeight: colonneCadre.implicitHeight + 2 * marge
        radius: Theme.radius?.control ?? 0
        color: Theme.color?.surfacePanel ?? "transparent"
        border.width: Theme.hairline(1) ?? 0
        border.color: Theme.color?.borderSubtle ?? "transparent"

        ColumnLayout {
            id: colonneCadre
            x: cadre.marge
            y: cadre.marge
            width: cadre.width - 2 * cadre.marge
            spacing: Theme.space?.scale[1] ?? 0
        }
    }

    // Bloc — ligne de mot de passe dépliée : en-tête, mot de passe, erreur, boutons ; il prend le focus à sa
    // construction. Entrées : nom, le réseau visé ; erreur, message affiché sous le champ ; occupe, vrai pendant la
    // connexion, qui désactive « Rejoindre ». Sorties : secret (ChampSecret) ; signaux rejoindre() et annuler().
    // Erreurs : aucune. Dépendances : Encadre, ChampSecret, Bouton, Texte, Theme.
    component Bloc: Encadre {
        id: bloc
        property string nom
        property string erreur
        property bool occupe: false
        readonly property alias secret: secret
        signal rejoindre()
        signal annuler()

        Component.onCompleted: secret.forceActiveFocus()

        RowLayout {
            spacing: 0
            Texte { text: bloc.nom; echelon: 1; moyen: true; elide: Text.ElideRight; Layout.maximumWidth: bloc.width / 2 }
            Texte {
                Layout.fillWidth: true
                text: " · réseau protégé"
                echelon: 1
                color: Theme.color?.textSecondary ?? "transparent"
                elide: Text.ElideRight
            }
        }
        ChampSecret { id: secret; Layout.fillWidth: true; placeholderText: "Mot de passe"; onAccepted: if (!bloc.occupe) bloc.rejoindre() }
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
            Bouton { text: "Rejoindre"; principal: true; enabled: !bloc.occupe; onClicked: bloc.rejoindre() }
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
        // chaque variation de force et déplacerait les rangées sous le pointeur et sous la saisie. ordre en garde
        // les noms, qui restent lisibles même quand un WifiNetwork de la liste figée a été détruit.
        property var reseaux: []
        property var ordre: []
        // Réseaux présents au dernier balayage, suivis même liste figée : un réseau de la liste figée qui n'y figure
        // plus est masqué et ne peut plus être choisi ni rejoint (son WifiNetwork peut avoir été détruit).
        property var presents: Array.from(etat.reseaux ?? [])
        // Nom du réseau dont la ligne est dépliée, vide sinon ; mode, ce qu'elle porte : « actions » sous le réseau
        // joint, « mdp » (mot de passe) sous un autre.
        property string deplie: ""
        property string mode: "mdp"
        property string erreur: ""
        property var enCours: null
        // Vrai entre un clic sur la recherche et le retour de la liste, borné par finBalayage.
        property bool balayage: false
        // Nom → délégué de la liste, tenu par les délégués eux-mêmes.
        property var delegues: ({})
        // Nom → ordonnée de la ligne dans la liste, sans glissement : la somme des hauteurs des lignes qui la
        // précèdent dans ordre (une ligne masquée a une hauteur nulle) ; « » donne la hauteur de la liste. Calculée
        // ici d'un seul tenant, et non de proche en proche par chaque ligne, pour qu'un nouvel ordre ne forme
        // jamais de boucle entre deux lignes qui échangent leur place.
        readonly property var bases: {
            const b = {}
            let y = 0
            for (const nom of ordre) {
                b[nom] = y
                y += delegues[nom]?.height ?? 0
            }
            b[""] = y
            return b
        }
        // Ligne de mot de passe de la ligne dépliée, null sans elle (ni pendant le repli d'une autre).
        readonly property Item bloc: delegues[deplie]?.bloc ?? null

        focus: true
        implicitWidth: 342
        implicitHeight: colonne.implicitHeight + 2 * (Theme.space?.scale[1] ?? 0)
        Component.onCompleted: { trier(); popover.panneau = panneau }
        Component.onDestruction: if (popover.panneau === panneau) popover.panneau = null

        // trier — fige l'ordre de la liste et met le modèle des lignes à jour : un nom nouveau y est ajouté, un nom
        // disparu retiré, les autres lignes restent et glissent de leur place d'avant à la nouvelle. Tant qu'une
        // ligne de mot de passe est dépliée, rien ne change, pour ne perdre ni la saisie ni le message d'erreur ; le
        // tri reprend dès qu'elle se replie. Entrées : aucune. Sortie : aucune. Erreurs : aucune.
        // Dépendances : nmcli.js (trierReseaux), etat.reseaux, deplie, mode, modele, delegues (glisser).
        function trier(): void {
            if (deplie !== "" && mode === "mdp") return
            const avant = Object.entries(delegues).map(([nom, d]) => [nom, d.y])
            reseaux = Nmcli.trierReseaux(Array.from(etat.reseaux ?? []))
            ordre = reseaux.map(r => r.name)
            for (let i = modele.count - 1; i >= 0; i--) if (!ordre.includes(modele.get(i).cle)) modele.remove(i)
            const connus = Array.from({ length: modele.count }, (_, i) => modele.get(i).cle)
            for (const nom of ordre) if (!connus.includes(nom)) modele.append({ cle: nom })
            for (const [nom, y] of avant) delegues[nom]?.glisser(y)
        }
        onDeplieChanged: trier()

        // inscrire, desinscrire — tiennent la table delegues à la construction et à la destruction d'une ligne.
        // Entrées : nom, la clé de la ligne ; d, son délégué. Sortie : aucune. Erreurs : aucune ; desinscrire
        // ignore un délégué qui a déjà été remplacé. Dépendances : delegues.
        function inscrire(nom: string, d: Item): void { delegues = Object.assign({}, delegues, { [nom]: d }) }
        function desinscrire(nom: string, d: Item): void {
            if (delegues[nom] !== d) return
            const reste = Object.assign({}, delegues)
            delete reste[nom]
            delegues = reste
        }

        // present — le réseau figure-t-il encore au balayage ? Entrée : r, un réseau, éventuellement null (objet
        // détruit). Sortie : bool. Erreurs : aucune. Dépendances : presents.
        function present(r): bool { return !!r && presents.includes(r) }

        // replierAbsent — replie la ligne dépliée si son réseau a quitté le balayage ; le repli relance le tri.
        // Entrées : aucune. Sortie : aucune. Erreurs : aucune. Dépendances : deplie, presents.
        function replierAbsent(): void {
            if (deplie !== "" && !presents.some(r => r.name === deplie)) {
                deplie = ""
                erreur = ""
            }
        }

        // securise — un réseau demande-t-il un mot de passe ? Entrée : r, un réseau. Sortie : vrai sauf ouvert,
        // OWE ou sécurité inconnue (essayés sans secret). Erreurs : aucune. Dépendances : WifiSecurityType.
        function securise(r): bool {
            return ![WifiSecurityType.Owe, WifiSecurityType.Open, WifiSecurityType.Unknown].includes(r?.security)
        }

        // deplier — déplie la ligne d'un réseau dans un mode, ou la replie si elle l'était déjà.
        // Entrées : nom, le réseau ; m, « actions » ou « mdp ». Sortie : aucune. Erreurs : aucune.
        // Dépendances : deplie, mode.
        function deplier(nom: string, m: string): void {
            const replier = deplie === nom
            mode = m
            deplie = replier ? "" : nom
        }

        // choisir — clic sur un réseau : sous le réseau joint, déplie (ou replie) ses actions ; un réseau connu ou
        // ouvert se rejoint directement ; sous un autre, déplie (ou replie) la ligne de mot de passe ; un réseau
        // déjà en cours de connexion est ignoré. Entrée : r, le réseau. Sortie : aucune. Erreurs : un réseau qui
        // n'est plus au balayage est ignoré ; un échec arrive par connectionFailed (voir Connections).
        // Dépendances : present, securise, deplier, enCours.
        function choisir(r): void {
            if (!present(r) || r === enCours) return
            erreur = ""
            if (r.connected) deplier(r.name, "actions")
            else if (r.known || !securise(r)) {
                deplie = ""
                enCours = r
                r.connect()
            } else deplier(r.name, "mdp")
        }

        // rejoindre — valide la ligne de mot de passe dépliée par connectWithPsk ; la ligne reste dépliée pendant
        // la connexion, qui la replie à son succès. Entrées : aucune. Sortie : aucune. Erreurs : réseau qui n'est
        // plus au balayage, la ligne se replie. Dépendances : bloc, presents, enCours.
        function rejoindre(): void {
            if (!bloc) return
            const r = presents.find(x => x.name === deplie) ?? null
            if (!r) {
                deplie = ""
                return
            }
            erreur = ""
            enCours = r
            r.connectWithPsk(bloc.secret.text)
        }

        // deconnecter — « Se déconnecter » sous le réseau joint : replie ses actions et le déconnecte.
        // Entrée : r, le réseau. Sortie : aucune. Erreurs : réseau détruit, rien n'est fait. Dépendances : deplie.
        function deconnecter(r): void {
            deplie = ""
            r?.disconnect()
        }

        // details — « Détails… » sous le réseau joint : demande la fenêtre Réseau sur son profil (l'uuid du profil
        // Wi-Fi actif, sinon le nom du réseau), puis ferme le popover. Entrée : r, le réseau. Sortie : aucune.
        // Erreurs : aucune. Dépendances : etat (profils, profilDemande, fenetre), fermer.
        function details(r): void {
            etat.profilDemande = (etat.profils ?? []).find(p => p.actif && p.type === "802-11-wireless")?.uuid
                ?? r?.name ?? ""
            etat.fenetre = true
            fermer()
        }

        // echec — connectionFailed du réseau suivi : déplie sa ligne de mot de passe avec le message de la raison,
        // secret révélé comme sur la maquette. Entrée : raison, ConnectionFailReason : secrets absents ou refusés,
        // client déconnecté, échec ou délai d'authentification donnent « Mot de passe refusé », les autres
        // « Connexion impossible ». Sortie : aucune. Erreurs : aucune. Dépendances : enCours, bloc,
        // ConnectionFailReason.
        function echec(raison): void {
            const refus = [ConnectionFailReason.NoSecrets, ConnectionFailReason.WifiClientDisconnected,
                           ConnectionFailReason.WifiClientFailed, ConnectionFailReason.WifiAuthTimeout]
            mode = "mdp"
            deplie = enCours.name
            enCours = null
            erreur = refus.includes(raison) ? "Mot de passe refusé. Vérifiez-le et réessayez." : "Connexion impossible."
            if (bloc) bloc.secret.revele = true
        }

        // rechercher — relance le balayage (« nmcli device wifi rescan ») et montre l'indicateur d'activité jusqu'au
        // retour de la liste, au plus finBalayage.interval. Entrées : aucune. Sortie : aucune. Erreurs : aucune.
        // Dépendances : etat.executer, finBalayage.
        function rechercher(): void {
            balayage = true
            finBalayage.restart()
            etat.executer(["device", "wifi", "rescan"])
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
                panneau.balayage = false
                finBalayage.stop()
                panneau.presents = Array.from(panneau.etat.reseaux ?? [])
                panneau.replierAbsent()
                panneau.trier()
            }
            // Le réseau joint a changé : ses actions dépliées n'ont plus d'objet.
            function onNomActifChanged() {
                if (panneau.mode === "actions") panneau.deplie = ""
                panneau.trier()
            }
        }
        // Borne du retour visuel de la recherche quand le balayage ne change pas la liste ; armé par le seul clic.
        Timer { id: finBalayage; interval: 6000; onTriggered: panneau.balayage = false }
        // Une entrée par nom de réseau ; l'ordre affiché vient de ordre, pas du modèle.
        ListModel { id: modele }

        ColumnLayout {
            id: colonne
            y: Theme.space?.scale[1] ?? 0
            width: panneau.width
            spacing: Theme.space?.scale[0] ?? 0

            // En-tête : la bascule du Wi-Fi, le titre et l'état.
            RowLayout {
                Layout.leftMargin: panneau.marge
                Layout.rightMargin: panneau.marge
                Layout.bottomMargin: Theme.space?.scale[0] ?? 0
                spacing: Theme.space?.scale[2] ?? 0

                // Elle suit la radio réelle après chaque bascule ; sans carte Wi-Fi, désactivée, elle montre le lien.
                Bascule {
                    id: bascule
                    objectName: "bascule"
                    readonly property bool allumee: panneau.etat.carte ? panneau.etat.radio : panneau.etat.connecte
                    icone: panneau.etat.icone
                    enabled: panneau.etat.carte
                    checked: allumee
                    onToggled: { panneau.etat.allumer(checked); checked = Qt.binding(() => bascule.allumee) }
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
                }
            }

            // Portail captif : la page de connexion s'ouvre dans le navigateur, et la connectivité est revérifiée.
            Encadre {
                visible: panneau.etat.connectivite === "portal"
                Layout.fillWidth: true
                Layout.leftMargin: Theme.space?.scale[1] ?? 0
                Layout.rightMargin: Layout.leftMargin
                Texte { Layout.fillWidth: true; text: "Cette connexion demande une page de connexion."; echelon: 1; wrapMode: Text.Wrap }
                Bouton {
                    Layout.alignment: Qt.AlignRight
                    icone: "web-browser"
                    text: "Ouvrir la page de connexion"
                    principal: true
                    onClicked: { panneau.etat.ouvrirPortail(); panneau.fermer() }
                }
            }

            Separateur { visible: panneau.listeVisible; Layout.fillWidth: true; Layout.topMargin: Theme.space?.scale[0] ?? 0 }

            RowLayout {
                visible: panneau.listeVisible
                Layout.leftMargin: panneau.marge
                Layout.rightMargin: Theme.space?.scale[1] ?? 0
                Texte { Layout.fillWidth: true; text: "RÉSEAUX À PROXIMITÉ"; echelon: 0; moyen: true; color: Theme.color?.textTertiary ?? "transparent" }
                // Recherche : l'icône, ou l'indicateur d'activité pendant un balayage relancé.
                Item {
                    id: recherche
                    objectName: "recherche"
                    implicitWidth: Theme.density?.controlHeight ?? 0
                    implicitHeight: implicitWidth
                    BoutonIcone { anchors.fill: parent; visible: !panneau.balayage; nom: "view-refresh"; onClique: panneau.rechercher() }
                    Activite { objectName: "activiteRecherche"; anchors.centerIn: parent; visible: panneau.balayage }
                    Infobulle { objectName: "infobulleRecherche"; cible: recherche; texte: "Rechercher les réseaux" }
                }
            }

            Flickable {
                visible: panneau.listeVisible
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(contentHeight, 8 * panneau.hauteurLigne)
                contentHeight: lignes.height
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                // Chaque ligne se pose à son ordonnée (bases), plus son décalage de glissement.
                Item {
                    id: lignes
                    width: parent.width
                    height: panneau.bases[""]

                    Repeater {
                        model: panneau.listeVisible ? modele : null

                        delegate: Item {
                            id: ligne
                            required property string cle
                            readonly property int rang: panneau.ordre.indexOf(cle)
                            // Lectures sûres : le WifiNetwork d'une liste figée peut avoir été détruit (null).
                            readonly property var modelData: panneau.reseaux[rang] ?? null
                            readonly property bool joint: modelData?.connected ?? false
                            readonly property bool montre: panneau.present(modelData)
                            readonly property bool ouverte: panneau.deplie === cle
                            readonly property bool enConnexion: panneau.enCours !== null && panneau.enCours === modelData
                                || modelData?.state === ConnectionState.Connecting
                            readonly property real base: panneau.bases[cle] ?? 0
                            // Mode retenu à l'ouverture : il reste pendant le repli, même si une autre ligne se déplie.
                            property string modeCharge: "mdp"
                            readonly property Item bloc: ouverte && modeCharge === "mdp" ? charge.item : null
                            readonly property alias depliage: depliage
                            readonly property alias decalage: decalage

                            width: lignes.width
                            height: montre ? rangee.height + depliage.value : 0
                            visible: montre
                            y: base + decalage.value
                            Component.onCompleted: panneau.inscrire(cle, ligne)
                            Component.onDestruction: panneau.desinscrire(cle, ligne)
                            onOuverteChanged: if (ouverte) modeCharge = panneau.mode

                            // glisser — fait partir la ligne de sa place d'avant un nouveau tri vers la nouvelle,
                            // par le ressort reflow, depuis sa position courante même en plein glissement.
                            // Entrée : avant, l'ordonnée affichée avant le tri. Sortie : aucune. Erreurs : aucune.
                            // Dépendances : decalage (Ressort), base.
                            function glisser(avant: real): void {
                                const ecart = avant - base
                                if (Math.abs(ecart) < 0.5) return
                                decalage.cible = ecart
                                decalage.poser()
                                decalage.cible = 0
                            }

                            Ressort { id: decalage; transition: "reflow"; cible: 0 }
                            Ressort {
                                id: depliage
                                transition: "reveal"
                                cible: ligne.ouverte ? charge.implicitHeight + (Theme.space?.scale[0] ?? 0) : 0
                            }

                            Rangee {
                                id: rangee
                                index: 0
                                width: parent.width
                                implicitHeight: panneau.hauteurLigne
                                hoverEnabled: true
                                icone: panneau.iconeSignal(ligne.modelData?.signalStrength ?? 0)
                                text: ligne.cle
                                accentue: ligne.joint
                                onActive: panneau.choisir(ligne.modelData)
                                suffixe: Component {
                                    Row {
                                        spacing: Theme.space?.scale[1] ?? 0
                                        Texte {
                                            anchors.verticalCenter: parent.verticalCenter
                                            visible: ligne.enConnexion
                                            text: "Connexion…"
                                            echelon: 1
                                            color: Theme.color?.textSecondary ?? "transparent"
                                        }
                                        Activite { anchors.verticalCenter: parent.verticalCenter; visible: ligne.enConnexion }
                                        Icone {
                                            anchors.verticalCenter: parent.verticalCenter
                                            visible: panneau.securise(ligne.modelData)
                                            nom: "network-wireless-encrypted"
                                            taille: Theme.icons?.sizes.dense ?? 0
                                            couleur: Theme.color?.textTertiary ?? "transparent"
                                        }
                                        Coche {
                                            anchors.verticalCenter: parent.verticalCenter
                                            visible: ligne.joint
                                            width: Theme.icons?.sizes.dense ?? 0
                                            height: width
                                            couleur: Theme.color?.accentStandalone ?? "transparent"
                                        }
                                    }
                                }
                            }

                            // Ligne dépliée, découpée à la hauteur du ressort ; elle vit jusqu'à la fin du repli.
                            Item {
                                y: rangee.height
                                width: parent.width
                                height: depliage.value
                                clip: true
                                Loader {
                                    id: charge
                                    active: ligne.ouverte || depliage.value > 0
                                    x: Theme.space?.scale[1] ?? 0
                                    width: parent.width - 2 * x
                                    sourceComponent: ligne.modeCharge === "actions" ? actions : mdp
                                }
                            }

                            Component {
                                id: mdp
                                Bloc {
                                    nom: ligne.cle
                                    erreur: ligne.ouverte ? panneau.erreur : ""
                                    occupe: ligne.enConnexion
                                    onRejoindre: panneau.rejoindre()
                                    onAnnuler: { panneau.deplie = ""; panneau.erreur = "" }
                                }
                            }
                            Component {
                                id: actions
                                Encadre {
                                    RowLayout {
                                        Layout.alignment: Qt.AlignRight
                                        spacing: Theme.space?.scale[1] ?? 0
                                        Bouton { text: "Se déconnecter"; onClicked: panneau.deconnecter(ligne.modelData) }
                                        Bouton { text: "Détails…"; onClicked: panneau.details(ligne.modelData) }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Separateur { Layout.fillWidth: true; Layout.topMargin: Theme.space?.scale[0] ?? 0 }

            Rangee {
                index: 0
                Layout.fillWidth: true
                implicitHeight: panneau.hauteurLigne
                hoverEnabled: true
                icone: "emblem-system"
                text: "Réglages réseau…"
                onActive: { panneau.etat.fenetre = true; panneau.fermer() }
            }
        }
    }
}
