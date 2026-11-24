.pragma library

// lanceur.js — logique pure du lanceur d'applications (L2-16), sans dépendance à Quickshell.
// Rôle : recherche floue (normalisation, score, pertinence), ciblage d'une action de bureau par la saisie, et
// classement des résultats (calcul, groupes d'application avec leurs fenêtres, actions, commandes, fenêtres isolées),
// relevé d'usage, applications fréquentes et rôles de roles.lua, sélection au clavier.
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
// Entrée : paires, tableau de [clé, valeur]. Sortie : l'objet correspondant, sans la clé « __proto__ ». Erreurs : aucune. Dépendances : aucune.
function depuis(paires) {
    const o = {}
    for (const [c, v] of paires) if (c !== "__proto__") o[c] = v
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
    const titre = apps.slice().sort((a, b) => (a.titre || "").localeCompare(b.titre || "")).map(a => a.cle)
    return [...new Set([...usage, ...roles.filter(r => cles.has(r)), ...titre])].slice(0, n)
}

// deplacer — nouvelle sélection après une touche du clavier.
// Entrées : sel, {zone, rang, index, rangee} où zone vaut « medaillons », « puces », « liste » ou « apercu », index est
// la position dans la zone (dans la rangée pour l'aperçu), rang la ligne de la liste retenue et rangee, pour l'aperçu
// seulement, « vignettes » ou « boutons » ; touche, « left », « right », « up », « down » (ou ← → ↑ ↓), « ctrl+j »,
// « ctrl+k », « tab », « shift+tab » ou « escape » ; dispo, {medaillons, puces, lignes, vignettes, boutons}, le nombre
// d'éléments de chaque zone (vignettes et boutons : ceux de l'aperçu de la ligne retenue).
// Sortie : la nouvelle sélection (sel même si rien ne bouge). Les déplacements sont bornés, sans bouclage ; une zone
// vide est sautée. L'aperçu est une grille dans l'ordre visuel : la rangée des vignettes au-dessus, celle des boutons
// en dessous ; on y entre par Tab ou → depuis la liste, sur le premier bouton (l'action par défaut), ou sur la première
// vignette faute de bouton ; ← et → s'y déplacent dans la rangée, ↑ et ↓ (ou ctrl+k et ctrl+j) changent de rangée en
// gardant l'index borné ; ← au bord gauche, Échap et shift+Tab reviennent à la ligne retenue de la liste. Échap n'est
// traité que depuis l'aperçu. Erreurs : aucune. Dépendances : aucune.
function deplacer(sel, touche, dispo) {
    const t = {"←": "left", "→": "right", "↑": "up", "↓": "down", "ctrl+k": "up", "ctrl+j": "down"}[touche] || touche
    const borne = (i, n) => Math.max(0, Math.min(n - 1, i))
    const vers = (zone, n, i) => n > 0 ? {zone, rang: sel.rang, index: borne(i, n)} : sel
    const pas = {left: -1, right: 1, up: -1, down: 1}[t]
    const liste = {zone: "liste", rang: sel.rang, index: sel.rang}
    const rangee = (r, i) => dispo[r] > 0 ? {zone: "apercu", rang: sel.rang, index: borne(i, dispo[r]), rangee: r} : sel
    switch (sel.zone) {
    case "medaillons":
        if (t === "down") return vers("puces", dispo.puces, sel.index)
        return pas && (t === "left" || t === "right") ? vers("medaillons", dispo.medaillons, sel.index + pas) : sel
    case "puces":
        if (t === "up") return vers("medaillons", dispo.medaillons, sel.index)
        return pas && (t === "left" || t === "right") ? vers("puces", dispo.puces, sel.index + pas) : sel
    case "liste": {
        if (t === "tab" || t === "right") {
            const r = dispo.boutons > 0 ? "boutons" : dispo.vignettes > 0 ? "vignettes" : ""
            return r ? {zone: "apercu", rang: sel.index, index: 0, rangee: r} : sel
        }
        if (!pas || t === "left" || dispo.lignes <= 0) return sel
        const i = borne(sel.index + pas, dispo.lignes)
        return {zone: "liste", rang: i, index: i}
    }
    case "apercu":
        if (t === "escape" || t === "shift+tab" || (t === "left" && sel.index <= 0)) return liste
        if (t === "left" || t === "right") return rangee(sel.rangee, sel.index + pas)
        if (t === "up" && sel.rangee === "boutons") return rangee("vignettes", sel.index)
        if (t === "down" && sel.rangee === "vignettes") return rangee("boutons", sel.index)
        return sel
    }
    return sel
}

// suivre — place d'une sélection quand la liste change sous elle.
// Entrées : cles, clés de la nouvelle liste ; cle, clé de l'élément retenu (« » si aucun) ; index, sa place dans
// l'ancienne liste ; calculEnTete, vrai si un calcul arrivé en tête doit prendre la sélection. Sortie : 0 pour un tel
// calcul ; sinon la place de cle dans cles ; sinon, l'élément ayant disparu, index ramené dans la liste (0 si elle est
// vide). Erreurs : aucune. Dépendances : aucune.
function suivre(cles, cle, index, calculEnTete) {
    if (calculEnTete) return 0
    const i = cles.indexOf(cle)
    return i >= 0 ? i : Math.max(0, Math.min(cles.length - 1, index))
}

