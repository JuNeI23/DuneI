import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../Theme"

// CalquePanneau — fenêtre de calque du panneau des notifications (L2-67), créée par FenetrePanneau.
// Rôle : PanelWindow ancrée en haut, à droite et en bas, sur la couche Top, sans zone réservée : le compositeur la
// pose sous la barre. Sa taille est constante (largeur du panneau et débord de l'ombre de la forme, hauteur de
// l'écran utile) : seule la forme qu'elle porte bouge (FormePanneau ; D132, D134). Fermée, elle est transparente et
// son masque de saisie est vide : les clics la traversent ; ouverte, le masque couvre le corps de la forme. Elle ne
// prend le clavier que tant que le panneau est ouvert ; la prise du clavier, que la barre de la cloche partage, le
// ferme au premier clic hors de la forme.
// Entrées : racine, la FenetrePanneau (ouvert, ecran, barre, attente).
// Sorties : aucune ; racine.ouvert repasse à faux à Échap et à la levée de la prise.
// Erreurs : aucune ; sans écran, Quickshell pose la fenêtre sur l'écran par défaut.
// Dépendances : quickshell ≥ 0.3 (PanelWindow, Region, WlrLayershell, HyprlandFocusGrab), FormePanneau, Theme
// (panneau). Le namespace « dunei-panneau » a sa règle de calque générée depuis tokens.toml (glass.namespaces).
PanelWindow {
    id: fenetre

    required property QtObject racine

    screen: racine.ecran
    anchors { top: true; right: true; bottom: true }
    implicitWidth: (Theme.panneau?.largeur ?? 0) + forme.marge
    exclusiveZone: 0
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "dunei-panneau"
    WlrLayershell.keyboardFocus: racine.ouvert ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    // Region ne prend que des entiers : le corps est arrondi vers l'extérieur.
    mask: Region {
        x: Math.floor(fenetre.width - forme.corps.width)
        y: Math.floor(forme.corps.y)
        width: forme.charge ? Math.ceil(forme.corps.width) : 0
        height: forme.charge ? Math.ceil(forme.corps.height) : 0
    }

    FormePanneau {
        id: forme
        anchors.fill: parent
        attente: racine.attente
        ouvert: racine.ouvert
        onFermer: racine.ouvert = false
    }

    HyprlandFocusGrab {
        windows: racine.barre ? [fenetre, racine.barre] : [fenetre]
        active: racine.ouvert
        onCleared: racine.ouvert = false
    }
}
