.pragma library

// calcul.js — logique pure du calcul du lanceur (L2-16), sans dépendance à Quickshell.
// Rôle : décide si une saisie part à qalc, la traduit du français vers la syntaxe de qalc et lit sa réponse.
// Entrées, sorties, erreurs : voir chaque fonction. Dépendances : aucune.

// Mots français qui introduisent une conversion ; qalc les comprend sous la forme « to ».
const MOTS_CONVERSION = ["en", "vers"]

// Unités de durée : une conversion vers l'une d'elles garde la forme composée de qalc, sans unité unique forcée.
const DUREES = ["h", "min", "s", "j", "jour", "jours", "heure", "heures", "seconde", "secondes"]

// aEnvoyer — dit si une saisie mérite d'être soumise à qalc.
// Entrée : saisie, chaîne. Sortie : vrai si elle contient un chiffre et commence (espaces écartés) par un chiffre,
// une parenthèse, un signe, un séparateur décimal ou une monnaie (€ $ £). Sans chiffre, qalc invente des résultats
// (« kitty » donne « 0 t² ») ; un nom d'application (« python3 », « 7zip ») ou une commande de qalc (« exit 1 »,
// qui le tuerait) ne part jamais ;
// un mot unique à lettres, sans espace ni opérateur (« 7zip »), est un nom, pas un calcul.
// Erreurs : aucune. Dépendances : aucune.
function aEnvoyer(saisie) {
    const s = (saisie || "").trim()
    return /\d/.test(s) && /^[\d(\-+.,€$£]/.test(s) && !/^[^\s+\-*\/^%()×÷]*[a-z][^\s+\-*\/^%()×÷]*$/i.test(s)
}

// traduire — met une saisie française en syntaxe de qalc.
// Entrée : saisie, chaîne. Sortie : « X % de Y » devient « X% * Y » ; « en » et « vers » (mots entiers) deviennent
// « to » ; la cible d'une conversion est préfixée de « - » pour forcer une seule unité, sauf pour une durée.
// Erreurs : aucune. Dépendances : MOTS_CONVERSION, DUREES.
function traduire(saisie) {
    const pourcent = (saisie || "").trim().replace(/(\d+(?:[.,]\d+)?)\s*%\s*de\s+/i, "$1% * ")
    const mots = MOTS_CONVERSION.join("|")
    const m = pourcent.match(new RegExp("^(.*?)\\s+(?:" + mots + ")\\s+(.+)$", "i"))
    if (!m) return pourcent
    const cible = m[2].trim()
    return m[1] + " to " + (DUREES.includes(cible.toLowerCase()) ? "" : "-") + cible
}

// lire — extrait le résultat d'une réponse de qalc.
// Entrées : sortie, la ligne de résultat de qalc ; envoye, l'expression qui lui a été soumise. Sortie : la ligne
// nettoyée des codes de couleur, ou « » si elle est vide, commence par « error » ou « warning », ou répète
// l'expression à l'espace près (« 1 / 0 »). Erreurs : aucune. Dépendances : aucune.
function lire(sortie, envoye) {
    const propre = (sortie || "").replace(/\x1b\[[0-9;]*m/g, "").trim()
    const sansEspace = t => t.replace(/\s+/g, "")
    if (!propre || /^(error|warning)/i.test(propre) || sansEspace(propre) === sansEspace(envoye || "")) return ""
    return propre
}
