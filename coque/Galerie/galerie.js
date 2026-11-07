.pragma library

// galerie.js — logique pure de la galerie de fonds d'écran.
// Rôle : filtres de formats, bornage et déplacement de la sélection, accumulation du défilement et comparaison
// avec le fond actuel, sans aucun accès au disque ni à Quickshell : le QML ne fait que brancher ces résultats.
// Dépendances : aucune (bibliothèque sans état, importable depuis tout QML ou depuis la coque d'essai).

// Formats que dunei-fond sait appliquer, sans le point.
const FORMATS = ["jpg", "jpeg", "png", "gif", "bmp", "webp", "tif", "tiff"]

// FILTRES — motifs de noms acceptés par le modèle de dossier, en minuscules puis en majuscules.
const FILTRES = [].concat(...FORMATS.map(f => ["*." + f, "*." + f.toUpperCase()]))

// borner — ramène un index dans les bornes de la liste.
// Entrées : index ; nombre, taille de la liste.
// Sortie : index entre 0 et nombre−1, ou −1 si la liste est vide. Erreurs : aucune.
function borner(index, nombre) {
    return nombre <= 0 ? -1 : Math.max(0, Math.min(nombre - 1, index))
}

// deplacer — déplace la sélection sans bouclage.
// Entrées : index courant ; pas, signé ; nombre, taille de la liste.
// Sortie : nouvel index, borné ; −1 si la liste est vide. Erreurs : aucune.
function deplacer(index, pas, nombre) {
    return borner(index + pas, nombre)
}

// initial — index de départ de la sélection.
// Entrées : chemins, liste des chemins affichés ; actuel, chemin du fond en place.
// Sortie : l'index du fond actuel, sinon 0 ; −1 si la liste est vide. Erreurs : aucune.
function initial(chemins, actuel) {
    return chemins.length === 0 ? -1 : Math.max(0, chemins.indexOf(actuel))
}

// cran — convertit un défilement cumulé (molette ou pavé tactile) en pas de sélection.
// Entrées : reste, défilement non consommé des événements précédents ; delta, défilement de l'événement ;
// tranche, défilement qui vaut un pas.
// Sortie : {pas, reste} ; pas est signé comme delta, reste est à rapporter à l'événement suivant. Erreurs : aucune.
function cran(reste, delta, tranche) {
    const total = reste + delta
    const pas = Math.trunc(total / tranche)
    return { pas: pas, reste: total - pas * tranche }
}

// identique — dit si l'image choisie est déjà le fond en place.
// Entrées : choisi, chemin de l'image ; actuel, chemin du fond actuel.
// Sortie : vrai si les deux chemins sont non vides et égaux. Erreurs : aucune.
function identique(choisi, actuel) {
    return choisi !== "" && choisi === actuel
}
