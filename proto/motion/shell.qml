import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

// shell.qml — banc de mouvement DuneI (prototype jetable, backlog L1-23).
// Rôle : choisir au ressenti les ressorts des six transitions de la bible (ch. 6)
// avant de les écrire dans motion.toml. Une fenêtre normale (FloatingWindow, se tuile),
// scène de démonstration à gauche, réglages à droite.
// Entrées : souris, clavier (1–6, Espace, I, R, E, Échap), IPC `qs ipc call banc …`.
// Sortie : proto/motion/export.toml sur « Exporter ». Erreurs : console de qs.
// Dépendances : Quickshell 0.3, Qt 6 (QtQuick, Layouts, Effects), fichiers du dossier.
ShellRoot {
    FloatingWindow {
        id: win
        title: "DuneI — banc de mouvement"
        implicitWidth: 1280; implicitHeight: 800
        minimumSize: Qt.size(960, 620)
        color: Theme.window

        property int current: 0
        property string exported: ""
        readonly property Params params: Motion.list[current]
        readonly property var demo: demos.children[current]

        // select — change de transition. Entrée : i (0–5). Sortie : aucune. Erreurs : hors borne ignoré.
        function select(i) { if (i >= 0 && i < 6) current = i }
        // doExport — écrit export.toml et ouvre l'aperçu. Sortie : texte exporté. Dépendances : Motion.
        function doExport() { exported = Motion.exportToFile(); exportView.toggle(true); return exported }

        IpcHandler {
            target: "banc"
            function select(i: int): void { win.select(i) }
            function play(): void { win.demo.play() }
            function interrupt(): void { win.demo.interrupt() }
            function reduced(on: bool): void { Motion.reduced = on }
            function exportToml(): string { return win.doExport() }
            function closeExport(): void { exportView.toggle(false) }
            // capture — image du banc rendue par Qt (ne capture jamais le reste de l'écran).
            function capture(path: string): void { content.grabToImage(r => r.saveToFile(path)) }
            // shoot — action (play | interrupt) puis capture ms millisecondes plus tard, mesurées dans Qt.
            function shoot(action: string, ms: int, path: string): void {
                if (action === "play") win.demo.play(); else if (action === "interrupt") win.demo.interrupt()
                shot.path = path; shot.interval = Math.max(1, ms); shot.restart()
            }
        }
        Timer { id: shot; property string path; onTriggered: content.grabToImage(r => r.saveToFile(path)) }

        Item {
            id: content
            anchors.fill: parent
            focus: true
            Keys.onPressed: event => {
                const k = event.key
                if (k >= Qt.Key_1 && k <= Qt.Key_6) win.select(k - Qt.Key_1)
                else if (k === Qt.Key_Space) win.demo.play()
                else if (k === Qt.Key_I) win.demo.interrupt()
                else if (k === Qt.Key_R) Motion.reduced = !Motion.reduced
                else if (k === Qt.Key_E) win.doExport()
                else if (k === Qt.Key_Escape) { if (exportView.open) exportView.toggle(false); else win.demo.dismiss?.() }
                else return
                event.accepted = true
            }

            // Sous le seuil `breakpoints.extended` (largeur du conteneur, bible ch. 8), la scène
            // et les réglages s'empilent : le banc reste utilisable tuilé en demi-écran.
            readonly property bool narrow: width < Theme.num("breakpoints", "extended", 900)
            readonly property real gap: Theme.sectionGap
            readonly property real bodyY: header.height + gap
            readonly property real bodyH: height - bodyY - gap

            // --- En-tête : sélecteur de transitions + actions globales (passe à la ligne si étroit) ---
            Surface {
                id: header
                level: 2; radius: 0
                width: parent.width; height: flow.implicitHeight + 16
                Flow {
                    id: flow
                    x: Theme.padding; y: 8; width: parent.width - 2 * Theme.padding; spacing: 8
                    Row {
                        spacing: 4
                        Repeater {
                            model: Motion.list
                            Btn {
                                required property var modelData
                                required property int index
                                level: 2; text: (index + 1) + "  " + modelData.name
                                checked: win.current === index
                                onClicked: win.select(index)
                            }
                        }
                    }
                    Row {
                        spacing: 8
                        Btn { text: "Rejouer"; onClicked: win.demo.play() }
                        Btn { text: "Interrompre"; onClicked: win.demo.interrupt() }
                        Btn { text: "Mouvement réduit"; checked: Motion.reduced; onClicked: Motion.reduced = !Motion.reduced }
                        Btn { text: "Exporter"; onClicked: win.doExport() }
                    }
                }
            }

            // --- Scène : posée sur le bureau (E0) ---
            Rectangle { anchors.fill: demos; color: Theme.base; radius: Theme.rWindow }
            Item {
                id: demos
                x: content.gap; y: content.bodyY
                width: content.narrow ? content.width - 2 * content.gap : panel.x - 2 * content.gap
                height: content.narrow ? Math.round(content.bodyH * 0.5) : content.bodyH
                DemoState { anchors.fill: parent; visible: win.current === 0 }
                DemoReveal { anchors.fill: parent; visible: win.current === 1 }
                DemoOverlay { anchors.fill: parent; visible: win.current === 2 }
                DemoWindow { anchors.fill: parent; visible: win.current === 3 }
                DemoReflow { anchors.fill: parent; visible: win.current === 4 }
                DemoSpectacle { anchors.fill: parent; visible: win.current === 5 }
            }

            // --- Réglages ---
            Surface {
                id: panel
                level: 2; radius: Theme.rPanel
                x: content.narrow ? content.gap : content.width - width - content.gap
                y: content.narrow ? demos.y + demos.height + content.gap : content.bodyY
                width: content.narrow ? content.width - 2 * content.gap : 360
                height: content.narrow ? content.bodyH - demos.height - content.gap : content.bodyH
                Flickable {
                    anchors { fill: parent; margins: Theme.padding + 4 }
                    contentHeight: settings.implicitHeight; clip: true
                    ColumnLayout {
                        id: settings
                        width: parent.width; spacing: 10
                        readonly property Params p: win.params

                        Text {
                            text: settings.p.name; color: Theme.textEmphasis
                            font { family: Theme.fontFamily; pixelSize: 22; weight: 500 }
                        }
                        Text {
                            Layout.fillWidth: true; wrapMode: Text.Wrap
                            text: settings.p.usage; color: Theme.textSecondary
                            font { family: Theme.fontFamily; pixelSize: Theme.fontSize }
                        }
                        ParamSlider {
                            Layout.fillWidth: true; label: "Masse m"; from: 0.1; to: 5; log: true; decimals: 2
                            value: settings.p.mass; onMoved: v => settings.p.mass = v
                        }
                        ParamSlider {
                            Layout.fillWidth: true; label: "Raideur k"; from: 10; to: 6000; log: true; decimals: 0
                            value: settings.p.stiffness; onMoved: v => settings.p.stiffness = v
                        }
                        ParamSlider {
                            Layout.fillWidth: true; label: "Amortissement c"; from: 1; to: 300; log: true; decimals: 1
                            value: settings.p.damping; onMoved: v => settings.p.damping = v
                        }
                        ParamSlider {
                            Layout.fillWidth: true; label: settings.p.symmetric ? "Sortie / entrée (symétrique)" : "Sortie / entrée"
                            from: 0.4; to: 1; decimals: 2; enabled: !settings.p.symmetric
                            value: settings.p.symmetric ? 1 : settings.p.exitRatio; onMoved: v => settings.p.exitRatio = v
                        }
                        ParamSlider {
                            Layout.fillWidth: true; visible: settings.p.staggerMs >= 0
                            label: "Décalage de cascade (≤ 5 éléments)"; from: 0; to: 80; decimals: 0; unit: "ms"
                            value: Math.max(0, settings.p.staggerMs); onMoved: v => settings.p.staggerMs = v
                        }

                        Repeater {   // lecture humaine : libellé à gauche, valeur à droite
                            model: [
                                ["ζ = c / (2√(k·m))", settings.p.zeta.toFixed(2) + (settings.p.zeta < 1 ? " · dépasse" : " · sans dépassement")],
                                ["Entrée, stable à ±1 %", Math.round(settings.p.enter.settle) + " ms"],
                                ["Sortie, stable à ±1 %", Math.round(settings.p.exit.settle) + " ms"],
                                ["Dépassement", settings.p.enter.overshoot.toFixed(1) + " %"],
                                ["Arrêt à ε 0,001 (Hyprland)", Math.round(settings.p.enter.stop) + " ms"]
                            ]
                            delegate: Item {
                                required property var modelData
                                Layout.fillWidth: true; implicitHeight: 18
                                Text {
                                    text: parent.modelData[0]; color: Theme.textSecondary
                                    font { family: Theme.fontFamily; pixelSize: Theme.fontSize }
                                }
                                Text {
                                    anchors.right: parent.right
                                    text: parent.modelData[1]; color: Theme.textPrimary
                                    font { family: Theme.fontFamily; pixelSize: Theme.fontSize; weight: 500; features: { "tnum": 1 } }
                                }
                            }
                        }
                        Text {
                            Layout.fillWidth: true; wrapMode: Text.Wrap; visible: settings.p.violation
                            text: "ζ < 1 : la bible n'autorise le dépassement qu'à window."
                            color: Theme.warning; font { family: Theme.fontFamily; pixelSize: Theme.fontSize; weight: 500 }
                        }
                        Text {
                            Layout.fillWidth: true; wrapMode: Text.Wrap; visible: Motion.reduced
                            text: "Mouvement réduit : ni déplacement ni échelle, fondu critique de 100 ms (ces curseurs ne s'appliquent pas)."
                            color: Theme.textSecondary; font { family: Theme.fontFamily; pixelSize: Theme.fontSize }
                        }
                        Curve { Layout.fillWidth: true; Layout.preferredHeight: 120; params: settings.p }
                        Text {
                            Layout.fillWidth: true; wrapMode: Text.Wrap
                            text: "Trait clair : entrée. Trait sombre : sortie. Graduations : 100 ms."
                            color: Theme.textTertiary; font { family: Theme.fontFamily; pixelSize: 12 }
                        }
                        Text {
                            Layout.fillWidth: true; wrapMode: Text.WrapAnywhere
                            readonly property var e: settings.p.exitSpring
                            text: "hl.curve(\"dunei-" + settings.p.name + "-in\", { type = \"spring\", mass = " + settings.p.mass.toFixed(2)
                                  + ", stiffness = " + settings.p.stiffness.toFixed(1) + ", dampening = " + settings.p.damping.toFixed(2) + " })\n"
                                  + "hl.curve(\"dunei-" + settings.p.name + "-out\", { type = \"spring\", mass = " + e.mass.toFixed(2)
                                  + ", stiffness = " + e.stiffness.toFixed(1) + ", dampening = " + e.damping.toFixed(2) + " })"
                            color: Theme.textSecondary; font { family: Theme.monoFamily; pixelSize: 11 }
                        }
                        Btn { text: "Réinitialiser cette transition"; onClicked: settings.p.reset() }
                        Text {
                            Layout.fillWidth: true; wrapMode: Text.Wrap
                            text: "Clavier : 1–6 transition · Espace rejouer · I interrompre · R mouvement réduit · E exporter"
                            color: Theme.textTertiary; font { family: Theme.fontFamily; pixelSize: 12 }
                        }
                    }
                }
            }

            // --- Aperçu d'export : overlay d'attention (voile, transition overlay) ---
            Item {
                id: exportView
                anchors.fill: parent
                property bool open: false
                visible: sp.value > 0.001
                // toggle — ouvre/ferme l'aperçu. Entrée : on (bool). Sortie : aucune. Dépendances : sp.
                function toggle(on) { open = on; sp.to(on ? 1 : 0, !on) }
                Spring { id: sp; params: Motion.overlay }
                Rectangle {
                    anchors.fill: parent; color: "black"; opacity: Theme.scrim * Math.min(1, Math.max(0, sp.value))
                    MouseArea { anchors.fill: parent; onClicked: exportView.toggle(false) }
                }
                Surface {
                    level: 3; radius: Theme.rPanel
                    width: Math.min(parent.width - 80, 860); height: parent.height - 120
                    anchors.centerIn: parent
                    opacity: Math.min(1, Math.max(0, sp.value))
                    scale: Motion.reduced ? 1 : 1 - 0.04 * (1 - sp.value)
                    MouseArea { anchors.fill: parent }
                    Text {
                        id: exTitle
                        x: Theme.padding + 4; y: Theme.padding
                        text: "Exporté dans " + Motion.exportPath()
                        color: Theme.textEmphasis; font { family: Theme.fontFamily; pixelSize: 15; weight: 500 }
                    }
                    Btn { anchors { right: parent.right; rightMargin: Theme.padding; top: parent.top; topMargin: 8 }
                          text: "Fermer"; onClicked: exportView.toggle(false) }
                    Flickable {
                        anchors { fill: parent; topMargin: 48; margins: Theme.padding + 4 }
                        contentHeight: exText.implicitHeight; clip: true
                        Text {
                            id: exText; width: parent.width; wrapMode: Text.WrapAnywhere
                            text: win.exported; color: Theme.textPrimary
                            font { family: Theme.monoFamily; pixelSize: 12 }
                        }
                    }
                }
            }
        }
    }
}
