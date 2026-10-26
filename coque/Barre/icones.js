.pragma library

// icones.js — correspondances pures entre l'état d'un service et le nom d'icône de la barre.
// Rôle : traduit un état (batterie, Wi-Fi, Bluetooth, notifications, moment du jour) en nom d'icône Adwaita
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
// dizaine) suivi de "-charging" en charge ; Adwaita n'a pas de niveau 100 en charge : en charge à la dizaine 100,
// le nom est "battery-level-100-charged", et hors charge "battery-level-100". Erreurs : aucune.
function iconeBatterie(presente, pourcent, enCharge, pleine) {
    if (!presente) return ""
    const dizaine = Math.round(pourcent / 10) * 10
    if (pleine || (enCharge && dizaine === 100)) return "battery-level-100-charged"
    return "battery-level-" + dizaine + (enCharge ? "-charging" : "")
}

// iconeWifi — icône du Wi-Fi.
// Entrées : carte, une carte Wi-Fi existe ; actif, la radio est allumée ; connecte, un réseau est joint ;
// force, qualité du signal de 0 à 1. Sortie : "" sans carte, "network-wireless-disabled" coupé,
// "network-wireless-offline" déconnecté, sinon "network-wireless-signal-" + none, weak, ok, good ou
// excellent (seuils 0,2 ; 0,4 ; 0,6 ; 0,8). Erreurs : aucune ; une force non numérique donne « none ».
function iconeWifi(carte, actif, connecte, force) {
    if (!carte) return ""
    if (!actif) return "network-wireless-disabled"
    if (!connecte) return "network-wireless-offline"
    const palier = ["none", "weak", "ok", "good", "excellent"]
    return "network-wireless-signal-" + palier[Math.max(0, Math.min(4, (Math.floor(force * 5) || 0)))]
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
