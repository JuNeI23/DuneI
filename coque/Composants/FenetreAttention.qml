import QtQuick
import Quickshell
import Quickshell.Wayland
import "../Theme"

// FenetreAttention — fenêtre d'un Overlay de la famille attention.
// Rôle : PanelWindow plein écran sur l'écran figé par l'Overlay, couche overlay, clavier exclusif, aucun espace
// réservé ; voile material.shade sur tout l'écran et contenu de l'Overlay posé au centre d'un Cadre aux coins
// radius.window et au retrait space.scale[2] (12), comme une feuille d'alerte (conception, § 7.7 et 7.10). Un clic
// sur le voile ou Échap ferment l'Overlay. Elle vit dans son propre fichier, que l'Overlay ne compile qu'à
// l'ouverture d'une attention : un fichier qui nomme PanelWindow ne se charge pas sans dorsale de couches (la
// plateforme offscreen des coques d'essai n'en a pas), et l'Overlay reste ainsi chargeable partout, ce qui permet
// d'éprouver les contextuels hors écran.
// Entrées : overlay, l'Overlay qui la porte (ecran, contenu, ouvert), requis.
// Sorties : aucune autre que celles de PanelWindow.
// Erreurs : aucune ; avant le chargement des tokens, voile et fond restent transparents et le retrait vaut 0.
// Dépendances : Quickshell (PanelWindow, ExclusionMode), Quickshell.Wayland (WlrLayershell), Theme (material,
// radius, space), Overlay (son composant en ligne Cadre).
PanelWindow {
    required property QtObject overlay

    screen: overlay.ecran
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    // Un clic hors du cadre tombe sur le voile et ferme ; un clic dans le cadre que le contenu n'a pas pris
    // descend aussi jusqu'ici, et il est ignoré.
    Rectangle {
        id: voile
        anchors.fill: parent
        color: Theme.material?.shade ?? "transparent"

        MouseArea {
            anchors.fill: parent
            onClicked: (m) => {
                if (!cadre.contains(cadre.mapFromItem(voile, m.x, m.y))) overlay.ouvert = false
            }
        }
    }

    Overlay.Cadre {
        id: cadre
        anchors.centerIn: parent
        contenu: overlay.contenu
        rayon: Theme.radius?.window ?? 0
        retrait: Theme.space?.scale[2] ?? 0
        onEchap: overlay.ouvert = false
    }
}
