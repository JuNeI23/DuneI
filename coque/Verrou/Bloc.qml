import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../Composants" as C
import "../Presquile" as P
import "../Theme"

// Bloc — le bloc opaque qui tombe sur la session d'un écran et reste sous le verrou (L2-22).
// Rôle : calque dunei-verrou en couche Overlay, de la taille de l'écran, mappé tant que Verrou.montre : la surface ne
// change jamais de taille (D132), seul son contenu bouge. Le bloc prend la taille et l'échelle de l'écran, et non
// celles du calque : caché, le calque n'a pas de taille, et l'image du bureau doit être décodée avant la chute (sans
// quoi les premières images de la chute montrent l'aplat). Le bloc (Contenu avec fond, image du bureau) est décalé de
// (1 − Verrou.position) × hauteur vers le haut, calé sur le pixel physique, à l'opacité Verrou.opacite ; il ne montre
// que le fond, le contenu se montrant dans la surface du verrou (voie B). Sous son bord bas
// pend sa presqu'île, à la forme de la vraie au repos (P.Encoche, évasements compris) : du verre au repos, l'image du
// bas du bloc pendant le mouvement (Verrou.matiere). Elle se montre entière dès le mappage, sur la vraie qui s'efface
// dessous, et la vraie reprend d'un coup à la fin, à l'identique (Presquile.qml) ; elle porte les
// points des bureaux, comme la vraie au repos (maquette verrou-v1), inertes : un clic n'y change rien. Pas de
// presqu'île sur un écran en vrai plein écran, où la vraie est cachée. Le calque prend le clavier en exclusif tant que
// Verrou.prendClavier, et n'en fait rien : Échap n'annule rien ; il couvre tout l'écran, les clics ne passent pas.
// Entrées : modelData, l'écran (obligatoire). Sorties : la fenêtre de calque. Erreurs : aucune ; avant les jetons, la
// presqu'île est vide et le fond est un aplat surface-base.
// Dépendances : quickshell ≥ 0.3 (PanelWindow, WlrLayershell, Hyprland.monitorFor), Verrou, Contenu, P.Encoche,
// P.Bureaux, C.PleinEcran, QtQuick.Shapes (ShapePath.fillItem), Theme (tokens.presquile, tokens.bureauxVirtuels).
PanelWindow {
    id: fenetre

    required property var modelData
    readonly property var cotes: Theme.tokens?.presquile
    readonly property int bureaux: Theme.tokens?.bureauxVirtuels?.nombre ?? 0
    // Largeur du corps de la vraie presqu'île au repos (comme CadreAutorisation).
    readonly property real repos: cotes ? cotes.pilule + (bureaux - 1) * (cotes.point + cotes.ecart) + 2 * cotes.marge
                                        : 0

    screen: modelData
    visible: Verrou.montre
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.namespace: "dunei-verrou"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: Verrou.prendClavier ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // Échelle de l'écran : celle de Hyprland, ou le rapport de pixels du calque avant la première lecture.
    readonly property real echelle: Hyprland.monitorFor(modelData)?.scale || devicePixelRatio

    Item {
        id: bloc
        width: fenetre.modelData?.width ?? 0
        height: fenetre.modelData?.height ?? 0
        y: -Math.round((1 - Verrou.position) * height * fenetre.echelle) / fenetre.echelle
        opacity: Verrou.opacite

        Contenu {
            id: contenu
            anchors.fill: parent
            echelle: fenetre.echelle
            vu: false
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

            P.Bureaux {
                x: encoche.evasement
                width: fenetre.repos
                height: encoche.hauteur
                ecran: fenetre.modelData
                enabled: false
            }
        }
    }
}
