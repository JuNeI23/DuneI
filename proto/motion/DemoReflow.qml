import QtQuick

// DemoReflow — transition `reflow` : tuilage maître + pile qui se réagence.
// Rôle : rien n'entre, rien ne sort, l'espace se redistribue ; la transition est
// symétrique (même ressort dans les deux sens). Chaque arête de tuile a son ressort :
// un ajout en plein retrait fait repartir chaque tuile de son état courant.
// Entrées : boutons, play(), interrupt(). Sortie : aucune. Erreurs : aucune.
// Dépendances : Spring, Surface, Btn, Theme, Motion.
Item {
    id: demo
    property Params params: Motion.reflow
    property int nextId: 4
    readonly property real margin: Theme.gutter
    readonly property rect area: Qt.rect(0, 52, width, height - 52)

    ListModel { id: tiles; ListElement { tid: 1; leaving: false } ListElement { tid: 2; leaving: false } ListElement { tid: 3; leaving: false } }

    // slot — rectangle de la i-ème tuile parmi n (maître à gauche, pile à droite).
    // Entrées : i, n. Sortie : rect. Erreurs : aucune. Dépendances : area, margin.
    function slot(i, n) {
        const g = margin, a = area
        const x0 = a.x + g, y0 = a.y + g, w = a.width - 2 * g, h = a.height - 2 * g
        if (n <= 1) return Qt.rect(x0, y0, w, h)
        const mw = (w - g) / 2
        if (i === 0) return Qt.rect(x0, y0, mw, h)
        const sh = (h - (n - 2) * g) / (n - 1)
        return Qt.rect(x0 + mw + g, y0 + (i - 1) * (sh + g), mw, sh)
    }
    // relayout — envoie chaque tuile vers sa place ; une tuile qui part se replie sur son bas.
    // Entrées : instant (bool, optionnel) pose sans animer. Sortie : aucune. Erreurs : aucune. Dépendances : slot, rep.
    function relayout(instant) {
        let n = 0
        for (let i = 0; i < tiles.count; i++) if (!tiles.get(i).leaving) n++
        let k = 0
        for (let i = 0; i < tiles.count; i++) {
            const t = rep.itemAt(i)
            if (!t) continue
            if (tiles.get(i).leaving) t.goTo(Qt.rect(t.gx.value, t.gy.value + t.gh.value, t.gw.value, 0), instant)
            else t.goTo(slot(k++, n), instant)
        }
    }
    // add — ajoute une tuile ; si une tuile est en train de partir, elle revient.
    // Entrées/sortie : aucune. Erreurs : aucune. Dépendances : tiles, relayout.
    function add() {
        for (let i = tiles.count - 1; i >= 0; i--)
            if (tiles.get(i).leaving) { tiles.setProperty(i, "leaving", false); relayout(); return }
        if (tiles.count >= 5) return
        tiles.append({ tid: nextId++, leaving: false })
        relayout()
    }
    // remove — retire la dernière tuile présente (elle se replie puis disparaît).
    // Entrées/sortie : aucune. Erreurs : aucune. Dépendances : tiles, relayout.
    function remove() {
        let n = 0
        for (let i = 0; i < tiles.count; i++) if (!tiles.get(i).leaving) n++
        if (n <= 1) return
        for (let i = tiles.count - 1; i >= 0; i--)
            if (!tiles.get(i).leaving) { tiles.setProperty(i, "leaving", true); break }
        relayout()
    }
    // play — alterne ajout et retrait. Entrées/sortie : aucune.
    function play() { let n = 0; for (let i = 0; i < tiles.count; i++) if (!tiles.get(i).leaving) n++; n >= 4 ? remove() : add() }
    // interrupt — ajoute puis retire à 40 % de la stabilisation (ou l'inverse).
    function interrupt() {
        play()
        flip.interval = Math.max(20, 0.4 * (Motion.reduced ? 100 : params.enter.settle)); flip.restart()
    }
    Timer { id: flip; onTriggered: demo.play() }
    // drop — supprime du modèle la tuile partie. Entrée : tid. Sortie : aucune. Erreurs : aucune.
    function drop(tid) {
        for (let i = 0; i < tiles.count; i++) if (tiles.get(i).tid === tid && tiles.get(i).leaving) { tiles.remove(i); return }
    }
    // Redimensionnement de la fenêtre du banc : pose immédiate (ce n'est pas un réagencement).
    onWidthChanged: Qt.callLater(relayout, true)
    onHeightChanged: Qt.callLater(relayout, true)

    Rectangle { anchors.fill: parent; color: Theme.base; radius: Theme.rWindow }   // bureau E0
    Row {
        x: margin; y: 12; spacing: 8
        Btn { text: "Ajouter une fenêtre"; level: 3; onClicked: demo.add() }
        Btn { text: "Retirer une fenêtre"; level: 3; onClicked: demo.remove() }
    }

    Repeater {
        id: rep
        model: tiles
        delegate: Item {
            id: tile
            required property int index
            required property int tid
            required property bool leaving
            property alias gx: sx
            property alias gy: sy
            property alias gw: sw
            property alias gh: sh
            property bool born: false
            x: sx.value; y: sy.value; width: Math.max(0, sw.value); height: Math.max(0, sh.value)
            opacity: Math.min(1, Math.max(0, fade.value))
            clip: true
            Spring { id: sx; params: demo.params; honorReduced: false }
            Spring { id: sy; params: demo.params; honorReduced: false }
            Spring { id: sw; params: demo.params; honorReduced: false }
            Spring { id: sh; params: demo.params; honorReduced: false; onSettled: if (tile.leaving && sh.value < 1) demo.drop(tile.tid) }
            Spring { id: fade; params: demo.params; onSettled: if (tile.leaving && fade.value < 0.01) demo.drop(tile.tid) }
            Component.onCompleted: fade.snap(1)

            // goTo — cible géométrique ; en mouvement réduit, saut + fondu court.
            // Entrées : r (rect) ; instant (bool) pose sans animer. Sortie : aucune.
            // Erreurs : aucune. Dépendances : sx, sy, sw, sh, fade.
            function goTo(r, instant) {
                if (instant) { born = true; sx.snap(r.x); sy.snap(r.y); sw.snap(r.width); sh.snap(r.height); return }
                if (!born) {   // naissance : part de sa place, repliée sur son bas
                    born = true
                    sx.snap(r.x); sy.snap(r.y + r.height); sw.snap(r.width); sh.snap(0)
                    if (Motion.reduced) fade.snap(0)
                }
                if (Motion.reduced) {   // ni déplacement ni échelle : saut, fondu court
                    if (leaving) { fade.to(0, false); return }
                    sx.snap(r.x); sy.snap(r.y); sw.snap(r.width); sh.snap(r.height); fade.to(1, false)
                    return
                }
                fade.to(1, false)
                sx.to(r.x, false); sy.to(r.y, false); sw.to(r.width, false); sh.to(r.height, false)
            }
            Surface {
                level: 1; radius: Theme.rWindow
                width: tile.width; height: Math.max(tile.height, 2 * Theme.rWindow)
                Text {
                    anchors.centerIn: parent; text: "Fenêtre " + tile.tid
                    color: Theme.textSecondary; font { family: Theme.fontFamily; pixelSize: 15 }
                }
            }
        }
    }
    Component.onCompleted: Qt.callLater(relayout, true)
}
