import QtQuick
import "../Theme"
import "etats.js" as Etats

// Etat — moteur d'état d'un contrôle : clés des tokens et couleurs animées de son fond et de son texte.
// Rôle : lit l'interaction du contrôle (désactivé, pressé, survolé, repos), sa sélection et le modificateur
// inactive hérité, prend le rôle de fond un cran au-dessus de son conteneur (conception, § 7.4 et 7.5), et
// fait rejoindre aux couleurs Theme.stateColors par deux ColorSpring, au ressort transitions.state.in, retour au
// repos compris (conception, § 7.8). Élément non visuel : il ne peint rien lui-même.
// Entrées : controle, le contrôle observé (enabled, down, hovered, comme un gabarit de QtQuick.Templates),
// dont les ancêtres portent dnRole et dnInactive ; selectionne ; focusDansGroupe, vrai par défaut ; role, rôle
// de fond, par défaut le cran au-dessus du dnRole hérité (surfaceWindow à la racine) ; forcer, réservée à la
// planche de contrôle : une clé d'interaction ("hover", "pressed"…) qui, non vide, remplace celle que lit le
// contrôle, pour montrer un état sans geste ; vide par défaut, et jamais posée par une surface de la coque ;
// peintFond et peintTexte, vrais par défaut : faux quand le contrôle ne peint pas cette couleur, qui reste alors
// transparente, si bien que son ressort ne démarre jamais (sobriété, D80).
// Sorties : interaction, selection, inactif (clés des tokens) ; fond, texte, couleurs affichées ; texteNeutre, le
// texte du même rôle et de la même interaction sans sélection, sans ressort, pour un libellé posé à côté d'une
// marque sélectionnable (case, radio, interrupteur, bascule) ou d'un en-tête sans fond (section dépliable).
// Erreurs : aucune ; avant le chargement des tokens ou pour une combinaison absente, les couleurs restent
// transparentes.
// Dépendances : Theme (stateColors, motion), ColorSpring (module Theme), etats.js (herite, cran,
// interaction, selection). Les deux ColorSpring sont les premiers enfants de l'élément, dans cet ordre (fond,
// texte) : la coque d'essai les lit ainsi.
Item {
    id: etat

    required property Item controle
    property bool selectionne: false
    property bool focusDansGroupe: true
    property string forcer: ""
    property bool peintFond: true
    property bool peintTexte: true
    property string role: Etats.cran(Etats.herite(controle, "dnRole", "surfaceWindow"))
    readonly property bool inactif: Etats.herite(controle, "dnInactive", false)
    readonly property string interaction: forcer || Etats.interaction(controle)
    readonly property string selection: Etats.selection(selectionne, focusDansGroupe, inactif)
    readonly property var couleurs: Theme.stateColors(role, selection, interaction)
    readonly property color fond: ressortFond.value
    readonly property color texte: ressortTexte.value
    readonly property color texteNeutre: Theme.stateColors(role, "none", interaction)?.text ?? "transparent"

    visible: false

    ColorSpring {
        id: ressortFond
        target: etat.peintFond ? (etat.couleurs?.fill ?? "transparent") : "transparent"
    }

    ColorSpring {
        id: ressortTexte
        target: etat.peintTexte ? (etat.couleurs?.text ?? "transparent") : "transparent"
    }
}
