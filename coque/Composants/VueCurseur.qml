import QtQuick

// VueCurseur — arbitre du curseur d'une vue : un seul élément le porte à la fois.
// Rôle : une vue (fenêtre ou popover entier) déclare sur sa racine « property VueCurseur dnVue: VueCurseur {} » ;
// chaque Etat qui suit le curseur (suitCurseur) la retrouve par remontée (Etats.herite) et y prend le curseur au
// survol ou au focus clavier, puis l'y lâche. Le dernier mouvement, souris ou clavier, l'emporte : la vue ne
// montre donc jamais deux marques du curseur (conception L2-73, arbitrage 1).
// Entrées : aucune, hors les appels de prendre et lacher.
// Sorties : porteur, l'élément sous le curseur, ou null quand aucun ne l'est.
// Erreurs : aucune ; un porteur détruit est remis à null par le moteur, et son Etat le lâche aussi à sa destruction
// ou quand il devient invisible.
// Dépendances : aucune.
QtObject {
    property Item porteur: null

    // prendre — pose le curseur sur un élément, qui le retire à tout autre.
    // Entrée : item, l'élément qui prend le curseur. Sortie : aucune. Erreurs : aucune. Dépendances : porteur.
    function prendre(item: Item) {
        porteur = item
    }

    // lacher — retire le curseur d'un élément, s'il le porte encore ; un autre porteur n'est pas touché.
    // Entrée : item, l'élément qui lâche le curseur. Sortie : aucune. Erreurs : aucune. Dépendances : porteur.
    function lacher(item: Item) {
        if (porteur === item) porteur = null
    }
}
