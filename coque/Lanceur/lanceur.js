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
    const mots = (saisie || "").trim().split(/\s+/)
    return mots.length >= 2 && score(nomApp, mots[0]) >= 3 && mots.slice(1).some(m => score(nomAction, m) >= 3)
}

// classer — ordre d'affichage des résultats du lanceur.
// Entrées : resultats, tableau de résultats (les fenêtres rangées portent retrait et app, la clé de leur application) ;
// poids, objet {clé: nombre} d'usage. Sortie : nouveau tableau : le calcul d'abord ; puis les groupes d'application
// (l'application suivie de ses fenêtres rangées par poids décroissant, puis par titre), puis les actions, les commandes et les
// fenêtres isolées ; chaque rang trié par pertinence, poids puis titre. Erreurs : aucune. Dépendances : aucune.
function classer(resultats, poids) {
    const p = r => poids[r.cle] || 0
    const ordre = (a, b) => b.pertinence - a.pertinence || p(b) - p(a) || (a.titre || "").localeCompare(b.titre || "")
    const rang = g => resultats.filter(r => r.genre === g && !r.retrait).sort(ordre)
    const rangees = a => resultats.filter(r => r.retrait && r.app === a.cle)
                                    .sort((x, y) => p(y) - p(x) || (x.titre || "").localeCompare(y.titre || ""))
    return [].concat(rang("calcul"), ...rang("application").map(a => [a].concat(rangees(a))),
                     rang("action"), rang("commande"), rang("fenetre"))
}

// depuis — équivalent d'Object.fromEntries, absent du moteur JavaScript de QML.
// Entrée : paires, tableau de [clé, valeur]. Sortie : l'objet correspondant. Erreurs : aucune. Dépendances : aucune.
function depuis(paires) {
    const o = {}
    for (const [c, v] of paires) o[c] = v
    return o
}

// noter — enregistre une utilisation dans le relevé d'usage.
// Entrées : usage, objet {clé: {n, dernier}} ; cle, la clé du résultat lancé ; maintenant, l'instant en millisecondes.
// Sortie : un nouvel objet d'usage où n de la clé augmente de un et dernier vaut maintenant (l'entrée n'est pas
// modifiée). Erreurs : aucune. Dépendances : aucune.
function noter(usage, cle, maintenant) {
    return Object.assign({}, usage, {[cle]: {n: ((usage[cle] || {}).n || 0) + 1, dernier: maintenant}})
}

// poids — poids de chaque clé du relevé d'usage, qui s'éteint de moitié tous les quatorze jours.
// Entrées : usage, objet {clé: {n, dernier}} ; maintenant, l'instant en millisecondes. Sortie : objet {clé: nombre},
// n × 0,5 puissance (âge en jours / 14), l'âge étant borné à zéro. Erreurs : aucune. Dépendances : aucune.
function poids(usage, maintenant) {
    const jour = 86400000
    return depuis(Object.entries(usage).map(([c, u]) =>
        [c, u.n * Math.pow(0.5, Math.max(0, maintenant - u.dernier) / jour / 14)]))
}

// assainir — remet d'aplomb un relevé d'usage lu sur le disque.
// Entrée : brut, n'importe quelle valeur lue du fichier. Sortie : un objet {clé: {n, dernier}} ne gardant que les
// entrées dont n est un entier au moins égal à un et dernier un nombre fini ; {} si brut n'est pas un objet simple.
// Erreurs : aucune. Dépendances : aucune.
function assainir(brut) {
    if (!brut || typeof brut !== "object" || Array.isArray(brut)) return {}
    return depuis(Object.entries(brut).filter(([, u]) => u && Number.isInteger(u.n) && u.n >= 1
        && typeof u.dernier === "number" && isFinite(u.dernier)).map(([c, u]) => [c, {n: u.n, dernier: u.dernier}]))
}

// frequentes — applications proposées à l'accueil.
// Entrées : apps, tableau de {cle, titre} ; poids, objet {clé: nombre} ; roles, clés des applications de rôle dans
// l'ordre de préférence ; n, nombre maximal. Sortie : au plus n clés sans doublon : celles de poids positif par poids
// décroissant, puis les rôles dans l'ordre, puis les autres applications par titre. Erreurs : aucune (une clé de
// rôle absente de apps est ignorée). Dépendances : aucune.
function frequentes(apps, poids, roles, n) {
    const cles = new Set(apps.map(a => a.cle))
    const usage = apps.filter(a => poids[a.cle] > 0).sort((a, b) => poids[b.cle] - poids[a.cle]).map(a => a.cle)
    const titre = apps.slice().sort((a, b) => a.titre.localeCompare(b.titre)).map(a => a.cle)
    return [...new Set([...usage, ...roles.filter(r => cles.has(r)), ...titre])].slice(0, n)
}

// deplacer — nouvelle sélection après une touche du clavier.
// Entrées : sel, {zone, rang, index} où zone vaut « medaillons », « puces », « liste » ou « apercu », index est la
// position dans la zone et rang la ligne de la liste retenue ; touche, « left », « right », « up », « down »
// (ou ← → ↑ ↓), « ctrl+j », « ctrl+k », « tab », « shift+tab » ou « escape » ; dispo, {medaillons, puces, lignes,
// apercu}, le nombre d'éléments de chaque zone. Sortie : la nouvelle sélection (sel même si rien ne bouge). Les
// déplacements sont bornés, sans bouclage ; une zone vide est sautée. Échap n'est traité que depuis l'aperçu.
// Erreurs : aucune. Dépendances : aucune.
function deplacer(sel, touche, dispo) {
    const t = {"←": "left", "→": "right", "↑": "up", "↓": "down"}[touche] || touche
    const borne = (i, n) => Math.max(0, Math.min(n - 1, i))
    const vers = (zone, n, i) => n > 0 ? {zone, rang: sel.rang, index: borne(i, n)} : sel
    const pas = {left: -1, right: 1, up: -1, down: 1, "ctrl+k": -1, "ctrl+j": 1}[t]
    switch (sel.zone) {
    case "medaillons":
        if (t === "down") return vers("puces", dispo.puces, sel.index)
        return pas && (t === "left" || t === "right") ? vers("medaillons", dispo.medaillons, sel.index + pas) : sel
    case "puces":
        if (t === "up") return vers("medaillons", dispo.medaillons, sel.index)
        return pas && (t === "left" || t === "right") ? vers("puces", dispo.puces, sel.index + pas) : sel
    case "liste": {
        if (t === "tab") return dispo.apercu > 0 ? {zone: "apercu", rang: sel.index, index: 0} : sel
        const i = pas && t !== "left" && t !== "right" ? borne(sel.index + pas, dispo.lignes) : sel.index
        return dispo.lignes > 0 ? {zone: "liste", rang: i, index: i} : sel
    }
    case "apercu":
        if (t === "escape" || t === "shift+tab") return {zone: "liste", rang: sel.rang, index: sel.rang}
        return pas ? vers("apercu", dispo.apercu, sel.index + pas) : sel
    }
    return sel
}
