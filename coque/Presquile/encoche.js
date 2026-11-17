// encoche.js — tracé de la forme de la presqu'île, partagé par l'Encoche et le remplissage du module Volume.
// Deux côtés pour une même courbe : la forme du haut (tracer), qui descend du bord haut de l'écran, et la forme
// latérale (tracerLateral, L2-67), collée au bord droit ; elles partagent leurs points (segments), la seconde n'étant
// que la première transposée.
// Dépendances : aucune. Fonctions pures, sans état.
.pragma library

// segments — points de l'encoche continue du haut, du coin haut gauche, dans le sens des aiguilles d'une montre.
// Entrées : l, largeur du corps ; h, hauteur ; e, évasement (0 pour le corps seul) ; r, rayon des angles du bas
// (px logiques). Sortie : tableau de segments, chacun un tableau de points [x, y] : un point pour un trait droit
// (le premier ouvre le tracé), trois pour une cubique (deux poignées, puis l'arrivée). Erreurs : aucune ; des
// dimensions nulles donnent un tracé vide de surface. Dépendances : aucune.
function segments(l, h, e, r) {
    const w = l + 2 * e, creux = 12 * e / 13, a = Math.max(0, Math.min(1.4 * r, l / 2, h - creux))
    return [[[0, 0]], [[w, 0]],
            [[w - 8 * e / 13, 0], [w - 12 * e / 13, 3 * e / 13], [w - e, creux]], [[w - e, h - a]],
            [[w - e, h - 5 * a / 14], [w - e - 4 * a / 14, h], [w - e - a, h]], [[e + a, h]],
            [[e + 4 * a / 14, h], [e, h - 5 * a / 14], [e, h - a]], [[e, creux]],
            [[12 * e / 13, 3 * e / 13], [8 * e / 13, 0], [0, 0]]]
}

// ecrire — chaîne de chemin SVG d'une suite de segments.
// Entrée : s, segments au format de segments. Sortie : chemin SVG (M, H, V, C, Z) : un trait droit s'écrit H quand
// son ordonnée ne change pas, V sinon (les traits de l'encoche sont tous horizontaux ou verticaux).
// Erreurs : aucune. Dépendances : aucune.
function ecrire(s) {
    let [x, y] = s[0][0]
    const morceaux = [`M${x} ${y}`]
    for (const p of s.slice(1)) {
        const [nx, ny] = p[p.length - 1]
        morceaux.push(p.length === 3 ? "C" + p.map(q => q.join(" ")).join(" ") : ny === y ? `H${nx}` : `V${ny}`)
        x = nx; y = ny
    }
    return morceaux.join(" ") + " Z"
}

// tracer — tracé SVG de l'encoche continue, du coin haut gauche, dans le sens des aiguilles d'une montre.
// Entrées : l, largeur du corps ; h, hauteur ; e, évasement (0 pour le corps seul) ; r, rayon des angles du bas
// (px logiques). Sortie : chaîne de chemin SVG (M, H, C, V, Z), en px logiques depuis le coin haut gauche de
// l'encoche. Erreurs : aucune ; des dimensions nulles donnent un tracé vide de surface.
// Dépendances : segments, ecrire.
function tracer(l, h, e, r) {
    return ecrire(segments(l, h, e, r))
}

// tracerLateral — tracé SVG de la forme latérale, collée au bord droit : le corps, large de l et haut de h, sort du
// bord droit ; deux évasements de e le raccordent à ce bord, au-dessus et au-dessous ; ses angles gauches ont le
// rayon r. C'est l'encoche du haut de corps h et de hauteur l, dont chaque point (x, y) devient (l − y, x).
// Entrées : l, h, e, r (px logiques). Sortie : chaîne de chemin SVG, dans une boîte de l × (h + 2 e), depuis son
// coin haut gauche. Erreurs : aucune ; des dimensions nulles donnent un tracé vide de surface.
// Dépendances : segments, ecrire.
function tracerLateral(l, h, e, r) {
    return ecrire(segments(h, l, e, r).map(p => p.map(([x, y]) => [l - y, x])))
}
