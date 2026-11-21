import QtQuick
import Quickshell
import "../Theme"
import "../Composants"
import "../Parametres"
import "garde.js" as Garde

// Panneau — contenu du panneau des notifications (L2-67) : ce qui reste à traiter, et « ne pas déranger ».
// Rôle : de haut en bas, dans une marge intérieure de notifications.interieur : l'en-tête « Notifications » avec, à
// droite, « Tout effacer » (Bouton plat et danger, sans marque : un lien en texte rouge, sans plaque ; absent quand rien
// n'attend) ; la bascule à glyphe des notifications (Bascule, dans une ZoneCurseur neutre : sans plaque, elle garde son propre survol),
// allumée quand elles sont actives, éteinte sous « ne pas déranger », sous la cloche ou la cloche barrée en fondu
// croisé (D182), avec un seul libellé, l'état présent (« Notifications actives » ou « Ne pas déranger ») ; puis les
// groupes par application (GroupeAttente), le plus récent en tête, un groupe qui contient une critique passant devant ;
// sans rien à traiter, un état vide (cloche et « Rien à traiter ») centré dans la place restante. Le panneau n'a pas de
// fond : sa fenêtre (FenetrePanneau) fournit la forme de verre. Au pied, sous un filet translucide
// (material.glassLine), l'action en texte seul « Réglages des notifications… » ouvre la page Notifications de
// l'application Paramètres et demande la fermeture du panneau, comme le pied du popover de réglage rapide (D105). Il se
// déclare montré à l'attente tant qu'il est monté, pour qu'une entrée fermée reste le temps de son repli.
// Hauteur : celle du contenu, jamais sous panneau.hauteurMin, jamais au-dessus de hauteurMax ; au-delà, la liste des
// groupes défile entre l'en-tête et la bascule, en haut, et le pied, en bas, qui restent fixes ; la molette suit le
// défilement lissé de l'application Paramètres (motion.wheel), posé d'un coup en mouvement réduit.
// « Tout effacer » écarte les groupes en cascade, du haut vers le bas, à panneau.cascade ms l'un de l'autre.
// Curseur : le panneau déclare l'arbitre dnVue (VueCurseur) : une seule plaque à la fois, sur la ligne, l'action ou la
// bascule que la souris ou le clavier désigne en dernier ; aucun anneau de focus.
// Clavier : la liste est un seul arrêt de tabulation ; les flèches déplacent l'entrée courante parmi les entrées
// montrées, Entrée l'ouvre, Suppr l'écarte (l'entrée courante passe alors à la suivante). Tab va de la bascule à la
// liste, puis à « Tout effacer », puis aux réglages. Le survol d'une ligne en fait l'entrée courante (LigneAttente).
// Entrées : attente, l'Attente ; hauteurMax, posée par la fenêtre (infinie par défaut).
// Sorties : implicitHeight ; vide ; effacable, vrai quand « Tout effacer » est offert ; texteEtat, l'état de « ne pas
// déranger » ; groupes, les entrées rangées par application, sortantes comprises ; deplies, identifiants des groupes
// dépliés ; visibles, les entrées montrées dans l'ordre de l'écran ; courante, l'entrée courante au clavier ;
// lienReglages, la rangée « Réglages des notifications… » ; signal fermer(), la demande de fermeture du panneau ;
// clavier, vrai tant que la liste a le focus ; defilable ; pret, vrai une fois le panneau monté (les lignes et groupes
// qui naissent ensuite se déplient) ; bascule, effacer (« Tout effacer ») et groupesVus (le Repeater des groupes), lus
// par les essais. Fonctions : deplier, effacerGroupe, nePlusGarder, toutEffacer, reglages, touche, releve.
// Erreurs : aucune ; sans jetons chargés, les cotes sont nulles.
// Dépendances : Quickshell (ScriptModel), GroupeAttente, Bascule, ZoneCurseur, Bouton, VueCurseur, Rangee, Separateur,
// Texte, Icone, Ressort, garde.js, EtatNotifications, EtatParametres, Attente, Theme (panneau, notifications, space,
// color, density, material, motion.wheel).
FocusScope {
    id: panneau

    property QtObject attente: null
    property real hauteurMax: Infinity
    // Arbitre du curseur du panneau : une seule entrée, action ou bascule porte la plaque à la fois (L2-73).
    property VueCurseur dnVue: VueCurseur {}
    // Rôle de fond lu par les contrôles descendants (Etats.herite) : celui des cartes et des popovers de verre.
    readonly property string dnRole: "surfaceRaised"
    readonly property real marge: Theme.notifications?.interieur ?? 0
    readonly property real ecart: Theme.space?.scale[2] ?? 0
    readonly property var groupes: Garde.grouper(attente?.entrees ?? [])
    readonly property var identifiants: groupes.map(g => g.identifiant)
    property var deplies: ({})
    readonly property var visibles: [].concat(...groupes.map(g => {
        const v = g.entrees.filter(a => !a.sortante)
        return deplies[g.identifiant] ? v : v.slice(0, 1)
    }))
    property QtObject courante: null
    readonly property bool clavier: liste.activeFocus
    readonly property bool vide: (attente?.nombre ?? 0) === 0
    readonly property bool effacable: !vide
    readonly property string texteEtat: EtatNotifications.nePasDeranger ? qsTr("Ne pas déranger")
                                                                         : qsTr("Notifications actives")
    readonly property real fixe: marge + entete.height + ecart + reglage.height + ecart
    readonly property bool defilable: defilement.contentHeight > defilement.height + 0.5
    readonly property alias bascule: bascule
    readonly property alias lienReglages: lienReglages
    readonly property alias effacer: effacer
    readonly property alias groupesVus: vues
    // Hauteur d'une rangée d'action en texte, celle du pied du popover de réglage rapide.
    readonly property real hauteurLigne: (Theme.density?.controlHeight ?? 0) + (Theme.space?.scale[0] ?? 0)
    property bool pret: false
    // File des groupes que « Tout effacer » écarte un à un.
    property var _cascade: []

    implicitHeight: Math.min(hauteurMax, Math.max(Theme.panneau?.hauteurMin ?? 0, fixe + colonne.height + pied.height))

    signal fermer()

    // reglages — ouvre la page Notifications de l'application Paramètres et demande la fermeture du panneau ; la
    // fenêtre Paramètres attend le repli du panneau, contextuel du registre Overlays (D174).
    // Entrées, sortie, erreurs : aucune. Dépendances : EtatParametres.ouvrir, fermer.
    function reglages() {
        EtatParametres.ouvrir("notifications", [])
        fermer()
    }

    // Le panneau se déclare montré à sa création et ne l'est plus à sa destruction : un Binding détruit avec lui ne
    // rendrait pas sa valeur à la cible (relecture finale de L2-67). Une cascade de « Tout effacer » interrompue par
    // la fermeture du panneau va à son terme d'un coup.
    Component.onCompleted: {
        if (attente) attente.montree = true
        Qt.callLater(() => panneau.pret = true)
    }
    Component.onDestruction: {
        _cascade.forEach(effacerGroupe)
        if (attente) attente.montree = false
    }

    // deplier — déplie un groupe. Entrée : identifiant de l'application. Sortie : aucune. Erreurs : aucune.
    // Dépendances : deplies.
    function deplier(identifiant) { deplies = Object.assign({}, deplies, {[identifiant]: true}) }

    // effacerGroupe — écarte toutes les notifications d'une application. Entrée : identifiant. Sortie : aucune.
    // Erreurs : aucune. Dépendances : Attente.ecarterGroupe.
    function effacerGroupe(identifiant) { attente.ecarterGroupe(identifiant) }

    // nePlusGarder — écarte les notifications d'une application et la retire du panneau (elle se remet depuis la
    // page Notifications de Paramètres). Entrée : identifiant. Sortie : aucune. Erreurs : aucune ; sans effet pour
    // une application anonyme (identifiant vide). Dépendances : EtatNotifications.retirer, effacerGroupe.
    function nePlusGarder(identifiant) {
        if (identifiant === "") return
        EtatNotifications.retirer(identifiant)
        effacerGroupe(identifiant)
    }

    // toutEffacer — écarte tous les groupes en cascade, du haut vers le bas. Entrées, sortie, erreurs : aucune.
    // Dépendances : cascade, effacerGroupe.
    function toutEffacer() {
        _cascade = identifiants.slice()
        suivant()
    }

    // suivant — écarte le premier groupe de la file de la cascade, puis attend le pas suivant. Entrées, sortie,
    // erreurs : aucune. Dépendances : _cascade, cascade, effacerGroupe.
    function suivant() {
        if (_cascade.length === 0) return
        effacerGroupe(_cascade[0])
        _cascade = _cascade.slice(1)
        if (_cascade.length > 0) cascade.restart()
    }

    // touche — applique une touche à la liste. Entrée : cle, une touche de Qt (Key_Down, Key_Up, Key_Return,
    // Key_Enter, Key_Delete). Sortie : vrai si la touche est consommée. Erreurs : aucune.
    // Dépendances : visibles, courante, Attente.ouvrir, Attente.ecarter.
    function touche(cle) {
        const i = visibles.indexOf(courante)
        if (cle === Qt.Key_Down || cle === Qt.Key_Up) {
            const j = i < 0 ? (cle === Qt.Key_Down ? 0 : visibles.length - 1)
                            : Math.max(0, Math.min(visibles.length - 1, i + (cle === Qt.Key_Down ? 1 : -1)))
            courante = visibles[j] ?? null
        } else if (i >= 0 && (cle === Qt.Key_Return || cle === Qt.Key_Enter)) attente.ouvrir(courante)
        else if (i >= 0 && cle === Qt.Key_Delete) {
            const a = courante
            courante = visibles[i + 1] ?? visibles[i - 1] ?? null
            attente.ecarter(a)
        } else return false
        return true
    }

    // vueCourante — position de la ligne courante dans la vue de la liste. Entrées : aucune. Sortie : { haut, bas,
    // hauteur } en px (haut et bas de la ligne, hauteur de la vue), null sans ligne courante montrée.
    // Erreurs : aucune. Dépendances : ligneDe, defilement.
    function vueCourante() {
        const l = ligneDe(courante)
        if (!l) return null
        const y = l.mapToItem(colonne, 0, 0).y - defilement.contentY
        return {haut: y, bas: y + l.height, hauteur: defilement.height}
    }

    // ligneDe — LigneAttente qui montre une entrée. Entrée : a, l'Attendue. Sortie : la ligne, ou null.
    // Erreurs : aucune. Dépendances : vues (GroupeAttente.ligneDe).
    function ligneDe(a) {
        for (let i = 0; a && i < vues.count; i++) {
            const l = vues.itemAt(i)?.ligneDe(a)
            if (l) return l
        }
        return null
    }

    // suivreCourante — fait défiler la liste juste assez pour que la ligne courante soit entière dans la vue, par la
    // même animation que la molette (posée d'un coup en mouvement réduit). Une ligne devenue courante par le survol ne
    // fait pas défiler : la liste ne glisse pas sous le pointeur. Entrées, sortie, erreurs : aucune.
    // Dépendances : ligneDe, vueCourante, defilement, elan.
    function suivreCourante() {
        const v = vueCourante()
        if (!v || ligneDe(courante)?.hovered) return
        const delta = v.haut < 0 ? v.haut : v.bas > v.hauteur ? v.bas - v.hauteur : 0
        if (delta === 0) return
        const cible = Math.max(0, Math.min(defilement.maximum, defilement.contentY + delta))
        if (Theme.mouvementReduit) { elan.stop(); defilement.contentY = cible; return }
        defilement.cible = cible
        elan.to = cible
        elan.restart()
    }

    onCouranteChanged: Qt.callLater(suivreCourante)

    // releve — relevé des groupes montrés, pour les essais. Entrées : aucune. Sortie : tableau de { nom, nombre,
    // deplie, autres, retirable, lignes }, dans l'ordre de l'écran, groupes en cours de repli exclus.
    // Erreurs : aucune. Dépendances : vues.
    function releve() {
        const sortie = []
        for (let i = 0; i < vues.count; i++) {
            const g = vues.itemAt(i)
            if (g && g.nombre > 0)
                sortie.push({nom: g.nom, nombre: g.nombre, deplie: g.deplie, autres: g.autres, retirable: g.retirable,
                             lignes: g.lignes})
        }
        return sortie
    }

    Timer { id: cascade; interval: Theme.panneau?.cascade ?? 0; onTriggered: panneau.suivant() }

    // En-tête : le titre et « Tout effacer ».
    Item {
        id: entete
        x: panneau.marge
        y: panneau.marge
        width: panneau.width - 2 * panneau.marge
        height: titre.implicitHeight

        Texte { id: titre; echelon: 3; moyen: true; text: qsTr("Notifications") }
        Bouton {
            id: effacer
            anchors.right: parent.right
            anchors.rightMargin: -horizontalPadding
            anchors.verticalCenter: titre.verticalCenter
            marque: false
            visible: opacity > 0
            opacity: efface.value
            enabled: panneau.effacable
            plat: true
            danger: true
            KeyNavigation.tab: lienReglages
            text: qsTr("Tout effacer")
            onClicked: panneau.toutEffacer()
            Ressort { id: efface; transition: "state"; nature: "fondu"; cible: panneau.effacable ? 1 : 0 }
        }
    }

    // Les notifications : la bascule à glyphe de la bible, allumée quand elles sont actives, son libellé et son état.
    Item {
        id: reglage
        x: panneau.marge
        y: entete.y + entete.height + panneau.ecart
        width: entete.width
        height: bascule.height

        ZoneCurseur {
            marque: false
            Bascule {
                id: bascule
                icone: EtatNotifications.icone
                fondu: true
                KeyNavigation.tab: liste
                onToggled: EtatNotifications.poser(!checked)
                Binding { target: bascule; property: "checked"; value: !EtatNotifications.nePasDeranger }
            }
        }
        // Un seul libellé, qui dit l'état présent ; le passage de l'un à l'autre est un fondu croisé.
        Ressort { id: fonduEtat; transition: "state"; nature: "fondu"; cible: EtatNotifications.nePasDeranger ? 1 : 0 }
        Texte {
            anchors.verticalCenter: parent.verticalCenter
            x: bascule.width + panneau.ecart
            moyen: true
            opacity: 1 - fonduEtat.value
            text: qsTr("Notifications actives")
        }
        Texte {
            anchors.verticalCenter: parent.verticalCenter
            x: bascule.width + panneau.ecart
            moyen: true
            opacity: fonduEtat.value
            text: qsTr("Ne pas déranger")
        }
    }

    // Liste des groupes : un seul arrêt de tabulation, défilante au-delà de la hauteur maximale.
    FocusScope {
        id: liste
        x: panneau.marge
        y: panneau.fixe
        width: entete.width
        height: panneau.height - panneau.fixe - pied.height
        activeFocusOnTab: !panneau.vide
        KeyNavigation.tab: effacer
        Keys.onPressed: event => event.accepted = panneau.touche(event.key)
        onActiveFocusChanged: if (activeFocus && !panneau.visibles.includes(panneau.courante))
                                  panneau.courante = panneau.visibles[0] ?? null

        Flickable {
            id: defilement
            anchors.fill: parent
            clip: true
            interactive: false
            boundsBehavior: Flickable.StopAtBounds
            contentHeight: colonne.height

            readonly property real maximum: Math.max(0, contentHeight - height)
            property real cible: 0

            // Un contenu qui raccourcit ne laisse pas la vue au-delà de sa fin.
            onMaximumChanged: if (contentY > maximum) { elan.stop(); contentY = maximum }

            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: event => {
                    const borner = y => Math.max(0, Math.min(defilement.maximum, y))
                    if (event.pixelDelta.y !== 0 || Theme.mouvementReduit) {
                        elan.stop()
                        defilement.contentY = borner(defilement.contentY - (event.pixelDelta.y
                            || event.angleDelta.y / 120 * (Theme.motion?.wheel?.step ?? 0)))
                        return
                    }
                    defilement.cible = borner((elan.running ? defilement.cible : defilement.contentY)
                                              - event.angleDelta.y / 120 * (Theme.motion?.wheel?.step ?? 0))
                    elan.to = defilement.cible
                    elan.restart()
                }
            }

            NumberAnimation {
                id: elan
                target: defilement
                property: "contentY"
                duration: Theme.motion?.wheel?.duration ?? 0
                easing.type: Easing.OutCubic
            }

            Column {
                id: colonne
                width: defilement.width

                Repeater {
                    id: vues
                    model: ScriptModel { values: panneau.identifiants }

                    GroupeAttente {
                        required property string modelData
                        width: colonne.width
                        identifiant: modelData
                        donnees: panneau.groupes.find(g => g.identifiant === modelData) ?? null
                        attente: panneau.attente
                        hote: panneau
                    }
                }
            }
        }

        // État vide, centré dans la place de la liste.
        Column {
            anchors.centerIn: parent
            spacing: Theme.space?.scale[1] ?? 0
            visible: opacity > 0
            opacity: rien.value

            Ressort { id: rien; transition: "reveal"; nature: "fondu"; cible: panneau.vide ? 1 : 0 }
            Icone {
                anchors.horizontalCenter: parent.horizontalCenter
                nom: "preferences-system-notifications"
                couleur: Theme.color?.textTertiary ?? "transparent"
            }
            Texte {
                anchors.horizontalCenter: parent.horizontalCenter
                color: Theme.color?.textTertiary ?? "transparent"
                text: qsTr("Rien à traiter")
            }
        }
    }

    // Pied : sous un filet translucide (material.glassLine : un filet opaque se lit comme un trait blanc sur le verre,
    // D103), l'action en texte seul qui ouvre les réglages des notifications.
    Item {
        id: pied
        y: panneau.height - height
        width: panneau.width
        height: lienReglages.y + lienReglages.height + (Theme.space?.scale[1] ?? 0)

        Separateur {
            id: filet
            x: panneau.marge
            y: Theme.space?.scale[1] ?? 0
            width: parent.width - 2 * panneau.marge
            color: Theme.material?.glassLine ?? "transparent"
        }
        Rangee {
            id: lienReglages
            index: 0
            y: filet.y + filet.height + (Theme.space?.scale[0] ?? 0)
            width: parent.width
            implicitHeight: panneau.hauteurLigne
            hoverEnabled: true
            activeFocusOnTab: true
            KeyNavigation.tab: bascule
            text: qsTr("Réglages des notifications…")
            onActive: panneau.reglages()
        }
    }
}
