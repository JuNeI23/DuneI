import QtQuick
import "physics.js" as Physics

// Ressort — grandeur numérique affichée qui rejoint sa cible par le ressort d'une transition de mouvement.
// Rôle : à chaque nouvelle cible, repart de la position et de la vitesse courantes (une interruption en vol ne
// saute pas et ne forme aucune file d'attente, bible ch. 6) ; sert de moteur à toute taille ou position animée
// de la coque (largeur d'une pastille, taille de la presqu'île). Les paramètres viennent toujours de
// motion.json : `in` quand la cible est supérieure à la valeur affichée, `out` quand elle est inférieure.
// Entrées : transition nom d'une transition de motion.json (défaut « navigate ») ; cible valeur visée.
// Sorties : value valeur affichée ; moving vrai tant que le ressort avance ; vitesse() vitesse courante ; poser()
//          pose le ressort sur sa cible sans animation.
// Erreurs : aucune ; avant que Theme soit prêt, ou si la transition est inconnue, value prend cible sans
//           animation, ainsi qu'à la création : la cible initiale se pose d'un coup. Le mouvement réduit n'a pas encore de bascule dans la
//           coque : il n'est pas lu ici.
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
    // MESURE TEMPORAIRE de l'essai de mouvement.
    property string mesure: ""
    // ESSAI JETABLE : force « in » ou « out » pour que plusieurs ressorts avancent ensemble, quel que soit leur sens.
    property string force: ""
    property var _t: null
    // ESSAI JETABLE : écart, en unités de la valeur, sous lequel le ressort se pose ; 0 garde le critère de physics.js.
    property real seuil: 0
    property var _dts: []

    Component.onCompleted: { _pret = true; _st = { x: cible, v: 0, acc: 0 }; _x = cible }

    // vitesse — vitesse courante du ressort, en unités de valeur par seconde.
    // Entrées : aucune. Sortie : réel, nul au repos. Erreurs : aucune. Dépendances : _st.
    function vitesse() { return _st.v }

    // poser — pose le ressort sur sa cible d'un coup, sans animation ni vitesse résiduelle.
    // Entrées : aucune. Sortie : aucune ; value égale cible et moving est faux aussitôt. Erreurs : aucune.
    // Dépendances : anim, _st. Sert à la première valeur d'une grandeur dont la cible n'est connue qu'après la création.
    function poser() {
        anim.stop()
        _st = { x: cible, v: 0, acc: 0 }
        _x = cible
    }

    onCibleChanged: {
        if (!_pret) return
        const t = Theme.ready ? Theme.motion?.transitions?.[transition] : null
        if (!t) {
            anim.stop()
            _st = { x: cible, v: 0, acc: 0 }
            _x = cible
            return
        }
        _t = t
        _params = cible > _x ? t.in : t.out
        _st.x = _x
        anim.start()
    }

    FrameAnimation {
        id: anim
        onTriggered: {
            const r = ressort.force ? ressort._t[ressort.force] : ressort._params
            if (ressort.mesure) ressort._dts.push(frameTime * 1000)
            // Le temps d'une image est plafonné : une image très longue ne doit pas faire sauter le ressort.
            Physics.integrate(ressort._st, ressort.cible, r.mass, r.stiffness, r.dampening, Math.min(frameTime, 0.05))
            const done = Physics.atRest(ressort._st, ressort.cible) || Math.abs(ressort._st.x - ressort.cible) < ressort.seuil
            ressort._x = done ? ressort.cible : ressort._st.x
            if (done) { ressort._st.x = ressort.cible; ressort._st.v = 0; stop()
                if (ressort.mesure) { const d = ressort._dts; console.info("MESURE", ressort.mesure, "images", d.length, "total", Math.round(d.reduce((x, y) => x + y, 0)), "ms ; delta", d.map(v => Math.round(v)).join(" ")); ressort._dts = [] } }
        }
    }
}
