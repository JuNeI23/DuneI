pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Theme — couleurs et dimensions du banc, lues dans les sources du dépôt.
// Rôle : aucune valeur de design écrite ici ; tout vient de generated/tokens.json
// (couleurs OKLCH déjà résolues pour la machine) et de tokens.toml (dimensions,
// voile, matière). La conversion OKLCH → sRGB reprend dunei_theme/color.py.
// Dépendances : Quickshell.Io.FileView. Erreurs : fichier absent → valeurs de repli
// (signalées dans la console par FileView).
Singleton {
    id: root

    FileView { id: jsonFile; path: Quickshell.shellPath("../../generated/tokens.json"); blockLoading: true }
    FileView { id: tomlFile; path: Quickshell.shellPath("../../tokens.toml"); blockLoading: true }

    readonly property var tokens: { try { return JSON.parse(jsonFile.text()) } catch (e) { return ({}) } }
    readonly property string toml: tomlFile.text()

    // --- Couleurs (objets OKLCH, pour pouvoir composer les états) ---
    readonly property var lPanel: parse(tokens.roles?.["surface-panel"])
    readonly property var lText: parse(tokens.roles?.["text-primary"])
    readonly property var lAccent: parse(tokens.accent)
    readonly property var lOnAccent: parse(tokens.on_accent)

    readonly property color base: role("surface-base")
    readonly property color window: role("surface-window")
    readonly property color panel: role("surface-panel")
    readonly property color raised: role("surface-raised")
    readonly property color borderSubtle: role("border-subtle")
    readonly property color borderDefault: role("border-default")
    readonly property color borderStrong: role("border-strong")
    readonly property color textDisabled: role("text-disabled")
    readonly property color textTertiary: role("text-tertiary")
    readonly property color textSecondary: role("text-secondary")
    readonly property color textPrimary: role("text-primary")
    readonly property color textEmphasis: role("text-emphasis")
    readonly property color accent: toColor(lAccent)
    readonly property color accentStandalone: toColor(parse(tokens.accent_standalone))
    readonly property color onAccent: toColor(lOnAccent)
    readonly property color warning: toColor(parse(tokens.semantic?.warning))
    readonly property var categorical: (tokens.categorical ?? []).map(s => toColor(parse(s)))

    // --- Dimensions et matière (tokens.toml) ---
    readonly property real scrim: num("render", "scrim_opacity", 0.55)
    readonly property real edgeLight: num("surface_material", "edge_light_opacity", 0.08)
    readonly property real edgeShadow: num("surface_material", "edge_shadow_opacity", 0.12)
    readonly property real shade: num("surface_material", "shade_opacity", 0.36)
    readonly property real hoverDelta: num("states.hover", "lightness_delta", 0.04)
    readonly property real pressedDelta: num("states.pressed", "lightness_delta", -0.03)
    readonly property real rWindow: num("radii", "window", 12)
    readonly property real rPanel: num("radii", "panel", 10)
    readonly property real rControl: num("radii", "control", 6)
    readonly property real rSmall: num("radii", "small", 4)
    readonly property real rowHeight: num("density.comfortable", "row_height", 24)
    readonly property real controlHeight: num("density.comfortable", "control_height", 28)
    readonly property real gutter: num("density.comfortable", "tiling_gutter", 8)
    readonly property real padding: num("spacing", "panel_padding", 12)
    readonly property real sectionGap: num("spacing", "section_gap", 16)
    readonly property real fontSize: num("type", "base_size", 13)
    readonly property string fontFamily: str("type", "interface", "Source Sans 3")
    // Nom canonique si fontconfig le connaît, sinon la version Nerd Font, sinon le monospace système.
    readonly property string monoFamily: [str("type", "mono", "Source Code Pro"), "SauceCodePro Nerd Font Mono", "monospace"]
        .find(f => f === "monospace" || Qt.fontFamilies().includes(f))

    // num — valeur numérique d'une clé de tokens.toml (lecteur minimal, clés à plat).
    // Entrées : section (sans crochets), key, fallback. Sortie : réel (fallback si absent).
    // Erreurs : aucune. Dépendances : root.toml.
    function num(section, key, fallback) {
        const v = parseFloat(raw(section, key))
        return isNaN(v) ? fallback : v
    }

    // str — valeur chaîne d'une clé de tokens.toml. Entrées/sortie : comme num.
    // Erreurs : aucune. Dépendances : raw.
    function str(section, key, fallback) {
        const v = raw(section, key)
        return v ? v.replace(/^"|"$/g, "") : fallback
    }

    // raw — texte brut de la valeur d'une clé, sans commentaire. Entrées : section, key.
    // Sortie : chaîne ou "" si introuvable. Erreurs : aucune. Dépendances : root.toml.
    function raw(section, key) {
        const start = toml.indexOf("\n[" + section + "]")
        if (start < 0) return ""
        const end = toml.indexOf("\n[", start + 2)
        const body = toml.slice(start, end < 0 ? undefined : end)
        const m = body.match(new RegExp("^" + key + "\\s*=\\s*([^#\\n]+)", "m"))
        return m ? m[1].trim() : ""
    }

    // stateFill — fond composé base → sélection → survol → pression (bible ch. 7), en OKLCH.
    // Entrées : base { l, c, h } ; sel, hover, press : progressions de ressort (0–1).
    // Sortie : color. Erreurs : aucune. Dépendances : lAccent, hoverDelta, pressedDelta, ok.
    function stateFill(base, sel, hover, press) {
        const p = Math.min(1, Math.max(0, press))
        return ok(base.l + (lAccent.l - base.l) * sel + hoverDelta * hover * (1 - p) + pressedDelta * p,
                  Math.max(0, base.c + (lAccent.c - base.c) * sel), base.h)
    }

    // stateText — texte primaire → texte sur accent selon la sélection.
    // Entrée : sel (0–1). Sortie : color. Erreurs : aucune. Dépendances : lText, lOnAccent, ok.
    function stateText(sel) {
        const t = Math.min(1, Math.max(0, sel))
        return ok(lText.l + (lOnAccent.l - lText.l) * t, lText.c + (lOnAccent.c - lText.c) * t, lText.h)
    }

    // role — couleur d'un rôle de tokens.json. Entrée : nom du rôle. Sortie : color.
    // Erreurs : rôle absent → magenta (visible exprès). Dépendances : parse, toColor.
    function role(name) { return toColor(parse(tokens.roles?.[name])) }

    // parse — "oklch(L C H)" → { l, c, h }. Entrée : chaîne. Sortie : objet (gris moyen si illisible).
    // Erreurs : aucune. Dépendances : aucune.
    function parse(s) {
        const m = (s ?? "").match(/oklch\(([\d.]+)\s+([\d.]+)\s+([\d.]+)\)/)
        return m ? { l: +m[1], c: +m[2], h: +m[3] } : { l: 0.6, c: 0.3, h: 330 }
    }

    // ok — couleur OKLCH directe (composition d'états). Entrées : l, c, h, a (opacité, défaut 1).
    // Sortie : color. Erreurs : aucune. Dépendances : toColor.
    function ok(l, c, h, a) { return toColor({ l: l, c: c, h: h }, a) }

    // linear — OKLCH → sRGB linéaire (matrices d'Ottosson, comme color.py).
    // Entrée : { l, c, h }. Sortie : [r, g, b] possiblement hors [0, 1]. Erreurs : aucune.
    function linear(o) {
        const h = o.h * Math.PI / 180, a = o.c * Math.cos(h), b = o.c * Math.sin(h)
        const l3 = Math.pow(o.l + 0.3963377774 * a + 0.2158037573 * b, 3)
        const m3 = Math.pow(o.l - 0.1055613458 * a - 0.0638541728 * b, 3)
        const s3 = Math.pow(o.l - 0.0894841775 * a - 1.2914855480 * b, 3)
        return [4.0767416621 * l3 - 3.3077115913 * m3 + 0.2309699292 * s3,
                -1.2684380046 * l3 + 2.6097574011 * m3 - 0.3413193965 * s3,
                -0.0041960863 * l3 - 0.7034186147 * m3 + 1.7076147010 * s3]
    }

    // toColor — OKLCH → color sRGB, rabattement de gamut à teinte préservée (dichotomie sur C).
    // Entrées : o { l, c, h }, a opacité (défaut 1). Sortie : color. Erreurs : aucune.
    // Dépendances : linear.
    function toColor(o, a) {
        const inGamut = rgb => rgb.every(v => v >= -1e-7 && v <= 1 + 1e-7)
        let rgb = linear(o)
        if (!inGamut(rgb)) {
            let lo = 0, hi = o.c
            for (let i = 0; i < 20; i++) {
                const mid = (lo + hi) / 2
                if (inGamut(linear({ l: o.l, c: mid, h: o.h }))) lo = mid; else hi = mid
            }
            rgb = linear({ l: o.l, c: lo, h: o.h })
        }
        const g = v => { v = Math.min(1, Math.max(0, v)); return v <= 0.0031308 ? 12.92 * v : 1.055 * Math.pow(v, 1 / 2.4) - 0.055 }
        return Qt.rgba(g(rgb[0]), g(rgb[1]), g(rgb[2]), a === undefined ? 1 : a)
    }
}
