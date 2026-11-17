.pragma library
.import "garde.js" as Garde

// son.js — règle de la voix des notifications, fonctions pures de la pile et de la lecture (L2-68).
// Rôle : dit quelle voix une notification fait entendre (voix), et compose la commande de lecture (commande). Une
// notification ne sonne que si le panneau la garderait ; l'ordre des règles est celui de la fiche de conception,
// « Quand une notification sonne ». Une voix future s'ajoute ici, sans toucher la pile.
// Entrées, sorties, erreurs : voir chaque fonction. Dépendances : garde.js.

// voix — voix que fait entendre une notification, nouvelle ou mise à jour.
// Entrées : n, notification (urgency, hints, et ce que lit Garde.gardee) ; c, contexte : active, nePasDeranger,
// pleinEcran (booléens), retirees (identifiants), maintenant et dernierSon (ms ; dernierSon vaut -Infinity avant tout
// son), precedente (null pour une nouvelle notification, {age, urgence} de la version remplacée sinon), salve et
// renouvellement (ms). Sortie : « » si elle reste muette, « urgence » si elle est critique, « arrivee » sinon.
// Erreurs : aucune. Dépendances : Garde.gardee.
function voix(n, c) {
    const critique = n.urgency === 2
    if (!c.active || n.hints?.["suppress-sound"] || !Garde.gardee(n, c.retirees))
        return ""
    if (c.precedente && c.precedente.age < c.renouvellement && !(critique && c.precedente.urgence !== 2))
        return ""
    if (!critique && (c.nePasDeranger || c.pleinEcran || c.maintenant - c.dernierSon < c.salve))
        return ""
    return critique ? "urgence" : "arrivee"
}

// commande — arguments de pw-play pour faire entendre un fichier.
// Entrées : fichier, chemin du son ; volume, de 0 à 100. Sortie : tableau d'arguments, « pw-play » en tête (la
// lecture peut le remplacer). Le rôle Notification suit le volume du système ; state.restore-props = false empêche
// WirePlumber d'enregistrer ce volume pour tout le rôle, ce qui l'imposerait aux notifications des autres
// applications (épreuve du 17 novembre 2026, D186). Erreurs : aucune. Dépendances : aucune.
function commande(fichier, volume) {
    return ["pw-play", "--media-role", "Notification", "-P",
            '{ application.name = "DuneI" state.restore-props = false }', "--volume", String(volume / 100), fichier]
}
