import QtQuick
import "physics.js" as Physics

// ColorSpring — couleur affichée qui rejoint une couleur générée par le ressort d'état.
// Rôle : à chaque nouvelle cible d'un même thème, part de la couleur affichée (une interruption en vol ne
// saute pas) et avance une progression 0 → 1 selon le ressort transitions.state.in de motion.json ; la couleur
// affichée est l'interpolation sRGB, composante par composante, entre l'origine et la cible. Aucune couleur
// n'est calculée ici : origine et cible viennent toujours de Theme.
// Entrées : target couleur visée ; params ressort {mass, stiffness, dampening}, par défaut celui des
//           changements d'état.
// Sorties : value couleur affichée ; moving vrai tant que le ressort avance.
// Erreurs : aucune ; avant que Theme soit prêt, au premier chargement et à chaque changement de thème,
//           value prend target sans animation : tout le thème bascule dans la même image.
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
    // Objet de tokens sur lequel repose la couleur affichée : une cible qui change avec un nouvel objet
    // (premier chargement ou changement de thème) se pose d'un coup, comme les couleurs liées directement.
    // Il est rangé dans un objet JavaScript : affecté directement à une propriété var, il serait converti et
    // ne serait plus identique à Theme.tokens.
    property var seen: ({ tokens: null })

    Component.onCompleted: { value = target; seen.tokens = Theme.tokens }

    onTargetChanged: {
        if (!Theme.ready || !params || Theme.tokens !== seen.tokens) {
            seen.tokens = Theme.tokens
            anim.stop()
            value = target
            return
        }
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
