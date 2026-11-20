import QtQuick
import Quickshell.Wayland
import Quickshell.Hyprland
import "../Theme"

// Vignette — image figée d'une fenêtre, dans l'aperçu du lanceur (L2-16).
// Rôle : ScreencopyView en image figée (live faux), source le Toplevel Wayland de la fenêtre (HyprlandToplevel.wayland,
// protocole hyprland-toplevel-export-v1). Une seule capture par vignette affichée : avec live faux, la vue prend
// d'elle-même une image dès que son contexte d'enregistrement est prêt (éprouvé sur caladan le 2026-11-19 sous
// Quickshell 0.3.2) ; un captureFrame() appelé plus tôt, même au tour de boucle suivant l'affichage, ne fait
// qu'écrire « no recording context is ready » au journal, et n'est donc pas appelé. Tant que l'image n'est pas là, ou
// pour une fenêtre sans Toplevel (fenêtre disparue, fausse fenêtre des essais), une fenêtre schématique la remplace :
// un fond color.surfaceWindow sous une barre color.surfacePanel à trois points. Survolée, la vignette se soulève seulement (comme
// une tuile de l'accueil) ; choisie au clavier, elle grandit à l'échelle galerie.echelle (comme la tuile choisie de
// l'accueil) et s'entoure d'un anneau d'accent, au ressort des états : l'accent n'appartient qu'à l'élément sous le
// curseur du clavier. Un clic amène sa fenêtre.
// Entrées : adresse, adresse Hyprland de la fenêtre ; choisie, vrai quand le curseur du clavier est dessus.
// Sorties : capturee, vrai une fois l'image reçue ; activee(), émis au clic. Erreurs : aucune.
// Dépendances : Quickshell.Wayland (ScreencopyView), Quickshell.Hyprland (toplevels),
// Ressort, Theme (color, radius, space, galerie).
// Cotes : coins radius.panel (10, maquette 8) ; barre de 12 % de la hauteur, au moins space.scale[1] ; points de
// space.scale[0].
Item {
    id: vignette

    required property string adresse
    property bool choisie: false
    readonly property var toplevel: Hyprland.toplevels.values.find(t => t.address === adresse) ?? null
    readonly property bool capturee: vue.hasContent
    signal activee()

    transform: [
        Translate { y: -(Theme.space?.scale[0] ?? 0) * survol.value },
        Scale { origin.x: vignette.width / 2; origin.y: vignette.height / 2; xScale: grandeur.value + 0.03 * survol.value; yScale: xScale }
    ]
    Ressort { id: apparition; transition: "reveal"; nature: "fondu"; cible: vue.hasContent ? 1 : 0 }
    Ressort { id: survol; transition: "state"; cible: pointeur.hovered ? 1 : 0 }
    // Mise en avant de la vignette choisie au clavier : l'échelle des vignettes choisies (galerie.echelle).
    Ressort { id: grandeur; transition: "state"; cible: vignette.choisie ? Theme.galerie?.echelle ?? 1 : 1 }
    // Fondu de l'anneau du choix : les ressorts de déplacement ci-dessus ne portent pas d'opacité.
    Ressort { id: anneau; transition: "state"; nature: "fondu"; cible: vignette.choisie ? 1 : 0 }

    Rectangle {
        id: fond
        anchors.fill: parent
        radius: Theme.radius?.panel ?? 0
        color: Theme.color?.surfaceWindow ?? "transparent"
        border.width: 1
        border.color: Theme.material?.glassLine ?? "transparent"
        clip: true

        Rectangle {
            visible: !vue.hasContent
            width: parent.width
            height: Math.max(Theme.space?.scale[1] ?? 0, parent.height * 0.12)
            color: Theme.color?.surfacePanel ?? "transparent"
            topLeftRadius: fond.radius
            topRightRadius: fond.radius

            Row {
                x: Theme.space?.scale[1] ?? 0
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.space?.scale[0] ?? 0
                Repeater {
                    model: 3
                    delegate: Rectangle {
                        width: Theme.space?.scale[0] ?? 0
                        height: width
                        radius: width / 2
                        color: Theme.color?.textTertiary ?? "transparent"
                    }
                }
            }
        }

        ScreencopyView {
            id: vue
            anchors.fill: parent
            anchors.margins: 1
            captureSource: vignette.toplevel?.wayland ?? null
            live: false
            opacity: apparition.value
        }
    }

    // Anneau d'accent du choix au clavier, au-dessus de l'image.
    Rectangle {
        anchors.fill: parent
        anchors.margins: -2
        radius: fond.radius + 2
        color: "transparent"
        border.width: 2
        border.color: Theme.color?.accentStandalone ?? "transparent"
        opacity: anneau.value
    }

    HoverHandler { id: pointeur; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: vignette.activee() }
}
