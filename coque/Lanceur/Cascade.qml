import QtQuick
import "../Theme"

// Cascade — entrée en cascade d'un élément du lanceur (tuile, puce, ligne, vignette).
// Rôle : un Ressort de la transition reveal, nature « fondu » (le mouvement réduit le change en fondu court), qui part
// de 0 et rejoint 1 après un délai : base, plus le pas de cascade de motion.json (reveal.stagger.ms, 40 ms) par rang,
// le rang étant plafonné à neuf (dix éléments au plus en cascade, maquette v3). L'élément lit value pour son opacité
// et son glissé.
// Entrées : rang, place de l'élément dans sa suite, 0 par défaut ; base, délai commun en millisecondes, 0 par défaut.
// Sorties : value, de 0 à 1 (celle du Ressort) ; rejouer(), qui repart de 0 (nouveau contenu dans le même élément).
// Erreurs : aucune ; sans mouvement chargé, le pas vaut 0.
// Dépendances : Ressort, Theme (motion.transitions.reveal.stagger).
Ressort {
    id: cascade

    property int rang: 0
    property int base: 0

    transition: "reveal"
    nature: "fondu"
    cible: 0

    // rejouer — refait l'entrée depuis 0, après le même délai. Entrées : aucune. Sortie : aucune. Erreurs : aucune.
    // Dépendances : poser (Ressort), minuterie.
    function rejouer() { cible = 0; poser(); minuterie.restart() }

    Timer {
        id: minuterie
        interval: cascade.base + Math.min(cascade.rang, 9) * (Theme.motion?.transitions?.reveal?.stagger?.ms ?? 0)
        running: true
        // onTriggered — lance l'entrée. Entrées : aucune. Sortie : cible à 1. Erreurs : aucune. Dépendances : aucune.
        onTriggered: cascade.cible = 1
    }
}
