import QtQuick
import Quickshell
import Quickshell.Wayland

// Apparition — le contenu de l'écran verrouillé qui apparaît au-dessus du verrou de hyprlock (L2-22).
// Rôle : calque dunei-verrou-apparition en couche Overlay, que la règle de calque above_lock = 1 montre au-dessus du
// verrou de session sans le rendre interactif (masque d'entrée vide, aucun clavier : les touches vont à hyprlock).
// Mappé seulement tant que Verrou.apparition. Il porte un Contenu sans fond, posé sur celui de hyprlock, identique à
// lui : vu passé à vrai, il joue l'apparition (recul de l'horloge, puis date, pastille, nom et champ) ; vu passé à
// faux, il se retire. Le Contenu existe calque caché : retiré, il est prêt à apparaître dès le mappage.
// Entrées : modelData, l'écran (obligatoire). Sorties : la fenêtre de calque. Erreurs : aucune.
// Dépendances : quickshell ≥ 0.3 (PanelWindow, WlrLayershell, Region), Verrou, Contenu.
PanelWindow {
    id: fenetre

    required property var modelData

    screen: modelData
    visible: Verrou.apparition
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    mask: Region {}
    WlrLayershell.namespace: "dunei-verrou-apparition"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    Contenu {
        anchors.fill: parent
        echelle: fenetre.devicePixelRatio
        avecFond: false
        avecImage: false
        vu: Verrou.vu
    }
}
