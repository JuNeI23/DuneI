.pragma library

// etiquettes.js — clé de remplacement et durée d'affichage d'une notification, fonctions pures de la pile.
// Rôle : une application qui renvoie une notification portant la même étiquette (indice D-Bus) remplace la
// précédente au lieu d'en empiler une nouvelle ; la durée d'affichage se déduit du délai demandé par l'application.
// Entrées, sorties, erreurs : voir chaque fonction. Dépendances : aucune.

// Indices reconnus comme étiquette de remplacement, par ordre de priorité. Seul endroit à modifier pour brancher
// l'étiquette d'une autre application.
const INDICES = ["x-dunst-stack-tag", "x-canonical-private-synchronous"]

// cle — clé de remplacement d'une notification.
// Entrées : appName, nom de l'application ; hints, dictionnaire des indices de la notification (peut manquer).
// Sortie : « application NUL étiquette » pour le premier indice de INDICES présent et non vide, « » sinon ; une clé
// vide ne remplace jamais rien. Erreurs : aucune. Dépendances : INDICES.
function cle(appName, hints) {
    const indice = INDICES.find(i => hints && hints[i] !== undefined && hints[i] !== null && String(hints[i]) !== "")
    return indice === undefined ? "" : appName + "\u0000" + String(hints[indice])
}

// duree — durée d'affichage d'une notification, en millisecondes.
// Entrées : expireTimeout, délai demandé par l'application en ms (négatif : défaut du serveur ; 0 : jamais) ;
// defaut, durée par défaut en ms (Theme.notifications.duree).
// Sortie : defaut si le délai est négatif, le délai lui-même s'il est positif, 0 (jamais d'expiration) s'il est nul.
// Erreurs : aucune. Dépendances : aucune.
function duree(expireTimeout, defaut) {
    return expireTimeout < 0 ? defaut : expireTimeout
}
