.pragma library

// deconnexion.js — logique pure du menu de déconnexion (L2-23) : validation des actions déclarées, curseur en boucle,
// lettre d'accès et double appui des actions à confirmer. Aucun accès à Quickshell ni à la session : le contrôleur
// Deconnexion.qml s'en sert, et tests/test_deconnexion.py (LogiqueTest) l'éprouve par la coque d'essai
// essai/logique.

// valider — garde les actions bien formées de actions.json, dans leur ordre.
// Entrée : actions, tableau d'objets {id, libelle, lettre, icone, commande, confirmer}.
// Sortie : le tableau des entrées complètes (id, libelle, icone chaînes non vides ; lettre d'un seul caractère ;
// commande tableau non vide de chaînes ; confirmer booléen) dont la lettre n'a pas déjà été prise par une entrée
// précédente, sans égard à la casse.
// Erreurs : chaque entrée écartée est journalisée par console.warn, avec la raison ; une entrée non tableau rend [].
// Dépendances : aucune.
function valider(actions) {
    if (!Array.isArray(actions)) { console.warn("Déconnexion : actions illisibles, tableau attendu"); return [] }
    const prises = new Set()
    return actions.filter(a => {
        const texte = v => typeof v === "string" && v.length > 0
        const complete = a !== null && typeof a === "object" && texte(a.id) && texte(a.libelle) && texte(a.icone)
            && typeof a.lettre === "string" && a.lettre.length === 1 && typeof a.confirmer === "boolean"
            && Array.isArray(a.commande) && a.commande.length > 0 && a.commande.every(texte)
        if (!complete) { console.warn("Déconnexion : action incomplète écartée : " + JSON.stringify(a)); return false }
        const lettre = a.lettre.toLowerCase()
        if (prises.has(lettre)) { console.warn("Déconnexion : lettre « " + a.lettre + " » en double, action « " + a.id + " » écartée"); return false }
        prises.add(lettre)
        return true
    })
}

// suivant — rang du curseur après un pas, en boucle.
// Entrées : index, rang courant ; pas, +1 pour avancer, -1 pour reculer ; n, nombre de boutons (> 0).
// Sortie : le nouveau rang, dans [0, n). Erreurs : aucune ; n nul rend NaN, que le contrôleur n'atteint pas (il ne
// s'ouvre qu'avec des actions). Dépendances : aucune.
function suivant(index, pas, n) { return ((index + pas) % n + n) % n }

// indexLettre — rang de l'action dont la lettre d'accès est donnée, sans égard à la casse.
// Entrées : actions, tableau validé ; lettre, un caractère. Sortie : le rang, ou -1 si aucune action ne la porte.
// Erreurs : aucune. Dépendances : aucune.
function indexLettre(actions, lettre) {
    return actions.findIndex(a => a.lettre.toLowerCase() === String(lettre).toLowerCase())
}

// appui — effet d'un appui sur un bouton (lettre, Entrée, Espace ou clic, indifféremment).
// Entrées : actions, tableau validé ; arme, rang du bouton armé, -1 si aucun ; index, rang du bouton appuyé.
// Sortie : {arme, executer}. Sans confirmation : {arme: -1, executer: true}. Avec confirmation : exécute si le bouton
// était déjà armé ({arme: index, executer: true}), sinon l'arme ({arme: index, executer: false}).
// Erreurs : aucune ; un rang hors des actions ne change rien ({arme, executer: false}). Dépendances : aucune.
function appui(actions, arme, index) {
    const a = actions[index]
    if (!a) return { arme: arme, executer: false }
    if (!a.confirmer) return { arme: -1, executer: true }
    return { arme: index, executer: arme === index }
}
