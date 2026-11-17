import QtQuick
import "../Theme"
import "../Composants"
import "../Composants/etats.js" as Etats

// LigneAttente — une notification en attente, dans un groupe du panneau (L2-67).
// Rôle : montre le contenu de la notification (CorpsNotification, sans ligne d'en-tête : le groupe nomme déjà
// l'application) sans plaque propre : on ne pose pas de verre sur du verre. Au survol, elle prend l'état de rangée de
// la bible (pastille de survol, transparente au repos), déplie ses actions en texte et montre, à la place de l'heure,
// son bouton d'écart. Un clic hors des actions ouvre la notification (Attente.ouvrir) ; le bouton l'écarte. Au
// clavier, l'entrée courante du panneau porte le contour de focus des rangées.
// Mouvement : la ligne se déplie et se replie en hauteur et en fondu au ressort « reveal », découpée pendant le
// mouvement (D157) : quand son groupe se déplie ou se replie (montree), quand elle arrive dans un panneau déjà
// monté, et quand sa notification est fermée (sortante) ; repliée et sortante, elle fait oublier son entrée à
// l'attente.
// Entrées : attendue, l'Attendue montrée ; attente, l'Attente ; hote, le Panneau (courante, clavier, pret) ;
// montree, faux quand le groupe replié la cache.
// Sorties : hovered et down, lus par son Etat ; height, hauteur montrée.
// Erreurs : aucune. Dépendances : CorpsNotification, Etat, Icone, Ressort, etats.js, Theme (panneau, space, radius,
// focus, icons, color), Attente (ouvrir, agir, ecarter, oublier).
// Cotes : retrait intérieur de space.scale[1] (8) ; pastille au rayon radius.control ; bouton d'écart de
// icons.sizes.dense, glyphe edit-clear.
Item {
    id: ligne

    required property QtObject attendue
    required property QtObject attente
    required property QtObject hote
    property bool montree: true
    readonly property bool hovered: survol.hovered
    readonly property bool down: clic.pressed
    readonly property bool courante: hote.courante === attendue && hote.clavier
    readonly property real retrait: Theme.space?.scale[1] ?? 0
    readonly property bool presente: montree && !(attendue?.sortante ?? true)

    height: Math.max(0, presence.value) * (contenu.implicitHeight + 2 * retrait)
    opacity: Math.max(0, Math.min(1, fondu.value))
    visible: height > 0
    clip: presence.moving

    // verifier — fait oublier l'entrée sortante une fois la ligne repliée. Entrées, sortie, erreurs : aucune.
    // Dépendances : presence, Attente.oublier.
    function verifier() {
        if (attendue?.sortante && !presence.moving && presence.value <= 0) attente.oublier(attendue)
    }

    Ressort { id: presence; transition: "reveal"; cible: ligne.presente ? 1 : 0; onMovingChanged: ligne.verifier() }
    Ressort { id: fondu; transition: "reveal"; nature: "fondu"; cible: presence.cible }
    Ressort { id: ecartable; transition: "state"; nature: "fondu"; cible: ligne.hovered ? 1 : 0 }

    // Une ligne qui naît dans un panneau déjà monté se déplie ; à l'ouverture du panneau, elle est posée.
    Component.onCompleted: if (hote.pret && presente) { presence.reprendre(0, 0); fondu.reprendre(0, 0) }

    Connections {
        target: ligne.attendue
        function onSortanteChanged() { Qt.callLater(ligne.verifier) }
    }

    HoverHandler { id: survol }
    // Clic hors des actions et du bouton d'écart, qui saisissent le leur dès l'appui.
    TapHandler { id: clic; gesturePolicy: TapHandler.ReleaseWithinBounds; onTapped: ligne.attente.ouvrir(ligne.attendue) }

    Etat {
        id: etat
        controle: ligne
        role: Etats.herite(ligne, "dnRole", "surfaceWindow")
        fondReposTransparent: true
        peintTexte: false
    }

    Rectangle {
        id: pastille
        anchors.fill: parent
        radius: Theme.radius?.control ?? 0
        color: etat.fond

        Rectangle {
            readonly property real decalage: Theme.focus?.rowOffset ?? 0
            anchors.fill: parent
            anchors.margins: -decalage
            radius: pastille.radius + decalage
            visible: ligne.courante
            color: "transparent"
            border.width: Theme.focus?.width ?? 0
            border.color: Theme.focus?.color ?? "transparent"
        }
    }

    CorpsNotification {
        id: contenu
        x: ligne.retrait
        y: ligne.retrait
        width: ligne.width - 2 * ligne.retrait
        notification: ligne.attendue?.notification ?? null
        arrivee: ligne.attendue?.arrivee ?? new Date(0)
        lignes: Theme.panneau?.lignes ?? 1
        enTete: false
        survolee: ligne.hovered
        estompe: ecartable.value
        onAction: a => ligne.attente.agir(ligne.attendue, a)
    }

    // Bouton d'écart, à la place de l'heure tant que la ligne est survolée.
    Icone {
        anchors.right: parent.right
        anchors.rightMargin: ligne.retrait
        y: ligne.retrait
        visible: opacity > 0
        opacity: ecartable.value
        taille: Theme.icons?.sizes.dense ?? 0
        nom: "edit-clear"
        couleur: Theme.color?.textSecondary ?? "transparent"

        TapHandler { gesturePolicy: TapHandler.ReleaseWithinBounds; onTapped: ligne.attente.ecarter(ligne.attendue) }
    }
}
