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
// selectionNeutre, faux par défaut : vrai, une sélection prend toujours la clé « inactive » (sans accent ni accent
// muet) et les couleurs au repos du rôle controlRaised, un cran levé, neutre et légèrement teinté, distinct du
// panneau et de son survol aux deux moments (la sélection inactive du jour se confond avec surfacePanel), sans
// réagir au survol ni à la pression, comme la sélection d'une barre latérale de macOS : c'est la rangée choisie
// d'une colonne de navigation ; peintFond et peintTexte, vrais par défaut : faux quand le contrôle ne peint pas cette couleur, qui reste alors
// transparente, si bien que son ressort ne démarre jamais (sobriété, D80) ; fondReposTransparent, faux par
// défaut : vrai, le fond ni survolé, ni pressé, ni sélectionné (au repos ou désactivé) vise sa couleur rendue
// transparente, pour un élément qui ne se distingue pas de son conteneur au repos (une rangée) et ne doit pas en
// repeindre la couleur opaque, qui se détacherait d'une surface de verre. L'opacité seule change : le ressort
// fond la couleur d'état depuis sa propre teinte, sans passer par le noir ; fondSurvolTransparent, faux par défaut :
// vrai, le survol (non sélectionné) fait de même, pour un élément qui ne se peint qu'à la pression (le segment d'une
// barre d'onglets) et dont le ressort, resté sur le fond de survol opaque, le ferait apparaître au premier instant
// de la pression ; suitCurseur, faux par défaut : vrai, l'état prend le curseur de sa vue (l'arbitre VueCurseur
// hérité par dnVue) au survol et au focus clavier, ou dès sa création, son changement de vue ou son retour à la
// visibilité s'il est déjà survolé ou focalisé, et le lâche quand l'un ou l'autre cesse ou quand le contrôle
// devient invisible (par un ancêtre compris) ou est détruit ; sa sélection vaut alors celle d'un élément sélectionné dans un groupe qui a le
// focus (l'accent, ou l'accent sans chroma sous inactive) sous le curseur, et hors du curseur une sélection fournie
// (selectionne) reste toujours « inactive », jamais à l'accent (L2-73). Faux, la sélection suit selectionne et
// focusDansGroupe comme avant, si bien que les contrôles allumés gardent leur accent.
// Sorties : interaction, selection, inactif (clés des tokens) ; levee, vrai pour une sélection neutre (selectionNeutre)
// peinte en controlRaised, hors du curseur ; vue, l'arbitre du curseur hérité (null sans suitCurseur ou sans vue) ;
// sousCurseur, vrai quand le contrôle porte le curseur (toujours faux sans suitCurseur), pour un composant qui peint
// la marque du curseur ailleurs que sur ce fond ; fond, texte, couleurs affichées ; texteNeutre, le
// texte du même rôle et de la même interaction sans sélection, sans ressort, pour un libellé posé à côté d'une
// marque sélectionnable (case, radio, interrupteur, bascule) ou d'un en-tête sans fond (section dépliable).
// Erreurs : aucune ; avant le chargement des tokens ou pour une combinaison absente, les couleurs restent
// transparentes.
// Dépendances : Theme (stateColors, motion), ColorSpring (module Theme), VueCurseur, etats.js (herite, cran,
// interaction, selection, sousCurseur). Les deux ColorSpring sont les premiers enfants de l'élément, dans cet ordre (fond,
// texte) : la coque d'essai les lit ainsi.
Item {
    id: etat

    required property Item controle
    property bool selectionne: false
    property bool focusDansGroupe: true
    property string forcer: ""
    property bool peintFond: true
    property bool peintTexte: true
    property bool fondReposTransparent: false
    property bool fondSurvolTransparent: false
    property bool selectionNeutre: false
    property bool suitCurseur: false
    property string role: Etats.cran(Etats.herite(controle, "dnRole", "surfaceWindow"))
    readonly property bool inactif: Etats.herite(controle, "dnInactive", false)
    readonly property string interaction: forcer || Etats.interaction(controle)
    readonly property VueCurseur vue: suitCurseur ? Etats.herite(controle, "dnVue", null) : null
    readonly property bool sousCurseur: suitCurseur && Etats.sousCurseur(controle, vue)
    readonly property string selection: sousCurseur ? Etats.selection(true, true, inactif)
        : (suitCurseur || selectionNeutre) && selectionne ? "inactive"
        : Etats.selection(selectionne, focusDansGroupe, inactif)
    readonly property bool levee: selectionNeutre && selectionne && !sousCurseur
    readonly property var couleurs: levee ? Theme.stateColors("controlRaised", "none", "rest")
        : Theme.stateColors(role, selection, interaction)
    readonly property color fond: ressortFond.value
    readonly property color texte: ressortTexte.value
    readonly property color texteNeutre: Theme.stateColors(role, "none", interaction)?.text ?? "transparent"

    visible: false

    ColorSpring {
        id: ressortFond
        readonly property color plein: etat.peintFond ? (etat.couleurs?.fill ?? "transparent") : "transparent"
        target: etat.selection === "none" && (etat.fondReposTransparent
            && (etat.interaction === "rest" || etat.interaction === "disabled")
            || etat.fondSurvolTransparent && etat.interaction === "hover")
            ? Qt.alpha(plein, 0) : plein
    }

    ColorSpring {
        id: ressortTexte
        target: etat.peintTexte ? (etat.couleurs?.text ?? "transparent") : "transparent"
    }

    // suivre — prend ou lâche le curseur de la vue pour le contrôle.
    // Entrée : pris, vrai pour prendre le curseur, faux pour le lâcher. Sortie : aucune.
    // Erreurs : aucune ; sans vue, rien. Dépendances : vue (VueCurseur), controle.
    function suivre(pris: bool) {
        if (vue) pris ? vue.prendre(controle) : vue.lacher(controle)
    }

    // synchroniser — aligne le curseur sur l'état présent du contrôle : un contrôle visible déjà survolé ou focalisé
    // au clavier le prend, tout autre le lâche. Sert quand aucun signal de survol ni de focus ne viendra : à la
    // création, au changement de vue et au retour à la visibilité (un contrôle qui paraît sous le pointeur immobile).
    // Entrées : aucune. Sortie : aucune. Erreurs : aucune ; sans vue, rien. Un contrôle simulé sans visualFocus
    // compte comme sans focus. Dépendances : suivre, controle (visible, hovered, visualFocus).
    function synchroniser() {
        suivre(controle.visible && (controle.hovered || controle.visualFocus === true))
    }

    Component.onCompleted: synchroniser()
    Component.onDestruction: suivre(false)
    onVueChanged: synchroniser()

    // Le survol et le focus clavier du contrôle déplacent le curseur de la vue ; un contrôle caché, lui-même ou par un
    // ancêtre (visible suit la visibilité effective), le lâche, et il le reprend en reparaissant survolé. Le pointeur
    // qui quitte un contrôle lui retire le curseur même si le focus clavier y reste : c'est voulu, le dernier mouvement
    // place le curseur, et la vue n'en montre aucun jusqu'au prochain geste. Un contrôle simulé sans visualFocus
    // n'émet pas ce signal, d'où ignoreUnknownSignals.
    Connections {
        target: etat.vue ? etat.controle : null
        ignoreUnknownSignals: true
        function onHoveredChanged() { etat.suivre(etat.controle.hovered) }
        function onVisualFocusChanged() { etat.suivre(etat.controle.visualFocus) }
        function onVisibleChanged() { etat.synchroniser() }
    }
}
