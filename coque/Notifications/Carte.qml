import QtQuick
import "../Theme"
import "../Composants"

// Carte — une notification affichée dans la pile, en verre e3 comme les popovers.
// Rôle : pose sur une plaque de verre le contenu de la notification courante d'une entrée (CorpsNotification :
// icône, en-tête au nom de l'application avec l'heure d'arrivée, titre, corps sur Theme.notifications.lignes lignes au
// plus, actions en texte dépliées au survol ; chaîne d'icône et règles du corps y sont décrites). Le survol est écrit
// dans l'entrée, qui suspend sa minuterie ; un clic hors des actions écarte la notification.
// Entrées : entree, l'Entree tenue par la pile ; pile, la Pile, qui reçoit les clics.
// Sorties : implicitHeight, contenu et marges compris (la largeur est fixée à Theme.notifications.largeur) ;
// survolee ; sourceIcone (« image », « application » ou « generique ») ; actionsVisibles, vrai tant que la rangée
// d'actions est au moins en partie dépliée ; enMouvement, vrai tant que le dépliant avance ; couleurTitre,
// lignesCorps, libelles (textes des actions affichés), libellesRendus(), texteApplication et texteHeure, lus par
// les essais.
// Erreurs : aucune ; sans jetons chargés, la carte est de taille nulle et transparente.
// Dépendances : Theme (notifications, radius), Composants (Surface, OmbreElevation, VueCurseur), CorpsNotification, Entree, Pile.
Item {
    id: carte

    required property QtObject entree
    required property QtObject pile
    // Arbitre du curseur de la carte : ses actions y prennent la plaque au survol, comme dans le panneau (L2-73).
    property VueCurseur dnVue: VueCurseur {}

    readonly property QtObject notification: entree?.notification ?? null
    readonly property real interieur: Theme.notifications?.interieur ?? 0
    readonly property bool survolee: entree?.survolee ?? false
    readonly property alias actions: contenu.actions
    readonly property alias sourceIcone: contenu.sourceIcone
    readonly property alias actionsVisibles: contenu.actionsVisibles
    readonly property alias enMouvement: contenu.enMouvement
    readonly property alias couleurTitre: contenu.couleurTitre
    readonly property alias lignesCorps: contenu.lignesCorps

    // libellesRendus — textes des actions affichés par la rangée (CorpsNotification.libellesRendus), lus par les
    // essais. Entrées : aucune. Sortie : tableau de chaînes. Erreurs : aucune. Dépendances : contenu.
    function libellesRendus() { return contenu.libellesRendus() }

    // boutonsRendus — boutons des actions affichés (CorpsNotification.boutonsRendus), lus par les essais. Entrées :
    // aucune. Sortie : tableau de Bouton. Erreurs : aucune. Dépendances : contenu.
    function boutonsRendus() { return contenu.boutonsRendus() }
    readonly property alias libelles: contenu.libelles
    readonly property alias texteApplication: contenu.texteApplication
    readonly property alias texteHeure: contenu.texteHeure

    width: Theme.notifications?.largeur ?? 0
    implicitHeight: contenu.implicitHeight + 2 * interieur

    // Le survol de la carte est celui de l'entrée : la pile en déduit l'arrêt de la minuterie.
    HoverHandler { id: survol }
    Binding { target: carte.entree; property: "survolee"; value: survol.hovered; when: carte.entree !== null }

    // Clic hors des actions : la notification est écartée. Chaque action saisit son propre clic dès l'appui
    // (ReleaseWithinBounds), si bien qu'il n'atteint pas ce gestionnaire.
    TapHandler { gesturePolicy: TapHandler.ReleaseWithinBounds; onTapped: carte.pile.cliquer(carte.entree) }

    OmbreElevation { cible: verre; niveau: "e3"; evidee: true }

    Surface {
        id: verre
        anchors.fill: parent
        role: "surfaceRaised"
        verre: true
        radius: Theme.radius?.panel ?? 0
    }

    CorpsNotification {
        id: contenu
        x: carte.interieur
        y: carte.interieur
        width: carte.width - 2 * carte.interieur
        notification: carte.notification
        arrivee: carte.entree?.arrivee ?? new Date(0)
        survolee: carte.survolee
        onAction: a => carte.pile.agir(carte.entree, a)
    }
}
