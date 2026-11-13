import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

// FenetreNotifications — fenêtre de calque de la pile de notifications (L2-19), unique, sur l'écran actif.
// Rôle : PanelWindow ancrée en haut, à droite et en bas, sur la couche Top (le plein écran la recouvre, les popovers
// en Overlay passent au-dessus), sans zone réservée : à exclusiveZone 0, le compositeur la pose sous la barre, dont il
// respecte la zone exclusive ; une marge de calque négative la remonte du débord de l'ombre e3, pour que l'ombre et le
// glissement d'entrée de la première carte, posée à marge sous la barre, ne soient pas rognés. Elle porte l'Empilement des cartes de la pile du Centre. Sa largeur est constante
// (largeur de carte, marge et débord de l'ombre e3) et sa hauteur suit l'écran : elle n'est jamais redimensionnée à
// l'entrée ou à la sortie d'une carte (D132, D134) ; seul son masque de saisie change, à la boîte des cartes affichées,
// sortantes comprises, et vide sans carte, pour que les clics passent partout ailleurs. Elle ne prend jamais le
// clavier. À la fin de l'animation de sortie d'une carte, elle fait oublier son entrée à la pile.
// Entrées : centre, le Centre (serveur et pile) ; ecran, l'écran porteur, par défaut celui du moniteur focalisé
// d'Hyprland (même recherche que AnnonceurAlerte).
// Sortie : aucune ; pile.oublier(entree) à la fin de chaque sortie.
// Erreurs : aucune ; sans écran trouvé, Quickshell choisit l'écran par défaut.
// Dépendances : quickshell ≥ 0.3 (PanelWindow, Region, WlrLayershell, Hyprland), Empilement, Centre, Pile. Le
// namespace « dunei-notifications » a sa règle de calque générée depuis tokens.toml (glass.namespaces).
PanelWindow {
    id: fenetre

    required property QtObject centre
    property var ecran: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? null

    screen: ecran
    anchors { top: true; right: true; bottom: true }
    implicitWidth: empilement.largeurUtile
    exclusiveZone: 0
    margins.top: -empilement.debord
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "dunei-notifications"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    // Region ne prend que des entiers : la boîte est arrondie vers l'extérieur pour couvrir chaque carte entière.
    mask: Region {
        x: Math.floor(empilement.boite.x)
        y: Math.floor(empilement.boite.y)
        width: Math.ceil(empilement.boite.x + empilement.boite.width) - x
        height: Math.ceil(empilement.boite.y + empilement.boite.height) - y
    }

    Empilement {
        id: empilement
        anchors.fill: parent
        pile: fenetre.centre.pile
        onPartie: entree => fenetre.centre.pile.oublier(entree)
    }
}
