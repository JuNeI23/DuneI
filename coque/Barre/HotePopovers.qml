import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

// HotePopovers — fenêtre unique et permanente des popovers de la barre, une par écran (L2-06, L2-56).
// Rôle : calque posé en haut de l'écran qui porte le CadrePopovers de tous les popovers hébergés de cette barre. Il
// mesure une ligne au repos et prend la hauteur de l'écran tant que le cadre est déployé (D109), sans jamais se recréer :
// l'ouverture n'attend ni fenêtre ni contenu. Sans popover ouvert, son masque de saisie est vide, dès la fermeture et sans
// attendre la fin du mouvement : les clics le traversent. Il ne prend le clavier que popover ouvert, car un
// clavier à la demande peut garder le focus au détriment d'une autre fenêtre. La prise du clavier associe la barre : un
// clic sur une autre icône passe à son popover sans fermeture parasite, et un clic ailleurs ferme.
// Entrées : barre, la fenêtre de la barre ; popovers, les Overlay hébergés (heberge: true), voir CadrePopovers.
// Sorties : courant, l'Overlay ouvert, ou null ; deploye, vrai tant que le cadre est déployé.
// Erreurs : aucune ; sans barre, la fenêtre suit l'écran par défaut et la prise ne porte que sur elle.
// Dépendances : quickshell ≥ 0.3 (PanelWindow, Region, WlrLayershell), Quickshell.Hyprland (HyprlandFocusGrab),
// CadrePopovers. Le namespace « dunei-popovers » a sa règle de calque générée depuis tokens.toml.
PanelWindow {
    id: hote

    property var barre
    property alias popovers: contenu.popovers
    readonly property alias courant: contenu.courant
    readonly property alias deploye: contenu.deploye

    screen: barre?.screen ?? null
    anchors { top: true; left: true; right: true }
    implicitHeight: deploye ? (screen?.height ?? 0) : 1
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "dunei-popovers"
    WlrLayershell.keyboardFocus: courant ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    mask: Region {
        x: contenu.cadre.x
        y: contenu.cadre.y
        width: hote.courant ? contenu.cadre.width : 0
        height: hote.courant ? contenu.cadre.height : 0
    }

    CadrePopovers {
        id: contenu
        anchors.fill: parent
        largeurEcran: hote.screen?.width ?? 0
        hauteurBarre: hote.barre?.implicitHeight ?? 0
    }

    // La liaison réarme la prise à chaque ouverture : sa levée la met à faux sans rompre la liaison, et la fermeture qui
    // la suit repasse courant à null.
    HyprlandFocusGrab {
        windows: hote.barre ? [hote, hote.barre] : [hote]
        active: hote.courant !== null
        onCleared: if (hote.courant) hote.courant.ouvert = false
    }
}
