.pragma library

// verrou.js — logique pure du verrouillage (L2-22) : date et heure affichées, ordre des messages du lanceur,
// machine du champ de mot de passe, issue de la vérification PAM et ligne du média. Aucun accès à Quickshell ni à la
// session : le contrôleur du verrou s'en sert, et tests/test_verrou.py (LogiqueTest) l'éprouve par la coque d'essai
// essai/logique.

// Jours et mois de la date longue, en minuscules.
const JOURS = ["dimanche", "lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi"]
const MOIS = ["janvier", "février", "mars", "avril", "mai", "juin", "juillet", "août", "septembre", "octobre",
    "novembre", "décembre"]

// dateLongue — date affichée sous l'horloge, par exemple « mercredi 25 novembre ».
// Entrée : d, une Date (ou ce que le constructeur Date accepte). Sortie : la chaîne, jour et mois en minuscules.
// Erreurs : aucune ; une date invalide donne « undefined NaN undefined ». Dépendances : aucune.
function dateLongue(d) {
    d = new Date(d)
    return JOURS[d.getDay()] + " " + d.getDate() + " " + MOIS[d.getMonth()]
}

// heures — les heures sur deux chiffres. Entrée : d, une Date. Sortie : « 07 ». Erreurs : aucune. Dépendances : aucune.
function heures(d) { return String(new Date(d).getHours()).padStart(2, "0") }

// minutes — les minutes sur deux chiffres. Entrée : d, une Date. Sortie : « 05 ». Erreurs : aucune.
// Dépendances : aucune.
function minutes(d) { return String(new Date(d).getMinutes()).padStart(2, "0") }

// ordreValable — vrai si un message n'est pas plus ancien que le courant.
// Entrées : recu, numéro du message reçu ; courant, numéro du dernier accepté. Sortie : recu >= courant.
// Erreurs : aucune. Dépendances : aucune.
function ordreValable(recu, courant) { return recu >= courant }


// Textes des échecs de la vérification, tels que le verrou les affiche.
const ECHEC = "Mot de passe incorrect", IMPOSSIBLE = "Vérification impossible"

// frappe — transition du champ de mot de passe à la réception d'une touche.
// Entrées : etat, {texte, ouvert, verifie, message} ; touche, {nature : "imprimable" | "retour" | "echap" | "entree" |
// "repos", texte : le caractère de la touche imprimable}. Sortie : {etat, action}, action valant null, "rearmer"
// (une touche imprimable : le délai de repos repart) ou "verifier" (Entrée sur un texte non vide). Pendant la
// vérification, toute touche est ignorée : l'état revient tel quel. Le texte est compté en caractères entiers
// (Array.from), pour que Retour arrière retire un « é » ou un « € » d'un seul coup.
// Erreurs : aucune ; une nature inconnue laisse l'état inchangé. Dépendances : aucune.
function frappe(etat, touche) {
    const avec = champs => Object.assign({}, etat, champs)
    if (etat.verifie) return { etat, action: null }
    const vide = avec({ texte: "", ouvert: false })
    switch (touche.nature) {
    case "imprimable":
        return { etat: avec({ texte: etat.texte + touche.texte, ouvert: true, message: "" }), action: "rearmer" }
    case "retour": {
        const texte = Array.from(etat.texte).slice(0, -1).join("")
        return { etat: avec({ texte, ouvert: texte !== "" }), action: null }
    }
    case "echap": case "repos":
        return { etat: vide, action: null }
    case "entree":
        return etat.texte === "" ? { etat, action: null } : { etat: avec({ verifie: true }), action: "verifier" }
    }
    return { etat, action: null }
}

// issue — transition du champ quand la vérification PAM se termine.
// Entrées : etat, l'état du champ ; quoi, "succes" | "echec" | "impossible" ; messagePam, le message d'erreur de PAM
// (vide si PAM n'en a pas donné), affiché tel quel à la place du texte « Mot de passe incorrect » en cas d'échec.
// Sortie : {etat, action} ; le champ est vidé et fermé, la vérification terminée ; action valant "deverrouiller"
// (succès), "secouer" (échec) ou null (impossible).
// Erreurs : aucune ; un « quoi » inconnu est traité comme « impossible ». Dépendances : aucune.
function issue(etat, quoi, messagePam) {
    const fin = message => Object.assign({}, etat, { texte: "", ouvert: false, verifie: false, message })
    if (quoi === "succes") return { etat: fin(""), action: "deverrouiller" }
    if (quoi === "echec") return { etat: fin(messagePam || ECHEC), action: "secouer" }
    return { etat: fin(IMPOSSIBLE), action: null }
}

// lecteurActif — le lecteur de médias à afficher.
// Entrée : lecteurs, tableau d'objets portant isPlaying (les lecteurs MPRIS). Sortie : le premier dont isPlaying est
// vrai, ou null s'il n'y en a pas. Erreurs : aucune. Dépendances : aucune.
function lecteurActif(lecteurs) { return Array.from(lecteurs).find(l => l.isPlaying) || null }

// ligneMedia — les deux lignes du média en cours.
// Entrées : titre ; artiste, éventuellement vide. Sortie : {titre, artiste}, l'artiste précédé d'un point médian
// (« · Hans Zimmer »), ou vide s'il n'y en a pas. Erreurs : aucune. Dépendances : aucune.
function ligneMedia(titre, artiste) { return { titre, artiste: artiste ? "· " + artiste : "" } }
