import QtQuick

// RessortVue — animation de ressort pour une transition de vue (add, remove, move, displaced d'une ListView).
// Rôle : une transition de vue anime les propriétés de ses délégués par des animations de Qt, que Ressort (un
// élément, hors de toute transition) ne peut pas porter. RessortVue est une SpringAnimation réglée par le ressort
// d'une transition de motion.json : même raideur, même amortissement, même masse. Qt intègre ce ressort par pas
// fixes de 16 ms sans rapporter la raideur ni l'amortissement au pas ; ils sont donc multipliés ici par ce pas, pour
// que le mouvement ait la durée du ressort décrit par le jeton. L'intégration de Qt étant plus grossière que celle de
// physics.js, seuls les ressorts peu raides lui conviennent (reflow, reveal) : au-delà d'un amortissement de 62,5,
// son pas rendrait le mouvement instable.
// Entrées : transition, nom d'une transition de motion.json (« reflow » par défaut) ; sens, « in » (défaut) ou
// « out », le réglage lu ; properties, from et to, comme toute animation de nombre.
// Sorties : celles de SpringAnimation.
// Erreurs : aucune ; avant le chargement du mouvement ou pour une transition inconnue, raideur nulle : l'animation
// ne déplace rien, et la vue pose ses délégués d'elle-même.
// Mouvement réduit : RessortVue ne le lit pas ; la transition qui la porte se désactive (déplacement) ou cède la
// place à un fondu court (rules.reduced_fade_ms).
// Dépendances : Theme (motion.transitions).
SpringAnimation {
    property string transition: "reflow"
    property string sens: "in"
    readonly property var reglage: Theme.motion?.transitions?.[transition]?.[sens] ?? null
    // Pas d'intégration de SpringAnimation, en secondes : une constante de Qt, pas une valeur de dessin.
    readonly property real pas: 0.016

    spring: (reglage?.stiffness ?? 0) * pas
    damping: (reglage?.dampening ?? 0) * pas
    mass: reglage?.mass ?? 1
}
