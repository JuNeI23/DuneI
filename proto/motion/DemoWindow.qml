import QtQuick
import QtQuick.Effects

// DemoWindow — transition `window` : fenêtre flottante qui s'ouvre et se ferme depuis un point.
// Rôle : seule transition à dépassement autorisé (ζ < 1). L'échelle part du point
// d'action (icône du dock, ou n'importe quel clic sur le bureau) ; ombre deux couches.
// Entrées : clic, play(), interrupt(). Sortie : aucune. Erreurs : aucune.
// Dépendances : Spring, Surface, Theme, Motion.
Item {
    id: demo
    property Params params: Motion.window
    property bool open: false
    property point origin: Qt.point(width / 2, height - 40)
    readonly property real gap: Motion.reduced ? 0 : 1
    readonly property real s0: 0.3          // échelle de départ : la fenêtre « sort » du point

    // toggle — ouvre ou ferme depuis un point. Entrée : pt (optionnel, coordonnées de la démo).
    // Sortie : aucune. Erreurs : aucune. Dépendances : sp.
    function toggle(pt) {
        if (pt && !open) origin = pt
        open = !open
        sp.to(open ? 1 : 0, !open)
    }
    // play — ferme sans animation puis ouvre depuis l'icône centrale. Entrées/sortie : aucune.
    function play() { open = false; sp.snap(0); toggle(dockOrigin(1)) }
    // interrupt — bascule puis inverse à 40 % de la stabilisation. Dépendances : flip.
    function interrupt() {
        toggle(open ? undefined : dockOrigin(1))
        flip.interval = Math.max(20, 0.4 * (Motion.reduced ? 100 : open ? params.enter.settle : params.exit.settle))
        flip.restart()
    }
    // dockOrigin — centre de l'icône i du dock, en coordonnées de la démo. Sortie : point.
    function dockOrigin(i) { const it = icons.itemAt(i); return it.mapToItem(demo, it.width / 2, it.height / 2) }
    Timer { id: flip; onTriggered: demo.toggle() }
    Spring { id: sp; params: demo.params }

    Rectangle { anchors.fill: parent; color: Theme.base; radius: Theme.rWindow }   // bureau E0
    MouseArea { anchors.fill: parent; onClicked: mouse => demo.toggle(Qt.point(mouse.x, mouse.y)) }
    Text {
        anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 20 }
        text: "Cliquez une icône ou n'importe où sur le bureau : la fenêtre part du point de clic."
        color: Theme.textTertiary; font { family: Theme.fontFamily; pixelSize: Theme.fontSize }
    }

    Surface {   // dock
        level: 2; radius: Theme.rPanel; width: row.implicitWidth + 16; height: 52
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 16 }
        Row {
            id: row; anchors.centerIn: parent; spacing: 8
            Repeater {
                id: icons
                model: 3
                Rectangle {
                    required property int index
                    width: 36; height: 36; radius: Theme.rControl
                    color: Theme.categorical[index * 2] ?? Theme.accent
                    MouseArea { anchors.fill: parent; onClicked: demo.toggle(demo.dockOrigin(parent.index)) }
                }
            }
        }
    }

    Surface {   // la fenêtre flottante (couche 2, E1, ombre deux couches)
        id: win
        level: 1; radius: Theme.rWindow; floating: true
        width: Math.min(460, demo.width - 48); height: Math.min(300, demo.height - 150)
        x: (demo.width - width) / 2; y: (demo.height - height) / 2 - 30
        visible: sp.value > 0.001
        opacity: Math.min(1, Math.max(0, sp.value * 1.6))
        transform: Scale {
            origin.x: demo.origin.x - win.x; origin.y: demo.origin.y - win.y
            xScale: 1 - demo.gap * (1 - demo.s0) * (1 - sp.value)
            yScale: xScale
        }
        Surface {
            level: 2; radius: Theme.rWindow; width: parent.width; height: 32
            Text {
                anchors.centerIn: parent; text: "Fenêtre flottante"
                color: Theme.textPrimary; font { family: Theme.fontFamily; pixelSize: Theme.fontSize; weight: 500 }
            }
        }
        Column {
            x: 20; y: 52; spacing: 10
            Repeater { model: 8; Rectangle { required property int index; width: 260 + (index * 53) % 140; height: 8; radius: 4; color: Theme.borderSubtle } }
        }
        MouseArea { anchors.fill: parent }   // un clic dans la fenêtre ne la ferme pas
    }
}
