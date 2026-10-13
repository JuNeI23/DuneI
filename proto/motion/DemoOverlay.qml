import QtQuick
import QtQuick.Effects

// DemoOverlay — transition `overlay` : lanceur, overlay d'attention.
// Rôle : voile à render.scrim_opacity, flou en FONDU CROISÉ entre l'image nette et une
// copie floutée à rayon fixe (le rayon ne s'anime jamais, bible), panneau E3 qui entre.
// Entrées : clic, Échap, play(), interrupt(). Sortie : aucune. Erreurs : aucune.
// Dépendances : Spring, Surface, Btn, Theme, Motion, QtQuick.Effects (MultiEffect).
Item {
    id: demo
    property Params params: Motion.overlay
    property bool open: false
    readonly property real gap: Motion.reduced ? 0 : 1
    readonly property real p: Math.min(1, Math.max(0, sp.value))

    // toggle — ouvre ou ferme le lanceur. Entrées/sortie : aucune. Erreurs : aucune.
    function toggle() { open = !open; sp.to(open ? 1 : 0, !open) }
    // dismiss — Échap : ferme si ouvert. Entrées/sortie : aucune. Erreurs : aucune.
    function dismiss() { if (open) toggle() }
    // play — ferme sans animation puis ouvre. Entrées/sortie : aucune. Erreurs : aucune.
    function play() { open = false; sp.snap(0); toggle() }
    // interrupt — bascule puis inverse à 40 % de la stabilisation. Dépendances : flip.
    function interrupt() {
        toggle()
        flip.interval = Math.max(20, 0.4 * (Motion.reduced ? 100 : open ? params.enter.settle : params.exit.settle))
        flip.restart()
    }
    Timer { id: flip; onTriggered: demo.toggle() }
    Spring { id: sp; params: demo.params }

    Item {   // le travail en cours, derrière
        id: work
        anchors.fill: parent
        Surface {
            level: 1; radius: Theme.rWindow
            anchors { fill: parent; margins: 32 }
            Text {
                x: 32; y: 28; width: parent.width - 64
                text: "Notes de direction"
                color: Theme.textEmphasis; font { family: Theme.fontFamily; pixelSize: 22; weight: 500 }
            }
            Text {
                x: 32; y: 72; width: Math.min(parent.width - 64, 620)
                wrapMode: Text.Wrap; lineHeight: 1.45
                text: "Un système d'atelier — dense, silencieux, immédiat — qui se met au service de l'outil qu'on y installe et ne réclame l'attention que lorsqu'il a quelque chose à dire.\n\nL'overlay d'attention suspend le travail et attend une décision : voile, flou, transition overlay. Un seul à la fois. Le test : l'utilisateur peut-il continuer à lire ce qu'il y a derrière ? Si non, voile."
                color: Theme.textPrimary; font { family: Theme.fontFamily; pixelSize: Theme.fontSize }
            }
            Btn { x: 32; anchors.bottom: parent.bottom; anchors.bottomMargin: 24; text: "Ouvrir le lanceur"; onClicked: demo.toggle() }
        }
    }
    MultiEffect {   // copie floutée à rayon CONSTANT : seule son opacité varie
        anchors.fill: work; source: work
        blurEnabled: true; blur: 1.0; blurMax: 48; autoPaddingEnabled: false
        opacity: demo.p; visible: opacity > 0.001
    }
    Rectangle {   // voile
        anchors.fill: parent; color: "black"; radius: Theme.rWindow
        opacity: Theme.scrim * demo.p; visible: opacity > 0.001
        MouseArea { anchors.fill: parent; enabled: demo.open; onClicked: demo.toggle() }
    }

    Surface {   // panneau du lanceur, E3
        id: panel
        level: 3; radius: Theme.rPanel
        width: Math.min(520, demo.width - 48); height: 6 * Theme.rowHeight + Theme.controlHeight + 3 * Theme.padding
        anchors.horizontalCenter: parent.horizontalCenter; y: parent.height * 0.18
        visible: sp.value > 0.001
        opacity: demo.p
        scale: 1 - demo.gap * 0.04 * (1 - sp.value)
        Rectangle {   // champ : s'enfonce à E0
            x: Theme.padding; y: Theme.padding; width: parent.width - 2 * Theme.padding; height: Theme.controlHeight
            radius: Theme.rControl; color: Theme.base
            Text {
                x: 10; anchors.verticalCenter: parent.verticalCenter; text: "Rechercher une application…"
                color: Theme.textTertiary; font { family: Theme.fontFamily; pixelSize: Theme.fontSize }
            }
        }
        Column {
            x: Theme.padding / 2; y: 2 * Theme.padding + Theme.controlHeight; width: parent.width - Theme.padding
            Repeater {
                model: ["Terminal", "Navigateur", "Fichiers", "Éditeur", "Musique", "Paramètres"]
                Rectangle {
                    required property string modelData
                    required property int index
                    width: parent.width; height: Theme.rowHeight; radius: Theme.rSmall
                    color: index === 0 ? Theme.accent : "transparent"
                    Text {
                        x: 10; anchors.verticalCenter: parent.verticalCenter; text: parent.modelData
                        color: parent.index === 0 ? Theme.onAccent : Theme.textPrimary
                        font { family: Theme.fontFamily; pixelSize: Theme.fontSize }
                    }
                }
            }
        }
    }
}
