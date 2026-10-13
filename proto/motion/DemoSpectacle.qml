import QtQuick

// DemoSpectacle — transition `spectacle` : moment sans contenu, registre du verrouillage.
// Rôle : grande horloge en Source Sans 3 léger, interlettrage resserré, qui monte
// lentement en fondu ; la date suit avec un déplacement plus ample (parallaxe, même ressort).
// Entrées : clic, play(), interrupt(). Sortie : aucune. Erreurs : aucune.
// Dépendances : Spring, Theme, Motion.
Item {
    id: demo
    property Params params: Motion.spectacle
    property bool open: false
    property date now: new Date()
    readonly property real gap: Motion.reduced ? 0 : 1
    readonly property real p: Math.min(1, Math.max(0, sp.value))

    // toggle — fait apparaître ou disparaître l'horloge. Entrées/sortie : aucune.
    function toggle() { open = !open; sp.to(open ? 1 : 0, !open) }
    // play — efface sans animation puis fait apparaître. Entrées/sortie : aucune.
    function play() { open = false; sp.snap(0); toggle() }
    // interrupt — bascule puis inverse à 40 % de la stabilisation. Dépendances : flip.
    function interrupt() {
        toggle()
        flip.interval = Math.max(20, 0.4 * (Motion.reduced ? 100 : open ? params.enter.settle : params.exit.settle))
        flip.restart()
    }
    Timer { id: flip; onTriggered: demo.toggle() }
    Timer { interval: 1000; running: true; repeat: true; onTriggered: demo.now = new Date() }
    Spring { id: sp; params: demo.params }

    Rectangle { anchors.fill: parent; color: Theme.base; radius: Theme.rWindow }   // E0
    MouseArea { anchors.fill: parent; onClicked: demo.toggle() }

    Text {
        id: clock
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.max(8, (parent.height - 260) / 2) + demo.gap * 24 * (1 - sp.value)   // bloc horloge + date centré
        opacity: demo.p
        text: Qt.formatTime(demo.now, "HH:mm")
        color: Theme.textEmphasis
        font { family: Theme.fontFamily; pixelSize: 128; weight: Font.Light; letterSpacing: -4; features: { "tnum": 1 } }
    }
    Text {
        anchors { horizontalCenter: parent.horizontalCenter; top: clock.bottom }
        anchors.topMargin: demo.gap * 48 * (1 - sp.value)
        opacity: demo.p
        text: Qt.formatDate(demo.now, "dddd d MMMM")
        color: Theme.textSecondary
        font { family: Theme.fontFamily; pixelSize: 22 }
    }
    Text {
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 24 }
        text: "Cliquez pour faire apparaître ou disparaître l'horloge."
        color: Theme.textTertiary; font { family: Theme.fontFamily; pixelSize: Theme.fontSize }
    }
}
