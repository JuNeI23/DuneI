import Quickshell
import Quickshell.Wayland
import "../Theme"

// Fond — le calque du fond d'écran, posé sur chaque écran sous toutes les autres fenêtres (L2-27).
// Rôle : fenêtre de calque plein écran, au niveau Background, qui contient l'Affichage. Elle ne réserve aucune place,
// ne prend jamais le focus clavier et laisse tout clic la traverser (masque vide). Sa couleur est l'aplat du bureau,
// qui se voit tant qu'aucune image n'est posée. Aucune animation d'apparition : la règle de calque générée l'en prive.
// Entrées : modelData, l'écran que lui donne le Variants de la coque (obligatoire) ; Theme.bureau.
// Sorties : une fenêtre de calque au namespace « dunei-fond » (le jeton [bureau].namespace, accordé par un test).
// Erreurs : sans jeton de thème, la fenêtre est transparente ; l'image absente ou illisible se signale dans Affichage.
// Dépendances : quickshell ≥ 0.3 (PanelWindow, Region, WlrLayershell, ShellScreen.devicePixelRatio), Affichage, Theme.
PanelWindow {
    id: surface

    required property var modelData

    screen: modelData
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: Theme.bureau?.fond ?? "transparent"
    mask: Region {}
    WlrLayershell.namespace: "dunei-fond"
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    Affichage {
        anchors.fill: parent
        echelle: modelData.devicePixelRatio
    }
}
