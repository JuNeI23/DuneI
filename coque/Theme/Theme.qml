pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Theme — source unique des valeurs de design de la coque.
// Rôle : lit coque-tokens.json et motion.json, produits par make tokens et make motion et déployés par
// deploy.py, ainsi que theme.json, le choix du thème écrit par dunei-theme ; les surveille sur disque et
// remplace d'un bloc l'objet exposé à chaque lecture valide : toutes les liaisons se réévaluent dans la même
// image. coque-tokens.json porte les quatre thèmes (themes[famille][moment]) ; tokens est la vue du thème
// actif, un objet neuf à chaque lecture, fait des clés partagées du fichier et de la branche choisie, ce qui
// fait basculer ColorSpring d'un coup, sans animation (D81). Aucune valeur de design n'est écrite ici.
// Entrées : DUNEI_TOKENS_DIR (dossier redirigé, pour la planche et les essais), sinon
//           $XDG_CONFIG_HOME/dunei, sinon $HOME/.config/dunei ; dans ce dossier, theme.json
//           {famille, moment}, facultatif.
// Sorties : dir, ready, famille, moment, tokens et ses raccourcis par groupe (pastilles, knob, controls et glass
//           compris), density (confortable), motion, stateColors(), hairline(), police(), fichier().
// Erreurs : tokens ou mouvement absents ou illisibles → console.error, ready reste faux ; contenu invalide ou
//           incomplet → console.warn, valeurs précédentes gardées. theme.json absent → défaut des tokens, en
//           silence ; theme.json invalide ou thème inconnu → défaut des tokens et un seul console.warn ;
//           theme.json illisible (droits) → console.error et défaut des tokens.
// Dépendances : Quickshell (env), Quickshell.Io (FileView, FileViewError).
Singleton {
    id: root

    readonly property string dir: Quickshell.env("DUNEI_TOKENS_DIR")
        || (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/dunei"
    property var tokens: null
    property var motion: null
    // Contenus bruts : brut, coque-tokens.json entier ; choix, theme.json validé ({famille, moment}) ou null
    // pour le défaut. Seul composer() les combine en tokens.
    property var brut: null
    property var choix: null
    // Thème inconnu déjà signalé, pour ne l'écrire qu'une fois au journal même si les tokens sont relus.
    property string signale: ""
    // famille et moment sont posés par composer() avant tokens : un consommateur de tokensChanged les lit à jour.
    property string _famille: ""
    property string _moment: ""
    readonly property string famille: _famille
    readonly property string moment: _moment
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
    // Opacité du verre des fenêtres de coque, par niveau d'élévation (e2, e3), lue par Materiau.
    readonly property var glass: tokens?.glass
    readonly property var render: tokens?.render
    // Contrôles blancs du thème actif : contour (outline, couleur ou null), piste éteinte au rôle controlOff
    // (offTrack), ombre de la poignée et de l'onglet coché (shadow, couleur ou null ; shadowBlur, shadowOffsetY).
    readonly property var controls: tokens?.controls
    readonly property var space: tokens?.space
    readonly property var radius: tokens?.radius
    readonly property var window: tokens?.window
    readonly property var layout: tokens?.layout
    readonly property var breakpoints: tokens?.breakpoints
    readonly property var typo: tokens?.typo
    readonly property var icons: tokens?.icons
    readonly property var pastilles: tokens?.pastilles
    readonly property var knob: tokens?.knob
    // La préférence de densité viendra de L2-26 ; d'ici là, la densité confortable s'applique.
    readonly property var density: tokens?.density.comfortable

    // stateColors — couleurs de fond et de texte d'une combinaison d'états, toutes précalculées.
    // Entrées : role (surfaceWindow, surfacePanel, surfaceRaised, controlRaised), selection (none, active, inactive,
    //           activeMuted), interaction (rest, hover, pressed, disabled).
    // Sortie : objet {fill, text} de couleurs sRGB, ou undefined si la combinaison n'existe pas ou si les
    //          tokens ne sont pas encore chargés.
    // Erreurs : aucune. Dépendances : tokens.
    function stateColors(role, selection, interaction) {
        return tokens?.states[role]?.[selection]?.[interaction]
    }

    // police — police d'interface à un échelon de l'échelle typographique, celle de Texte, de Champ et de Compteur.
    // Entrées : echelon, indice dans typo.scale ; moyen, graisse weightMedium au lieu de weightRegular.
    // Sortie : une valeur font ; avant le chargement des tokens, la famille et la taille de l'application, graisse
    //          normale.
    // Erreurs : aucune. Dépendances : typo.
    function police(echelon, moyen) {
        return Qt.font({ family: typo?.interface ?? Qt.application.font.family,
                         pixelSize: typo?.scale[echelon] ?? Qt.application.font.pixelSize,
                         weight: (moyen ? typo?.weightMedium : typo?.weightRegular) ?? Font.Normal })
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

    // fichier — URL d'un fichier déployé à côté des tokens, comme le shader compilé du matériau.
    // Rôle : désigne nom dans dir, le dossier de coque-tokens.json ; évite Qt.resolvedUrl, que les liens
    //        symboliques de la planche et des coques d'essai feraient résoudre ailleurs.
    // Entrées : nom, nom du fichier dans dir (par exemple « materiau.frag.qsb »).
    // Sortie : URL file:// du fichier ; son existence n'est pas vérifiée.
    // Erreurs : aucune ; un fichier absent se signale au chargement par son consommateur. Dépendances : dir.
    function fichier(nom) {
        return "file://" + dir + "/" + nom
    }

    // composer — construit la vue du thème actif et la publie d'un bloc.
    // Rôle : choisit la branche themes[famille][moment] désignée par choix, ou le défaut des tokens si choix est
    //        nul ou nomme une famille ou un moment que les tokens ne déclarent pas, puis remplace tokens par un
    //        objet neuf : les clés partagées du fichier, sans themes, et celles de la branche.
    // Entrées : aucune ; lit brut et choix. Sortie : aucune ; pose famille, moment puis tokens. Sans tokens
    //           lus, ne fait rien.
    // Erreurs : thème inconnu → console.warn « Theme : thème <f>/<m> inconnu ; défaut <f>/<m> appliqué », une
    //           seule fois par nom inconnu.
    // Dépendances : brut (defaut, familles, moments, themes), choix.
    function composer() {
        if (!brut) return
        const d = brut.defaut
        let f = choix?.famille ?? d.famille, m = choix?.moment ?? d.moment
        if (!brut.familles.includes(f) || !brut.moments.includes(m)) {
            if (signale !== f + "/" + m)
                console.warn("Theme : thème " + f + "/" + m + " inconnu ; défaut " + d.famille + "/" + d.moment
                    + " appliqué")
            signale = f + "/" + m
            f = d.famille
            m = d.moment
        } else signale = ""
        const vue = Object.assign({}, brut, brut.themes[f][m])
        delete vue.themes
        _famille = f
        _moment = m
        tokens = vue
    }

    // parse — analyse un fichier lu et vérifie ses clés obligatoires.
    // Entrées : text contenu du fichier ; name nom du fichier, pour le journal ; keys clés de premier niveau
    //           exigées ; suite, ce qui s'applique à la place, pour le journal.
    // Sortie : l'objet analysé, ou null s'il est illisible ou incomplet.
    // Erreurs : console.warn « Theme : <fichier> ignoré, <raison> ; <suite> ».
    // Dépendances : aucune.
    function parse(text, name, keys, suite) {
        let data = null, reason = ""
        try { data = JSON.parse(text) } catch (e) { reason = "JSON illisible (" + e.message + ")" }
        const missing = data instanceof Object ? keys.filter(k => !(k in data)) : keys
        if (!reason && missing.length) reason = "clés absentes : " + missing.join(", ")
        if (!reason) return data
        console.warn("Theme : " + name + " ignoré, " + reason + " ; " + suite)
        return null
    }

    // Source — un fichier surveillé sur disque et relu à chaque changement, renommage compris.
    // Entrées : name nom du fichier dans dir ; keys clés exigées ; optional, vrai pour un fichier dont l'absence
    // est normale ; suite, ce qui s'applique quand le contenu est invalide, pour le journal.
    // Sortie : signal parsed(data) à chaque lecture valide ; signal rejected() à chaque lecture invalide, ou
    // impossible pour un fichier facultatif.
    // Erreurs : chargement impossible → console.error, sauf l'absence d'un fichier facultatif, silencieuse ;
    // contenu invalide → voir parse.
    // Dépendances : FileView, parse.
    component Source: FileView {
        id: source
        required property string name
        required property var keys
        property bool optional: false
        property string suite: "valeurs précédentes gardées"
        signal parsed(var data)
        signal rejected()

        path: root.dir + "/" + name
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            const data = root.parse(text(), name, keys, suite)
            data ? parsed(data) : rejected()
        }
        onLoadFailed: error => {
            if (optional) rejected()
            if (!optional || error !== FileViewError.FileNotFound)
                console.error("Theme : " + name
                    + (error === FileViewError.FileNotFound ? " introuvable" : " illisible") + " dans " + root.dir
                    + " (" + FileViewError.toString(error) + ")")
        }
    }

    Source {
        name: "coque-tokens.json"
        keys: ["_generated", "defaut", "familles", "moments", "themes"]
        onParsed: data => {
            root.brut = data
            root.composer()
            root._ready = root.motion !== null
            console.info("Theme : chargé, teinte " + data.hue + ", thème " + root.famille + "/" + root.moment)
        }
    }

    // Le choix du thème : absent, invalide ou supprimé, il vaut le défaut des tokens. Un choix déjà nul ne
    // recompose pas, pour qu'un theme.json absent au lancement ne publie pas un second objet de tokens.
    Source {
        name: "theme.json"
        keys: ["famille", "moment"]
        optional: true
        suite: "défaut des tokens appliqué"
        onParsed: data => {
            root.choix = data
            root.composer()
            if (root.brut) console.info("Theme : thème " + root.famille + "/" + root.moment + " appliqué")
        }
        onRejected: {
            if (root.choix === null) return
            root.choix = null
            root.composer()
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
