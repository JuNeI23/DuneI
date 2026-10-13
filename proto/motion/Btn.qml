import QtQuick

// Btn — bouton du banc, animé par la transition `state` (survol, pression, sélection).
// Entrées : text, checked (sélection), level (fond de repos : 2 = posé sur panneau, se confond avec lui ; 3 = relief).
// Sortie : signal clicked(). Erreurs : aucune. Dépendances : Spring, Theme, Motion.
Item {
    id: b
    property string text
    property bool checked: false
    property int level: 3
    signal clicked()

    implicitWidth: label.implicitWidth + 2 * Theme.padding
    implicitHeight: Theme.controlHeight

    readonly property var lch: Theme.parse(Theme.tokens.elevation?.["e" + level])
    Spring { id: hov; params: Motion.state }
    Spring { id: prs; params: Motion.state }
    Spring { id: sel; params: Motion.state }
    onCheckedChanged: sel.to(checked ? 1 : 0, !checked)
    Component.onCompleted: sel.snap(checked ? 1 : 0)

    Rectangle {
        anchors.fill: parent; radius: Theme.rControl
        color: Theme.stateFill(b.lch, sel.value, hov.value, prs.value)
    }
    Text {
        id: label
        anchors.centerIn: parent
        text: b.text
        color: Theme.stateText(sel.value)
        font { family: Theme.fontFamily; pixelSize: Theme.fontSize; weight: 500 }
    }
    MouseArea {
        anchors.fill: parent; hoverEnabled: true
        onEntered: hov.to(1, false)
        onExited: hov.to(0, true)
        onPressed: prs.to(1, false)
        onReleased: prs.to(0, true)
        onClicked: b.clicked()
    }
}
