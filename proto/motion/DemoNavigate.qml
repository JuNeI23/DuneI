import QtQuick

// DemoNavigate — transition `navigate` : changement de bureau, mouvement de caméra.
// Rôle : les bureaux forment une bande horizontale ordonnée par numéro, séparés par la
// marge du tuilage ; l'écran recadre la bande et la caméra glisse d'un bloc (translation
// pure, ni fondu ni échelle, symétrique). Un seul ressort anime l'index de bureau réel :
// plusieurs appuis rapides reciblent en plein vol, vitesse conservée, sans file d'attente.
// Mouvement réduit : la caméra saute, le bureau d'arrivée apparaît en fondu court.
// Entrées : boutons ←/→, clic sur un point, play(), interrupt(). Sortie : aucune.
// Erreurs : aucune. Dépendances : Spring, Surface, Btn, Theme, Motion.
Item {
    id: demo
    property Params params: Motion.navigate
    readonly property int count: 5
    property int current: 0                  // bureau visé (cible de la caméra)
    property int prev: 0                     // bureau quitté (fond du fondu, mouvement réduit)
    readonly property real gap: Motion.reduced ? 0 : 1
    readonly property real step: viewport.width + Theme.tilingMargin   // pas de la bande, en px

    // go — vise le bureau i depuis l'état courant de la caméra (vitesse conservée).
    // Entrée : i (borné à 0–count-1). Sortie : aucune. Erreurs : hors borne rabattu.
    // Dépendances : cam, fade, back, flip.
    function go(i) {
        back.stop(); flip.stop()
        i = Math.max(0, Math.min(count - 1, i))
        if (i === current) return
        prev = current; current = i
        if (Motion.reduced) { cam.snap(i); fade.snap(0); fade.to(1, false) }
        else cam.to(i, false)
    }
    // play — aller-retour représentatif : bureau 1 → 3, pause, retour au 1. Dépendances : back.
    function play() {
        back.stop(); flip.stop(); current = prev = 0; cam.snap(0); fade.snap(1)
        go(2); back.origin = 0
        back.interval = (Motion.reduced ? 100 : params.enter.settle) + 400; back.start()
    }
    // interrupt — part vers le bureau voisin puis revient à l'origine à 40 % de la stabilisation.
    function interrupt() {
        const o = current
        go(o < count - 1 ? o + 1 : o - 1)
        flip.origin = o; flip.interval = Math.max(20, 0.4 * (Motion.reduced ? 100 : params.enter.settle)); flip.start()
    }
    Timer { id: back; property int origin; onTriggered: demo.go(origin) }
    Timer { id: flip; property int origin; onTriggered: demo.go(origin) }
    Spring { id: cam; params: demo.params; honorReduced: false }   // position de caméra, en bureaux
    Spring { id: fade; params: demo.params }                        // fondu court du mouvement réduit
    Component.onCompleted: fade.snap(1)

    // slot — rectangle de la tuile t parmi n dans un bureau w × h (maître à gauche, pile à droite).
    // Entrées : t, n, w, h. Sortie : rect. Erreurs : aucune. Dépendances : Theme (marge, gouttière).
    function slot(t, n, w, h) {
        const m = Theme.tilingMargin, g = Theme.gutter, iw = w - 2 * m, ih = h - 2 * m, mw = (iw - g) / 2
        if (t === 0) return Qt.rect(m, m, mw, ih)
        const sh = (ih - (n - 2) * g) / (n - 1)
        return Qt.rect(m + mw + g, m + (t - 1) * (sh + g), mw, sh)
    }

    Rectangle { anchors.fill: parent; color: Theme.base; radius: Theme.rWindow }   // E0
    Row {
        x: Theme.sectionGap; y: 12; spacing: 8
        Btn { text: "←"; level: 3; onClicked: demo.go(demo.current - 1) }
        Btn { text: "→"; level: 3; onClicked: demo.go(demo.current + 1) }
        Text {
            anchors.verticalCenter: parent.verticalCenter; leftPadding: 8
            text: "Bureau " + (demo.current + 1) + " / " + demo.count + " · cliquez un point pour sauter directement"
            color: Theme.textTertiary; font { family: Theme.fontFamily; pixelSize: Theme.fontSize }
        }
    }

    Rectangle {   // l'écran : recadre la bande ; sa couleur est celle de la marge entre bureaux
        id: viewport
        x: 48; y: 64; width: parent.width - 96; height: parent.height - 64 - 56
        color: Theme.borderSubtle; clip: true
        Item {   // la bande de bureaux, déplacée d'un bloc par la caméra
            x: -demo.gap * cam.value * demo.step
            Repeater {
                model: demo.count
                Rectangle {   // un bureau (E0) et ses fenêtres tuilées
                    id: desk
                    required property int index
                    readonly property int n: index % 2 ? 2 : 3
                    x: demo.gap * index * demo.step; width: viewport.width; height: viewport.height
                    color: Theme.base
                    z: index === demo.current ? 1 : 0
                    opacity: !Motion.reduced ? 1 : index === demo.current ? fade.value : index === demo.prev ? 1 : 0
                    Repeater {
                        model: desk.n
                        Surface {
                            id: tile
                            required property int index
                            readonly property rect r: demo.slot(index, desk.n, desk.width, desk.height)
                            level: 1; radius: Theme.rWindow
                            x: r.x; y: r.y; width: r.width; height: r.height
                            Text {
                                x: Theme.padding; y: Theme.padding; visible: tile.index === 0
                                text: desk.index + 1
                                color: Theme.textTertiary; font { family: Theme.fontFamily; pixelSize: 15; weight: 500 }
                            }
                            Column {   // lignes de contenu : donnent de la matière au glissement
                                x: Theme.padding; y: 44; spacing: 10
                                Repeater {
                                    model: Math.max(0, Math.floor((tile.height - 56) / 18))
                                    Rectangle {
                                        required property int index
                                        width: Math.max(0, tile.width - 2 * Theme.padding) * (0.5 + ((index + desk.index) * 37 % 45) / 100)
                                        height: 8; radius: 4; color: Theme.borderSubtle
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Item {   // indicateur de bureaux : un point par bureau, la pastille suit la caméra
        anchors { horizontalCenter: parent.horizontalCenter; top: viewport.bottom; topMargin: 16 }
        width: demo.count * Theme.rowHeight; height: Theme.rowHeight
        Row {
            Repeater {
                model: demo.count
                Item {
                    required property int index
                    width: Theme.rowHeight; height: Theme.rowHeight
                    Rectangle { anchors.centerIn: parent; width: 8; height: 8; radius: 4; color: Theme.borderStrong }
                    MouseArea { anchors.fill: parent; onClicked: demo.go(parent.index) }
                }
            }
        }
        Rectangle {
            x: (Motion.reduced ? demo.current : cam.value) * Theme.rowHeight + (Theme.rowHeight - width) / 2
            anchors.verticalCenter: parent.verticalCenter
            width: 16; height: 8; radius: 4; color: Theme.accent
        }
    }
}
