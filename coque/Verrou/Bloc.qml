import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import "../Composants" as C
import "../Presquile" as P
import "../Theme"

// Bloc — le bloc opaque qui tombe sur la session d'un écran et reste sous le verrou (L2-22).
// Rôle : calque dunei-verrou en couche Overlay, de la taille de l'écran, mappé tant que Verrou.montre : la surface ne
// change jamais de taille (D132), seul son contenu bouge. Le bloc (Contenu avec fond, image du bureau) est décalé de
// (1 − Verrou.position) × hauteur vers le haut, calé sur le pixel physique, à l'opacité Verrou.opacite ; son contenu
// est posé à la cession, sans mouvement (il est sous le verrou), et se retire au déverrouillage. Sous son bord bas
// pend sa presqu'île, à la forme de la vraie au repos (P.Encoche, évasements compris) : du verre au repos, l'image du
// bas du bloc pendant le mouvement (Verrou.matiere), en fondu croisé avec la vraie (Verrou.effacement). Pas de
// presqu'île sur un écran en vrai plein écran, où la vraie est cachée. Le calque prend le clavier en exclusif tant que
// Verrou.prendClavier, et n'en fait rien : Échap n'annule rien ; il couvre tout l'écran, les clics ne passent pas.
// Entrées : modelData, l'écran (obligatoire). Sorties : la fenêtre de calque. Erreurs : aucune ; avant les jetons, la
// presqu'île est vide et le fond est un aplat surface-base.
// Dépendances : quickshell ≥ 0.3 (PanelWindow, WlrLayershell), Verrou, Contenu, P.Encoche, C.PleinEcran,
// QtQuick.Shapes (ShapePath.fillItem), Theme (tokens.presquile, tokens.bureauxVirtuels).
PanelWindow {
    id: fenetre

    required property var modelData
    readonly property var ile: Theme.tokens?.presquile
    readonly property int bureaux: Theme.tokens?.bureauxVirtuels?.nombre ?? 0
    // Largeur du corps de la vraie presqu'île au repos (comme CadreAutorisation).
    readonly property real repos: ile ? ile.pilule + (bureaux - 1) * (ile.point + ile.ecart) + 2 * ile.marge : 0

    screen: modelData
    visible: Verrou.montre
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.namespace: "dunei-verrou"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: Verrou.prendClavier ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Item {
        id: bloc
        width: fenetre.width
        height: fenetre.height
        y: -Math.round((1 - Verrou.position) * height * fenetre.devicePixelRatio) / fenetre.devicePixelRatio
        opacity: Verrou.opacite

        Contenu {
            id: contenu
            anchors.fill: parent
            echelle: fenetre.devicePixelRatio
            vu: Verrou.contenuBloc
            entreeAnimee: false
        }

        // Presqu'île du bloc, sous son bord bas.
        Item {
            id: ile
            visible: !C.PleinEcran.sur(fenetre.modelData?.name ?? "")
            x: (bloc.width - encoche.implicitWidth) / 2
            y: bloc.height
            width: encoche.implicitWidth
            height: encoche.implicitHeight
            opacity: Verrou.effacement

            P.Encoche { id: encoche; largeurCorps: fenetre.repos }

            // Le bas de l'image du bloc, à l'aplomb de la presqu'île : sa matière pendant le mouvement.
            ShaderEffectSource {
                id: bande
                width: ile.width
                height: ile.height
                visible: false
                sourceItem: contenu.fond
                sourceRect: Qt.rect(ile.x, bloc.height - ile.height, ile.width, ile.height)
            }
            Shape {
                anchors.fill: parent
                opacity: Verrou.matiere
                visible: opacity > 0
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeWidth: -1
                    fillItem: bande
                    PathSvg { path: encoche.trace }
                }
            }
        }
    }
}
