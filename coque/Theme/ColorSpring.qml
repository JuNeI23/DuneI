import QtQuick
import "physics.js" as Physics

// ColorSpring — couleur affichée qui rejoint une couleur générée par le ressort d'état.
// Rôle : à chaque nouvelle cible d'un même thème, part de la couleur affichée (une interruption en vol ne
// saute pas) et avance une progression 0 → 1 selon le ressort employé ; la couleur affichée est
// l'interpolation sRGB, composante par composante, entre l'origine et la cible. Aucune couleur n'est calculée
// ici : origine et cible viennent toujours de Theme.
// Entrées : target couleur visée ; params ressort {mass, stiffness, dampening}, par défaut celui des
//           changements d'état (transitions.state.in de motion.json), employé aussi pour le retour au repos
//           (conception, § 7.8).
// Sorties : value couleur affichée ; moving vrai tant que le ressort avance.
// Erreurs : aucune ; avant que Theme soit prêt, au premier chargement et à chaque changement de thème,
//           value prend target sans animation : tout le thème bascule dans la même image. Un nouvel objet de
//           tokens qui ne change pas la cible (relecture d'un contenu identique, ou cible de même valeur dans
//           les deux thèmes) pose aussi un ressort en vol sur sa cible, au tour de boucle suivant.
// Dépendances : Theme (singleton du module), physics.js (integrate, atRest).
// Le ressort n'est pas figé au changement de cible : chaque image de l'animation lit params.
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

    // settle — prend acte d'un nouvel objet de tokens que onTargetChanged n'a pas vu passer.
    // Rôle : appelé un tour de boucle après Theme.tokensChanged, quand toutes les liaisons sont réévaluées ;
    //        si la cible n'a pas changé (contenu identique ou même couleur dans les deux thèmes), mémorise le
    //        nouvel objet, faute de quoi le prochain changement d'état se poserait d'un coup au lieu d'animer,
    //        et pose sur sa cible un ressort en vol, dont l'origine appartient à l'ancien thème.
    // Entrées : aucune. Sortie : aucune. Erreurs : aucune. Dépendances : Theme.tokens, anim.
    function settle() {
        if (seen.tokens === Theme.tokens) return
        seen.tokens = Theme.tokens
        anim.stop()
        value = target
    }

    // Le délai laisse onTargetChanged, déclenché par la même notification, poser le ressort dans la même image.
    Connections {
        target: Theme
        function onTokensChanged() { Qt.callLater(spring.settle) }
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
            const r = spring.params
            Physics.integrate(spring.st, 1, r.mass, r.stiffness, r.dampening, frameTime)
            const done = Physics.atRest(spring.st, 1)
            spring.value = done ? spring.target : spring.mix(spring.origin, spring.target, spring.st.x)
            if (done) stop()
        }
    }
}
