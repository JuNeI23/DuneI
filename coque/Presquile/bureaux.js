.pragma library

// bureaux.js — logique pure des bureaux de la presqu'île.
// Rôle : calcule la position de la pilule, les pas de molette, les bureaux visés et les commandes Hyprland
// à émettre, sans jamais appeler Hyprland : le QML ne fait que brancher ces résultats sur l'état et sur
// Hyprland.dispatch.
// Dépendances : aucune (bibliothèque sans état, importable depuis tout QML ou depuis la coque d'essai).

// Tranche de défilement qui vaut un pas de molette (une encoche de souris donne 120 sur angleDelta.y).
const TRANCHE = 120

// indexPilule — position du point qui porte la pilule.
// Entrées : idActif, identifiant du bureau actif ; nombre, nombre de bureaux.
// Sortie : 0 à nombre−1, ou −1 si idActif n'est pas un entier de 1 à nombre (bureau absent, bureau spécial).
// Erreurs : aucune.
function indexPilule(idActif, nombre) {
    return Number.isInteger(idActif) && idActif >= 1 && idActif <= nombre ? idActif - 1 : -1
}

// pasMolette — convertit le défilement cumulé en pas de bureau.
// Entrées : cumul, reste des événements précédents ; delta, angleDelta.y de l'événement (positif vers le haut).
// Sortie : {pas, reste} ; pas vaut −1 vers le haut et +1 vers le bas par tranche de 120, reste est à rapporter
// au prochain événement. Erreurs : aucune.
function pasMolette(cumul, delta) {
    const total = cumul + delta
    const tranches = Math.trunc(total / TRANCHE)
    return { pas: tranches === 0 ? 0 : -tranches, reste: total - tranches * TRANCHE }
}

// cibleMolette — bureau visé par un pas de molette.
// Entrées : idActif ; pas, nombre de bureaux à franchir (signé) ; nombre, nombre de bureaux.
// Sortie : bureau visé, borné à 1 et nombre ; 0 s'il n'y a rien à faire (pas nul, déjà en butée ou idActif
// hors plage). Erreurs : aucune.
function cibleMolette(idActif, pas, nombre) {
    if (pas === 0 || indexPilule(idActif, nombre) < 0) return 0
    const cible = Math.max(1, Math.min(nombre, idActif + pas))
    return cible === idActif ? 0 : cible
}

// lireSpecial — nom du bureau spécial ouvert.
// Entrée : donnees, données de l'événement Hyprland activespecial (« nom,moniteur »).
// Sortie : le nom (« special:accueil »), ou "" si aucun spécial n'est ouvert. Erreurs : aucune.
function lireSpecial(donnees) {
    return donnees.split(",")[0]
}

// commandeBureau — expression Hyprland qui donne le focus à un bureau ; seul endroit qui la construit.
// Entrée : id, identifiant du bureau. Sortie : expression hl.dsp.* à passer à Hyprland.dispatch.
// Erreurs : aucune.
function commandeBureau(id) {
    return "hl.dsp.focus({ workspace = " + id + " })"
}

// commandesClic — expressions à émettre pour un clic sur un point.
// Entrées : id, bureau cliqué ; idActif ; special, nom du spécial ouvert (« special:… ») ou "".
// Sortie : liste ordonnée d'expressions hl.dsp.*. Spécial fermé : [] sur le bureau actif, sinon le focus.
// Spécial ouvert : la bascule du spécial seule sur la pilule grisée, sinon la bascule (qui le referme) puis le focus.
// Erreurs : aucune.
function commandesClic(id, idActif, special) {
    if (special === "") return id === idActif ? [] : [commandeBureau(id)]
    const bascule = 'hl.dsp.workspace.toggle_special("' + special.replace("special:", "") + '")'
    return id === idActif ? [bascule] : [bascule, commandeBureau(id)]
}
