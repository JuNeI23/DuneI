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
// toujours sur la cible ; bulle, l'Overlay, exposé pour les essais et les relevés de mémoire.
// Erreurs : aucune ; sans cible, rien n'est observé ; avant le chargement du mouvement, le délai est nul et le
// minuteur ne s'arme pas.
// Dépendances : Theme (motion.delays), Overlay (famille infobulle), Texte.
QtObject {
    id: infobulle

    property Item cible: null
    property string texte
    property bool due: false
    // Vrai après un clic sur la cible, jusqu'au départ du pointeur : la bulle ne s'arme plus d'ici là.
    property bool masquee: false
    readonly property bool armee: delai.running

    // Le survol et le clic sont observés par des gestionnaires posés sur la cible elle-même : ils ne prennent ni
    // le clic ni le survol à la cible (le TapHandler ne fait qu'une saisie passive), et suivent n'importe quel
    // élément, qu'il ait ou non une propriété hovered. Un gestionnaire doit naître dans un Item avant d'être déplacé
    // sur la cible : créé directement comme valeur d'une propriété du QtObject, puis déplacé, il fait planter
    // Quickshell 0.3.2 (constaté sous Qt 6.12). Le porteur, Item invisible hors de toute scène, les fait donc naître,
    // et les reprend tant qu'il n'y a pas de cible.
    readonly property Item porteur: Item {
        id: porteur

        HoverHandler {
            id: survol
            parent: infobulle.cible ?? porteur
            onHoveredChanged: if (!hovered) infobulle.due = infobulle.masquee = false
        }

        TapHandler {
            parent: infobulle.cible ?? porteur
            gesturePolicy: TapHandler.DragThreshold
            onPressedChanged: if (pressed) [infobulle.due, infobulle.masquee] = [false, true]
        }
    }

    readonly property Timer delai: Timer {
        interval: Theme.motion?.delays?.tooltip ?? 0
        running: survol.hovered && !infobulle.due && !infobulle.masquee && interval > 0
        onTriggered: infobulle.due = true
    }

    readonly property Overlay bulle: Overlay {
        famille: "infobulle"
        ancre: infobulle.cible
        Texte { echelon: 1; text: infobulle.texte }
    }

    // L'Overlay s'ouvre par affectation, selon son protocole : il n'a rien d'autre qui écrive son état ouvert.
    onDueChanged: bulle.ouvert = due && texte !== ""
}
