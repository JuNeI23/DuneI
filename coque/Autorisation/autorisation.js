.pragma library

// autorisation.js — logique pure de l'agent d'authentification (L2-24) : réglages et relevé de faillock, état de la
// fenêtre, ligne d'état et rafale d'échecs. Aucun accès à Quickshell, à polkit ni à PAM : le contrôleur Autorisation.qml
// s'en sert, et tests/test_autorisation.py (LogiqueTest) l'éprouve par la coque d'essai essai/logique.

const DEFAUTS = { deny: 3, fail_interval: 900, unlock_time: 600 }
const NOMBRES = ["Zéro", "Un", "Deux", "Trois", "Quatre", "Cinq", "Six", "Sept", "Huit", "Neuf"]

// lireConf — réglages de faillock.conf qui comptent pour la coque.
// Entrée : texte, contenu du fichier (vide s'il manque). Sortie : {deny, fail_interval, unlock_time}, entiers ; un
// réglage absent, commenté ou invalide garde le défaut de pam_faillock. Erreurs : aucune. Dépendances : DEFAUTS.
function lireConf(texte) {
    const conf = Object.assign({}, DEFAUTS)
    for (const l of String(texte).split("\n")) {
        const m = l.match(/^\s*(deny|fail_interval|unlock_time)\s*=\s*(\d+)\s*(#.*)?$/)
        if (m) conf[m[1]] = Number(m[2])
    }
    return conf
}

// verrou — verrou du compte et essais restants, d'après la sortie de faillock --user, jamais d'après le texte de PAM.
// Entrées : faillock, texte de la commande ; conf, rendu par lireConf ; maintenant, secondes Unix.
// Sortie : {restants, jusqua} : restants, échecs encore permis, null si le relevé est illisible ; jusqua, fin du verrou
// en secondes Unix, null si le compte est libre. Seules comptent les lignes valides (V). Comme pam_faillock, le verrou
// tient aux échecs groupés à moins de fail_interval du plus récent, et les essais restants à ceux qui seront encore
// dans l'intervalle au prochain échec. Erreurs : aucune. Dépendances : aucune.
function verrou(faillock, conf, maintenant) {
    if (!/^When\s+Type/m.test(faillock)) return { restants: null, jusqua: null }
    const instants = []
    const motif = /^(\d{4})-(\d\d)-(\d\d) (\d\d):(\d\d):(\d\d)\s.*\sV\s*$/
    for (const l of faillock.split("\n")) {
        const m = l.match(motif)
        if (m) instants.push(new Date(+m[1], m[2] - 1, +m[3], +m[4], +m[5], +m[6]).getTime() / 1000)
    }
    const dernier = Math.max(0, ...instants)
    const proches = t0 => instants.filter(t => t0 - t < conf.fail_interval).length
    if (proches(dernier) >= conf.deny) {
        const fin = dernier + conf.unlock_time
        return maintenant < fin ? { restants: 0, jusqua: fin } : { restants: conf.deny, jusqua: null }
    }
    return { restants: conf.deny - proches(maintenant), jusqua: null }
}

// etat — état de la fenêtre, par ordre de priorité.
// Entrée : objet {termine, verrouille, enVol, requis} de booléens : demande close, compte verrouillé, réponse envoyée
// sans retour de PAM, réponse attendue par PAM. Sortie : « succes », « verrouille », « verification », « saisie » ou
// « attente ». Erreurs : aucune. Dépendances : aucune.
function etat(o) {
    return o.termine ? "succes" : o.verrouille ? "verrouille" : o.enVol ? "verification" : o.requis ? "saisie" : "attente"
}

// heure — heure locale d'un instant, arrondie à la minute suivante pour ne jamais annoncer un verrou encore tenu.
// Entrée : secondes Unix. Sortie : « 16 h 38 ». Erreurs : aucune. Dépendances : aucune.
function heure(secondes) {
    const d = new Date(Math.ceil(secondes / 60) * 60000)
    return d.getHours() + " h " + String(d.getMinutes()).padStart(2, "0")
}

// ligne — texte de la ligne d'état et sa gravité.
// Entrées : etat, rendu par etat() ; o, {echec, restants, jusqua, supplement}, tous facultatifs : dernier essai refusé,
// rendus de verrou(), message de PAM. Sortie : {texte, erreur}. Le message de PAM ne paraît, tel quel, qu'hors échec.
// Erreurs : aucune. Dépendances : heure, NOMBRES.
function ligne(etat, o) {
    if (etat === "verrouille") return { texte: "Compte verrouillé. Réessayer à " + heure(o.jusqua) + ".", erreur: true }
    if (etat === "verification") return { texte: "Vérification", erreur: false }
    if (etat !== "saisie") return { texte: "", erreur: false }
    if (!o.echec) return { texte: o.supplement || "", erreur: false }
    const n = o.restants
    const suite = n > 0 ? " " + (NOMBRES[n] || n) + (n > 1 ? " essais restants." : " essai restant.") : ""
    return { texte: "Mot de passe incorrect." + suite, erreur: true }
}

// rafale — détecte les échecs en chaîne que Quickshell provoque en rouvrant une session PAM sans plafond.
// Entrées : instants, dates en millisecondes des échecs précédents ; maintenant, celle du dernier. Sortie : vrai si
// trois échecs tombent en moins d'une seconde. Erreurs : aucune. Dépendances : aucune.
function rafale(instants, maintenant) {
    return instants.filter(t => maintenant - t < 1000).length >= 2
}
