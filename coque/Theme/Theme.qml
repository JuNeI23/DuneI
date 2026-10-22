pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Theme — source unique des valeurs de design de la coque.
// Rôle : lit coque-tokens.json et motion.json, produits par make tokens et make motion et déployés par
// deploy.py, les surveille sur disque et remplace d'un bloc l'objet exposé à chaque lecture valide : toutes
// les liaisons se réévaluent dans la même image. Aucune valeur de design n'est écrite ici.
// Entrées : DUNEI_TOKENS_DIR (dossier redirigé, pour la planche et les essais), sinon
//           $XDG_CONFIG_HOME/dunei, sinon $HOME/.config/dunei.
// Sorties : dir, ready, tokens et ses raccourcis par groupe, density (confortable), motion, stateColors(),
//           hairline().
// Erreurs : fichier absent ou illisible → console.error, ready reste faux ; contenu invalide ou incomplet →
//           console.warn, valeurs précédentes gardées.
// Dépendances : Quickshell (env), Quickshell.Io (FileView, FileViewError).
Singleton {
    id: root

    readonly property string dir: Quickshell.env("DUNEI_TOKENS_DIR")
        || (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/dunei"
    property var tokens: null
    property var motion: null
    // ready est posé par affectation, après celle des données, dans chaque onParsed : lié directement à tokens,
    // il pouvait changer pendant la notification de tokensChanged avant que les raccourcis ci-dessous ne soient
    // réévalués, et un consommateur réagissant à readyChanged lisait alors Theme.color indéfini.
    property bool _ready: false
    readonly property bool ready: _ready

    readonly property var color: tokens?.color
    readonly property var states: tokens?.states
    readonly property var focus: tokens?.focus
    readonly property var disabled: tokens?.disabled
    readonly property var elevation: tokens?.elevation
    readonly property var material: tokens?.material
    readonly property var render: tokens?.render
    readonly property var space: tokens?.space
    readonly property var radius: tokens?.radius
    readonly property var window: tokens?.window
    readonly property var layout: tokens?.layout
    readonly property var breakpoints: tokens?.breakpoints
    readonly property var typo: tokens?.typo
    readonly property var icons: tokens?.icons
    // La préférence de densité viendra de L2-26 ; d'ici là, la densité confortable s'applique.
    readonly property var density: tokens?.density.comfortable

    // stateColors — couleurs de fond et de texte d'une combinaison d'états, toutes précalculées.
    // Entrées : role (surfaceWindow, surfacePanel, surfaceRaised), selection (none, active, inactive,
    //           activeMuted), interaction (rest, hover, pressed, disabled).
    // Sortie : objet {fill, text} de couleurs sRGB, ou undefined si la combinaison n'existe pas ou si les
    //          tokens ne sont pas encore chargés.
    // Erreurs : aucune. Dépendances : tokens.
    function stateColors(role, selection, interaction) {
        return tokens?.states[role]?.[selection]?.[interaction]
    }

    // hairline — épaisseur d'un liseré (arête, bordure d'un pixel) en pixels logiques Qt.
    // Rôle : simple conversion d'unité ; la règle vient de render.hairlinePhysical (tokens.toml,
    //        scaling.hairlines_in_physical_pixels) : vraie, le liseré occupe un pixel physique quelle que soit
    //        la mise à l'échelle de l'écran, sans flou.
    // Entrées : dpr, rapport pixels physiques / logiques de la fenêtre (QsWindow.devicePixelRatio).
    // Sortie : 1 / dpr si la règle s'applique, sinon 1 ; undefined avant le chargement des tokens.
    // Erreurs : aucune. Dépendances : tokens.render.
    function hairline(dpr) {
        return render ? (render.hairlinePhysical ? 1 / dpr : 1) : undefined
    }

    // parse — analyse un fichier lu et vérifie ses clés obligatoires.
    // Entrées : text contenu du fichier ; name nom du fichier, pour le journal ; keys clés de premier niveau
    //           exigées.
    // Sortie : l'objet analysé, ou null s'il est illisible ou incomplet.
    // Erreurs : console.warn « Theme : <fichier> ignoré, <raison> ; valeurs précédentes gardées ».
    // Dépendances : aucune.
    function parse(text, name, keys) {
        let data = null, reason = ""
        try { data = JSON.parse(text) } catch (e) { reason = "JSON illisible (" + e.message + ")" }
        const missing = data instanceof Object ? keys.filter(k => !(k in data)) : keys
        if (!reason && missing.length) reason = "clés absentes : " + missing.join(", ")
        if (!reason) return data
        console.warn("Theme : " + name + " ignoré, " + reason + " ; valeurs précédentes gardées")
        return null
    }

    // Source — un fichier généré, surveillé sur disque et relu à chaque changement.
    // Entrées : name nom du fichier dans dir ; keys clés exigées. Sortie : signal parsed(data) à chaque
    // lecture valide. Erreurs : chargement impossible → console.error ; contenu invalide → voir parse.
    // Dépendances : FileView, parse.
    component Source: FileView {
        id: source
        required property string name
        required property var keys
        signal parsed(var data)

        path: root.dir + "/" + name
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            const data = root.parse(text(), name, keys)
            if (data) parsed(data)
        }
        onLoadFailed: error => console.error("Theme : " + name
            + (error === FileViewError.FileNotFound ? " introuvable" : " illisible") + " dans " + root.dir
            + " (" + FileViewError.toString(error) + ")")
    }

    Source {
        name: "coque-tokens.json"
        keys: ["_generated", "color", "states"]
        onParsed: data => {
            root.tokens = data
            root._ready = root.motion !== null
            console.info("Theme : chargé, teinte " + data.hue)
        }
    }

    Source {
        name: "motion.json"
        keys: ["_generated", "transitions"]
        onParsed: data => {
            root.motion = data
            root._ready = root.tokens !== null
            console.info("Theme : mouvement chargé, version " + data.version)
        }
    }
}
