import QtQuick
import "physics.js" as Physics

// Spring — un ressort animé, le seul moteur de mouvement du banc.
// Rôle : fait tendre `value` vers `target` selon les paramètres d'une transition.
// L'état (position + vitesse) est conservé : changer de cible en plein vol repart
// de l'état courant, sans file d'attente ni remise à zéro (bible ch. 6).
// Entrées : params (Params), reduced (bool) ; to(), snap().
// Sorties : value, velocity, moving, signal settled().
// Erreurs : aucune. Dépendances : physics.js, Motion (mouvement réduit).
Item {
    id: s
    visible: false

    property Params params: Motion.state
    property bool honorReduced: true       // faux pour les ressorts purement géométriques
    property real value: 0
    property real velocity: 0
    property real target: 0
    property real scale: 1                 // accélération temporelle courante (sortie : 1/exit_ratio)
    readonly property bool moving: anim.running
    readonly property bool reduced: honorReduced && Motion.reduced
    readonly property real m: reduced ? Motion.fade.mass : params.mass
    readonly property real k: reduced ? Motion.fade.stiffness : params.stiffness
    readonly property real c: reduced ? Motion.fade.damping : params.damping
    property var st: ({ x: 0, v: 0, acc: 0 })

    signal settled()

    // to — nouvelle cible, depuis l'état courant. Entrées : t cible ; exiting (bool) applique
    // le facteur de sortie ; delayMs retard optionnel (cascade). Sortie : aucune.
    // Erreurs : aucune. Dépendances : delay, anim.
    function to(t, exiting, delayMs) {
        delay.stop()
        if (delayMs > 0) { delay.pending = [t, exiting]; delay.interval = delayMs; delay.start(); return }
        target = t
        scale = exiting ? params.exitScale : 1
        st.x = value; st.v = velocity
        anim.start()
    }

    // snap — pose la valeur sans animation (état initial d'une démo). Entrée : v. Sortie : aucune.
    // Erreurs : aucune. Dépendances : anim, delay.
    function snap(v) {
        delay.stop(); anim.stop()
        value = target = v; velocity = 0
        st = { x: v, v: 0, acc: 0 }
    }

    Timer { id: delay; property var pending; onTriggered: s.to(pending[0], pending[1], 0) }

    FrameAnimation {
        id: anim
        onTriggered: {
            Physics.integrate(s.st, s.target, s.m, s.k, s.c, Math.min(frameTime, 0.05) * s.scale)
            s.value = s.st.x; s.velocity = s.st.v
            if (Physics.atRest(s.st, s.target)) {
                s.value = s.target; s.velocity = 0; s.st.x = s.target; s.st.v = 0
                stop(); s.settled()
            }
        }
    }
}
