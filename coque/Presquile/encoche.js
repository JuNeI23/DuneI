// encoche.js — tracé de la forme de la presqu'île, partagé par l'Encoche et le remplissage du module Volume.
// Dépendances : aucune. Fonctions pures, sans état.
.pragma library

// tracer — tracé SVG de l'encoche continue, du coin haut gauche, dans le sens des aiguilles d'une montre.
// Entrées : l, largeur du corps ; h, hauteur ; e, évasement (0 pour le corps seul) ; r, rayon des angles du bas
// (px logiques). Sortie : chaîne de chemin SVG (M, H, C, V, Z), en px logiques depuis le coin haut gauche de
// l'encoche. Erreurs : aucune ; des dimensions nulles donnent un tracé vide de surface.
function tracer(l, h, e, r) {
    const w = l + 2 * e, creux = 12 * e / 13, a = Math.max(0, Math.min(1.4 * r, l / 2, h - creux))
    return `M0 0 H${w} C${w - 8 * e / 13} 0 ${w - 12 * e / 13} ${3 * e / 13} ${w - e} ${creux} V${h - a} `
        + `C${w - e} ${h - 5 * a / 14} ${w - e - 4 * a / 14} ${h} ${w - e - a} ${h} H${e + a} `
        + `C${e + 4 * a / 14} ${h} ${e} ${h - 5 * a / 14} ${e} ${h - a} V${creux} `
        + `C${12 * e / 13} ${3 * e / 13} ${8 * e / 13} 0 0 0 Z`
}
