.pragma library

// garde.js — règles de garde des notifications, fonctions pures de la pile et du panneau (L2-67).
// Rôle : dit si une notification doit attendre dans le panneau une fois sa carte effacée (gardée), si elle peut
// s'afficher en carte (affichable), à quelle application elle appartient (identifiant), et range les notifications en
// attente en groupes par application. Une règle future s'ajoute ici, sans toucher la pile.
// Entrées, sorties, erreurs : voir chaque fonction. Dépendances : aucune.
// Urgences, comme NotificationUrgency : 0 basse, 1 normale, 2 critique.

// identifiant — identifiant de l'application d'une notification.
// Entrée : n, objet à l'interface de Notification (desktopEntry, appName). Sortie : desktopEntry s'il est fourni,
// appName sinon, « » si ni l'un ni l'autre ne l'est. Erreurs : aucune. Dépendances : aucune.
function identifiant(n) {
    return n.desktopEntry || n.appName || ""
}

// gardee — vrai si la notification doit attendre dans le panneau tant qu'elle n'est ni effacée ni cliquée.
// Entrées : n, notification (transient, urgency, desktopEntry, appName) ; retirees, identifiants des applications
// retirées par Nicolas. Sortie : faux si elle est éphémère, d'urgence basse, ou d'une application retirée ; vrai
// sinon. Erreurs : aucune. Dépendances : identifiant.
function gardee(n, retirees) {
    return !n.transient && n.urgency !== 0 && !retirees.includes(identifiant(n))
}

// affichable — vrai si la notification peut s'afficher en carte.
// Entrées : n, notification (urgency) ; nePasDeranger, état « ne pas déranger ». Sortie : vrai hors « ne pas
// déranger », et sous lui pour les seules critiques. Erreurs : aucune. Dépendances : aucune.
function affichable(n, nePasDeranger) {
    return !nePasDeranger || n.urgency === 2
}

// grouper — range les notifications en attente en groupes par application.
// Entrée : attendues, tableau d'objets portant notification et arrivee (date ou nombre), dans un ordre quelconque.
// Sortie : tableau de { identifiant ; nom, l'appName de l'entrée la plus récente ou « Application inconnue » ;
// critique, vrai si une entrée est critique ; entrees, de la plus récente à la plus ancienne }, les groupes contenant
// une critique d'abord, puis par arrivée la plus récente. Erreurs : aucune. Dépendances : identifiant.
function grouper(attendues) {
    const groupes = new Map()
    for (const a of attendues.slice().sort((x, y) => y.arrivee - x.arrivee)) {
        const id = identifiant(a.notification)
        if (!groupes.has(id))
            groupes.set(id, {identifiant: id, nom: a.notification.appName || "Application inconnue", critique: false,
                             entrees: []})
        const g = groupes.get(id)
        g.entrees.push(a)
        g.critique = g.critique || a.notification.urgency === 2
    }
    return [...groupes.values()].sort((x, y) => y.critique - x.critique || y.entrees[0].arrivee - x.entrees[0].arrivee)
}
