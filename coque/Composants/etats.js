.pragma library

// etats.js — règles d'états partagées par les composants de la coque.
// Rôle : traduit l'état d'un contrôle et la position d'un élément dans l'arbre en clés des tokens
// (Theme.stateColors : rôle, sélection, interaction). Bibliothèque sans état ni accès aux singletons QML :
// elle ne lit que ses arguments, si bien qu'une seule instance sert toute la coque.
// Dépendances : aucune.

// Rôle de fond un cran au-dessus de chaque rôle ; controlRaised, déjà au sommet, reste sur lui-même.
const CRANS = {
    surfaceWindow: "surfacePanel",
    surfacePanel: "surfaceRaised",
    surfaceRaised: "controlRaised",
    controlRaised: "controlRaised"
}

// Niveau d'élévation peint par chaque rôle de fond (tokens.toml : e0 est le bureau, la fenêtre se tient en e1).
const NIVEAUX = {
    surfaceWindow: "e1",
    surfacePanel: "e2",
    surfaceRaised: "e3"
}

// herite — valeur d'une propriété héritée par remontée des parents, comme dnRole ou dnInactive.
// Rôle : parcourt les ancêtres stricts de item (item.parent, puis ses parents successifs) et rend la propriété
//        nom du premier qui la déclare. Appelée dans une liaison, elle reste réactive : le moteur enregistre la
//        lecture de chaque parent et de la propriété trouvée, si bien qu'un reparentage ou un changement de la
//        valeur réévalue la liaison.
// Entrées : item, élément visuel de départ (exclu de la recherche) ; nom, nom de la propriété ; defaut, valeur
//           rendue si aucun ancêtre ne la déclare.
// Sortie : la valeur trouvée (toute valeur différente de undefined), sinon defaut.
// Erreurs : aucune ; un item nul ou indéfini rend defaut. Dépendances : aucune.
function herite(item, nom, defaut) {
    for (let p = item?.parent; p; p = p.parent)
        if (p[nom] !== undefined) return p[nom]
    return defaut
}

// cran — rôle de fond d'un contrôle posé sur un conteneur.
// Rôle : un contrôle se tient un cran au-dessus de son conteneur (conception, § 7.4) :
//        surfaceWindow → surfacePanel → surfaceRaised → controlRaised.
// Entrées : role, rôle de fond du conteneur. Sortie : le rôle du contrôle, ou undefined pour un rôle inconnu.
// Erreurs : aucune. Dépendances : CRANS.
function cran(role) {
    return CRANS[role]
}

// niveau — niveau d'élévation d'une surface selon son rôle de fond.
// Rôle : fournit l'élévation par défaut d'une Surface, pour que rôle et fond peint ne se contredisent pas :
//        surfaceWindow → e1, surfacePanel → e2, surfaceRaised → e3.
// Entrées : role, rôle de fond de la surface. Sortie : "e1", "e2" ou "e3" ; e1 pour un rôle inconnu.
// Erreurs : aucune. Dépendances : NIVEAUX.
function niveau(role) {
    return NIVEAUX[role] ?? "e1"
}

// interaction — état d'interaction d'un contrôle, clé des tokens.
// Rôle : applique l'ordre des états ; désactivé l'emporte sur la pression, qui l'emporte sur le survol.
// Entrées : c, objet portant enabled, down et hovered (un gabarit de QtQuick.Templates, ou un objet simple).
// Sortie : "disabled", "pressed", "hover" ou "rest".
// Erreurs : aucune ; enabled absent vaut désactivé. Dépendances : aucune.
function interaction(c) {
    return !c.enabled ? "disabled" : c.down ? "pressed" : c.hovered ? "hover" : "rest"
}

// selection — état de sélection d'un élément, clé des tokens.
// Rôle : un élément sélectionné prend l'accent si son groupe a le focus, le fond neutre teinté sinon, et
//        l'accent sans chroma quand son conteneur porte le modificateur inactive (conception, § 7.5).
// Entrées : selectionne, l'élément est sélectionné ; focusDansGroupe, le focus est dans sa liste ou son
//           groupe ; inactif, modificateur inactive hérité du conteneur.
// Sortie : "none", "activeMuted", "active" ou "inactive".
// Erreurs : aucune. Dépendances : aucune.
function selection(selectionne, focusDansGroupe, inactif) {
    return !selectionne ? "none" : inactif ? "activeMuted" : focusDansGroupe ? "active" : "inactive"
}
