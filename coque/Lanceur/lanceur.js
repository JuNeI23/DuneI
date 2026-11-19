.pragma library

// lanceur.js — logique pure du lanceur d'applications (L2-16), sans dépendance à Quickshell.
// Rôle : recherche floue (normalisation, score, pertinence), ciblage d'une action de bureau par la saisie, et
// classement des résultats (calcul, groupes d'application avec leurs fenêtres, actions, commandes, fenêtres isolées).
// Un résultat est un objet {cle, genre, titre, retrait, pertinence, app, …} ; seuls les champs lus par chaque
// fonction sont requis. Entrées, sorties, erreurs : voir chaque fonction. Dépendances : aucune.

// normaliser — forme comparable d'un texte : minuscules et sans signes diacritiques.
// Entrée : texte, chaîne (ou undefined). Sortie : chaîne normalisée, vide si le texte est absent.
// Erreurs : aucune. Dépendances : aucune.
function normaliser(texte) {
    return (texte || "").normalize("NFD").replace(/[̀-ͯ]/g, "").toLowerCase()
}

// score — qualité de la correspondance d'une saisie dans un texte, accents et casse ignorés.
// Entrées : texte, chaîne où chercher ; saisie, chaîne cherchée. Sortie : 4 si le texte commence par la saisie, 3 si
// un mot du texte la commence, 2 si elle en est une sous-chaîne, 1 si ses lettres s'y suivent dans l'ordre, sinon 0
// (toujours 0 pour une saisie vide). Erreurs : aucune. Dépendances : normaliser.
function score(texte, saisie) {
    const t = normaliser(texte), s = normaliser(saisie)
    if (!s) return 0
    if (t.startsWith(s)) return 4
    if (t.split(/[^a-z0-9]+/).some(m => m.startsWith(s))) return 3
    if (t.includes(s)) return 2
    let i = 0
    for (const c of t) if (c === s[i]) i++
    return i === s.length ? 1 : 0
}

// pertinence — meilleure correspondance d'une saisie parmi plusieurs champs d'un résultat.
// Entrées : champs, tableau de chaînes (nom, nom générique, mots-clés) ; saisie, chaîne cherchée. Sortie : le plus
// grand score, 0 si aucun champ. Erreurs : aucune. Dépendances : score.
function pertinence(champs, saisie) {
    return Math.max(0, ...champs.map(c => score(c, saisie)))
}

// actionVisee — dit si la saisie vise une action de bureau d'une application.
// Entrées : nomApp, nom de l'application ; nomAction, nom de l'action ; saisie, chaîne cherchée. Sortie : vrai si
// l'action elle-même correspond (score ≥ 2), ou si la saisie compte au moins deux mots dont le premier désigne
// l'application (score ≥ 3) et un autre l'action (score ≥ 3). Erreurs : aucune. Dépendances : score.
function actionVisee(nomApp, nomAction, saisie) {
    if (score(nomAction, saisie) >= 2) return true
    const mots = saisie.trim().split(/\s+/)
    return mots.length >= 2 && score(nomApp, mots[0]) >= 3 && mots.slice(1).some(m => score(nomAction, m) >= 3)
}

// classer — ordre d'affichage des résultats du lanceur.
// Entrées : resultats, tableau de résultats (les fenêtres rangées portent retrait et app, la clé de leur application) ;
// poids, objet {clé: nombre} d'usage. Sortie : nouveau tableau : le calcul d'abord ; puis les groupes d'application
// (l'application suivie de ses fenêtres rangées par poids décroissant), puis les actions, les commandes et les
// fenêtres isolées ; chaque rang trié par pertinence, poids puis titre. Erreurs : aucune. Dépendances : aucune.
function classer(resultats, poids) {
    const p = r => poids[r.cle] || 0
    const ordre = (a, b) => b.pertinence - a.pertinence || p(b) - p(a) || (a.titre || "").localeCompare(b.titre || "")
    const rang = g => resultats.filter(r => r.genre === g && !r.retrait).sort(ordre)
    const rangees = a => resultats.filter(r => r.retrait && r.app === a.cle).sort((x, y) => p(y) - p(x))
    return [].concat(rang("calcul"), ...rang("application").map(a => [a].concat(rangees(a))),
                     rang("action"), rang("commande"), rang("fenetre"))
}
