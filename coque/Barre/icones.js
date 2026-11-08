.pragma library

// icones.js — correspondances pures entre l'état d'un service et le nom d'icône de la barre.
// Rôle : traduit un état (batterie, Wi-Fi, Bluetooth, notifications, moment du jour) en nom d'icône freedesktop
// sans suffixe « -symbolic ». Un nom vide signifie que la chose manque physiquement : l'élément de barre
// qui le reçoit disparaît (visible: false) sans laisser de trou dans la rangée.
// Dépendances : aucune (bibliothèque sans état, importable depuis tout QML ou depuis la coque d'essai).

// normaliserPourcent — ramène le pourcentage de UPower à un entier de 0 à 100.
// Rôle : UPower exprime `percentage` tantôt sur 0–1, tantôt sur 0–100 selon la version ; les deux échelles
// doivent donner « 78 % » et jamais « 1 % » ni « 7800 % ».
// Entrée : p, réel. Sortie : entier borné à 0–100 (p ≤ 1 est lu comme une fraction).
// Erreurs : aucune ; une valeur non numérique donne 0.
function normaliserPourcent(p) {
    const v = Math.round(p <= 1 ? p * 100 : p)
    return isNaN(v) ? 0 : Math.max(0, Math.min(100, v))
}

// iconeBatterie — icône de batterie.
// Entrées : presente, une batterie existe ; pourcent, entier 0–100 ; enCharge ; pleine.
// Sortie : "" sans batterie, "battery-level-100-charged" si pleine, sinon "battery-level-N" (N arrondi à la
// dizaine) suivi de "-charging" en charge ; le thème n'a pas de niveau 100 en charge : en charge à la dizaine 100,
// le nom est "battery-level-100-charged", et hors charge "battery-level-100". Erreurs : aucune.
function iconeBatterie(presente, pourcent, enCharge, pleine) {
    if (!presente) return ""
    const dizaine = Math.round(pourcent / 10) * 10
    if (pleine || (enCharge && dizaine === 100)) return "battery-level-100-charged"
    return "battery-level-" + dizaine + (enCharge ? "-charging" : "")
}

// iconeReseau — icône du réseau (Wi-Fi et filaire).
// Entrée : e, objet {carte, radio, filaire, connecte, connectivite, facture, force} : une carte Wi-Fi existe ;
// sa radio est allumée ; un lien filaire est connecté ; le Wi-Fi est joint ; connectivité NetworkManager (« full »,
// « limited », « portal », « none » ou « unknown ») ; la connexion est facturée à l'usage ; qualité du signal de
// 0 à 1 ; filaire signifie « lien filaire connecté ». Sortie, par ordre de priorité : "" sans carte ni filaire ;
// « network-wired » dès que filaire est vrai (l'état de la carte Wi-Fi, présente ou non, n'y change rien),
// avec « -no-route » si la connectivité est « limited », « portal » ou « none » ; « network-wireless-disabled » radio coupée ; « network-wireless-offline » non joint ;
// « network-wireless-no-route » sans internet (« limited » ou « none ») ou derrière un portail captif ; « network-wireless-hotspot »
// facturé ; sinon les cinq paliers de signal (seuils 0,2 ; 0,4 ; 0,6 ; 0,8).
// Erreurs : aucune ; une force non numérique donne « none ». Dépendances : aucune.
function iconeReseau(e) {
    if (!e.carte && !e.filaire) return ""
    const sansInternet = ["limited", "portal", "none"].includes(e.connectivite)
    if (e.filaire) return sansInternet ? "network-wired-no-route" : "network-wired"
    if (!e.radio) return "network-wireless-disabled"
    if (!e.connecte) return "network-wireless-offline"
    if (sansInternet) return "network-wireless-no-route"
    if (e.facture) return "network-wireless-hotspot"
    const palier = ["none", "weak", "ok", "good", "excellent"]
    return "network-wireless-signal-" + palier[Math.max(0, Math.min(4, (Math.floor(e.force * 5) || 0)))]
}

// iconeForce — icône de force d'un réseau Wi-Fi joint ou disponible, aux mêmes paliers que la barre.
// Entrée : force, qualité du signal de 0 à 1. Sortie : nom « network-wireless-signal-… ». Erreurs : aucune ; une
// force non numérique donne « none ». Dépendances : iconeReseau.
function iconeForce(force) {
    return iconeReseau({carte: true, radio: true, connecte: true, connectivite: "full", force})
}

// iconeBluetooth — icône du Bluetooth.
// Entrées : adaptateur, un adaptateur existe ; allume, il est allumé. Sortie : "" sans adaptateur,
// "bluetooth-disabled" éteint, "bluetooth-active" allumé, qu'un appareil soit connecté ou non (comme macOS).
// Erreurs : aucune.
function iconeBluetooth(adaptateur, allume) {
    return !adaptateur ? "" : allume ? "bluetooth-active" : "bluetooth-disabled"
}

// iconeNotifications — icône de l'état des notifications.
// Entrée : enPause, ne pas déranger actif. Sortie : "notifications-disabled" ou
// "preferences-system-notifications". Erreurs : aucune.
function iconeNotifications(enPause) {
    return enPause ? "notifications-disabled" : "preferences-system-notifications"
}

// iconeMoment — icône de l'interrupteur jour/nuit.
// Entrée : moment, « jour » ou « nuit ». Sortie : "weather-clear-night" pour la nuit, "weather-clear" sinon.
// Erreurs : aucune.
function iconeMoment(moment) {
    return moment === "nuit" ? "weather-clear-night" : "weather-clear"
}

// texteBatterie — pourcentage affiché à côté de l'icône de batterie.
// Entrée : pourcent, entier 0–100. Sortie : par exemple « 78 % ». Erreurs : aucune.
function texteBatterie(pourcent) {
    return pourcent + " %"
}

// iconeAudio — icône du volume de sortie.
// Entrées : presente, une sortie existe ; muet, elle est coupée ; pourcent, volume de 0 à 100. Sortie : "" sans sortie,
// « audio-volume-muted » si muet ou à 0, puis « -low » jusqu'à 33, « -medium » jusqu'à 66, sinon « -high ».
// Erreurs : aucune.
function iconeAudio(presente, muet, pourcent) {
    if (!presente) return ""
    if (muet || pourcent <= 0) return "audio-volume-muted"
    return pourcent <= 33 ? "audio-volume-low" : pourcent <= 66 ? "audio-volume-medium" : "audio-volume-high"
}

// iconeMicro — icône de l'entrée audio.
// Entrée : muet, le micro est coupé. Sortie : « microphone-sensitivity-muted » ou « microphone-sensitivity-high ».
// Erreurs : aucune.
function iconeMicro(muet) {
    return muet ? "microphone-sensitivity-muted" : "microphone-sensitivity-high"
}
