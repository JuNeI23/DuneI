.pragma library

// calcul.js — logique pure du calcul du lanceur (L2-16, L2-82), sans dépendance à Quickshell.
// Rôle : décide si une saisie part à qalc, la traduit du français vers la syntaxe de qalc et lit sa réponse. Une saisie
// n'est traduite que si tous ses mots sont au vocabulaire et que ses grandeurs s'accordent : qalc répond toujours.
// Entrées, sorties, erreurs : voir chaque fonction. Dépendances : unites.js.
.import "unites.js" as Unites

// aEnvoyer — dit si une saisie mérite d'être soumise à qalc.
// Entrée : saisie, chaîne. Sortie : vrai si elle contient un chiffre et commence (espaces écartés) par un chiffre,
// une parenthèse, un signe, un séparateur décimal ou une monnaie (€ $ £). Sans chiffre, qalc invente des résultats
// (« kitty » donne « 0 t² ») ; un nom d'application (« python3 », « 7zip ») ou une commande de qalc (« exit 1 »,
// qui le tuerait) ne part jamais : un mot unique à lettres, sans espace ni opérateur (« 7zip »), est un nom, pas un
// calcul.
// Erreurs : aucune. Dépendances : aucune.
function aEnvoyer(saisie) {
    const s = (saisie || "").trim()
    return /\d/.test(s) && /^[\d(\-+.,€$£]/.test(s) && !/^[^\s+\-*\/^%()×÷]*[a-z][^\s+\-*\/^%()×÷]*$/i.test(s)
}

// normaliser — ramène un mot à la forme des noms du vocabulaire.
// Entrée : mot. Sortie : le mot en minuscules, sans accent ni « œ ». Erreurs : aucune. Dépendances : aucune.
function normaliser(mot) {
    return mot.toLowerCase().replace(/œ/g, "oe").normalize("NFD").replace(/[̀-ͯ]/g, "")
}

// singulier — ôte le « s » final d'un mot, pour chaque mot d'un nom composé.
// Entrée : nom normalisé. Sortie : le nom au singulier. Erreurs : aucune. Dépendances : aucune.
function singulier(nom) { return nom.replace(/s(?= |$)/g, "") }

// lexique — dresse une fois pour toutes les tables de recherche à partir d'unites.js, préfixes compris.
// Entrées : aucune. Sortie : { symboles, noms }, deux Map d'un mot vers { texte (nom qalc), grandeur }. Les mots sans
// préfixe sont posés en premier et ne sont jamais remplacés (« min » n'est pas « milli-in », « Pa » n'est pas
// « péta-a »). Erreurs : aucune. Dépendances : Unites, grandeur.
const lexique = (() => {
    const tables = { symboles: new Map(), noms: new Map() }
    // poser — inscrit un mot s'il est neuf. Entrées : table, mot, texte qalc, dim. Sortie : aucune. Erreurs : aucune.
    // Dépendances : aucune.
    function poser(table, mot, texte, dim) { if (mot && !table.has(mot)) table.set(mot, { texte, grandeur: dim }) }
    const lignes = Unites.UNITES.map(u => ({ texte: u[0], dim: grandeur(u[1]), symboles: u[2].split("|"),
                                             noms: u[3].split("|"), prefixes: u[4] }))
    for (const l of lignes) {
        for (const s of l.symboles) poser(tables.symboles, s, l.texte, l.dim)
        // Un nom dont le singulier finit par « s » se cherche aussi sans lui (« degrés celsius »).
        for (const n of l.noms) for (const forme of [n, singulier(n)])
            poser(tables.noms, forme, l.texte, l.dim)
    }
    for (const l of lignes) {
        for (const [symbole, autre, nom] of Unites.PREFIXES[l.prefixes]) {
            for (const s of l.symboles) if (s) {
                poser(tables.symboles, symbole + s, symbole + l.texte, l.dim)
                if (autre) poser(tables.symboles, autre + s, symbole + l.texte, l.dim)
            }
            for (const n of l.noms) if (n) poser(tables.noms, nom + n, symbole + l.texte, l.dim)
        }
    }
    return tables
})()

// grandeur — lit une grandeur écrite (« L T-1 »).
// Entrée : texte. Sortie : objet des puissances par lettre. Erreurs : aucune. Dépendances : aucune.
function grandeur(texte) {
    const g = {}
    for (const mot of texte.split(" ")) g[mot[0]] = Number(mot.slice(1) || 1)
    return g
}

// combiner — multiplie une grandeur par une puissance d'une autre.
// Entrées : a, b grandeurs ; n, la puissance de b (−1 divise). Sortie : la grandeur produite, sans puissance nulle.
// Erreurs : aucune. Dépendances : aucune.
function combiner(a, b, n) {
    const g = Object.assign({}, a)
    for (const k in b) {
        g[k] = (g[k] || 0) + b[k] * n
        if (!g[k]) delete g[k]
    }
    return g
}

// pareilles — dit si deux grandeurs sont la même. Entrées : a, b. Sortie : booléen. Erreurs : aucune.
// Dépendances : combiner.
function pareilles(a, b) { return Object.keys(combiner(a, b, -1)).length === 0 }

// uniteDe — cherche une unité dans le vocabulaire.
// Entrée : mot, tel que saisi, en un ou plusieurs mots. Sortie : { texte, grandeur } ou undefined ; le symbole, à la
// casse près, l'emporte sur le nom. Erreurs : aucune. Dépendances : lexique, normaliser, singulier.
function uniteDe(mot) {
    const nom = normaliser(mot)
    return lexique.symboles.get(mot) || lexique.noms.get(nom) || lexique.noms.get(singulier(nom))
}

// elementDe — reconnaît un mot hors unité.
// Entrées : mot, tel que saisi ; avant, l'élément qui précède ou undefined ; apres, la suite de la saisie. Sortie :
// l'élément, ou undefined si le mot est inconnu ; « x » ne multiplie que devant un nombre (« 2x + 3 » est une
// équation). Erreurs : aucune. Dépendances : Unites, normaliser, singulier.
function elementDe(mot, avant, apres) {
    const nom = normaliser(mot)
    // parmi — valeur associée à un mot. Entrées : liste de couples, cle. Sortie : la valeur ou undefined.
    // Erreurs : aucune. Dépendances : aucune.
    function parmi(liste, cle) { return (liste.find(l => l[0] === cle) || [])[1] }
    if (Unites.CONVERSIONS.includes(nom)) return { genre: "conversion", texte: "to" }
    if (nom === "de" && avant && avant.genre === "pourcent") return { genre: "op", texte: "*" }
    if (nom === "x" && !/^\s*[\d.,(]/.test(apres)) return undefined
    if (parmi(Unites.OPERATEURS, nom)) return { genre: "op", texte: parmi(Unites.OPERATEURS, nom) }
    if (parmi(Unites.CONSTANTES, mot)) return { genre: "constante", texte: parmi(Unites.CONSTANTES, mot) }
    if (parmi(Unites.BASES, nom)) return { genre: "base", texte: parmi(Unites.BASES, nom) }
    if (parmi(Unites.FONCTIONS, nom)) return { genre: "fonction", texte: nom, effet: parmi(Unites.FONCTIONS, nom) }
    const n = Unites.EXPOSANTS.find(e => e[0] === singulier(nom))
    return n && avant && avant.genre === "unite" ? exposant(n[1]) : undefined
}

// exposant — fabrique l'élément d'une puissance collée à une unité. Entrée : n. Sortie : l'élément. Erreurs : aucune.
// Dépendances : aucune.
function exposant(n) { return { genre: "exposant", texte: "^" + n, n: n, colle: true } }

// Un mot : une monnaie (« k€ » comprise), des lettres (précédées ou non de « ° »), ou « ° » seul.
const LETTRES = "[A-Za-zÀ-ÖØ-öø-ÿœŒµμπ\u03a9\u2126]+"
const MOT = new RegExp("^(?:[kMG]?[€$£¥]|log(?:2|10)(?!\\d)|°?" + LETTRES + "|°)")
const SUITE = new RegExp("^[ \\-'’]" + LETTRES)
// Un nombre : hexadécimal, à milliers séparés par une espace (« 1 500 »), ou à un seul séparateur décimal (une
// adresse ou une date n'est pas un nombre).
const MILLIERS = "\\d{1,3}(?:[ \\u00a0\\u202f]\\d{3})+(?!\\d)(?:[.,]\\d+)?"
const NOMBRE = new RegExp("^(?:0x[\\da-fA-F]+|(?:" + MILLIERS + "|\\d+(?:[.,]\\d*)?|[.,]\\d+)(?:e[+-]?\\d+)?)")

// decouper — découpe une saisie en éléments reconnus.
// Entrée : saisie. Sortie : liste d'éléments { genre, texte (en syntaxe qalc), espace (vrai si un blanc précède),
// grandeur, mot }, ou null si un mot ou un signe est inconnu. Erreurs : aucune.
// Dépendances : uniteDe, elementDe, exposant.
function decouper(saisie) {
    const elements = []
    let reste = saisie.trim()
    while (reste) {
        const blanc = reste.match(/^\s*/)[0].length
        reste = reste.slice(blanc)
        const avant = elements[elements.length - 1]
        const nombre = reste.match(NOMBRE)
        const mot = reste.match(MOT)
        let lu, e
        if (nombre) {
            lu = nombre[0]
            // Un chiffre collé à une unité est une puissance (« cm2 »), et rien d'autre.
            if (avant && avant.genre === "unite" && !blanc && /^[A-Za-z]/.test(avant.mot))
                e = /^[23]$/.test(lu) ? exposant(Number(lu)) : undefined
            else e = { genre: "nombre", texte: lu.replace(/\s/g, "") }
        } else if (mot) {
            // Le nom composé le plus long l'emporte (« livres sterling » avant « livres »).
            let essai = mot[0]
            const essais = [essai]
            for (let i = 0; i < 2; i++) {
                const suite = reste.slice(essai.length).match(SUITE)
                if (!suite) break
                essai += suite[0]
                essais.unshift(essai)
            }
            for (const candidat of essais) {
                lu = candidat
                const compose = candidat.length > mot[0].length
                // « in » après une unité est la conversion à l'anglaise, après un nombre le pouce.
                const u = candidat === "in" && avant && avant.genre === "unite" ? undefined
                    : uniteDe(compose ? candidat.replace(/[-'’]/g, " ") : candidat)
                e = u ? { genre: "unite", texte: u.texte, grandeur: u.grandeur, mot: candidat }
                    : compose ? undefined : elementDe(candidat, avant, reste.slice(candidat.length))
                if (e) break
            }
        } else {
            lu = reste.startsWith("**") ? "**" : reste[0]
            if (lu === "**") e = { genre: "op", texte: "^" }
            else if (lu === "√") e = { genre: "fonction", texte: "sqrt", effet: "racine", mot: "√" }
            else if (lu === "²" || lu === "³") e = exposant(lu === "²" ? 2 : 3)
            else if (lu === "%") e = { genre: "pourcent", texte: "%", colle: true }
            else if ("+-−*/×÷^!()".includes(lu)) e = { genre: "op", texte: lu === "−" ? "-" : lu }
        }
        if (!e) return null
        elements.push(Object.assign(e, { espace: blanc > 0 && !e.colle }))
        reste = reste.slice(lu.length)
    }
    return elements
}

// grouper — pose les parenthèses qui font lire à qalc ce que analyser comprend.
// Entrée : elements. Sortie : une liste où « 1/2 m » est « (1/2) m », où « √9 » est « sqrt(9) », et où une quantité
// composée (« 90 km/h ») ou mêlée (« 2 h 30 min ») est entre parenthèses après « * », « / » ou « - » : qalc grouperait
// selon les espaces. Erreurs : aucune. Dépendances : aucune.
function grouper(elements) {
    const sortie = []
    // est — dit si un élément est un opérateur donné. Entrées : e, élément ou undefined ; textes. Sortie : booléen.
    // Erreurs : aucune. Dépendances : aucune.
    function est(e, ...textes) { return !!e && e.genre === "op" && textes.includes(e.texte) }
    // genre — genre de l'élément à une place. Entrée : k. Sortie : chaîne, « » hors de la liste. Erreurs : aucune.
    // Dépendances : aucune.
    function genre(k) { return elements[k] ? elements[k].genre : "" }
    // parentheser — ajoute des éléments entre parenthèses à la sortie. Entrée : partie. Sortie : aucune.
    // Erreurs : aucune. Dépendances : aucune.
    function parentheser(partie) {
        sortie.push({ genre: "op", texte: "(", espace: partie[0].espace },
                    Object.assign({}, partie[0], { espace: false }),
                    ...partie.slice(1), { genre: "op", texte: ")", espace: false })
    }
    for (let i = 0; i < elements.length; i++) {
        const avant = elements[i - 1]
        if (genre(i) === "nombre" && avant && avant.mot === "√") {
            parentheser([Object.assign({}, elements[i], { espace: false })])
            continue
        }
        if (genre(i) === "nombre" && est(elements[i + 1], "/") && genre(i + 2) === "nombre" && genre(i + 3) === "unite"
            && !elements[i + 1].espace && !elements[i + 2].espace && elements[i + 3].espace
            && !est(avant, "/", "÷", "^")) {
            sortie.push({ genre: "nombre", texte: "(" + elements[i].texte + "/" + elements[i + 2].texte + ")",
                          espace: elements[i].espace })
            i += 2
            continue
        }
        // Une quantité : des paires nombre et unité, les unités pouvant être liées par « / » ou « * » sans espace.
        let fin = i, parts = 0
        while (est(avant, "*", "×", "/", "÷", "-") && genre(fin) === "nombre" && genre(fin + 1) === "unite") {
            fin += 2
            parts++
            for (;;) {
                if (genre(fin) === "exposant") fin++
                else if (est(elements[fin], "/", "*") && !elements[fin].espace && genre(fin + 1) === "unite"
                         && !elements[fin + 1].espace) { fin += 2; parts++ }
                else break
            }
        }
        if (parts > 1) { parentheser(elements.slice(i, fin)); i = fin - 1 }
        else sortie.push(elements[i])
    }
    return sortie
}

// analyser — vérifie qu'une suite d'éléments est une expression complète et en donne la grandeur.
// Entrée : elements. Sortie : { dim, pourcent } ; pourcent dit que l'expression n'est qu'un pourcentage, qui s'ajoute à
// toute grandeur. Erreurs : lève Error si l'expression est inachevée ou si ses grandeurs ne s'accordent pas ; une
// parenthèse fermante manquante en fin de saisie est admise, comme par qalc. Dépendances : combiner, pareilles.
function analyser(elements) {
    let i = 0
    // refus — abandonne l'analyse. Entrées : aucune. Sortie : aucune. Erreurs : lève toujours. Dépendances : aucune.
    function refus() { throw new Error("saisie incomprise") }
    // est — dit si l'élément courant est un opérateur donné. Entrée : textes. Sortie : booléen. Erreurs : aucune.
    // Dépendances : aucune.
    function est(...textes) { return genre() === "op" && textes.includes(elements[i].texte) }
    // genre — genre de l'élément courant. Entrées : aucune. Sortie : chaîne, « » à la fin. Erreurs : aucune.
    // Dépendances : aucune.
    function genre() { return elements[i] ? elements[i].genre : "" }
    // sansGrandeur — dit si une grandeur est celle d'un nombre. Entrée : d. Sortie : booléen. Erreurs : aucune.
    // Dépendances : aucune.
    function sansGrandeur(d) { return Object.keys(d).length === 0 }
    // valeur — résultat d'une partie. Entrées : dim ; pourcent, faux par défaut. Sortie : { dim, pourcent }.
    // Erreurs : aucune. Dépendances : aucune.
    function valeur(dim, pourcent) { return { dim, pourcent: !!pourcent } }

    // accorder — grandeur d'une somme. Entrées : a, b. Sortie : celle de a. Erreurs : refus. Dépendances : pareilles.
    function accorder(a, b) { return b.pourcent || pareilles(a.dim, b.dim) ? a : refus() }

    // somme — termes ajoutés, retranchés ou juxtaposés (« 5 ft 3 in » ; deux nombres nus ne s'ajoutent pas).
    // Entrées : aucune (lit i). Sortie : grandeur. Erreurs : refus. Dépendances : produit, accorder.
    function somme() {
        let g = produit()
        while (est("+", "-") || genre() === "nombre") {
            if (genre() !== "nombre") i++
            else if (sansGrandeur(g.dim)) refus()
            g = accorder(g, produit())
        }
        return g
    }

    // produit — groupes multipliés ou divisés ; « mod » ne prend que des nombres, qalc laissant le reste en l'état.
    // Entrées : aucune. Sortie : grandeur. Erreurs : refus. Dépendances : groupe, combiner.
    function produit() {
        let g = groupe()
        while (est("*", "/", "×", "÷", "mod")) {
            const op = elements[i++].texte
            const d = groupe()
            if (op === "mod" && !(sansGrandeur(g.dim) && sansGrandeur(d.dim))) refus()
            g = valeur(combiner(g.dim, d.dim, "/÷".includes(op) ? -1 : 1))
        }
        return g
    }

    // groupe — facteurs juxtaposés (« 5 m », « €5 », « 2 (3+1) ») : un seul nombre au plus, et jamais deux unités de
    // même grandeur à la suite (« 5 in cm »). Entrées : aucune. Sortie : grandeur. Erreurs : refus.
    // Dépendances : facteur, combiner, pareilles.
    function groupe() {
        let compte = genre() === "nombre" || est("(", "-", "+")
        let derniere = genre() === "unite" ? elements[i].grandeur : null
        let g = facteur()
        while (["unite", "constante", "fonction"].includes(genre()) || est("(") || (genre() === "nombre" && !compte)) {
            compte = compte || genre() === "nombre" || est("(")
            const unite = genre() === "unite" ? elements[i].grandeur : null
            if (unite && derniere && pareilles(unite, derniere)) refus()
            derniere = unite
            g = valeur(combiner(g.dim, facteur().dim, 1))
        }
        return g
    }

    // facteur — un atome signé, avec ses puissances, factorielles et pourcents ; un pourcent suivi d'un nombre serait
    // un modulo pour qalc. Entrées : aucune. Sortie : grandeur. Erreurs : refus. Dépendances : atome, combiner.
    function facteur() {
        if (est("+", "-")) { i++; return facteur() }
        let g = atome()
        for (;;) {
            if (genre() === "exposant") g = valeur(combiner({}, g.dim, elements[i++].n))
            else if (genre() === "pourcent" || est("!")) {
                const pourcent = genre() === "pourcent"
                i++
                if (!sansGrandeur(g.dim) || (pourcent && (genre() === "nombre" || est("(")))) refus()
                g = valeur({}, pourcent)
            } else if (est("^")) {
                i++
                const entier = genre() === "nombre" && /^\d+$/.test(elements[i].texte)
                    ? Number(elements[i].texte) : null
                const p = facteur()
                if (!sansGrandeur(p.dim) || (entier === null && !sansGrandeur(g.dim))) refus()
                g = valeur(entier === null ? {} : combiner({}, g.dim, entier))
            } else return g
        }
    }

    // atome — nombre, unité, constante, fonction ou parenthèse. Entrées : aucune. Sortie : grandeur. Erreurs : refus.
    // Dépendances : parenthese.
    function atome() {
        const e = elements[i]
        if (est("(")) return parenthese()
        if (!["nombre", "constante", "unite", "fonction"].includes(genre())) refus()
        i++
        if (e.genre !== "fonction") return valeur(e.grandeur || {})
        if (!est("(")) refus()
        const { dim } = parenthese()
        if (e.effet === "garde") return valeur(dim)
        if (e.effet === "racine") return valeur(combiner({}, dim, 0.5))
        return sansGrandeur(dim) || pareilles(dim, { A: 1 }) ? valeur({}) : refus()
    }

    // parenthese — le contenu d'une parenthèse. Entrées : aucune. Sortie : grandeur. Erreurs : refus.
    // Dépendances : somme.
    function parenthese() {
        i++
        const g = somme()
        if (est(")")) i++
        else if (i < elements.length) refus()
        return valeur(g.dim)
    }

    const g = somme()
    return i === elements.length ? g : refus()
}

// assembler — réécrit des éléments en syntaxe de qalc. Entrée : elements. Sortie : chaîne. Erreurs : aucune.
// Dépendances : aucune.
function assembler(elements) { return elements.map(e => (e.espace ? " " : "") + e.texte).join("").trim() }

// traduire — met une saisie française en syntaxe de qalc, si elle est comprise de bout en bout.
// Entrée : saisie, chaîne. Sortie : « » si un mot est inconnu, si l'expression est inachevée, ou si la conversion ou
// une somme mêle deux grandeurs. Sinon les unités prennent leur nom qalc ; « X % de Y » devient « X% * Y » ; « en »,
// « vers », « to » et « in » deviennent « to » ; la cible d'une conversion est préfixée de « - » pour forcer une seule
// unité, sauf pour une durée ou une base ; un « = » final est ôté ; un degré est un angle, mais un degré Celsius quand
// l'autre côté de la conversion est en Fahrenheit ou en Kelvin.
// Erreurs : aucune. Dépendances : decouper, grouper, analyser, assembler, pareilles, Unites.DUREES.
function traduire(saisie) {
    const elements = decouper((saisie || "").replace(/\s*=\s*$/, ""))
    if (!elements) return ""
    const coupe = elements.findIndex(e => e.genre === "conversion")
    const source = grouper(coupe < 0 ? elements : elements.slice(0, coupe))
    const cible = coupe < 0 ? [] : elements.slice(coupe + 1)
    const chaud = e => ["°F", "K"].includes(e.texte)
    if (cible.length === 1 && (chaud(cible[0]) || (cible[0].texte === "deg" && source.some(chaud))))
        for (const e of source.concat(cible))
            if (e.texte === "deg") Object.assign(e, { texte: "°C", grandeur: { K: 1 } })
    try {
        const dim = analyser(source).dim
        if (coupe < 0) return assembler(source)
        if (cible.length === 1 && cible[0].genre === "base")
            return Object.keys(dim).length ? "" : assembler(source) + " to " + cible[0].texte
        if (cible.some(e => !["unite", "exposant"].includes(e.genre) && !["*", "/", "×", "÷", "^"].includes(e.texte))
            || !cible.some(e => e.genre === "unite") || !pareilles(dim, analyser(cible).dim)) return ""
        const texte = assembler(cible)
        return assembler(source) + " to " + (Unites.DUREES.includes(texte) ? "" : "-") + texte
    } catch (e) {
        return ""
    }
}

// nettoyer — retire d'une ligne de qalc les codes de couleur et les espaces des bords.
// Entrée : ligne. Sortie : la ligne nettoyée. Erreurs : aucune. Dépendances : aucune.
function nettoyer(ligne) { return (ligne || "").replace(/\x1b\[[0-9;]*m/g, "").trim() }

// avertissement — dit si une ligne de qalc est un message et non un résultat.
// Entrée : ligne. Sortie : vrai si elle commence par « error » ou « warning ». Erreurs : aucune.
// Dépendances : nettoyer.
function avertissement(ligne) { return /^(error|warning)/i.test(nettoyer(ligne)) }

// lire — extrait le résultat d'une réponse de qalc.
// Entrées : sortie, la ligne de résultat de qalc ; envoye, l'expression qui lui a été soumise. Sortie : la ligne
// nettoyée, ou « » si elle est vide, est un avertissement ou répète l'expression à l'espace près (« 1 / 0 »).
// Erreurs : aucune. Dépendances : nettoyer, avertissement.
function lire(sortie, envoye) {
    const propre = nettoyer(sortie)
    const sansEspace = t => t.replace(/\s+/g, "")
    if (!propre || avertissement(sortie) || sansEspace(propre) === sansEspace(envoye || "")) return ""
    return propre
}
