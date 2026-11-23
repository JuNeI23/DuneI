.pragma library

// selecteur.js — logique pure du sélecteur de fenêtres (L2-17), sans dépendance à Quickshell.
// Rôle : filtrage et ordre des fenêtres retenues, avance circulaire de la sélection, défilement de la rangée de
// vignettes et largeur d'une vignette selon le format de sa fenêtre.
// Une fenêtre est un objet {adresse, classe, titre, bureau, historique}, tel que le rend Applications.toplevels().
// Entrées, sorties, erreurs : voir chaque fonction. Dépendances : aucune.

// fenetres — fenêtres proposées par le sélecteur, de la plus récemment utilisée à la plus ancienne.
// Entrée : toplevels, tableau de fenêtres. Sortie : nouveau tableau des fenêtres des bureaux 1 à 4 (le bureau
// spécial et les autres bureaux sont exclus), trié par historique croissant ; l'entrée n'est pas modifiée.
// Erreurs : aucune. Dépendances : aucune.
function fenetres(toplevels) {
    return toplevels.filter(f => ["1", "2", "3", "4"].includes(String(f.bureau))).sort((a, b) => a.historique - b.historique)
}

// avancer — déplace la sélection en boucle.
// Entrées : index, position actuelle ; n, nombre de fenêtres (strictement positif) ; pas, déplacement, négatif pour
// reculer. Sortie : le nouvel index, dans [0, n[ ; 0 si n n'est pas strictement positif (liste vide), au lieu de NaN
// (L2-79 f). Erreurs : aucune. Dépendances : aucune.
function avancer(index, n, pas) {
    return n > 0 ? ((index + pas) % n + n) % n : 0
}

// decalage — abscisse de départ de la rangée de vignettes, pour que la vignette choisie reste entière dans la vue.
// Entrées : index, vignette choisie ; largeurs, largeur de chaque vignette en pixels ; ecart, espace entre deux
// vignettes ; vue, largeur visible. Sortie : 0 quand la rangée tient dans la vue, ou quand index sort de largeurs
// (au lieu de NaN, L2-79 f) ; sinon l'abscisse (≤ 0) qui centre la vignette choisie, bornée pour qu'aucun vide ne
// reste à gauche ni à droite. Erreurs : aucune. Dépendances : aucune.
function decalage(index, largeurs, ecart, vue) {
    const total = largeurs.reduce((s, w) => s + w, 0) + ecart * Math.max(0, largeurs.length - 1)
    if (total <= vue || !(index >= 0 && index < largeurs.length)) return 0
    const debut = largeurs.slice(0, index).reduce((s, w) => s + w + ecart, 0)
    return Math.round(Math.min(0, Math.max(vue - total, (vue - largeurs[index]) / 2 - debut)))
}

// largeur — largeur d'une vignette, à la hauteur fixe de la rangée, selon le format de la fenêtre.
// Entrées : w, h, dimensions de la fenêtre ; cotes, {hauteur, largeurMin, largeurMax} (issues de Theme.selecteur).
// Sortie : hauteur × w / h arrondie et bornée entre largeurMin et largeurMax ; largeurMin si h vaut 0.
// Erreurs : aucune. Dépendances : aucune.
function largeur(w, h, cotes) {
    return h ? Math.round(Math.min(cotes.largeurMax, Math.max(cotes.largeurMin, cotes.hauteur * w / h))) : cotes.largeurMin
}
