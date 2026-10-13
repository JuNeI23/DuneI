pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "physics.js" as Physics

// Motion — état global du banc : les sept transitions, le mouvement réduit, l'export.
// Rôle : source unique des réglages lus par toutes les démos et le panneau.
// Sorties : state, reveal, overlay, window, reflow, spectacle, navigate (Params), list,
//           reduced, fade (ressort du fondu court), exportText().
// Erreurs : écriture d'export impossible → message dans la console (FileView).
// Dépendances : Params.qml, physics.js, Quickshell.Io.FileView.
Singleton {
    id: root

    property bool reduced: false
    // Fondu court du mouvement réduit : critique, ±1 % en 100 ms (bible : « un fondu de 100 ms »).
    readonly property var fade: Physics.criticalFor(100)

    property Params state: Params {
        name: "state"; usage: "Changement d'état sur place — survol, focus, pression, sélection"
        stiffness: 2500; damping: 100
    }
    property Params reveal: Params {
        name: "reveal"; usage: "Apparition d'éléments dans le flux — popover, menu, notification"
        stiffness: 600; damping: 50; staggerMs: 24
    }
    property Params overlay: Params {
        name: "overlay"; usage: "Entrée d'une surface de couche 3 — overlay d'attention"
        stiffness: 450; damping: 44
    }
    property Params window: Params {
        name: "window"; usage: "Ouverture et fermeture de fenêtre — seul dépassement autorisé"
        stiffness: 300; damping: 27; overshoot: true
    }
    property Params reflow: Params {
        name: "reflow"; usage: "Réagencement du tuilage — symétrique"
        stiffness: 400; damping: 40; exitRatio: 1; symmetric: true
    }
    property Params spectacle: Params {
        name: "spectacle"; usage: "Moments sans contenu — verrouillage, bureau"
        stiffness: 80; damping: 18
    }
    property Params navigate: Params {
        name: "navigate"; usage: "Changement de bureau — la caméra glisse le long de la bande, symétrique"
        stiffness: 280; damping: 33.5; exitRatio: 1; symmetric: true
    }
    readonly property var list: [state, reveal, overlay, window, reflow, spectacle, navigate]

    FileView { id: exportFile; path: Quickshell.shellPath("export.toml"); blockLoading: true; blockWrites: true }

    // Clés de export.toml → propriétés de Params.
    readonly property var keys: ({ mass: "mass", stiffness: "stiffness", damping: "damping",
                                   exit_ratio: "exitRatio", stagger_ms: "staggerMs" })

    // Au démarrage (et à chaque rechargement à chaud), reprend le dernier export :
    // les réglages survivent à une modification du banc. Après les onCompleted des
    // Params, pour que « Réinitialiser » garde les valeurs de départ.
    Component.onCompleted: Qt.callLater(importText, exportFile.text())

    // set — fixe un paramètre d'une transition. Entrées : name (state…), key (propriété
    // de Params), value. Sortie : « ok » ou motif du refus. Erreurs : transition ou clé inconnue.
    // Dépendances : list.
    function set(name, key, value) {
        const p = list.find(x => x.name === name)
        if (!p) return "transition inconnue : " + name
        if (!Object.values(keys).includes(key)) return "clé inconnue : " + key
        p[key] = value
        return "ok"
    }

    // importText — applique un export.toml (tables [transition], lignes « clé = nombre »).
    // Entrée : t, texte TOML (vide = rien). Sortie : aucune. Erreurs : lignes non reconnues
    // ignorées ; les transitions symétriques (reflow, navigate) gardent leur facteur figé.
    // Une transition absente du texte garde ses valeurs de départ. Dépendances : set, keys, list.
    function importText(t) {
        let name = ""
        for (const line of (t || "").split("\n")) {
            const sec = line.match(/^\[(\w+)\]/), kv = line.match(/^(\w+)\s*=\s*(-?[\d.]+)\s*$/)
            if (sec) name = sec[1]
            else if (kv && keys[kv[1]] && !(kv[1] === "exit_ratio" && list.find(x => x.name === name)?.symmetric)) set(name, keys[kv[1]], +kv[2])
        }
    }

    // exportPath — chemin local du fichier d'export. Sortie : chaîne. Dépendances : exportFile.
    function exportPath() { return exportFile.path.toString().replace(/^file:\/\//, "") }

    // fmt — nombre formaté pour le TOML (point décimal, chiffres utiles).
    // Entrées : v, d décimales. Sortie : chaîne. Erreurs : aucune.
    function fmt(v, d) { return (+v).toFixed(d) }

    // exportText — proposition de motion.toml : une table par transition.
    // Entrées : aucune. Sortie : texte TOML. Erreurs : aucune. Dépendances : list, Physics.
    function exportText() {
        const out = [
            "# motion.toml — proposition issue du banc proto/motion (" + Qt.formatDateTime(new Date(), "yyyy-MM-dd HH:mm:ss") + ")",
            "#",
            "# Ressort commun à la coque (QML) et au compositeur (Hyprland) : progression",
            "# normalisée 0 → 1, masse m, raideur k, amortissement c, temps en secondes.",
            "# ζ = c / (2·√(k·m)) : ζ < 1 dépasse, ζ ≥ 1 ne dépasse pas.",
            "# Sortie : même ressort, temps accéléré de 1/exit_ratio, soit",
            "#   k_sortie = k / exit_ratio²,  c_sortie = c / exit_ratio  (ζ inchangé).",
            "# Hyprland 0.56.2 : la clé s'écrit « dampening » (le wiki récent dit « damping »).",
            ""]
        for (const p of list) {
            const e = p.exitSpring
            out.push("[" + p.name + "]")
            out.push("mass = " + fmt(p.mass, 2))
            out.push("stiffness = " + fmt(p.stiffness, 1))
            out.push("damping = " + fmt(p.damping, 2))
            out.push("exit_ratio = " + fmt(p.symmetric ? 1 : p.exitRatio, 2))
            out.push("overshoot = " + p.overshoot)
            if (p.staggerMs >= 0) out.push("stagger_ms = " + Math.round(p.staggerMs), "stagger_cap = 5")
            out.push("# ζ = " + fmt(p.zeta, 2) + " · entrée ±1 % ≈ " + Math.round(p.enter.settle) + " ms"
                     + " · sortie ≈ " + Math.round(p.exit.settle) + " ms"
                     + (p.enter.overshoot > 0.05 ? " · dépassement " + fmt(p.enter.overshoot, 1) + " %" : ""))
            if (p.violation) out.push("# ATTENTION : ζ < 1 alors que la bible interdit le dépassement ici")
            out.push("# hyprland : hl.curve(\"dunei-" + p.name + "-in\",  { type = \"spring\", mass = " + fmt(p.mass, 2)
                     + ", stiffness = " + fmt(p.stiffness, 1) + ", dampening = " + fmt(p.damping, 2) + " })")
            out.push("# hyprland : hl.curve(\"dunei-" + p.name + "-out\", { type = \"spring\", mass = " + fmt(e.mass, 2)
                     + ", stiffness = " + fmt(e.stiffness, 1) + ", dampening = " + fmt(e.damping, 2) + " })")
            out.push("")
        }
        out.push("[reduced]", "# Mouvement réduit : ni déplacement ni échelle, fondu court conservé.",
                 "mass = 1.00", "stiffness = " + fmt(fade.stiffness, 1), "damping = " + fmt(fade.damping, 2), "")
        return out.join("\n")
    }

    // exportToFile — écrit exportText() dans proto/motion/export.toml.
    // Entrées : aucune. Sortie : le texte écrit. Erreurs : signalées par FileView.
    // Dépendances : exportFile, exportText.
    function exportToFile() {
        const t = exportText()
        exportFile.setText(t)
        return t
    }
}
