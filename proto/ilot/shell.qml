import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// shell.qml — maquette jetable de l'îlot de la coque (repérage du lot 2).
// Rôle : pose l'îlot en haut de l'écran sur une surface layer-shell transparente, avec
// flou d'arrière-plan, et mesure la cadence pendant les morphings. Ne réserve aucune place :
// les fenêtres passent dessous, les clics hors de l'îlot les atteignent (masque de saisie).
// Entrées : clic sur l'îlot (état suivant), IPC « ilot » (voir README.md).
// Sorties : la surface « dunei-ilot » ; stats() rend la mesure de cadence.
// Erreurs : ilot.frag.qsb absent → l'îlot ne se dessine pas (run.sh le compile).
// Dépendances : Island.qml, Motion.qml, Quickshell ≥ 0.3.
ShellRoot {
    PanelWindow {
        id: win

        readonly property var order: ["repos", "son", "notif", "ouvert"]
        property bool blur: true
        // Mesure de cadence, cumulée tant qu'un ressort est en vol.
        property int frames: 0
        property real busy: 0
        property real worst: 0
        property int late: 0

        anchors { top: true; left: true; right: true }
        implicitHeight: 260
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.namespace: "dunei-ilot"
        WlrLayershell.layer: WlrLayer.Top
        mask: Region { item: island }
        BackgroundEffect.blurRegion: win.blur ? blurRegion : null
        Region { id: blurRegion; item: island; radius: island.radius }

        // next — passe à l'état suivant de l'ordre de démonstration. Sortie : aucune.
        // Erreurs : aucune. Dépendances : order, island.mode.
        function next() { island.mode = order[(order.indexOf(island.mode) + 1) % order.length] }

        Island {
            id: island
            anchors.horizontalCenter: parent.horizontalCenter
            y: 6
            MouseArea { anchors.fill: parent; onClicked: win.next() }
        }

        // Démonstration automatique : un changement d'état tous les `interval` ms ; en mode
        // interruption, l'intervalle tombe sous la durée du ressort et chaque morphing est repris en vol.
        Timer { id: demoTimer; interval: 900; repeat: true; onTriggered: win.next() }

        FrameAnimation {
            running: island.moving
            onTriggered: {
                win.frames++; win.busy += frameTime
                win.worst = Math.max(win.worst, frameTime)
                if (frameTime > 1.5 / 60) win.late++
            }
        }

        IpcHandler {
            target: "ilot"
            // mode — fixe l'état. Entrée : repos | son | notif | ouvert. Sortie : aucune.
            function mode(name: string): void { island.mode = name }
            function next(): void { win.next() }
            // demo — démonstration automatique. Entrées : on, intervalle en ms (180 = interruptions).
            function demo(on: bool, ms: int): void { demoTimer.interval = Math.max(60, ms); demoTimer.running = on }
            function blur(on: bool): void { win.blur = on }
            function dither(on: bool): void { island.dither = on }
            function alpha(a: real): void { island.alpha = a }
            // transition — ressort du morphing. Entrée : state | reveal | overlay | window | spectacle.
            function transition(name: string): void { island.transition = name }
            function reduced(on: bool): void { Motion.reduced = on }
            // stats — cadence mesurée depuis le dernier reset. Sortie : texte d'une ligne.
            function stats(): string {
                const fps = win.busy > 0 ? win.frames / win.busy : 0
                return `images=${win.frames} cadence=${fps.toFixed(1)}/s pire=${(win.worst * 1000).toFixed(1)}ms retards=${win.late}`
            }
            function reset(): void { win.frames = 0; win.busy = 0; win.worst = 0; win.late = 0 }
            // capture — rendu Qt de l'îlot seul, sans le reste de l'écran. Entrée : chemin du PNG.
            function capture(path: string): void { island.grabToImage(r => r.saveToFile(path)) }
        }
    }
}
