import QtQuick
import QtQuick.Layouts
import Quickshell.Bluetooth
import "../Theme"
import "../Composants"
import "bluetooth.js" as Bt

// PopoverBluetooth — popover du Bluetooth, ancré sous l'indicateur Bluetooth de la barre (L2-14).
// Rôle : copie adaptée du popover réseau (PopoverReseau, décision de Nicolas : pas de base commune, D107). Un Overlay
// contextuel dont le contenu est construit une fois pour toutes et que l'hôte des popovers montre ou cache (il n'est
// plus détruit à la fermeture ; D80 reste vrai pour un popover non hébergé), compact, carré, sur le verre de E3 (D103). Il
// porte de haut en bas : l'en-tête, dont la bascule à glyphe allume ou coupe la radio (accent plein allumée, neutre
// éteinte), avec « Bluetooth » et la ligne d'état (appareil connecté et sa batterie, « Aucun appareil connecté » ou
// « Désactivé ») ; « Mes appareils », les appareils appairés, connectés d'abord, une ligne chacun (icône du type,
// nom affiché sans préfixe « LE- », état) : un clic connecte ou déconnecte, le chevron déplie sous la ligne « Oublier cet appareil », un second
// clic replie ; « Appareils à proximité », petite étiquette au texte secondaire avec l'indicateur d'activité tant que
// la recherche tourne, le bouton de nouvelle recherche sinon, puis les appareils voisins nommés : un clic lance
// l'appairage, que l'état poursuit (confiance, connexion) même popover fermé. Une ligne en cours montre « Appairage… »,
// « Connexion… » ou « Déconnexion… » et l'indicateur d'activité ; « Connecté » ne vaut, pour un appareil audio, que si
// PipeWire a sa sortie (EtatBluetooth.pret) ; un échec remplace l'état par « Appairage
// impossible » ou « Connexion impossible », en couleur d'alerte, jusqu'au clic suivant. Les transitions sont celles du
// popover réseau : une ligne paraît ou se referme en hauteur et en fondu (reveal), glisse vers sa nouvelle place
// (reflow), et l'ordre est figé tant qu'une ligne est dépliée. Ainsi, un appareil qui vient d'être appairé quitte les
// voisins et entre dans « Mes appareils ». Radio coupée : listes absentes et recherche non demandée. Popover de la
// barre (D108) : en ouvrir un autre le ferme ; il se ferme 1,5 s après le départ de la souris, sauf tant que
// « Oublier » est déplié ou qu'une ligne est occupée (appairage, connexion), pour en montrer l'issue (retenu). Pour
// l'hôte, le panneau offre fonduContenu et fonduDisque, deux fondus distincts (la bascule d'en-tête, posée sur un
// emplacement réservé hors de la colonne, ne suit que le second), et reinitialiser(), qui rend à la vue l'aspect d'un
// popover neuf sans couper un appairage ou une connexion en cours.
// Entrées : ancre, l'indicateur de la barre ; ouvert, à affecter (voir Overlay) ; associees, voir Overlay ; etat, la
// source de l'état et des actions, EtatBluetooth par défaut (la coque d'essai y met un factice).
// Sorties : ferme(), voir Overlay ; panneau, le contenu construit (null tant qu'il ne l'est pas, ou une fois détruit),
// lu par les essais ; fonduContenu, fonduDisque, reinitialiser(), voir ci-dessus.
// Erreurs : un echec(adresse, message) de l'état s'affiche sur la ligne de l'appareil.
// Dépendances : Overlay (famille contextuel), Bascule, Activite, Infobulle, Rangee, Icone, Texte, Ressort, Theme
// (density, space, icons, color, motion par Ressort), EtatBluetooth, bluetooth.js (trierAppareils, iconeAppareil),
// Quickshell.Bluetooth (BluetoothDeviceState).
// Cotes : celles du popover réseau ; surface de 288 px, panneau de 280 px, contenu à space.scale[2] (12) du bord,
// rangées de density.controlHeight plus space.scale[0] (32 px) ; au plus quatre lignes visibles pour « Mes
// appareils », la suite défile ; « Appareils à proximité » a une hauteur fixe de cinq lignes (fiche 0.3).
// Mouvement réduit (Theme.mouvementReduit) : comme le popover réseau, le déplacement et le dépliage des lignes se
// posent aussitôt et seule leur opacité (nature « fondu ») s'anime, en fondu court.
Overlay {
    id: popover

    property var etat: EtatBluetooth
    // Écrit par le panneau seul, à sa construction et à sa destruction (null avant la première et après la seconde).
    property Item panneau: null

    famille: "contextuel"
    exclusif: true
    fermeAuDepart: true
    retenu: panneau !== null && (panneau.deplie !== "" || panneau.occupe)
    // La recherche n'est demandée que popover ouvert et radio allumée ; seul un popover qui l'a demandée la rend.
    readonly property bool demande: ouvert && etat.allume
    onDemandeChanged: etat.recherche = demande
    Component.onDestruction: if (demande) etat.recherche = false

    // BoutonIcone — bouton réduit à une icône, sans fond, comme les boutons d'outil de macOS (copie du popover réseau).
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

    // Liste — liste animée d'appareils, tenue par adresse (logique du popover réseau).
    // Rôle : fige l'ordre reçu (cles) et met ses lignes à jour : une adresse nouvelle entre en s'ouvrant (sauf au
    // premier tri), une adresse partie reste à son ancien rang le temps que sa ligne se referme, les autres glissent
    // de leur place relevée à la nouvelle. Gelée, elle ne change rien et reprend le tri au dégel.
    // Entrées : cles, adresses dans l'ordre voulu ; gel ; appaires, vrai pour « Mes appareils » (clic : connecter ou
    // déconnecter ; chevron et « Oublier »), faux pour les voisins (clic : appairer) ; panneau, le panneau du popover.
    // Sorties : ordre, adresses figées ; delegues, adresse → ligne ; implicitHeight, hauteur des lignes ouvertes.
    // Erreurs : aucune. Dépendances : Ligne, ListModel.
    component Liste: Item {
        id: liste
        property var cles: []
        property bool gel: false
        property bool appaires: false
        // Le panneau du popover : les composants internes ne voient pas les id du fichier.
        property Item panneau: null
        property var ordre: []
        // Ordre d'affichage : ordre, plus les lignes qui sortent, gardées à leur ancien rang le temps de se refermer.
        property var disposition: []
        // Faux pendant le premier tri, qui a lieu à la construction de la coque : les lignes déjà présentes paraissent
        // d'emblée, seules celles qui arrivent ensuite entrent.
        property bool trie: false
        property var delegues: ({})
        // Adresse → ordonnée de la ligne sans glissement ; « » donne la hauteur de la liste (voir le popover réseau).
        readonly property var bases: {
            const b = {}
            let y = 0
            for (const cle of disposition) {
                b[cle] = y
                y += delegues[cle]?.height ?? 0
            }
            b[""] = y
            return b
        }

        implicitHeight: bases[""]
        onClesChanged: trier()
        onGelChanged: if (!gel) trier()
        Component.onCompleted: trier()

        // releve — ordonnées affichées des lignes. Entrées : aucune. Sortie : tableau de [adresse, ordonnée].
        function releve(): var { return Object.entries(delegues).map(([cle, d]) => [cle, d.y]) }

        // trier — fige l'ordre et met le modèle à jour (voir le rôle de Liste). Entrée : avant, ordonnées relevées
        // avant le changement (releve() par défaut). Sortie : aucune. Erreurs : aucune ; gelée, rien ne change.
        // Dépendances : cles, modele, disposition, delegues (glisser).
        function trier(avant = releve()): void {
            if (gel) return
            ordre = cles.slice()
            const connus = Array.from({ length: modele.count }, (_, i) => modele.get(i).cle)
            const d = ordre.slice()
            for (const [i, cle] of disposition.entries())
                if (!ordre.includes(cle) && connus.includes(cle)) d.splice(Math.min(i, d.length), 0, cle)
            disposition = d
            for (const cle of ordre) if (!connus.includes(cle)) modele.append({ cle, entre: trie })
            trie = true
            for (const [cle, y] of avant) delegues[cle]?.glisser(y)
        }

        // retirer — ôte la ligne d'une adresse sortie du tri, une fois refermée ; une adresse revenue est gardée.
        // Entrée : cle. Sortie : aucune. Erreurs : aucune. Dépendances : modele, ordre, disposition.
        function retirer(cle: string): void {
            if (ordre.includes(cle)) return
            for (let i = modele.count - 1; i >= 0; i--) if (modele.get(i).cle === cle) modele.remove(i)
            disposition = disposition.filter(c => c !== cle)
        }

        // inscrire, desinscrire — tiennent la table delegues. Entrées : cle ; d, la ligne. Sortie : aucune.
        function inscrire(cle: string, d: Item): void { delegues = Object.assign({}, delegues, { [cle]: d }) }
        function desinscrire(cle: string, d: Item): void {
            if (delegues[cle] !== d) return
            const reste = Object.assign({}, delegues)
            delete reste[cle]
            delegues = reste
        }

        ListModel { id: modele }
        Repeater {
            model: modele
            delegate: Ligne { conteneur: liste }
        }
    }

    // Ligne — une ligne d'appareil : rangée, état, chevron (appairés) et dépliage « Oublier cet appareil ».
    // Rôle : se pose à son ordonnée dans sa Liste, plus son décalage de glissement ; s'ouvre et se referme (reveal).
    // Entrées : cle, l'adresse ; entre, vrai pour une ligne ajoutée après le premier tri ; conteneur, sa Liste.
    // Sorties : appareil, le BluetoothDevice (null s'il a disparu) ; icone ; statut, le texte d'état affiché ;
    // rangee ; deplier(). Erreurs : aucune. Dépendances : panneau, Ressort, Rangee, BoutonIcone, Activite, Texte.
    component Ligne: Item {
        id: ligne
        required property string cle
        required property bool entre
        property Item conteneur
        readonly property Item panneau: conteneur.panneau
        readonly property int rang: conteneur.ordre.indexOf(cle)
        readonly property var appareil: panneau.appareil(cle)
        readonly property bool montre: rang >= 0 && appareil !== null
        readonly property bool ouverte: conteneur.appaires && panneau.deplie === cle
        readonly property string icone: Bt.iconeAppareil(appareil?.icon ?? "")
        readonly property string erreur: panneau.erreurs[cle] ?? ""
        readonly property bool enAppairage: !!panneau.etat.appairages?.[cle] || (appareil?.pairing ?? false)
        readonly property bool occupe: erreur === "" && (enAppairage
            || appareil?.state === BluetoothDeviceState.Connecting || appareil?.state === BluetoothDeviceState.Disconnecting)
        readonly property string statut: erreur !== "" ? erreur
            : enAppairage ? "Appairage…"
            : appareil?.state === BluetoothDeviceState.Connecting ? "Connexion…"
            : appareil?.state === BluetoothDeviceState.Disconnecting ? "Déconnexion…"
            : panneau.etat.pret(appareil) ? "Connecté" : ""
        readonly property real base: conteneur.bases[cle] ?? 0
        readonly property Item rangee: rangeeLigne
        readonly property alias depliage: depliage
        readonly property alias decalage: decalage
        readonly property alias apparition: apparition
        // Part de la hauteur que prend la ligne : elle suit le fondu, sauf en mouvement réduit, où la place se prend ou se
        // rend d'un coup et où seule l'opacité s'anime.
        readonly property real place: Theme.mouvementReduit ? apparition.cible : apparition.value
        property bool posee: !entre
        readonly property bool partie: rang < 0 && apparition.value === 0 && !apparition.moving

        width: conteneur.width
        height: (rangeeLigne.height + depliage.value) * place
        opacity: apparition.value
        visible: apparition.value > 0
        clip: true
        y: base + decalage.value
        Component.onCompleted: {
            conteneur.inscrire(cle, ligne)
            if (!posee) Qt.callLater(() => posee = true)
        }
        Component.onDestruction: conteneur.desinscrire(cle, ligne)
        // Une fonction propre à chaque appel : Qt.callLater fusionne les appels d'une même fonction, et plusieurs lignes
        // peuvent sortir ensemble.
        onPartieChanged: if (partie) Qt.callLater(() => conteneur.retirer(cle))

        // glisser — fait partir la ligne de sa place d'avant un tri vers la nouvelle (ressort reflow),
        // sans effet tant que la ligne est cachée (popover fermé).
        // Entrée : avant, l'ordonnée affichée avant le tri. Sortie : aucune. Erreurs : aucune. Dépendances : decalage.
        function glisser(avant: real): void {
            const ecart = avant - base
            if (!visible || Math.abs(ecart) < 0.5) return
            decalage.cible = ecart
            decalage.poser()
            decalage.cible = 0
        }

        // deplier — déplie « Oublier cet appareil » sous la ligne, ou la replie. Entrées : aucune. Sortie : aucune.
        function deplier(): void { panneau.deplie = ouverte ? "" : cle }

        Ressort { id: decalage; transition: "reflow"; cible: 0 }
        Ressort { id: apparition; transition: "reveal"; nature: "fondu"; cible: ligne.posee && ligne.montre ? 1 : 0 }
        Ressort {
            id: depliage
            transition: "reveal"
            cible: ligne.ouverte ? oubli.implicitHeight : 0
        }

        // Le chevron est hors de la rangée, à sa droite : son clic ne déclenche pas celui de la ligne.
        Rangee {
            id: rangeeLigne
            index: 0
            width: parent.width - (chevron.visible ? chevron.width + (Theme.space?.scale[1] ?? 0) : 0)
            implicitHeight: panneau.hauteurLigne
            hoverEnabled: true
            icone: ligne.icone
            text: Bt.nomAffiche(ligne.appareil?.name)
            onActive: panneau.choisir(ligne)
            suffixe: Component {
                Row {
                    spacing: Theme.space?.scale[1] ?? 0
                    Texte {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: ligne.statut !== ""
                        text: ligne.statut
                        echelon: 1
                        color: (ligne.erreur !== "" ? Theme.color?.warning : Theme.color?.textSecondary) ?? "transparent"
                    }
                    Activite { anchors.verticalCenter: parent.verticalCenter; visible: ligne.occupe }
                }
            }
        }
        BoutonIcone {
            id: chevron
            visible: ligne.conteneur.appaires
            anchors.right: parent.right
            anchors.rightMargin: Theme.space?.scale[1] ?? 0
            y: (rangeeLigne.height - height) / 2
            nom: "go-next"
            rotation: ligne.ouverte ? 90 : 0
            onClique: ligne.deplier()
        }

        // Dépliage, découpé à la hauteur du ressort : l'action en texte seul.
        Item {
            y: rangeeLigne.height
            width: parent.width
            height: depliage.value
            clip: true
            Rangee {
                id: oubli
                index: 0
                visible: ligne.ouverte || depliage.value > 0
                width: parent.width
                implicitHeight: panneau.hauteurLigne
                hoverEnabled: true
                text: "Oublier cet appareil"
                onActive: panneau.oublier(ligne.appareil)
            }
        }
    }

    FocusScope {
        id: panneau

        readonly property real marge: Theme.space?.scale[2] ?? 0
        readonly property real hauteurLigne: (Theme.density?.controlHeight ?? 0) + (Theme.space?.scale[0] ?? 0)
        readonly property var etat: popover.etat
        readonly property bool listeVisible: etat.disponible && etat.allume
        // Les deux listes, triées par bluetooth.js ; les lectures des propriétés des appareils relancent le tri.
        readonly property var tri: Bt.trierAppareils(Array.from(etat.appareils ?? []).filter(a => a).map(a => ({
            nom: a.name, adresse: a.address, appaire: a.paired, connecte: etat.pret(a) })))
        // Adresse de l'appareil dont « Oublier » est déplié, vide sinon.
        property string deplie: ""
        // Adresse → message d'échec, effacé au clic suivant sur la ligne.
        property var erreurs: ({})
        readonly property alias mes: listeMes
        readonly property alias proches: listeProches
        // Adresse → ligne, des deux listes ; « Mes appareils » l'emporte pendant le passage d'un appareil appairé.
        readonly property var delegues: Object.assign({}, listeProches.delegues, listeMes.delegues)
        readonly property real hauteurProches: flickProches.height
        // Vrai tant qu'une ligne est occupée (appairage, connexion, déconnexion) : le popover reste ouvert.
        readonly property bool occupe: Object.values(delegues).some(d => d.occupe)

        // Fondus que l'hôte des popovers pose, de 0 à 1 : fonduContenu pour tout l'en-tête sauf la bascule et pour le
        // reste du contenu, fonduDisque pour la bascule seule. Sans hôte, ils restent à 1 : le panneau est tel quel.
        property real fonduContenu: 1
        property real fonduDisque: 1

        focus: true
        implicitWidth: 70 * (Theme.space?.scale[0] ?? 0)
        implicitHeight: colonne.implicitHeight + 2 * (Theme.space?.scale[1] ?? 0)
        Component.onCompleted: popover.panneau = panneau
        Component.onDestruction: if (popover.panneau === panneau) popover.panneau = null

        // reinitialiser — rend au contenu l'aspect d'un popover neuf : « Oublier » replié, échecs affichés effacés,
        // listes en haut. Un appairage ou une connexion en cours n'est jamais annulé : seule la vue revient à neuf, et
        // le popover reste retenu tant que la ligne est occupée.
        // Entrées : aucune. Sortie : aucune. Erreurs : aucune. Dépendances : deplie, erreurs, flickMes, flickProches.
        function reinitialiser(): void {
            deplie = ""
            erreurs = ({})
            flickMes.contentY = 0
            flickProches.contentY = 0
        }

        // appareil — l'appareil d'une adresse. Entrée : cle. Sortie : le BluetoothDevice, ou null. Erreurs : aucune.
        function appareil(cle: string): var { return Array.from(etat.appareils ?? []).find(a => a?.address === cle) ?? null }

        // choisir — clic sur une ligne : efface son échec, puis connecte ou déconnecte un appareil appairé, appaire un
        // voisin. Entrée : ligne. Sortie : aucune. Erreurs : sans appareil, ou ligne occupée (un second clic pendant
        // un appairage ou une connexion), rien. Dépendances : etat, erreurs.
        function choisir(ligne): void {
            if (!ligne.appareil || ligne.occupe) return
            const reste = Object.assign({}, erreurs)
            delete reste[ligne.cle]
            erreurs = reste
            if (ligne.conteneur.appaires) etat.basculer(ligne.appareil)
            else etat.appairer(ligne.appareil)
        }

        // oublier — oublie l'appareil de la ligne dépliée et replie. Entrée : appareil. Sortie : aucune.
        function oublier(a): void {
            if (a) etat.oublier(a)
            deplie = ""
        }

        // relancer — relance la recherche arrêtée. Entrées : aucune. Sortie : aucune. Dépendances : etat.
        function relancer(): void {
            etat.recherche = false
            etat.recherche = true
        }

        Connections {
            target: panneau.etat
            function onEchec(adresse, message) { panneau.erreurs = Object.assign({}, panneau.erreurs, { [adresse]: message }) }
        }

        // La bascule de la radio, déclarée avant la colonne : elle garde sa place dans l'ordre de tabulation, la
        // première, et se pose par-dessus l'emplacement que l'en-tête lui réserve, au pixel près.
        Bascule {
            id: bascule
            objectName: "bascule"
            z: 1
            x: colonne.x + entete.x + emplacement.x
            y: colonne.y + entete.y + emplacement.y
            opacity: panneau.fonduDisque
            icone: panneau.etat.allume ? "bluetooth-active" : "bluetooth-disabled"
            enabled: panneau.etat.disponible
            checked: panneau.etat.allume
            onToggled: { panneau.etat.allumer(checked); checked = Qt.binding(() => panneau.etat.allume) }
        }

        ColumnLayout {
            id: colonne
            opacity: panneau.fonduContenu
            y: Theme.space?.scale[1] ?? 0
            width: panneau.width
            spacing: Theme.space?.scale[0] ?? 0

            // En-tête : l'emplacement de la bascule de la radio, le titre et la ligne d'état.
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
                    Texte { Layout.fillWidth: true; text: "Bluetooth"; echelon: 2; moyen: true; color: Theme.color?.textEmphasis ?? "transparent" }
                    Texte { Layout.fillWidth: true; text: panneau.etat.resumeTexte; echelon: 1; elide: Text.ElideRight; color: Theme.color?.textSecondary ?? "transparent" }
                }
            }

            Texte {
                visible: panneau.listeVisible && panneau.tri.mes.length > 0
                Layout.fillWidth: true
                Layout.leftMargin: panneau.marge
                text: "Mes appareils"
                echelon: 0
                moyen: true
                color: Theme.color?.textSecondary ?? "transparent"
            }
            Flickable {
                id: flickMes
                objectName: "listeMes"
                visible: panneau.listeVisible
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(contentHeight, 4 * panneau.hauteurLigne)
                contentHeight: listeMes.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                Liste {
                    id: listeMes
                    width: parent.width
                    appaires: true
                    panneau: panneau
                    cles: panneau.listeVisible ? panneau.tri.mes : []
                    gel: panneau.deplie !== ""
                }
            }

            RowLayout {
                visible: panneau.listeVisible
                Layout.leftMargin: panneau.marge
                Layout.rightMargin: Theme.space?.scale[1] ?? 0
                Texte { Layout.fillWidth: true; text: "Appareils à proximité"; echelon: 0; moyen: true; color: Theme.color?.textSecondary ?? "transparent" }
                // Recherche : l'indicateur d'activité tant qu'elle tourne, le bouton qui la relance sinon.
                Item {
                    id: recherche
                    objectName: "recherche"
                    implicitWidth: Theme.density?.controlHeight ?? 0
                    implicitHeight: implicitWidth
                    BoutonIcone { anchors.fill: parent; visible: !panneau.etat.enRecherche; nom: "view-refresh"; onClique: panneau.relancer() }
                    Activite { objectName: "activiteRecherche"; anchors.centerIn: parent; visible: panneau.etat.enRecherche }
                    Infobulle { cible: recherche; texte: "Rechercher les appareils" }
                }
            }
            // Hauteur fixe de cinq lignes : la fenêtre ne grandit pas par à-coups au fil de la recherche.
            Flickable {
                id: flickProches
                visible: panneau.listeVisible
                Layout.fillWidth: true
                Layout.preferredHeight: 5 * panneau.hauteurLigne
                contentHeight: listeProches.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                Liste {
                    id: listeProches
                    width: parent.width
                    panneau: panneau
                    cles: panneau.listeVisible ? panneau.tri.proches : []
                    gel: panneau.deplie !== ""
                }
            }
        }
    }
}
