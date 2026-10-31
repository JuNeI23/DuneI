import QtQuick
import "physics.js" as Physics

// Ressort — grandeur numérique affichée qui rejoint sa cible par le ressort d'une transition de mouvement.
// Rôle : à chaque nouvelle cible, repart de la position et de la vitesse courantes (une interruption en vol ne
// saute pas et ne forme aucune file d'attente, bible ch. 6) ; sert de moteur à toute taille ou position animée
// de la coque (largeur d'une pastille, taille de la presqu'île). Les paramètres viennent toujours de
// motion.json : `in` quand la cible est supérieure à la valeur affichée, `out` quand elle est inférieure.
// Entrées : transition nom d'une transition de motion.json (défaut « navigate ») ; cible valeur visée.
// Sorties : value valeur affichée ; moving vrai tant que le ressort avance ; vitesse() vitesse courante.
// Erreurs : aucune ; avant que Theme soit prêt, ou si la transition est inconnue, value prend cible sans
//           animation, ainsi qu'à la création : la cible initiale se pose d'un coup. Le mouvement réduit n'a pas encore de bascule dans la coque : il n'est pas lu ici.
// Dépendances : Theme (singleton du module), physics.js (integrate, atRest).
// L'animation ne tourne que tant que le ressort avance, pour rester à 0 % de processeur au repos.
Item {
    id: ressort
    visible: false

    property string transition: "navigate"
    property real cible: 0
    readonly property real value: _x
    readonly property bool moving: anim.running
    property real _x: cible
    property var _st: ({ x: 0, v: 0, acc: 0 })
    property var _params: null
    property bool _pret: false

    Component.onCompleted: { _pret = true; _st = { x: cible, v: 0, acc: 0 }; _x = cible }

    // vitesse — vitesse courante du ressort, en unités de valeur par seconde.
    // Entrées : aucune. Sortie : réel, nul au repos. Erreurs : aucune. Dépendances : _st.
    function vitesse() { return _st.v }

    onCibleChanged: {
        if (!_pret) return
        const t = Theme.ready ? Theme.motion?.transitions?.[transition] : null
        if (!t) {
            anim.stop()
            _st = { x: cible, v: 0, acc: 0 }
            _x = cible
            return
        }
        _params = cible > _x ? t.in : t.out
        _st.x = _x
        anim.start()
    }

    FrameAnimation {
        id: anim
        onTriggered: {
            const r = ressort._params
            // Le temps d'une image est plafonné : une image très longue ne doit pas faire sauter le ressort.
            Physics.integrate(ressort._st, ressort.cible, r.mass, r.stiffness, r.dampening, Math.min(frameTime, 0.05))
            const done = Physics.atRest(ressort._st, ressort.cible)
            ressort._x = done ? ressort.cible : ressort._st.x
            if (done) { ressort._st.x = ressort.cible; ressort._st.v = 0; stop() }
        }
    }
}
