.pragma library

// energie.js — logique pure de l'indicateur d'énergie (L2-13) : texte d'estimation, palier d'alerte de la batterie,
// armement des alertes et libellé des profils. Aucun accès à Quickshell : les fonctions reçoivent des valeurs simples,
// pour s'éprouver par tests/test_energie.py.
// Dépendances : aucune.

// duree — met en forme une durée arrondie à la minute la plus proche.
// Entrée : minutes, entier supérieur ou égal à 1. Sortie : « N min » sous une heure, sinon « H h MM » (minutes sur
// deux chiffres). Erreurs : aucune.
function duree(minutes) {
    return minutes < 60 ? minutes + " min" : Math.floor(minutes / 60) + " h " + String(minutes % 60).padStart(2, "0")
}

// texteEstimation — texte d'état de la batterie affiché dans le popover.
// Entrées : etat, « decharge », « charge », « chargee » ou « secteur » ; secondes, estimation d'UPower (0 ou négative si
// elle n'est pas encore connue) ; pourcent, niveau entier de la batterie. Sortie : « 7 h 40 restantes », « Plein dans
// 1 h 10 », « Pleine charge » (état « chargee », ou « charge » à 100 %, ou « charge » avec une estimation positive de
// moins d'une minute : UPower garde « charging » à 100 %), « Sur secteur », ou « Estimation en cours… » quand la durée
// arrondie vaut moins d'une minute (jamais « 0 min »). Erreurs : aucune ; un état inconnu rend la chaîne vide.
// Dépendances : duree.
function texteEstimation(etat, secondes, pourcent) {
    if (etat === "chargee" || (etat === "charge" && (pourcent >= 100 || (secondes > 0 && secondes < 60)))) return "Pleine charge"
    if (etat === "secteur") return "Sur secteur"
    if (etat !== "decharge" && etat !== "charge") return ""
    const minutes = Math.round(secondes / 60)
    if (!(minutes >= 1)) return "Estimation en cours…"
    return etat === "charge" ? "Plein dans " + duree(minutes) : duree(minutes) + " restantes"
}

// palier — palier d'alerte correspondant au niveau de la batterie.
// Entrées : pret, vrai quand l'appareil UPower est prêt ; surBatterie, vrai en décharge ; pourcent, niveau entier ;
// faible, critique, seuils lus dans energie.toml. Sortie : 0 aucun, 1 faible, 2 critique. Aucun palier tant que
// l'appareil n'est pas prêt (pourcentage provisoire à 0) ni hors batterie. Erreurs : aucune.
function palier(pret, surBatterie, pourcent, faible, critique) {
    if (!pret || !surBatterie) return 0
    return pourcent <= critique ? 2 : pourcent <= faible ? 1 : 0
}

// avancer — fait progresser l'armement des alertes.
// Entrées : arme, plus haut palier déjà annoncé depuis le dernier branchement ; palierCourant, palier actuel ;
// surBatterie, vrai en décharge. Sortie : { arme, annonce } ; annonce vaut le palier à montrer, ou 0. Hors batterie,
// tout est réarmé (arme 0, aucune annonce). Erreurs : aucune.
function avancer(arme, palierCourant, surBatterie) {
    if (!surBatterie) return { arme: 0, annonce: 0 }
    return palierCourant > arme ? { arme: palierCourant, annonce: palierCourant } : { arme, annonce: 0 }
}

// nomProfil — libellé du segment d'un profil d'énergie.
// Entrée : profil, entier de l'énumération PowerProfile de Quickshell (0 PowerSaver, 1 Balanced, 2 Performance).
// Sortie : « Économie », « Équilibré » ou « Performance » ; chaîne vide pour une valeur inconnue. Erreurs : aucune.
function nomProfil(profil) {
    return ["Économie", "Équilibré", "Performance"][profil] || ""
}
