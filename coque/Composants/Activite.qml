import QtQuick
import "../Theme"
import "etats.js" as Etats

// Activite — indicateur d'activité indéterminée de la coque : un anneau fin qui respire.
// Rôle : un cercle sans fond, cerné d'un trait à l'accent du rôle de son conteneur (sélection active, ou activeMuted
// sous le modificateur inactive hérité, § 7.5), dont l'opacité monte et descend lentement (conception, § 7.10). La
// respiration se fait par pas discrets : un cycle de motion.periods.spinner compte pasParCycle pas, arrondi de
// période × motion.cadences.spinner / 1000, si bien qu'un minuteur change l'opacité cadences.spinner fois par seconde
// (6), et non à chaque image comme le ferait une animation continue. L'opacité suit un cosinus : pleine au pas 0,
// au creux au demi-cycle. Sobriété (D80) : le minuteur ne court que si l'anneau est visible et en marche ; arrêté,
// il revient au pas 0 et reste affiché, pleinement opaque et immobile, sans rien coûter. La roue à traits de la
// version précédente, jugée chère et peu élégante, est abandonnée (v0.7). La progression déterminée est la
// Progression.
// Entrées : running, vrai par défaut ; visible.
// Sorties : pas, rang du pas courant dans le cycle ; pasParCycle ; creux, opacité minimale ; minuteur et anneau
// (le cercle dessiné), lus par les essais.
// Erreurs : aucune ; avant le chargement des tokens et du mouvement, l'anneau est de taille nulle, transparent, et le
// minuteur ne s'arme pas.
// Dépendances : Theme (icons.sizes, stateColors, motion.periods, motion.cadences), etats.js (herite) ; le rôle
// (dnRole) et le modificateur (dnInactive) viennent de la Surface englobante.
// Cotes : carré de icons.sizes.default ; le trait est une fraction du côté c, c / 8, et le creux de la respiration
// un facteur d'opacité, 0,35 : des proportions du dessin, non des cotes.
Item {
    id: activite

    property bool running: true
    property int pas: 0
    readonly property real creux: 0.35
    readonly property real periode: Theme.motion?.periods?.spinner ?? 0
    readonly property int pasParCycle: Math.round(periode * (Theme.motion?.cadences?.spinner ?? 0) / 1000)
    readonly property string role: Etats.herite(activite, "dnRole", "surfaceWindow")
    readonly property bool inactif: Etats.herite(activite, "dnInactive", false)
    readonly property alias minuteur: minuteur
    readonly property alias anneau: anneau

    implicitWidth: Theme.icons?.sizes.default ?? 0
    implicitHeight: implicitWidth

    Rectangle {
        id: anneau

        readonly property real c: Math.min(activite.width, activite.height)

        anchors.centerIn: parent
        width: c
        height: c
        radius: c / 2
        color: "transparent"
        border.width: c / 8
        border.color: Theme.stateColors(activite.role, activite.inactif ? "activeMuted" : "active", "rest")?.fill
                      ?? "transparent"
        opacity: activite.pasParCycle > 0 ? activite.creux + (1 - activite.creux)
                 * (1 + Math.cos(2 * Math.PI * activite.pas / activite.pasParCycle)) / 2 : 1
    }

    // Le minuteur avance d'un pas par intervalle ; à l'arrêt, il ramène l'anneau au pas 0, pleinement opaque.
    Timer {
        id: minuteur
        interval: activite.pasParCycle > 0 ? activite.periode / activite.pasParCycle : 0
        running: activite.visible && activite.running && interval > 0
        repeat: true
        onTriggered: activite.pas = (activite.pas + 1) % activite.pasParCycle
        onRunningChanged: if (!running) activite.pas = 0
    }
}
