import QtQuick
import "physics.js" as Physics

// Params — réglage d'une transition du vocabulaire (bible ch. 6).
// Rôle : porte m, k, c, le facteur de sortie et les règles de la bible qui
// s'appliquent à cette transition ; expose ζ et la réponse mesurée.
// Entrées : propriétés ci-dessous. Sorties : zeta, enter, exit, exitScale, violation.
// Erreurs : aucune. Dépendances : physics.js.
QtObject {
    property string name                 // nom canonique (clé de motion.toml)
    property string usage                // emploi, repris de la bible
    property real mass: 1
    property real stiffness: 300
    property real damping: 35
    property real exitRatio: 0.7         // sortie / entrée (bible : ≈ 70 %)
    property bool overshoot: false       // dépassement AUTORISÉ par la bible (window seule)
    property bool symmetric: false       // reflow : sortie = entrée, facteur figé à 1
    property real staggerMs: -1          // reveal : décalage de cascade ; < 0 = sans objet
    property var defaults: ({})          // valeurs de départ, pour « Réinitialiser »

    readonly property real zeta: Physics.zeta(mass, stiffness, damping)
    readonly property real exitScale: symmetric ? 1 : 1 / exitRatio
    readonly property var enter: Physics.response(mass, stiffness, damping, 1, 2, 0)
    readonly property var exit: Physics.response(mass, stiffness, damping, exitScale, 2, 0)
    readonly property var exitSpring: Physics.exitParams(mass, stiffness, damping, symmetric ? 1 : exitRatio)
    // Violation de règle : dépassement alors que la bible l'interdit.
    readonly property bool violation: !overshoot && zeta < 1

    Component.onCompleted: defaults = { mass: mass, stiffness: stiffness, damping: damping,
                                        exitRatio: exitRatio, staggerMs: staggerMs }

    // reset — revient aux valeurs de départ. Entrées : aucune. Sortie : aucune.
    // Erreurs : aucune. Dépendances : defaults.
    function reset() {
        mass = defaults.mass; stiffness = defaults.stiffness; damping = defaults.damping
        exitRatio = defaults.exitRatio; staggerMs = defaults.staggerMs
    }
}
