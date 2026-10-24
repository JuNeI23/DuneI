import QtQuick
import QtQuick.Shapes
import QtQuick.Templates as T
import "../Theme"
import "etats.js" as Etats

// Pastilles — les trois pastilles de fenêtre de macOS : fermer, réduire, agrandir.
// Rôle : une rangée de trois disques de density.pastille de diamètre, espacés de space.scale[1] (8), aux couleurs
// color.error, color.warning et color.success (conception, § 7.10). Au survol du groupe, chaque disque montre son
// glyphe dessiné (QtQuick.Shapes) : une croix, un tiret, et les deux flèches d'agrandissement de macOS (deux triangles
// pleins pointés vers les coins opposés). Les glyphes sont en color.surfaceBase, la couleur la plus sombre du thème :
// le contraste le plus fort qu'offre Theme sur les trois teintes (4,2:1 sur error, 8,8:1 sur warning et 8,6:1 sur
// success à la teinte 55), au-dessus des 3:1 demandés à un élément graphique. Le disque survolé s'éclaircit et le
// disque pressé fonce franchement : il prend la variante de survol (color.errorHover, warningHover, successHover) ou la
// variante pressée (errorPressed…) de sa teinte, précalculées par l'émetteur dans l'espace perceptif du thème avec les
// écarts propres aux pastilles (tokens.toml, section pastilles), plus marqués que ceux des états ; le QML ne dérive
// aucune couleur, et le repos garde la teinte. Sous le modificateur inactive hérité, comme une fenêtre inactive de
// macOS, les trois disques passent au neutre color.borderDefault et ne montrent plus de glyphe ; un disque désactivé
// (reduireActif ou agrandirActif faux) prend ce même neutre, sans glyphe ni réaction. Les pastilles ne sont pas un
// arrêt de tabulation (focusPolicy Qt.NoFocus) : la fenêtre se ferme, se réduit et s'agrandit aussi au clavier, par
// Hyprland. Leur rôle sous un gestionnaire en tuiles et leur emplacement se décideront avec la décoration des fenêtres
// (proposition : fermer la fenêtre, l'envoyer au bureau spécial, la passer en plein écran) ; ce composant n'émet que
// des signaux.
// Entrées : reduireActif, agrandirActif, vrais par défaut ; inactif, le modificateur inactive, hérité par défaut
// (dnInactive) ; forcer, réservée à la planche de contrôle : "hover" montre les glyphes et la variante de survol des
// trois disques sans geste, "pressed" leur variante pressée ; vide par défaut, et jamais posée par une surface de la
// coque.
// Sorties : signaux fermer(), reduire() et agrandir(), émis au clic du disque correspondant ; survol, vrai quand
// le pointeur est sur le groupe (ou forcé) ; disques, le Repeater des trois disques, lu par les essais : chaque
// disque expose couleur, la couleur peinte, et trace, son glyphe.
// Erreurs : aucune ; avant le chargement des tokens, les cotes sont nulles et les couleurs transparentes.
// Dépendances : QtQuick.Shapes (moteur CurveRenderer), QtQuick.Templates (AbstractButton : clic, pression),
// Theme (density, space, color), etats.js (herite) ; HoverHandler, qui suit le survol du groupe, intervalles
// compris, et celui de chaque disque, quel que soit Qt.styleHints.useHoverEffects.
// Cotes : diamètre density.pastille, écart space.scale[1] ; les glyphes sont décrits dans le carré unité et mis à
// l'échelle du diamètre : leurs points et leur trait (un dixième du diamètre) sont des fractions, non des cotes.
Row {
    id: pastilles

    property bool reduireActif: true
    property bool agrandirActif: true
    property bool inactif: Etats.herite(pastilles, "dnInactive", false)
    property string forcer: ""
    readonly property bool survol: forcer !== "" || zone.hovered
    readonly property alias disques: disques

    signal fermer()
    signal reduire()
    signal agrandir()

    spacing: Theme.space?.scale[1] ?? 0

    HoverHandler { id: zone }

    Repeater {
        id: disques

        // Chaque disque : sa teinte du thème et son glyphe dans le carré unité (chemin SVG ; plein pour les
        // flèches d'agrandissement, tracé sinon). Le modèle est fixe : l'activation et le signal se lisent au rang,
        // pour qu'un changement de reduireActif ne recrée pas les disques.
        model: [
            { teinte: "error", plein: false, trace: "M .3 .3 L .7 .7 M .7 .3 L .3 .7" },
            { teinte: "warning", plein: false, trace: "M .25 .5 L .75 .5" },
            { teinte: "success", plein: true, trace: "M .25 .25 L .6 .25 L .25 .6 Z M .75 .75 L .4 .75 L .75 .4 Z" }
        ]

        T.AbstractButton {
            id: disque

            required property var modelData
            required property int index
            readonly property color base: Theme.color?.surfaceBase ?? "transparent"
            readonly property bool neutre: !enabled || pastilles.inactif
            readonly property bool enfonce: pressed || pastilles.forcer === "pressed"
            readonly property bool survole: survolDisque.hovered || pastilles.forcer === "hover"
            readonly property color couleur: (neutre ? Theme.color?.borderDefault
                : Theme.color?.[modelData.teinte + (enfonce ? "Pressed" : survole ? "Hover" : "")]) ?? "transparent"
            readonly property alias trace: trace

            focusPolicy: Qt.NoFocus
            enabled: [true, pastilles.reduireActif, pastilles.agrandirActif][index]
            implicitWidth: Theme.density?.pastille ?? 0
            implicitHeight: implicitWidth
            onClicked: [pastilles.fermer, pastilles.reduire, pastilles.agrandir][index]()

            HoverHandler { id: survolDisque }

            background: Rectangle {
                radius: width / 2
                color: disque.couleur
            }

            // Le glyphe, décrit dans le carré unité puis mis à l'échelle du diamètre depuis son coin haut gauche.
            contentItem: Item {
                Shape {
                    id: trace

                    readonly property color couleur: disque.base

                    width: 1
                    height: 1
                    scale: disque.width
                    transformOrigin: Item.TopLeft
                    visible: pastilles.survol && !disque.neutre
                    preferredRendererType: Shape.CurveRenderer

                    ShapePath {
                        strokeColor: disque.modelData.plein ? "transparent" : trace.couleur
                        strokeWidth: 1 / 10
                        fillColor: disque.modelData.plein ? trace.couleur : "transparent"
                        capStyle: ShapePath.RoundCap
                        PathSvg { path: disque.modelData.trace }
                    }
                }
            }
        }
    }
}
