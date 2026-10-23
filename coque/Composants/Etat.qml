import QtQuick
import "../Theme"
import "etats.js" as Etats

// Etat — moteur d'état d'un contrôle : clés des tokens et couleurs animées de son fond et de son texte.
// Rôle : lit l'interaction du contrôle (désactivé, pressé, survolé, repos), sa sélection et le modificateur
// inactive hérité, prend le rôle de fond un cran au-dessus de son conteneur (conception, § 7.4 et 7.5), et
// fait rejoindre aux couleurs Theme.stateColors par deux ColorSpring ; le retour au repos emploie le ressort
// choisi dans Reglage (conception, § 7.8). Élément non visuel : il ne peint rien lui-même.
// Entrées : controle, le contrôle observé (enabled, down, hovered, comme un gabarit de QtQuick.Templates),
// dont les ancêtres portent dnRole et dnInactive ; selectionne ; focusDansGroupe, vrai par défaut ; role, rôle
// de fond, par défaut le cran au-dessus du dnRole hérité (surfaceWindow à la racine).
// Sorties : interaction, selection, inactif (clés des tokens) ; fond, texte, couleurs affichées.
// Erreurs : aucune ; avant le chargement des tokens ou pour une combinaison absente, les couleurs restent
// transparentes.
// Dépendances : Theme (stateColors, motion), ColorSpring (module Theme), Reglage, etats.js (herite, cran,
// interaction, selection). Les deux ColorSpring sont les premiers enfants de l'élément, dans cet ordre (fond,
// texte) : la coque d'essai les lit ainsi.
Item {
    id: etat

    required property Item controle
    property bool selectionne: false
    property bool focusDansGroupe: true
    property string role: Etats.cran(Etats.herite(controle, "dnRole", "surfaceWindow"))
    readonly property bool inactif: Etats.herite(controle, "dnInactive", false)
    readonly property string interaction: Etats.interaction(controle)
    readonly property string selection: Etats.selection(selectionne, focusDansGroupe, inactif)
    readonly property var couleurs: Theme.stateColors(role, selection, interaction)
    readonly property color fond: ressortFond.value
    readonly property color texte: ressortTexte.value

    visible: false

    // Les deux ressorts partagent le choix du retour : retour vaut vrai dès que l'interaction revient au repos.
    component Ressort: ColorSpring {
        retour: etat.interaction === "rest"
        paramsRetour: Theme.motion?.transitions.state[Reglage.retour]
    }

    Ressort {
        id: ressortFond
        target: etat.couleurs?.fill ?? "transparent"
    }

    Ressort {
        id: ressortTexte
        target: etat.couleurs?.text ?? "transparent"
    }
}
