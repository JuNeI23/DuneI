import QtQuick
import "physics.js" as Physics

// Ressort — grandeur numérique affichée qui rejoint sa cible par le ressort d'une transition de mouvement.
// Rôle : à chaque nouvelle cible, repart de la position et de la vitesse courantes (une interruption en vol ne
// saute pas et ne forme aucune file d'attente, bible ch. 6) ; sert de moteur à toute taille ou position animée
// de la coque (largeur d'une pastille, taille de la presqu'île). Les paramètres viennent toujours de
// motion.json : `in` quand la cible est supérieure à la valeur affichée, `out` quand elle est inférieure, sauf si
// `sens` impose l'un des deux.
// Mouvement réduit (Theme.mouvementReduit) : un ressort de nature « deplacement » se pose sur sa cible aussitôt ;
// un ressort de nature « fondu » suit le ressort `reduced` de motion.json, court et sans dépassement. Si la préférence
// devient réduite pendant qu'un ressort de déplacement avance, il se pose aussitôt sur sa cible.
// Entrées : transition nom d'une transition de motion.json (défaut « navigate ») ; cible valeur visée ;
//          sens « in » ou « out » pour forcer le réglage, relu à chaque image, « » pour le choisir selon le sens de
//          la cible (défaut) ; seuil écart, dans l'unité de la valeur, sous lequel le ressort se pose (0 garde le
//          critère de physics.js) ; nature « deplacement » (défaut) ou « fondu », ce que le ressort anime.
// Sorties : value valeur affichée ; moving vrai tant que le ressort avance ; vitesse() vitesse courante ; poser()
//          pose le ressort sur sa cible sans animation ; reprendre(x, v) le relance depuis une position et une vitesse,
//          pour qu'un autre ressort continue un mouvement sans rupture.
// Erreurs : aucune ; avant que Theme soit prêt, ou si la transition est inconnue, value prend cible sans
//           animation, ainsi qu'à la création : la cible initiale se pose d'un coup. Sans le réglage `reduced` (motion.json
//           ancien), un fondu réduit garde le réglage ordinaire de sa transition.
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
    property string sens: ""
    property real seuil: 0
    property string nature: "deplacement"
    property var _t: null
    // Vrai quand la préférence de mouvement réduit impose à ce ressort de se poser sur sa cible : seul un fondu garde un
    // ressort.
    readonly property bool _pose: Theme.mouvementReduit && nature !== "fondu"

    // Un ressort de déplacement qui avance quand la préférence devient réduite se pose aussitôt.
    on_PoseChanged: if (_pose && anim.running) poser()

    Component.onCompleted: { _pret = true; _st = { x: cible, v: 0, acc: 0 }; _x = cible }

    // vitesse — vitesse courante du ressort, en unités de valeur par seconde.
    // Entrées : aucune. Sortie : réel, nul au repos. Erreurs : aucune. Dépendances : _st.
    function vitesse() { return _st.v }

    // poser — pose le ressort sur sa cible d'un coup, sans animation ni vitesse résiduelle.
    // Entrées : aucune. Sortie : aucune ; value égale cible et moving est faux aussitôt. Erreurs : aucune.
    // Dépendances : anim, _st. Sert à la première valeur d'une grandeur dont la cible n'est connue qu'après la création,
    // et au mouvement réduit, où le ressort se pose d'un coup au lieu de rouler.
    function poser() {
        anim.stop()
        _st = { x: cible, v: 0, acc: 0 }
        _x = cible
    }

    // reprendre — relance le ressort depuis une position et une vitesse données, vers sa cible courante : un ressort
    // qui prend le relais d'un autre (même transition) continue son mouvement sans saut de valeur ni de vitesse.
    // Entrées : x, position de départ ; v, vitesse de départ, en unités de valeur par seconde (celle que rend
    // vitesse()). Sortie : aucune ; value vaut x aussitôt, et le ressort avance s'il n'est pas déjà au repos sur sa
    // cible. Erreurs : aucune ; avant que Theme soit prêt, si la transition est inconnue, ou pour un déplacement en
    // mouvement réduit, le ressort se pose sur sa cible comme à tout changement de cible.
    // Dépendances : anim, poser, Theme (motion.transitions).
    function reprendre(x, v) {
        anim.stop()
        _st = { x: x, v: v, acc: 0 }
        _x = x
        const t = Theme.ready ? Theme.motion?.transitions?.[transition] : null
        if (!t || _pose) return poser()
        _t = t
        _params = cible > x ? t.in : t.out
        if (x !== cible || v !== 0) anim.start()
    }

    onCibleChanged: {
        if (!_pret) return
        const t = Theme.ready ? Theme.motion?.transitions?.[transition] : null
        // Réduit, ce qui se déplace se pose aussitôt ; seul un fondu garde un ressort.
        if (!t || _pose) {
            poser()
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
            // Un fondu réduit suit `reduced` ; sans ce réglage (motion.json ancien), il garde celui de sa transition.
            const r = (Theme.mouvementReduit && ressort.nature === "fondu" ? Theme.motion?.reduced : null)
                ?? (ressort.sens ? ressort._t[ressort.sens] : ressort._params)
            // Le temps d'une image est plafonné : une image très longue ne doit pas faire sauter le ressort.
            Physics.integrate(ressort._st, ressort.cible, r.mass, r.stiffness, r.dampening, Math.min(frameTime, 0.05))
            const done = Physics.atRest(ressort._st, ressort.cible) || Math.abs(ressort._st.x - ressort.cible) < ressort.seuil
            ressort._x = done ? ressort.cible : ressort._st.x
            if (done) { ressort._st.x = ressort.cible; ressort._st.v = 0; stop() }
        }
    }
}
