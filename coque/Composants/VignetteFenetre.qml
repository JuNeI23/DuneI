import QtQuick
import Quickshell.Wayland
import Quickshell.Hyprland
import "../Theme"

// VignetteFenetre — image figée d'une fenêtre, commune à l'aperçu du lanceur (L2-16) et au sélecteur de fenêtres (L2-17).
// Rôle : ScreencopyView en image figée (live faux), source le Toplevel Wayland de la fenêtre (HyprlandToplevel.wayland,
// protocole hyprland-toplevel-export-v1). Une seule capture par vignette affichée : avec live faux, la vue prend
// d'elle-même une image dès que son contexte d'enregistrement est prêt (éprouvé sur caladan le 2026-11-19 sous
// Quickshell 0.3.2) ; un captureFrame() appelé plus tôt, même au tour de boucle suivant l'affichage, ne fait
// qu'écrire « no recording context is ready » au journal, et n'est donc pas appelé. Netteté (L2-80) : Quickshell
// 0.3.2 n'offre pas de mipmap sur ScreencopyView et Qt réduirait d'un seul coup une capture de 2560 px à 200 px, d'où
// un crénelage ; la vue garde donc sa taille native, cachée, et une ShaderEffectSource à paliers (mipmap) l'affiche à
// la taille de la vignette. La source ne suit la vue que jusqu'à l'arrivée de la capture, puis se fige : la recopie et
// le calcul des paliers ne se font qu'une fois par vignette. Tant que l'image n'est pas là, ou
// pour une fenêtre sans Toplevel (fenêtre disparue, fausse fenêtre des essais), une fenêtre schématique la remplace :
// un fond color.surfaceWindow sous une barre color.surfacePanel à trois points. Survolée, la vignette se soulève seulement (comme
// une tuile de l'accueil) ; choisie au clavier, elle grandit du facteur agrandi, galerie.echelle par défaut (comme la
// tuile choisie de l'accueil) et, si anneau est vrai, s'entoure d'un anneau d'accent, au ressort des états : l'accent n'appartient
// qu'à l'élément sous le curseur du clavier. Sans anneau (le sélecteur pose sa propre plaque), ni anneau ni fondu
// d'anneau ; l'échelle demeure. Sans survolActif (le sélecteur, où le survol déplace déjà la sélection), le survol ne
// soulève ni ne grandit la vignette : la seule marque du curseur reste celle de la sélection. Un clic amène sa fenêtre.
// Entrées : adresse, adresse Hyprland de la fenêtre ; choisie, vrai quand le curseur du clavier est dessus ;
// anneau, vrai par défaut, montre l'anneau d'accent de la vignette choisie ; survolActif, vrai par défaut, soulève la
// vignette survolée ; agrandi, facteur de la vignette choisie (galerie.echelle par défaut, selecteur.agrandi dans le
// sélecteur) ; estompe, opacité de la vignette entière, repli compris (1 par défaut, selecteur.estompe pour les
// vignettes non choisies du sélecteur), au ressort state.
// Sorties : survolee, vrai tant que le pointeur est dessus ; capturee, vrai une fois l'image reçue ; vue et image, la
// capture native et sa source d'effet (lues par les essais) ; activee(), émis au clic. Erreurs : aucune.
// Dépendances : Quickshell.Wayland (ScreencopyView), Quickshell.Hyprland (toplevels),
// Ressort, Theme (color, radius, space, galerie).
// Cotes : coins radius.panel (10, maquette 8) ; barre de 12 % de la hauteur, au moins space.scale[1] ; points de
// space.scale[0].
Item {
    id: vignette

    required property string adresse
    property bool choisie: false
    property bool anneau: true
    property bool survolActif: true
    property real agrandi: Theme.galerie?.echelle ?? 1
    property real estompe: 1
    // Vrai tant que le pointeur est sur la vignette, que survolActif soulève celle-ci ou non (le sélecteur s'en sert).
    readonly property bool survolee: pointeur.hovered
    readonly property var toplevel: Hyprland.toplevels.values.find(t => t.address === adresse) ?? null
    readonly property bool capturee: vue.hasContent
    readonly property alias vue: vue
    readonly property alias image: image
    signal activee()

    opacity: estompee.value
    transform: [
        Translate { y: -(Theme.space?.scale[0] ?? 0) * survol.value },
        Scale { origin.x: vignette.width / 2; origin.y: vignette.height / 2; xScale: grandeur.value + 0.03 * survol.value; yScale: xScale }
    ]
    Ressort { id: apparition; transition: "reveal"; nature: "fondu"; cible: vue.hasContent ? 1 : 0 }
    Ressort { id: survol; transition: "state"; cible: vignette.survolActif && pointeur.hovered ? 1 : 0 }
    // Mise en avant de la vignette choisie au clavier : le facteur agrandi.
    Ressort { id: grandeur; transition: "state"; cible: vignette.choisie ? vignette.agrandi : 1 }
    // Estompe de la vignette entière, repli compris, posée par le client.
    Ressort { id: estompee; transition: "state"; nature: "fondu"; cible: vignette.estompe }
    // Fondu de l'anneau du choix : les ressorts de déplacement ci-dessus ne portent pas d'opacité.
    Ressort { id: fonduAnneau; transition: "state"; nature: "fondu"; cible: vignette.anneau && vignette.choisie ? 1 : 0 }

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

        // Capture à sa taille native, jamais affichée elle-même.
        ScreencopyView {
            id: vue
            width: sourceSize.width
            height: sourceSize.height
            visible: false
            captureSource: vignette.toplevel?.wayland ?? null
            live: false
        }

        // Capture réduite par paliers à la taille de la vignette, figée dès son arrivée.
        ShaderEffectSource {
            id: image
            anchors.fill: parent
            anchors.margins: 1
            sourceItem: vue
            textureSize: vue.sourceSize
            mipmap: true
            smooth: true
            hideSource: true
            live: !vue.hasContent
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
        visible: vignette.anneau
        opacity: fonduAnneau.value
    }

    HoverHandler { id: pointeur; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: vignette.activee() }
}