// elementApercu — élément de l'aperçu désigné par une sélection.
// Entrées : elements, tableau rendu par elementsApercu ; sel, la sélection (zone « apercu », rangee, index).
// Sortie : l'élément d'index sel.index parmi ceux de genre « bouton » (rangée « boutons ») ou « vignette » (rangée
// « vignettes ») ; null hors de l'aperçu ou hors des bornes. Erreurs : aucune. Dépendances : aucune.
function elementApercu(elements, sel) {
    if (!sel || sel.zone !== "apercu") return null
    return elements.filter(e => e.genre === (sel.rangee === "vignettes" ? "vignette" : "bouton"))[sel.index] ?? null
}

// lireRoles — logiciels de rôles applicatifs déclarés dans roles.lua, pour compléter l'accueil.
// Entrées : texte, le contenu de config/hypr/donnees/roles.lua (ou undefined) ; noms, les rôles voulus, dans l'ordre
// voulu. Sortie : pour chaque nom présent, le premier mot de la commande de ce rôle, sans son chemin (« kitty -1 »
// donne « kitty ») ; un nom absent ou à variantes est sauté. Limites : seuls les rôles simples de la table de premier
// niveau, écrits « nom = "commande" » sur une ligne, sont lus ; les rôles à variantes (tables imbriquées) sont
// ignorés ; un commentaire « -- » est retiré jusqu'à la fin de la ligne, même dans une chaîne ; les accolades sont
// comptées sans tenir compte des chaînes. Erreurs : aucune (un texte vide ou illisible donne un tableau vide).
// Dépendances : aucune.
function lireRoles(texte, noms) {
    const roles = {}
    let niveau = 0
    for (const brute of (texte || "").split("\n")) {
        const ligne = brute.replace(/--.*$/, "")
        const m = ligne.match(/^\s*(\w+)\s*=\s*"([^"\s]+)/)
        if (m && niveau === 1) roles[m[1]] = m[2].split("/").pop()
        niveau += (ligne.match(/{/g) || []).length - (ligne.match(/}/g) || []).length
    }
    return noms.filter(n => Object.prototype.hasOwnProperty.call(roles, n)).map(n => roles[n])
}

// surligner — découpe un texte en segments, en marquant les lettres que la saisie y a trouvées.
// Entrées : texte, chaîne affichée ; saisie, chaîne cherchée. Sortie : tableau de {texte, trouve} dont la
// concaténation redonne le texte : la première sous-chaîne qui répond à la saisie, accents et casse ignorés, sinon ses
// lettres prises dans l'ordre (comme le score 1) ; un seul segment non trouvé si rien ne répond ou si la saisie est
// vide. Erreurs : aucune. Dépendances : normaliser.
function surligner(texte, saisie) {
    const lettres = Array.from(texte || ""), n = lettres.map(normaliser), s = normaliser(saisie)
    const marques = lettres.map(() => false)
    const debut = s ? n.findIndex((_, i) => n.slice(i).join("").startsWith(s) && n[i] !== "") : -1
    if (debut >= 0) {
        for (let i = debut, lu = 0; i < n.length && lu < s.length; i++) { marques[i] = true; lu += n[i].length }
    } else if (s) {
        let j = 0
        n.forEach((c, i) => { if (j < s.length && c && s.startsWith(c, j)) { marques[i] = true; j += c.length } })
        if (j < s.length) marques.fill(false)
    }
    const segments = []
    lettres.forEach((c, i) => {
        const dernier = segments[segments.length - 1]
        if (dernier && dernier.trouve === marques[i]) dernier.texte += c
        else segments.push({ texte: c, trouve: marques[i] })
    })
    return segments.length ? segments : [{ texte: "", trouve: false }]
}

// elementsApercu — éléments de l'aperçu qu'atteint le clavier.
// Entrée : r, un résultat (ou undefined). Sortie : tableau de {genre, action, adresse} : d'abord les boutons
// (l'action principale, puis les secondaires), puis une vignette par fenêtre de l'aperçu, dont l'action amène la
// fenêtre ; [] sans résultat. elementApercu y lit l'élément d'une sélection, par rangée. Erreurs : aucune. Dépendances : aucune.
function elementsApercu(r) {
    if (!r) return []
    return [r.principale].concat(r.secondaires || []).filter(a => a).map(action => ({ genre: "bouton", action, adresse: "" }))
        .concat(((r.apercu || {}).fenetres || []).map(adresse => ({ genre: "vignette", adresse,
            action: { libelle: "Amener", genre: "amener", cible: adresse } })))
}

// expressionLisible — saisie d'un calcul mise en forme pour l'affichage (« 12*7,5 » donne « 12 × 7,5 »).
// Entrée : saisie, chaîne. Sortie : la saisie où « * » devient « × » et « / » devient « ÷ », entourés d'une espace,
// les espaces répétées réduites à une et le texte rogné. Erreurs : aucune. Dépendances : aucune.
function expressionLisible(saisie) {
    return (saisie || "").replace(/\*/g, " × ").replace(/\//g, " ÷ ").replace(/\s+/g, " ").trim()
}

// filtrer — écarte le bruit de la recherche floue : dès qu'un résultat correspond franchement (pertinence 3 ou plus,
// début du texte ou d'un mot), ceux qui ne répondent que par lettres dans l'ordre (pertinence 1) sont retirés ; le
// calcul est toujours gardé. Entrée : resultats, tableau de {genre, pertinence}. Sortie : nouveau tableau (le même
// contenu si aucun résultat n'atteint 3). Erreurs : aucune. Dépendances : aucune.
function filtrer(resultats) {
    const net = resultats.some(r => r.genre !== "calcul" && r.pertinence >= 3)
    return resultats.filter(r => !net || r.genre === "calcul" || r.pertinence !== 1)
}
