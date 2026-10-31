import QtQuick
import "physics.js" as Physics

// Ressort — grandeur numérique affichée qui rejoint sa cible par le ressort d'une transition de mouvement.
// Rôle : à chaque nouvelle cible, repart de la position et de la vitesse courantes (une interruption en vol ne
// saute pas et ne forme aucune file d'attente, bible ch. 6) ; sert de moteur à toute taille ou position animée
// de la coque (largeur d'une pastille, taille de la presqu'île). Les paramètres viennent toujours de
// motion.json : `in` quand la cible est supérieure à la valeur affichée, `out` quand elle est inférieure.
// Entrées : transition nom d'une transition de motion.json (défaut « navigate ») ; cible valeur visée.
// Sorties : value valeur affichée ; moving vrai tant que le ressort avance.
// Erreurs : aucune ; avant que Theme soit prêt, ou si la transition est inconnue, value prend cible sans
//           animation. Le mouvement réduit n'a pas encore de bascule dans la coque : il n'est pas lu ici.
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
    property var st: ({ x: 0, v: 0, acc: 0 })
    property var params: null

    onCibleChanged: {
        const t = Theme.ready ? Theme.motion?.transitions?.[transition] : null
        if (!t) {
            anim.stop()
            st = { x: cible, v: 0, acc: 0 }
            _x = cible
            return
        }
        params = cible > _x ? t.in : t.out
        st.x = _x
        anim.start()
    }

    FrameAnimation {
        id: anim
        onTriggered: {
            const r = ressort.params
            // Le temps d'une image est plafonné : une image très longue ne doit pas faire sauter le ressort.
            Physics.integrate(ressort.st, ressort.cible, r.mass, r.stiffness, r.dampening, Math.min(frameTime, 0.05))
            const done = Physics.atRest(ressort.st, ressort.cible)
            ressort._x = done ? ressort.cible : ressort.st.x
            if (done) stop()
        }
    }
}
