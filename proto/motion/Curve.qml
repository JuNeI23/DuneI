import QtQuick
import "physics.js" as Physics

// Curve — réponse indicielle du ressort, entrée et sortie, sur un même axe de temps.
// Rôle : rendre lisible ce que ζ et la durée annoncent (dépassement, traîne).
// Entrées : params (Params). Sortie : dessin. Erreurs : aucune.
// Dépendances : physics.js, Theme.
Canvas {
    id: cv
    property Params params
    readonly property var enter: params ? Physics.response(params.mass, params.stiffness, params.damping, 1, 160, horizon) : null
    readonly property var exit: params ? Physics.response(params.mass, params.stiffness, params.damping, params.exitScale, 160, horizon) : null
    readonly property real horizon: params ? Math.max(0.2, params.enter.stop / 1000) : 1

    onEnterChanged: requestPaint()
    onWidthChanged: requestPaint()

    // trace — trace une série de points normalisés. Entrées : ctx, pts, couleur, épaisseur.
    // Sortie : aucune. Erreurs : aucune. Dépendances : aucune.
    function trace(ctx, pts, col, w) {
        const top = 12, h = height - 24
        ctx.strokeStyle = col; ctx.lineWidth = w; ctx.beginPath()
        for (let i = 0; i < pts.length; i++) {
            const x = i / (pts.length - 1) * width, y = top + h - pts[i] / 1.2 * h
            i ? ctx.lineTo(x, y) : ctx.moveTo(x, y)
        }
        ctx.stroke()
    }

    onPaint: {
        const ctx = getContext("2d")
        ctx.reset()
        const top = 12, h = height - 24
        ctx.fillStyle = Theme.base; ctx.fillRect(0, 0, width, height)
        ctx.strokeStyle = Theme.borderSubtle; ctx.lineWidth = 1
        for (let t = 0.1; t < horizon; t += 0.1) {          // graduations toutes les 100 ms
            const x = Math.round(t / horizon * width) + 0.5
            ctx.beginPath(); ctx.moveTo(x, top); ctx.lineTo(x, top + h); ctx.stroke()
        }
        const y1 = Math.round(top + h - h / 1.2) + 0.5            // niveau d'arrivée
        ctx.strokeStyle = Theme.borderStrong; ctx.beginPath(); ctx.moveTo(0, y1); ctx.lineTo(width, y1); ctx.stroke()
        if (exit) trace(ctx, exit.points, Theme.textTertiary, 1.5)
        if (enter) trace(ctx, enter.points, Theme.accentStandalone, 2)
    }
}
