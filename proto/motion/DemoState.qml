import QtQuick

// DemoState — transition `state` : rangées de liste et boutons, survol / pressé / sélection.
// Rôle : montrer un changement d'état sur place — aucun déplacement, aucune échelle ;
// seule la luminosité (+0,04 L au survol, sous le repos à la pression) et l'accent bougent.
// Entrées : souris, play(), interrupt(). Sortie : aucune. Erreurs : aucune.
// Dépendances : Spring, Surface, Btn, Theme, Motion.
Item {
    id: demo
    property Params params: Motion.state
    property int hoverIdx: -1      // survol simulé (la souris réelle s'ajoute)
    property int pressIdx: -1
    property int selIdx: 1
    property var script: []

    // play — rejoue une séquence : survol, glissement, pression, sélection.
    // Entrées : aucune. Sortie : aucune. Erreurs : aucune. Dépendances : step.
    function play() {
        hoverIdx = -1; pressIdx = -1; selIdx = 1
        script = [[0, -1, 1], [2, -1, 1], [3, -1, 1], [3, 3, 1], [3, -1, 3], [4, -1, 3], [-1, -1, 3]]
        step.restart()
    }

    // interrupt — sélectionne une autre rangée puis revient en plein vol (40 % de l'entrée).
    // Entrées : aucune. Sortie : aucune. Erreurs : aucune. Dépendances : flip.
    function interrupt() {
        step.stop()
        flip.back = selIdx; selIdx = selIdx === 4 ? 1 : 4
        flip.interval = Math.max(20, 0.4 * (Motion.reduced ? 100 : params.enter.settle)); flip.restart()
    }

    Timer { id: flip; property int back; onTriggered: demo.selIdx = back }
    Timer {
        id: step; interval: 260; repeat: true
        onTriggered: {
            const s = demo.script.shift()
            if (!s) { stop(); return }
            demo.hoverIdx = s[0]; demo.pressIdx = s[1]; demo.selIdx = s[2]
        }
    }

    Surface {   // barre latérale E2
        id: side
        level: 2; radius: Theme.rPanel
        width: 260; height: col.implicitHeight + 2 * Theme.padding
        anchors.centerIn: parent; anchors.horizontalCenterOffset: -140
        Column {
            id: col
            x: Theme.padding / 2; y: Theme.padding; width: parent.width - Theme.padding
            Repeater {
                model: ["Documents", "Images", "Musique", "Projets", "Téléchargements", "Vidéos"]
                delegate: Item {
                    id: row
                    required property string modelData
                    required property int index
                    width: col.width; height: Theme.rowHeight
                    readonly property bool hovered: demo.hoverIdx === index || ma.containsMouse
                    readonly property bool pressed: demo.pressIdx === index || ma.pressed
                    readonly property bool selected: demo.selIdx === index
                    Spring { id: hov; params: demo.params }
                    Spring { id: prs; params: demo.params }
                    Spring { id: sel; params: demo.params }
                    onHoveredChanged: hov.to(hovered ? 1 : 0, !hovered)
                    onPressedChanged: prs.to(pressed ? 1 : 0, !pressed)
                    onSelectedChanged: sel.to(selected ? 1 : 0, !selected)
                    Component.onCompleted: sel.snap(selected ? 1 : 0)
                    Rectangle {
                        anchors.fill: parent; radius: Theme.rSmall
                        color: Theme.stateFill(Theme.lPanel, sel.value, hov.value, prs.value)
                    }
                    Text {
                        x: Theme.padding / 2 + 4; anchors.verticalCenter: parent.verticalCenter
                        text: row.modelData
                        color: Theme.stateText(sel.value)
                        font { family: Theme.fontFamily; pixelSize: Theme.fontSize }
                    }
                    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; onClicked: demo.selIdx = row.index }
                }
            }
        }
    }

    Surface {   // panneau de boutons
        level: 2; radius: Theme.rPanel
        width: 220; height: side.height
        anchors { left: side.right; leftMargin: 24; verticalCenter: side.verticalCenter }
        Column {
            anchors.centerIn: parent; spacing: Theme.padding
            Btn { text: "Bouton en relief"; width: 160 }
            Btn { id: tg; text: tg.checked ? "Interrupteur : actif" : "Interrupteur : repos"; width: 160; onClicked: checked = !checked }
            Btn { text: "Posé sur le panneau"; level: 2; width: 160 }
        }
    }

    Text {
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 24 }
        text: "Survolez, pressez, cliquez. Rien ne bouge ni ne change de taille : seule la luminosité répond."
        color: Theme.textTertiary
        font { family: Theme.fontFamily; pixelSize: Theme.fontSize }
    }
}
