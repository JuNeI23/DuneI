import QtQuick

// DemoReveal — transition `reveal` : popover contextuel de 8 éléments.
// Rôle : la surface part de son bouton déclencheur (origine en haut à gauche),
// les éléments arrivent en cascade, décalage plafonné à 5 éléments ; la sortie
// est groupée et plus rapide (exit_ratio). Overlay contextuel : ombre seule, ni voile ni flou.
// Entrées : clic, play(), interrupt(). Sortie : aucune. Erreurs : aucune.
// Dépendances : Spring, Surface, Btn, Theme, Motion.
Item {
    id: demo
    property Params params: Motion.reveal
    property bool open: false
    readonly property real gap: Motion.reduced ? 0 : 1    // 0 = ni déplacement ni échelle

    // toggle — ouvre ou ferme le popover depuis l'état courant.
    // Entrées : aucune. Sortie : aucune. Erreurs : aucune. Dépendances : pop, items.
    function toggle() {
        open = !open
        pop.to(open ? 1 : 0, !open)
        for (let i = 0; i < items.count; i++)
            items.itemAt(i).spring.to(open ? 1 : 0, !open, open ? Math.min(i, 4) * params.staggerMs : 0)
    }
    // play — referme sans animation puis ouvre. Entrées/sortie : aucune. Erreurs : aucune.
    function play() {
        open = false; pop.snap(0)
        for (let i = 0; i < items.count; i++) items.itemAt(i).spring.snap(0)
        toggle()
    }
    // interrupt — lance la bascule puis l'inverse à 40 % de sa stabilisation.
    // Entrées/sortie : aucune. Erreurs : aucune. Dépendances : flip.
    function interrupt() {
        toggle()
        flip.interval = Math.max(20, 0.4 * (Motion.reduced ? 100 : open ? params.enter.settle : params.exit.settle))
        flip.restart()
    }
    Timer { id: flip; onTriggered: demo.toggle() }
    Spring { id: pop; params: demo.params }

    MouseArea { anchors.fill: parent; onClicked: if (demo.open) demo.toggle() }

    Surface {   // fenêtre d'application en fond
        id: win
        level: 1; radius: Theme.rWindow
        anchors { fill: parent; margins: 32 }
        Surface {
            id: bar
            level: 2; radius: Theme.rWindow
            width: parent.width; height: 44
            Btn { id: trigger; x: Theme.padding; anchors.verticalCenter: parent.verticalCenter
                  text: "Trier par ▾"; checked: demo.open; onClicked: demo.toggle() }
        }
        Column {
            x: 24; y: bar.height + 24; spacing: 10
            Repeater {
                model: 9
                Rectangle { required property int index; width: 360 + (index * 37) % 140; height: 8; radius: 4; color: Theme.borderSubtle }
            }
        }
    }

    Surface {   // popover E3, ancré sous le déclencheur
        id: popover
        level: 3; radius: Theme.rPanel
        x: win.x + trigger.x; y: win.y + trigger.y + trigger.height + 4
        width: 220; height: 8 * Theme.rowHeight + 8
        visible: pop.value > 0.001
        opacity: Math.min(1, Math.max(0, pop.value))
        transformOrigin: Item.TopLeft
        scale: 1 - demo.gap * 0.06 * (1 - pop.value)
        Column {
            x: 4; y: 4; width: parent.width - 8
            Repeater {
                id: items
                model: ["Nom", "Date de modification", "Date de création", "Taille", "Type", "Extension", "Étiquette", "Emplacement"]
                delegate: Item {
                    required property string modelData
                    required property int index
                    property alias spring: sp
                    width: parent.width; height: Theme.rowHeight
                    Spring { id: sp; params: demo.params }
                    opacity: Math.min(1, Math.max(0, sp.value))
                    transform: Translate { y: -demo.gap * 6 * (1 - sp.value) }
                    Text {
                        x: 8; anchors.verticalCenter: parent.verticalCenter; text: parent.modelData
                        color: Theme.textPrimary; font { family: Theme.fontFamily; pixelSize: Theme.fontSize }
                    }
                }
            }
        }
    }
}
