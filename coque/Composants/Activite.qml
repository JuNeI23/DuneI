import QtQuick
import "../Theme"

// Activite — indicateur d'activité indéterminée de la coque : la roue de macOS.
// Rôle : huit traits rayonnants, dessinés (rectangles aux bouts arrondis, pivotés autour du centre), au texte
// secondaire. Le trait de tête (pas) est opaque et les suivants s'estompent d'un huitième chacun dans le sens
// inverse de la rotation ; la tête avance d'un trait, dans le sens horaire, à chaque huitième de
// motion.periods.spinner, si bien qu'un tour complet dure cette période (conception, § 7.10). La roue tourne par pas
// et non en continu : un minuteur réveille la coque huit fois par tour, sans animation à chaque image. Sobriété
// (D80) : le minuteur ne court que si la roue est visible et en marche ; arrêtée, elle reste affichée, immobile, et
// ne coûte rien. La progression déterminée est la Progression.
// Entrées : running, vrai par défaut ; visible.
// Sorties : pas, rang du trait de tête ; minuteur et rayons (le Repeater des traits), lus par les essais.
// Erreurs : aucune ; avant le chargement des tokens et du mouvement, la roue est de taille nulle et le minuteur ne
// s'arme pas.
// Dépendances : Theme (icons.sizes, color, motion.periods).
// Cotes : carré de icons.sizes.default ; chaque trait, fraction du côté c, va de c / 4 à c / 2 du centre et a une
// épaisseur de c / 8.
Item {
    id: activite

    property bool running: true
    property int pas: 0
    readonly property int traits: 8
    readonly property real c: Math.min(width, height)
    readonly property alias minuteur: minuteur
    readonly property alias rayons: rayons

    implicitWidth: Theme.icons?.sizes.default ?? 0
    implicitHeight: implicitWidth

    Repeater {
        id: rayons
        model: activite.traits

        // Trait de rang index, posé au-dessus du centre puis pivoté de index huitièmes de tour ; son retard sur la
        // tête, en traits, fixe son opacité.
        Rectangle {
            id: trait
            required property int index

            x: (activite.width - width) / 2
            y: activite.height / 2 - activite.c / 2
            width: activite.c / 8
            height: activite.c / 4
            radius: width / 2
            color: Theme.color?.textSecondary ?? "transparent"
            opacity: 1 - ((activite.pas - index + activite.traits) % activite.traits) / activite.traits
            transform: Rotation {
                origin.x: trait.width / 2
                origin.y: activite.c / 2
                angle: trait.index * 360 / activite.traits
            }
        }
    }

    Timer {
        id: minuteur
        interval: (Theme.motion?.periods?.spinner ?? 0) / activite.traits
        running: activite.visible && activite.running && interval > 0
        repeat: true
        onTriggered: activite.pas = (activite.pas + 1) % activite.traits
    }
}
