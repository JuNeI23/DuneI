pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "physics.js" as Physics

// Motion — les ressorts de la maquette, lus dans generated/motion.json.
// Rôle : expose les transitions de motion.toml sous la forme attendue par Spring.qml
// (le ressort du banc proto/motion) ; aucune valeur de mouvement n'est écrite ici.
// Entrées : generated/motion.json (régénéré par `make motion`).
// Sorties : state, reveal, overlay, window, spectacle (Params), reduced, fade.
// Erreurs : fichier absent ou illisible → ressorts par défaut de Params, signalés par FileView.
// Dépendances : Params.qml, physics.js, Quickshell.Io.FileView.
Singleton {
    id: root

    property bool reduced: false
    readonly property var fade: Physics.criticalFor(json.rules?.reduced_fade_ms ?? 100)

    FileView { id: file; path: Quickshell.shellPath("../../generated/motion.json"); blockLoading: true; watchChanges: true; onFileChanged: reload() }
    readonly property var json: { try { return JSON.parse(file.text()) } catch (e) { return ({}) } }

    property Params state: make("state")
    property Params reveal: make("reveal")
    property Params overlay: make("overlay")
    property Params window: make("window")
    property Params spectacle: make("spectacle")

    // make — Params d'une transition, depuis son ressort d'entrée et sa règle de sortie.
    // Entrée : name, clé de motion.json. Sortie : Params. Erreurs : clé absente → valeurs de Params.
    // Dépendances : root.json, Params.qml.
    function make(name) {
        const t = json.transitions?.[name] ?? {}
        const v = { name: name, symmetric: t.symmetric ?? false, exitRatio: json.rules?.exit_ratio ?? 0.7 }
        if (t.in) Object.assign(v, { mass: t.in.mass, stiffness: t.in.stiffness, damping: t.in.dampening })
        return params.createObject(root, v)
    }

    Component { id: params; Params {} }
}
