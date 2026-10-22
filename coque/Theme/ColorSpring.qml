import QtQuick
import "physics.js" as Physics

// ColorSpring — couleur affichée qui rejoint une couleur générée par le ressort d'état.
// Rôle : à chaque nouvelle cible, part de la couleur affichée (une interruption en vol ne saute pas) et
// avance une progression 0 → 1 selon le ressort transitions.state.in de motion.json ; la couleur affichée
// est l'interpolation sRGB, composante par composante, entre l'origine et la cible. Aucune couleur n'est
// calculée ici : origine et cible viennent toujours de Theme.
// Entrées : target couleur visée ; params ressort {mass, stiffness, dampening}, par défaut celui des
//           changements d'état.
// Sorties : value couleur affichée ; moving vrai tant que le ressort avance.
// Erreurs : aucune ; jusqu'au premier chargement de Theme inclus, value suit target sans animation.
// Dépendances : Theme (singleton du module), physics.js (integrate, atRest).
Item {
    id: spring
    visible: false

    property color target
    property var params: Theme.motion?.transitions.state.in
    property color value
    readonly property bool moving: anim.running
    property color origin
    property var st: ({ x: 1, v: 0, acc: 0 })
    // Armé un tour de boucle après que Theme devient prêt : la cible posée par le premier chargement, dans le
    // même tour, s'applique sans animation au lieu de partir d'une couleur d'attente.
    property bool armed: false

    Component.onCompleted: { value = target; armed = Theme.ready }

    Connections {
        target: Theme
        function onReadyChanged() { Qt.callLater(() => spring.armed = Theme.ready) }
    }

    onTargetChanged: {
        if (!armed || !params) { anim.stop(); value = target; return }
        origin = value
        st = { x: 0, v: 0, acc: 0 }
        anim.restart()
    }

    // mix — interpolation linéaire composante par composante entre deux couleurs.
    // Entrées : a couleur d'origine, b couleur cible, p progression (0 → a, 1 → b).
    // Sortie : couleur interpolée. Erreurs : aucune. Dépendances : aucune.
    function mix(a, b, p) {
        return Qt.rgba(a.r + (b.r - a.r) * p, a.g + (b.g - a.g) * p, a.b + (b.b - a.b) * p, a.a + (b.a - a.a) * p)
    }

    FrameAnimation {
        id: anim
        onTriggered: {
            Physics.integrate(spring.st, 1, spring.params.mass, spring.params.stiffness, spring.params.dampening, frameTime)
            const done = Physics.atRest(spring.st, 1)
            spring.value = done ? spring.target : spring.mix(spring.origin, spring.target, spring.st.x)
            if (done) stop()
        }
    }
}
