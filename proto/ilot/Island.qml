import QtQuick
import QtQuick.Window

// Island — l'îlot de la maquette : une forme unique qui s'étire d'un état à l'autre.
// Rôle : largeur, hauteur et rayon suivent chacun un ressort de motion.json ; grandir
// prend le ressort d'entrée, rétrécir celui de sortie (bible : sortie ≈ 70 % de l'entrée).
// Une nouvelle cible en plein vol repart de la position et de la vitesse courantes.
// Entrées : mode (nom d'un état de `shapes`), transition (clé de Motion), dither, alpha.
// Sorties : moving (un ressort est en vol). Erreurs : mode inconnu → état « repos ».
// Dépendances : Spring.qml, Motion.qml, Theme.qml, ilot.frag.qsb.
Item {
    id: island

    property string mode: "repos"
    property string transition: "overlay"
    property bool dither: true
    property real alpha: 0.82
    readonly property bool moving: sw.moving || sh.moving || sr.moving
    readonly property real radius: sr.value
    // Géométrie de chaque état, en pixels logiques ; le rayon suit la bible (pilule, puis panneau).
    readonly property var shapes: ({
        repos:  { w: 168, h: 32,  r: 16 },
        son:    { w: 300, h: 44,  r: 22 },
        notif:  { w: 380, h: 104, r: Theme.rWindow * 2 },
        ouvert: { w: 440, h: 232, r: Theme.rWindow * 2 }
    })
    readonly property var shape: shapes[mode] ?? shapes.repos
    readonly property var lSurface: Theme.parse(Theme.tokens.roles?.["surface-raised"])

    width: sw.value; height: sh.value

    // retarget — envoie les trois ressorts vers la forme de l'état courant.
    // Entrées : aucune (lit shape). Sortie : aucune. Erreurs : aucune. Dépendances : Spring.to.
    function retarget() {
        const shrink = shape.w * shape.h < sw.target * sh.target
        sw.to(shape.w, shrink, 0); sh.to(shape.h, shrink, 0); sr.to(shape.r, shrink, 0)
    }
    onShapeChanged: retarget()
    Component.onCompleted: { sw.snap(shape.w); sh.snap(shape.h); sr.snap(shape.r) }

    Spring { id: sw; params: Motion[island.transition] }
    Spring { id: sh; params: Motion[island.transition] }
    Spring { id: sr; params: Motion[island.transition] }

    ShaderEffect {
        anchors.fill: parent
        fragmentShader: Qt.resolvedUrl("ilot.frag.qsb")
        property size size: Qt.size(width, height)
        property real radius: sr.value
        property real dpr: Screen.devicePixelRatio
        property color fill: Theme.toColor(island.lSurface)
        property color sheenTop: Theme.toColor(Object.assign({}, island.lSurface,
                                                 { l: island.lSurface.l + Theme.num("surface_material", "sheen_delta", 0.02) }))
        property real sheenHeight: Theme.num("surface_material", "sheen_max_height", 80)
        property real edgeLight: Theme.edgeLight
        property real alpha: island.alpha
        property real dither: island.dither ? 1 : 0
    }

    // Contenus : un par état, fondus par le ressort `state` ; seul celui de l'état courant est visible.
    Item {
        anchors.fill: parent
        anchors.margins: Math.min(12, height / 4)
        clip: true

        Content { when: "repos"
            Text {
                anchors.centerIn: parent
                text: Qt.formatTime(clock.now, "HH:mm")
                color: Theme.textPrimary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize
                font.features: { "tnum": 1 }
            }
        }
        Content { when: "son"
            Row {
                anchors.centerIn: parent; spacing: 12
                Text { text: "Son"; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize; anchors.verticalCenter: parent.verticalCenter }
                Rectangle {
                    width: 160; height: 6; radius: 3; color: Theme.borderSubtle; anchors.verticalCenter: parent.verticalCenter
                    Rectangle { width: parent.width * 0.62; height: parent.height; radius: 3; color: Theme.accent }
                }
                Text { text: "62 %"; color: Theme.textPrimary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize; font.features: { "tnum": 1 }; anchors.verticalCenter: parent.verticalCenter }
            }
        }
        Content { when: "notif"
            Column {
                anchors.fill: parent; anchors.margins: 8; spacing: 4
                Text { text: "Mise à jour prête"; color: Theme.textEmphasis; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize + 1; font.weight: Font.DemiBold }
                Text { text: "12 paquets préchargés attendent dunei-maj."; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize; width: parent.width; wrapMode: Text.Wrap }
            }
        }
        Content { when: "ouvert"
            Grid {
                anchors.centerIn: parent; columns: 2; spacing: 12
                Repeater {
                    model: ["Wi-Fi", "Bluetooth", "Son", "Énergie"]
                    Rectangle {
                        required property string modelData
                        required property int index
                        width: 180; height: 80; radius: Theme.rWindow; color: Theme.window
                        border.color: Theme.borderSubtle
                        Text { anchors.centerIn: parent; text: parent.modelData; color: Theme.textPrimary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize }
                        Rectangle { width: 8; height: 8; radius: 4; color: Theme.categorical[parent.index] ?? Theme.accent; x: 12; y: 12 }
                    }
                }
            }
        }
    }

    QtObject { id: clock; property date now: new Date() }
    Timer { interval: 1000; running: true; repeat: true; onTriggered: clock.now = new Date() }

    // Content — conteneur d'un état : visible et opaque seulement quand l'îlot est dans cet état.
    // Entrée : when, nom de l'état. Sortie : aucune. Erreurs : aucune. Dépendances : Spring, Motion.state.
    component Content: Item {
        id: c
        required property string when
        readonly property bool active: island.mode === when
        anchors.fill: parent
        opacity: fade.value
        visible: opacity > 0.01
        onActiveChanged: fade.to(active ? 1 : 0, !active, active ? 60 : 0)
        Component.onCompleted: fade.snap(active ? 1 : 0)
        Spring { id: fade; params: Motion.state }
    }
}
