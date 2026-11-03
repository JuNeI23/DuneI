.pragma library

// bluetooth.js — logique pure du popover Bluetooth (L2-14) : filtre des appareils anonymes, tri des listes, icône
// d'un type d'appareil, nom affiché, transport de l'appairage et résumé de l'en-tête. Aucun accès à Quickshell : les fonctions reçoivent des valeurs simples,
// pour s'éprouver par tests/test_bluetooth.py.
// Dépendances : aucune.

// Correspondance des icônes de BlueZ (propriété Icon d'un appareil) vers les noms du thème d'icônes DuneI.
const ICONES = {
    "audio-headset": "audio-headphones", "audio-headphones": "audio-headphones", "audio-card": "audio-speakers",
    "input-mouse": "input-mouse", "input-keyboard": "input-keyboard", "input-gaming": "input-gaming",
    "phone": "phone", "computer": "computer",
}

// nomAffiche — nom d'appareil sans le préfixe « LE- », « LE_ » ou « LE » que certains appareils doubles (classique et
// basse consommation) ajoutent à leur nom LE. Entrée : nom. Sortie : le nom nettoyé. Erreurs : aucune.
// Dépendances : aucune.
function nomAffiche(nom) {
    return String(nom ?? "").replace(/^LE[-_ ]/, "")
}

// transport — filtre de transport de l'appairage : « bredr » (Bluetooth classique) pour un appareil audio, dont la
// connexion audio exige une clé classique, « auto » sinon (une souris LE doit rester joignable).
// Entrée : icone, la valeur Icon de BlueZ. Sortie : « bredr » ou « auto ». Erreurs : aucune. Dépendances : aucune.
function transport(icone) {
    return String(icone ?? "").startsWith("audio-") ? "bredr" : "auto"
}

// anonyme — dit si un appareil n'a pas de vrai nom : BlueZ lui donne alors son adresse, en tirets.
// Entrées : nom, le nom affiché ; adresse, l'adresse MAC. Sortie : vrai si le nom est vide ou n'est que l'adresse,
// tirets et deux-points confondus, sans tenir compte de la casse. Erreurs : aucune. Dépendances : aucune.
function anonyme(nom, adresse) {
    const norme = t => String(t ?? "").replace(/-/g, ":").toUpperCase()
    return !nom || norme(nom) === norme(adresse)
}

// trierAppareils — range les appareils dans les deux listes du popover.
// Entrées : appareils, tableau de {nom, adresse, appaire, connecte}.
// Sortie : {mes, proches}, deux tableaux d'adresses. mes : les appareils appairés, connectés d'abord, puis par nom ;
// proches : les appareils non appairés et nommés, par nom (affiché). Erreurs : aucune. Dépendances : anonyme,
// nomAffiche.
function trierAppareils(appareils) {
    const parNom = (a, b) => nomAffiche(a.nom).localeCompare(nomAffiche(b.nom), "fr")
    const mes = appareils.filter(a => a.appaire).sort((a, b) => (b.connecte - a.connecte) || parNom(a, b))
    const proches = appareils.filter(a => !a.appaire && !anonyme(a.nom, a.adresse)).sort(parNom)
    return { mes: mes.map(a => a.adresse), proches: proches.map(a => a.adresse) }
}

// iconeAppareil — nom d'icône d'un type d'appareil.
// Entrées : icone, la valeur Icon de BlueZ. Sortie : le nom du thème DuneI ; « bluetooth-active » pour tout type
// inconnu. Erreurs : aucune. Dépendances : ICONES.
function iconeAppareil(icone) {
    return ICONES[icone] ?? "bluetooth-active"
}

// resume — ligne d'état de l'en-tête du popover.
// Entrées : allume, l'état de l'adaptateur ; connecte, {nom, batterie} du premier appareil connecté, ou null ;
// batterie est une fraction de 0 à 1, ou null quand l'appareil ne la donne pas.
// Sortie : « Désactivé », « Aucun appareil connecté », le nom affiché, ou le nom suivi de « · <n> % ».
// Erreurs : aucune. Dépendances : nomAffiche.
function resume(allume, connecte) {
    if (!allume) return "Désactivé"
    if (!connecte) return "Aucun appareil connecté"
    const nom = nomAffiche(connecte.nom)
    return connecte.batterie === null || connecte.batterie === undefined ? nom
        : nom + " · " + Math.round(connecte.batterie * 100) + " %"
}
