//@ pragma Env QSG_DISTANCEFIELD_ANTIALIASING=gray
// Rideau de la voie B (L2-22) : calque Overlay opaque, un par écran, posé par le lanceur avant que hyprlock reprenne
// un verrou abandonné, afin de masquer les quelques dizaines de millisecondes où la session reste visible.
// Configuration Quickshell autonome, lancée par `qs -p` : elle n'importe rien de la coque, car Quickshell ne suit
// pas les imports hors de son dossier, et elle ne peut donc pas lire les jetons. Sa couleur lui est transmise par
// DUNEI_RIDEAU_COULEUR (#rrggbb) ; à défaut elle est noire, jamais transparente (nom de couleur, non littéral hexadécimal).
// Journal : « rideau : posé » une fois que chaque écran a présenté sa première image. Le processus se tue par signal.
import Quickshell
import Quickshell.Wayland
import QtQuick

ShellRoot {
    id: racine

    // Couleur opaque du rideau. Entrée : variable d'environnement DUNEI_RIDEAU_COULEUR ; sortie : couleur QML.
    readonly property color couleur: Quickshell.env("DUNEI_RIDEAU_COULEUR") || "black"
    // Nombre d'écrans ayant présenté leur première image.
    property int prets: 0

    // Compte une première image et annonce la pose quand tous les écrans en ont une.
    // Entrée : aucune ; sortie : aucune, écrit « rideau : posé » au journal ; erreurs : aucune ; dépendances : console.
    function imagePosee() {
        racine.prets += 1
        if (racine.prets === Quickshell.screens.length) console.log("rideau : posé")
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: fenetre
            required property var modelData
            property bool vu: false
            screen: modelData
            color: racine.couleur
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "dunei-rideau"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore
            anchors { top: true; bottom: true; left: true; right: true }

            // Sonde de la première image : le signal frameSwapped appartient à la QQuickWindow sous-jacente, que
            // seul un élément visuel atteint par Window.window ; la PanelWindow elle-même ne l'émet pas.
            Item { id: sonde }

            // Signale la première image présentée par cette fenêtre, une seule fois.
            // Entrée : aucune ; sortie : aucune ; erreurs : aucune ; dépendances : ShellRoot.imagePosee.
            Connections {
                target: sonde.Window.window
                function onFrameSwapped() {
                    if (fenetre.vu) return
                    fenetre.vu = true
                    racine.imagePosee()
                }
            }
        }
    }
}
