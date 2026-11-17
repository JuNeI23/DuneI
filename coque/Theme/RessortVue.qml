import QtQuick

// RessortVue — animation d'une transition de vue (add, remove, move, displaced d'une ListView), au pas d'un ressort.
// Rôle : une transition de vue anime les propriétés de ses délégués par des animations de Qt, que Ressort (un
// élément, hors de toute transition) ne peut pas porter. RessortVue est une NumberAnimation qui approche la réponse
// du ressort d'une transition de motion.json : sa durée est le temps de stabilisation du ressort (settle_ms), et sa
// courbe une sortie cubique, à quelques centièmes de la course d'un ressort critique sur cette durée (0,39 contre
// 0,49 au cinquième du temps, 0,91 contre 0,94 aux trois cinquièmes). Elle ne convient donc qu'aux ressorts sans
// dépassement (reflow, reveal).
// Pourquoi pas SpringAnimation : elle ne survit pas à une transition de vue interrompue. Quand un changement du
// modèle relance la transition d'un délégué encore en mouvement, son animation s'arrête sans atteindre sa cible, et
// la rangée reste où elle était, souvent en tête de liste ou à demi effacée (recette du 16 novembre 2026). Une
// NumberAnimation, elle, repart de la valeur courante vers la nouvelle cible.
// Pourquoi pas la réponse exacte en spline de Bézier : une spline de seize segments ou plus corrompt le tas de Qt 6
// (« malloc(): invalid size », relevé le 16 novembre 2026).
// Entrées : transition, nom d'une transition de motion.json (« reflow » par défaut) ; sens, « in » (défaut) ou
// « out », le réglage lu ; properties, from et to, comme toute animation de nombre.
// Sorties : celles de NumberAnimation.
// Erreurs : aucune ; avant le chargement du mouvement ou pour une transition inconnue, durée nulle : la vue pose ses
// délégués d'elle-même.
// Mouvement réduit : RessortVue ne le lit pas ; la transition qui la porte se désactive (déplacement) ou cède la
// place à un fondu court (rules.reduced_fade_ms).
// Dépendances : Theme (motion.transitions).
NumberAnimation {
    property string transition: "reflow"
    property string sens: "in"
    readonly property var reglage: Theme.motion?.transitions?.[transition]?.[sens] ?? null

    duration: reglage?.settle_ms ?? 0
    easing.type: Easing.OutCubic
}
