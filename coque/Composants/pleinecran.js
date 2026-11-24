.pragma library

// pleinecran.js — logique pure de la lecture du vrai plein écran.
// Rôle : dit quel espace un écran montre et si cet espace porte une fenêtre en vrai plein écran, sans jamais appeler
// Hyprland : PleinEcran ne fait que lui passer les objets de Quickshell.
// Dépendances : aucune (bibliothèque sans état, importable depuis tout QML ou depuis une coque d'essai).

// lireSpecial — nom du bureau spécial ouvert.
// Entrée : donnees, données de l'événement Hyprland activespecial (« nom,moniteur »).
// Sortie : le nom (« special:accueil »), ou "" si aucun spécial n'est ouvert. Erreurs : aucune.
function lireSpecial(donnees) {
    return donnees.split(",")[0]
}

// courant — espace que montre un écran : son bureau spécial s'il est ouvert, sinon son espace actif.
// Entrées : special, nom du spécial ouvert ou "" ; actif, espace actif (ou null) ; espaces, liste de tous les espaces.
// Sortie : l'espace, ou null s'il est inconnu. Erreurs : aucune.
function courant(special, actif, espaces) {
    return (special === "" ? actif : espaces.find(e => e.name === special)) ?? null
}

// porte — dit si un espace porte une fenêtre en vrai plein écran. Le protocole Wayland n'annonce « fullscreen » que pour
// celui-ci ; une fenêtre agrandie est « maximized », alors que hasFullscreen de Hyprland les confond.
// Entrée : espace, HyprlandWorkspace ou null. Sortie : booléen. Erreurs : aucune ; une fenêtre sans poignée Wayland
// ne compte pas.
function porte(espace) {
    return espace?.toplevels.values.some(f => f.wayland?.fullscreen) ?? false
}
