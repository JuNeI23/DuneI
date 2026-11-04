import QtQuick
import QtQuick.Layouts
import Quickshell.Networking
import "../Theme"
import "../Composants"
import "../Barre/icones.js" as Icones
import "nmcli.js" as Nmcli

// PopoverReseau — popover du réseau, ancré sous l'indicateur réseau de la barre (L2-11, direction D5 des essais).
// Rôle : un Overlay contextuel dont le contenu est construit une fois pour toutes et que l'hôte des popovers montre ou
// cache (il n'est plus détruit à la fermeture ; D80 reste vrai pour un popover non hébergé), tenu à la marge d'écran
// des overlays ancrés à la barre (Overlay.margeEcran). Il suit les popovers sobres d'inspiration/anhphong : compact,
// carré, sur le verre de E3 (D103), il porte de haut en bas : l'en-tête, dont la bascule à glyphe allume ou coupe le
// Wi-Fi (accent plein allumée, neutre éteinte), avec le nom du réseau joint et son état (« Connecté », « Connecté
// sans internet », « Portail de connexion », « Partage du téléphone »…) ; derrière un portail captif, « Ouvrir la
// page de connexion » ; « Réseaux à proximité », petite étiquette au texte secondaire avec le bouton de nouvelle
// recherche, que l'indicateur d'activité remplace tant que le balayage relancé n'a pas rendu sa liste ; la liste des
// réseaux à proximité, une ligne chacun (signal, nom, cadenas si sécurisé), les connus puis la force décroissante,
// sans le réseau joint, que l'en-tête nomme déjà ; sous un filet translucide (material.glassLine), les actions en
// texte seul, à la manière d'un menu : « Se déconnecter » tant qu'un réseau Wi-Fi est joint, et « Réglages
// réseau… », qui demande la fenêtre Réseau. Un clic sur un réseau sécurisé inconnu, ou un échec de connexion, déplie
// sous sa ligne le mot de passe, sans plaque ; un second clic replie. Le dépliage et le repli animent la hauteur
// (transition reveal) ; un réseau en cours de connexion montre « Connexion… » et l'indicateur d'activité ; quand
// l'ordre de la liste change, chaque ligne glisse de son ancienne place à la nouvelle (transition reflow) ; une ligne
// qui paraît au balayage s'ouvre, une ligne qui le quitte se referme (hauteur et fondu, transition reveal), et ses
// voisines suivent sa hauteur sans sauter : ainsi le réseau qu'on vient de rejoindre quitte la liste pour l'en-tête,
// et l'ancien réseau joint y revient. Durées et courbes viennent toutes de motion.json, par Ressort. Sans carte
// Wi-Fi, la bascule est désactivée et la liste absente : seulement l'état filaire. Tant qu'il est ouvert, il demande
// le balayage Wi-Fi (etat.recherche), rendu à faux à la fermeture comme à la destruction d'un popover ouvert ;
// ouvert derrière un portail, il demande un contrôle de connectivité ponctuel (etat.verifier). La liste ne se retrie
// pas tant qu'une ligne de mot de passe est dépliée, pour ne pas en perdre la saisie. Une connexion suivie (enCours)
// appartient au panneau, qui survit à la fermeture : un connectionFailed tardif déplie la ligne du réseau, et
// reinitialiser() ne l'annule pas.
// Popover de la barre (D108) : en ouvrir un autre le ferme ; il se ferme 1,5 s après le départ de la souris, sauf
// pendant une saisie ou une connexion suivie (retenu). Pour l'hôte, le panneau offre fonduContenu et fonduDisque,
// deux fondus distincts (la bascule d'en-tête, posée sur un emplacement réservé hors de la colonne, ne suit que le
// second), et reinitialiser(), qui rend à la vue l'aspect d'un popover neuf sans couper une connexion en cours.
// Entrées : ancre, l'indicateur de la barre ; ouvert, à affecter (voir Overlay) ; associees, voir Overlay ; etat,
// la source de l'état et des actions, EtatReseau par défaut (la coque d'essai y met un factice).
// Sorties : ferme(), voir Overlay ; panneau, le contenu construit (null tant qu'il ne l'est pas, ou une fois détruit),
// lu par les essais ; fonduContenu, fonduDisque, reinitialiser(), voir ci-dessus.
// Erreurs : un connectionFailed déplie la ligne de mot de passe avec « Mot de passe refusé » (raison
// d'authentification) ou « Connexion impossible ». Le texte d'un mot de passe ne passe jamais au journal.
// Dépendances : Overlay (famille contextuel), Bascule, Activite, Infobulle, Rangee, Bouton, BlocSecret, Jonction, Separateur,
// Icone, Texte, Theme (density, space, material, motion par Ressort), Ressort, EtatReseau, nmcli.js (trierReseaux,
// resume), icones.js (iconeForce), Quickshell.Networking (ConnectionFailReason, ConnectionState, WifiSecurityType).
// Cotes : surface de 72 × space.scale[0] (288 px) de large comme l'essai D5, panneau de 280 px dans le retrait de
// l'Overlay ; contenu à space.scale[2] (12) du bord du panneau, rangées sur toute sa largeur ; rangées de
// density.controlHeight plus space.scale[0] (32 px).
// Mouvement réduit (Theme.mouvementReduit) : les animations passent toutes par Ressort. Le déplacement et le
// dépliage des lignes se posent aussitôt, et seule l'opacité des lignes (nature « fondu ») s'anime, en fondu court.
Overlay {
    id: popover

    property var etat: EtatReseau
    // Écrit par le panneau seul, à sa construction et à sa destruction (null avant la première et après la seconde).
    property Item panneau: null

    famille: "contextuel"
    // Popover de la barre (D108) : exclusif, et fermé 1,5 s après le départ de la souris, sauf tant qu'une ligne de
    // mot de passe est dépliée ou qu'une connexion suivie est en cours.
    exclusif: true
    fermeAuDepart: true
    retenu: panneau !== null && (panneau.deplie !== "" || panneau.enCours !== null)
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

    // Encadre — cadre de l'avis de portail captif, au fond du panneau et au filet subtil.
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
        // Ordre d'affichage : ordre, plus les lignes qui sortent (leur réseau a quitté le tri), gardées à leur ancien
        // rang le temps de se refermer, pour que les lignes voisines suivent leur hauteur au lieu de sauter.
        property var disposition: []
        // Faux pendant le premier tri, qui a lieu à la construction de la coque : les lignes déjà présentes paraissent
        // d'emblée, seules celles qui arrivent ensuite entrent.
        property bool trie: false
        // Réseaux présents au dernier balayage, suivis même liste figée : un réseau de la liste figée qui n'y figure
        // plus est masqué et ne peut plus être choisi ni rejoint (son WifiNetwork peut avoir été détruit).
        property alias presents: jonction.presents
        // Nom du réseau dont la ligne de mot de passe est dépliée, vide sinon.
        property alias deplie: jonction.deplie
        property alias erreur: jonction.erreur
        property alias enCours: jonction.enCours
        // Vrai entre un clic sur la recherche et le retour de la liste, borné par finBalayage.
        property bool balayage: false
        // Nom → délégué de la liste, tenu par les délégués eux-mêmes.
        property var delegues: ({})
        // Nom → ordonnée de la ligne dans la liste, sans glissement : la somme des hauteurs des lignes qui la
        // précèdent dans disposition (une ligne refermée a une hauteur nulle) ; « » donne la hauteur de la liste. Calculée
        // ici d'un seul tenant, et non de proche en proche par chaque ligne, pour qu'un nouvel ordre ne forme
        // jamais de boucle entre deux lignes qui échangent leur place.
        readonly property var bases: {
            const b = {}
            let y = 0
            for (const nom of disposition) {
                b[nom] = y
                y += delegues[nom]?.height ?? 0
            }
            b[""] = y
            return b
        }
        // Réseau Wi-Fi joint, que « Se déconnecter » vise ; null sans lui.
        readonly property var joint: presents.find(r => r.connected) ?? null
        // Ligne de mot de passe de la ligne dépliée, null sans elle (ni pendant le repli d'une autre).
        readonly property Item bloc: delegues[deplie]?.bloc ?? null

        // Fondus que l'hôte des popovers pose, de 0 à 1 : fonduContenu pour tout l'en-tête sauf la bascule et pour le
        // reste du contenu, fonduDisque pour la bascule seule. Sans hôte, ils restent à 1 : le panneau est tel quel.
        property real fonduContenu: 1
        property real fonduDisque: 1

        focus: true
        implicitWidth: 70 * (Theme.space?.scale[0] ?? 0)
        implicitHeight: colonne.implicitHeight + 2 * (Theme.space?.scale[1] ?? 0)
        Component.onCompleted: { trier(); popover.panneau = panneau }
        Component.onDestruction: if (popover.panneau === panneau) popover.panneau = null

        // reinitialiser — rend au contenu l'aspect d'un popover neuf : ligne de mot de passe repliée, saisie et message
        // d'erreur effacés, mot de passe de nouveau masqué, liste en haut, retour visuel du balayage éteint. Une connexion
        // suivie (enCours) n'est jamais annulée : seule la vue revient à neuf, et le popover reste retenu tant qu'elle dure.
        // Entrées : aucune. Sortie : aucune. Erreurs : aucune.
        // Dépendances : bloc, deplie, erreur, balayage, finBalayage, liste.
        function reinitialiser(): void {
            if (bloc) { bloc.secret.text = ""; bloc.secret.revele = false }
            deplie = ""
            erreur = ""
            balayage = false
            finBalayage.stop()
            liste.contentY = 0
        }

        // releve — ordonnées affichées des lignes, à relever avant tout changement qui les déplace.
        // Entrées : aucune. Sortie : tableau de [nom, ordonnée]. Erreurs : aucune. Dépendances : delegues.
        function releve(): var { return Object.entries(delegues).map(([nom, d]) => [nom, d.y]) }

        // trier — fige l'ordre de la liste et met le modèle des lignes à jour : un nom nouveau y est ajouté (sa
        // ligne entre en s'ouvrant, sauf au premier tri), un nom disparu reste à son ancien rang dans disposition le
        // temps que sa ligne se referme (elle se retire elle-même ensuite, voir retirer), les autres lignes glissent
        // de leur place relevée à la nouvelle. Le réseau joint n'y figure pas : l'en-tête le nomme. Tant qu'une ligne
        // de mot de passe est dépliée, rien ne change, pour ne perdre ni la saisie ni le message d'erreur ; le tri
        // reprend dès qu'elle se replie.
        // Entrée : avant, ordonnées relevées avant le changement qui provoque le tri (releve() par défaut).
        // Sortie : aucune. Erreurs : aucune.
        // Dépendances : nmcli.js (trierReseaux), etat.reseaux, deplie, modele, disposition, delegues (glisser).
        function trier(avant = releve()): void {
            if (deplie !== "") return
            reseaux = Nmcli.trierReseaux(Array.from(etat.reseaux ?? []).filter(r => !r.connected))
            ordre = reseaux.map(r => r.name)
            const connus = Array.from({ length: modele.count }, (_, i) => modele.get(i).cle)
            const d = ordre.slice()
            for (const [i, nom] of disposition.entries())
                if (!ordre.includes(nom) && connus.includes(nom)) d.splice(Math.min(i, d.length), 0, nom)
            disposition = d
            for (const nom of ordre) if (!connus.includes(nom)) modele.append({ cle: nom, entre: trie })
            trie = true
            for (const [nom, y] of avant) delegues[nom]?.glisser(y)
        }
        onDeplieChanged: trier()

        // retirer — ôte du modèle et de disposition la ligne d'un nom qui a quitté le tri, une fois refermée ; un nom
        // revenu au tri entre-temps est gardé. Entrée : nom. Sortie : aucune. Erreurs : aucune.
        // Dépendances : modele, ordre, disposition.
        function retirer(nom: string): void {
            if (ordre.includes(nom)) return
            for (let i = modele.count - 1; i >= 0; i--) if (modele.get(i).cle === nom) modele.remove(i)
            disposition = disposition.filter(n => n !== nom)
        }

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

        // present, choisir, securise — délèguent à la Jonction (logique partagée avec la page Wi-Fi de la fenêtre) ; voir Jonction.
        function present(r): bool { return jonction.present(r) }
        function choisir(r): void { jonction.choisir(r) }
        function securise(r): bool { return jonction.securise(r) }

        // rejoindre — valide la ligne de mot de passe dépliée par la Jonction ; sans ligne dépliée, ne fait rien.
        // Entrées : aucune. Sortie : aucune. Erreurs : voir Jonction.rejoindre. Dépendances : bloc, jonction.
        function rejoindre(): void { if (bloc) jonction.rejoindre(bloc.secret.text) }

        // deconnecter — « Se déconnecter » du pied : déconnecte le réseau Wi-Fi joint et ferme le popover.
        // Entrées : aucune. Sortie : aucune. Erreurs : sans réseau joint, rien n'est fait. Dépendances : joint, fermer.
        function deconnecter(): void {
            joint?.disconnect()
            fermer()
        }

        // rechercher — relance le balayage (« nmcli device wifi rescan ») et montre l'indicateur d'activité jusqu'au
        // retour de la liste, au plus finBalayage.interval (motion.delays.scan ; sans mouvement chargé, jusqu'au
        // retour de la liste). Entrées : aucune. Sortie : aucune. Erreurs : aucune.
        // Dépendances : etat.executer, finBalayage.
        function rechercher(): void {
            balayage = true
            if (finBalayage.interval > 0) finBalayage.restart()
            etat.executer(["device", "wifi", "rescan"])
        }

        // fermer — referme le popover après une action qui ouvre autre chose. Entrées : aucune. Sortie : aucune.
        function fermer(): void { popover.ouvert = false }

        // Logique de connexion partagée avec la page Wi-Fi ; un refus révèle le mot de passe saisi, comme sur la maquette.
        Jonction {
            id: jonction
            etat: popover.etat
            onRefuse: if (panneau.bloc) panneau.bloc.secret.revele = true
        }
        Connections {
            target: panneau.etat
            // Les ordonnées sont relevées avant tout changement : présents, repli et tri déplacent les lignes.
            function onReseauxChanged() {
                const avant = panneau.releve()
                panneau.balayage = false
                finBalayage.stop()
                jonction.actualiser()
                panneau.trier(avant)
            }
            // Le réseau joint a changé : il quitte la liste, et l'ancien y revient.
            function onNomActifChanged() { panneau.trier() }
        }
        // Borne du retour visuel de la recherche quand le balayage ne change pas la liste (motion.delays.scan) ;
        // armée par le seul clic.
        Timer { id: finBalayage; interval: Theme.motion?.delays?.scan ?? 0; onTriggered: panneau.balayage = false }
        // Une entrée par nom de réseau ; l'ordre affiché vient de ordre, pas du modèle.
        ListModel { id: modele }

        // Elle suit la radio réelle après chaque bascule ; sans carte Wi-Fi, désactivée, elle montre le lien. Elle est
        // déclarée avant la colonne : elle garde sa place dans l'ordre de tabulation, la première, et se pose par-dessus
        // l'emplacement que l'en-tête lui réserve, au pixel près.
        Bascule {
            id: bascule
            objectName: "bascule"
            z: 1
            x: colonne.x + entete.x + emplacement.x
            y: colonne.y + entete.y + emplacement.y
            opacity: panneau.fonduDisque
            readonly property bool allumee: panneau.etat.carte ? panneau.etat.radio : panneau.etat.connecte
            icone: panneau.etat.icone
            enabled: panneau.etat.carte
            checked: allumee
            onToggled: { panneau.etat.allumer(checked); checked = Qt.binding(() => bascule.allumee) }
        }

        ColumnLayout {
            id: colonne
            opacity: panneau.fonduContenu
            y: Theme.space?.scale[1] ?? 0
            width: panneau.width
            spacing: Theme.space?.scale[0] ?? 0

            // En-tête : l'emplacement de la bascule du Wi-Fi, le titre et l'état.
            RowLayout {
                id: entete
                Layout.leftMargin: panneau.marge
                Layout.rightMargin: panneau.marge
                Layout.bottomMargin: Theme.space?.scale[0] ?? 0
                spacing: Theme.space?.scale[2] ?? 0

                // Emplacement réservé à la bascule, de sa taille : elle s'y pose sans faire partie de la colonne, pour que
                // le fondu du contenu ne l'atteigne pas (voir fonduContenu et fonduDisque).
                Item { id: emplacement; implicitWidth: bascule.implicitWidth; implicitHeight: bascule.implicitHeight }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    Texte { Layout.fillWidth: true; text: panneau.resume.titre; echelon: 2; moyen: true; elide: Text.ElideRight; color: Theme.color?.textEmphasis ?? "transparent" }
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

            RowLayout {
                visible: panneau.listeVisible
                Layout.leftMargin: panneau.marge
                Layout.rightMargin: Theme.space?.scale[1] ?? 0
                Texte { Layout.fillWidth: true; text: "Réseaux à proximité"; echelon: 0; moyen: true; color: Theme.color?.textSecondary ?? "transparent" }
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
                id: liste
                objectName: "liste"
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
                            // Vrai pour une ligne ajoutée après le premier tri : elle entre en s'ouvrant.
                            required property bool entre
                            readonly property int rang: panneau.ordre.indexOf(cle)
                            // Lectures sûres : le WifiNetwork d'une liste figée peut avoir été détruit (null).
                            readonly property var modelData: panneau.reseaux[rang] ?? null
                            readonly property bool montre: panneau.present(modelData)
                            readonly property bool ouverte: panneau.deplie === cle
                            readonly property bool enConnexion: panneau.enCours !== null && panneau.enCours === modelData
                                || modelData?.state === ConnectionState.Connecting
                            readonly property real base: panneau.bases[cle] ?? 0
                            readonly property Item bloc: ouverte ? charge.item : null
                            readonly property alias depliage: depliage
                            readonly property alias decalage: decalage
                            readonly property alias apparition: apparition
                            // Part de la hauteur de la ligne : elle suit le fondu, sauf en mouvement réduit, où la place se prend
                            // ou se rend d'un coup et où seule l'opacité s'anime.
                            readonly property real place: Theme.mouvementReduit ? apparition.cible : apparition.value
                            // Faux le temps d'une passe pour une ligne qui entre : son ressort part ainsi de zéro.
                            property bool posee: !entre
                            // Refermée et sortie du tri : la ligne se retire du modèle.
                            readonly property bool partie: rang < 0 && apparition.value === 0 && !apparition.moving

                            width: lignes.width
                            // La ligne s'ouvre et se referme en hauteur et en fondu (reveal), sans glisser de côté.
                            height: (rangee.height + depliage.value) * place
                            opacity: apparition.value
                            visible: apparition.value > 0
                            clip: true
                            y: base + decalage.value
                            Component.onCompleted: {
                                panneau.inscrire(cle, ligne)
                                if (!posee) Qt.callLater(() => posee = true)
                            }
                            Component.onDestruction: panneau.desinscrire(cle, ligne)
                            onPartieChanged: if (partie) Qt.callLater(panneau.retirer, cle)

                            // glisser — fait partir la ligne de sa place d'avant un nouveau tri vers la nouvelle,
                            // par le ressort reflow, depuis sa position courante même en plein glissement.
                            // Sans effet tant que la ligne est cachée (popover fermé) : aucun ressort ne tourne pour rien.
                            // Entrée : avant, l'ordonnée affichée avant le tri. Sortie : aucune. Erreurs : aucune.
                            // Dépendances : decalage (Ressort), base.
                            function glisser(avant: real): void {
                                const ecart = avant - base
                                if (!visible || Math.abs(ecart) < 0.5) return
                                decalage.cible = ecart
                                decalage.poser()
                                decalage.cible = 0
                            }

                            Ressort { id: decalage; transition: "reflow"; cible: 0 }
                            // Présence de la ligne, de 0 (refermée) à 1 (ouverte) : entrée par le ressort reveal
                            // d'entrée, sortie par celui de sortie (environ 70 % de l'entrée, motion.json).
                            Ressort { id: apparition; transition: "reveal"; nature: "fondu"; cible: ligne.posee && ligne.montre ? 1 : 0 }
                            Ressort {
                                id: depliage
                                transition: "reveal"
                                cible: ligne.ouverte ? charge.implicitHeight + (Theme.space?.scale[0] ?? 0) : 0
                            }

                            Rangee {
                                id: rangee
                                // Hors d'une ListView, l'index de la rangée ne sert à rien (Rangee l'exige).
                                index: 0
                                width: parent.width
                                implicitHeight: panneau.hauteurLigne
                                hoverEnabled: true
                                icone: Icones.iconeForce(ligne.modelData?.signalStrength ?? 0)
                                text: ligne.cle
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
                                    sourceComponent: mdp
                                }
                            }

                            Component {
                                id: mdp
                                BlocSecret {
                                    erreur: ligne.ouverte ? panneau.erreur : ""
                                    occupe: ligne.enConnexion
                                    onRejoindre: panneau.rejoindre()
                                    onAnnuler: { panneau.deplie = ""; panneau.erreur = "" }
                                }
                            }
                        }
                    }
                }
            }

            // Pied : filet translucide en retrait (material.glassLine, D103 : un filet opaque se lisait comme un
            // trait blanc sur le verre), puis les actions en texte seul.
            Separateur {
                Layout.fillWidth: true
                Layout.leftMargin: panneau.marge
                Layout.rightMargin: panneau.marge
                Layout.topMargin: Theme.space?.scale[0] ?? 0
                Layout.bottomMargin: Theme.space?.scale[0] ?? 0
                color: Theme.material?.glassLine ?? "transparent"
            }
            Rangee {
                index: 0
                visible: panneau.joint !== null
                Layout.fillWidth: true
                implicitHeight: panneau.hauteurLigne
                hoverEnabled: true
                text: "Se déconnecter"
                onActive: panneau.deconnecter()
            }
            Rangee {
                index: 0
                Layout.fillWidth: true
                implicitHeight: panneau.hauteurLigne
                hoverEnabled: true
                text: "Réglages réseau…"
                // Une demande de profil restée sans suite ne détourne pas cette ouverture.
                onActive: { panneau.etat.profilDemande = ""; panneau.etat.fenetre = true; panneau.fermer() }
            }
        }
    }
}
