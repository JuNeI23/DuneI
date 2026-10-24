import QtQuick
import "../Theme"

// Infobulle — bulle d'aide qui paraît après un survol prolongé de sa cible.
// Rôle : à la manière de macOS (conception, § 7.10), le délai motion.delays.tooltip s'arme dès que le pointeur entre
// sur la cible ; s'il reste jusqu'au bout, l'infobulle est due et s'ouvre ; elle se ferme dès que le pointeur part,
// ou au clic, après lequel elle reste masquée jusqu'à ce que le pointeur reparte puis revienne. La bulle est un
// Overlay de la famille infobulle : une PopupWindow centrée sous la cible, ou au-dessus s'il n'y a pas la place,
// sans voile ni prise du clavier, au fond surfaceRaised et aux coins radius.small, qui porte le Texte d'échelon 1.
// Sobriété (D80) : la fenêtre n'est construite qu'à l'ouverture et détruite à la fermeture, par le LazyLoader de
// l'Overlay ; au repos, l'infobulle n'a qu'un HoverHandler et un TapHandler posés sur la cible, et un minuteur
// arrêté. Elle se déclare n'importe où (c'est un QtObject, qui n'occupe aucune place dans une mise en page) :
// Infobulle { cible: monBouton; texte: "…" }.
// Entrées : cible, l'élément survolé, dans une fenêtre affichée ; texte, le contenu de la bulle ; une infobulle sans
// texte n'ouvre jamais de fenêtre, même due.
// Sorties : armee, vrai pendant que le délai court ; due, vrai quand le délai est écoulé et que le pointeur est
// toujours sur la cible ; survolee, le survol de la cible ; survol et appui, les gestionnaires posés sur la cible
// courante (null sans cible) ; bulle, l'Overlay ; tous lus par les essais et les relevés de mémoire.
// Erreurs : aucune ; sans cible, rien n'est observé ; quand la cible passe à null ou est détruite, l'infobulle cesse
// d'être due et la bulle se ferme ; avant le chargement du mouvement, le délai est nul et le minuteur ne s'arme pas.
// Limite : une cible désactivée (enabled faux) désactive aussi les gestionnaires qu'elle porte ; l'infobulle ne
// s'ouvre donc pas sur une cible désactivée, contrairement à macOS, qui montre l'aide d'un contrôle grisé.
// Dépendances : Theme (motion.delays), Overlay (famille infobulle), Texte.
QtObject {
    id: infobulle

    property Item cible: null
    property string texte
    property bool due: false
    // Vrai après un clic sur la cible, jusqu'au départ du pointeur : la bulle ne s'arme plus d'ici là.
    property bool masquee: false
    // Recopie de l'état hovered du gestionnaire de la cible courante, qui peut disparaître avec elle.
    property bool survolee: false
    readonly property bool armee: delai.running
    // Propriétés d'objet typées : le moteur les remet à null si le gestionnaire est détruit avec sa cible.
    property HoverHandler survol: null
    property TapHandler appui: null

    // Le survol et le clic sont observés par des gestionnaires posés sur la cible elle-même : ils ne prennent ni
    // le clic ni le survol à la cible (le TapHandler ne fait qu'une saisie passive), et suivent n'importe quel
    // élément, qu'il ait ou non une propriété hovered. Ils naissent dans la cible (createObject), qui en est le
    // parent au sens des objets comme des éléments : ils meurent avec elle. Un gestionnaire né hors de tout Item puis
    // déplacé sur la cible fait planter Quickshell 0.3.2 (constaté sous Qt 6.12). Chacun ne rapporte que les
    // événements de la cible courante, pour qu'un gestionnaire en cours de destruction ne la trouble pas.
    readonly property Component modeleSurvol: Component {
        HoverHandler {
            onHoveredChanged: if (parent === infobulle.cible) infobulle.survolee = hovered
        }
    }

    readonly property Component modeleAppui: Component {
        TapHandler {
            gesturePolicy: TapHandler.DragThreshold
            onPressedChanged: if (pressed && parent === infobulle.cible) infobulle.masquer()
        }
    }

    readonly property Timer delai: Timer {
        interval: Theme.motion?.delays?.tooltip ?? 0
        running: infobulle.survolee && !infobulle.due && !infobulle.masquee && interval > 0
        onTriggered: infobulle.due = true
    }

    readonly property Overlay bulle: Overlay {
        famille: "infobulle"
        ancre: infobulle.cible
        Texte { echelon: 1; text: infobulle.texte }
    }

    // masquer — referme la bulle au clic et la garde masquée jusqu'au départ du pointeur.
    // Entrées : aucune. Sortie : aucune ; due passe à faux, masquee à vrai. Erreurs : aucune. Dépendances : aucune.
    function masquer() {
        due = false
        masquee = true
    }

    // poser — retire les gestionnaires de l'ancienne cible s'ils existent encore, remet l'état à zéro (la bulle se
    // ferme), puis pose de nouveaux gestionnaires sur la cible courante, s'il y en a une.
    // Entrées : aucune (lit cible). Sortie : aucune ; survol et appui désignent les nouveaux gestionnaires, ou null.
    // Erreurs : aucune. Dépendances : modeleSurvol, modeleAppui.
    function poser() {
        survol?.destroy()
        appui?.destroy()
        survolee = false
        due = false
        masquee = false
        survol = cible ? modeleSurvol.createObject(cible, { parent: cible }) : null
        appui = cible ? modeleAppui.createObject(cible, { parent: cible }) : null
    }

    Component.onCompleted: poser()
    // Les gestionnaires sont enfants de la cible, qui peut survivre à l'infobulle : ils partent avec elle, sans quoi
    // un survol ou un clic ultérieur sur la cible appellerait une infobulle disparue.
    Component.onDestruction: {
        survol?.destroy()
        appui?.destroy()
    }
    onCibleChanged: poser()
    // Le pointeur parti, la bulle se referme et le masquage du clic prend fin.
    onSurvoleeChanged: if (!survolee) {
        due = false
        masquee = false
    }
    // L'Overlay s'ouvre par affectation, selon son protocole : il n'a rien d'autre qui écrive son état ouvert.
    onDueChanged: bulle.ouvert = due && texte !== ""
    onTexteChanged: bulle.ouvert = due && texte !== ""
}
