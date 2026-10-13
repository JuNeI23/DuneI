import QtQuick

// ParamSlider — curseur de réglage d'un paramètre de ressort.
// Rôle : manipulation directe (la poignée suit le pointeur, sans animation) ;
// échelle logarithmique possible pour k et c, qui varient sur deux décades ;
// réglage atomique par − / + (pas `step`) ou saisie exacte (clic sur la valeur, Entrée).
// Entrées : label, value, from, to, log, decimals, step, unit, enabled.
// Sortie : signal moved(real v). Erreurs : saisie non numérique ignorée (valeur inchangée).
// Dépendances : Theme, Btn.
Item {
    id: sl
    property string label
    property real value
    property real from: 0
    property real to: 1
    property bool log: false
    property int decimals: 0
    property real step: Math.pow(10, -decimals)
    property string unit: ""
    signal moved(real v)

    implicitHeight: Theme.controlHeight + 18
    opacity: enabled ? 1 : 0.5

    // pos — valeur → position 0–1 sur la piste. Entrée : v. Sortie : réel borné. Erreurs : aucune.
    function pos(v) {
        const p = log ? Math.log(v / from) / Math.log(to / from) : (v - from) / (to - from)
        return Math.min(1, Math.max(0, p))
    }
    // clean — borne à [from, to] et arrondit à `decimals`. Entrée : v. Sortie : réel. Erreurs : aucune.
    function clean(v) {
        const f = Math.pow(10, decimals)
        return Math.round(Math.min(to, Math.max(from, v)) * f) / f
    }
    // val — position 0–1 → valeur arrondie. Entrée : p. Sortie : réel. Erreurs : aucune.
    function val(p) {
        p = Math.min(1, Math.max(0, p))
        return clean(log ? from * Math.pow(to / from, p) : from + p * (to - from))
    }
    // nudge — pas atomique. Entrée : n (±1). Sortie : émet moved. Erreurs : aucune.
    function nudge(n) { sl.moved(clean(value + n * step)) }

    Text {
        anchors.verticalCenter: plus.verticalCenter
        text: sl.label
        color: Theme.textSecondary
        font { family: Theme.fontFamily; pixelSize: Theme.fontSize }
    }
    Btn { id: plus; anchors.right: parent.right; width: height; text: "+"; level: 2; onClicked: if (sl.enabled) sl.nudge(1) }
    TextInput {   // saisie exacte : virgule ou point, Entrée valide, Échap annule
        id: field
        anchors { right: plus.left; rightMargin: 4; verticalCenter: plus.verticalCenter }
        width: 72; horizontalAlignment: TextInput.AlignRight
        readOnly: !sl.enabled; selectByMouse: true
        text: sl.value.toFixed(sl.decimals)
        color: activeFocus ? Theme.textEmphasis : Theme.textPrimary
        selectionColor: Theme.accent; selectedTextColor: Theme.onAccent
        font { family: Theme.fontFamily; pixelSize: Theme.fontSize; weight: 500; features: { "tnum": 1 } }
        onActiveFocusChanged: if (activeFocus) selectAll()
        onAccepted: {
            const v = parseFloat(text.replace(",", "."))
            if (!isNaN(v)) sl.moved(sl.clean(v))
            text = Qt.binding(() => sl.value.toFixed(sl.decimals)); sl.forceActiveFocus()
        }
        Keys.onEscapePressed: { text = Qt.binding(() => sl.value.toFixed(sl.decimals)); sl.forceActiveFocus() }
        Rectangle {   // soulignement : signale le champ éditable, accent pendant la saisie
            anchors { left: parent.left; right: parent.right; top: parent.bottom; topMargin: 1 }
            height: 1; color: field.activeFocus ? Theme.accent : Theme.borderStrong
        }
    }
    Text {
        anchors { right: field.left; rightMargin: 4; verticalCenter: plus.verticalCenter }
        visible: sl.unit !== ""; text: sl.unit
        color: Theme.textSecondary
        font { family: Theme.fontFamily; pixelSize: Theme.fontSize }
    }
    Btn {
        anchors { right: field.left; rightMargin: sl.unit ? 28 : 8 }
        width: height; text: "−"; level: 2; onClicked: if (sl.enabled) sl.nudge(-1)
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
        height: 16
        enabled: sl.enabled
        onPressed: mouse => sl.moved(sl.val(mouse.x / width))
        onPositionChanged: mouse => { if (pressed) sl.moved(sl.val(mouse.x / width)) }
        onWheel: wheel => sl.nudge(wheel.angleDelta.y > 0 ? 1 : -1)
    }
}
