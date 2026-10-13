import QtQuick

// ParamSlider — curseur de réglage d'un paramètre de ressort.
// Rôle : manipulation directe (la poignée suit le pointeur, sans animation) ;
// échelle logarithmique possible pour k et c, qui varient sur deux décades.
// Entrées : label, value, from, to, log, decimals, unit, enabled.
// Sortie : signal moved(real v). Erreurs : aucune. Dépendances : Theme.
Item {
    id: sl
    property string label
    property real value
    property real from: 0
    property real to: 1
    property bool log: false
    property int decimals: 0
    property string unit: ""
    signal moved(real v)

    implicitHeight: 40
    opacity: enabled ? 1 : 0.5

    // pos — valeur → position 0–1 sur la piste. Entrée : v. Sortie : réel borné. Erreurs : aucune.
    function pos(v) {
        const p = log ? Math.log(v / from) / Math.log(to / from) : (v - from) / (to - from)
        return Math.min(1, Math.max(0, p))
    }
    // val — position 0–1 → valeur arrondie à `decimals`. Entrée : p. Sortie : réel. Erreurs : aucune.
    function val(p) {
        p = Math.min(1, Math.max(0, p))
        const v = log ? from * Math.pow(to / from, p) : from + p * (to - from)
        const f = Math.pow(10, decimals)
        return Math.round(v * f) / f
    }

    Text {
        text: sl.label
        color: Theme.textSecondary
        font { family: Theme.fontFamily; pixelSize: Theme.fontSize }
    }
    Text {
        anchors.right: parent.right
        text: sl.value.toFixed(sl.decimals) + (sl.unit ? " " + sl.unit : "")
        color: Theme.textPrimary
        font { family: Theme.fontFamily; pixelSize: Theme.fontSize; weight: 500; features: { "tnum": 1 } }
    }
    Rectangle {   // piste à E0 (bible : curseur, piste à E0, poignée à E3)
        id: track
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; bottomMargin: 6 }
        height: 4; radius: 2; color: Theme.base
        Rectangle { width: sl.pos(sl.value) * track.width; height: parent.height; radius: 2; color: Theme.accent }
        Rectangle {
            width: 14; height: 14; radius: 7
            x: sl.pos(sl.value) * track.width - 7; anchors.verticalCenter: parent.verticalCenter
            color: Theme.raised; border { width: 1; color: Theme.borderStrong }
        }
    }
    MouseArea {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 24
        enabled: sl.enabled
        onPressed: mouse => sl.moved(sl.val(mouse.x / width))
        onPositionChanged: mouse => { if (pressed) sl.moved(sl.val(mouse.x / width)) }
        onWheel: wheel => sl.moved(sl.val(sl.pos(sl.value) + (wheel.angleDelta.y > 0 ? 0.005 : -0.005)))
    }
}
