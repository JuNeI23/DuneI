import QtQuick
import QtQuick.Shapes
import "../Theme"
import "etats.js" as Etats

// Activite — indicateur d'activité indéterminée de la coque : il dit « ça travaille » dans l'interface.
// Rôle : se pose là où un travail sans durée connue est en cours (une recherche de réseaux dans un popover, un
// chargement dans un panneau), à côté de ce qu'il concerne. Il ne remplace pas le curseur de la souris : le
// curseur d'attente reste l'affaire du système et des applications, l'indicateur ne parle que de sa zone. Une
// progression mesurable prend la Progression. Trois formes sont proposées au choix (conception, § 7.10), chacune
// dans son propre Component chargé par un Loader, pour que les formes écartées se retirent d'un bloc :
// - « arc » : un anneau ouvert aux trois quarts, d'un trait fin, qui tourne en continu, un tour par période ;
// - « grains » : trois points qui grossissent et s'éclairent tour à tour, en vague continue ; le cycle d'un point
//   enchaîne une montée, une descente et un repos d'un tiers de période chacun, décalé d'un tiers sur son voisin ;
// - « sable » : une courte pastille qui glisse d'un bout à l'autre d'une piste enfoncée, en va-et-vient adouci,
//   comme la progression indéterminée de macOS ; une traversée par période.
// Toutes s'animent par des Animators (RotationAnimator, ScaleAnimator et OpacityAnimator, XAnimator) sur le fil de
// rendu, image par image, sans pas discrets ; leurs étapes suivent la courbe InOutSine, que douceur() reproduit
// pour les poses. La couleur est l'accent du rôle de son conteneur (sélection active), ou activeMuted sous le
// modificateur inactive hérité (§ 7.5). Sobriété (D80) : les animations ne tournent que si l'indicateur est
// visible, ancêtre masqué compris, et en marche ; arrêté, il reprend aussitôt la pose de sa phase et ne coûte rien.
// Entrées : forme, "arc" (par défaut), "grains" ou "sable" ; running, vrai par défaut ; phase, fraction du cycle
//           que montre la pose arrêtée (0 par défaut ; la planche fige ainsi une forme à mi-cycle), sans effet sur
//           une forme en marche, qui part toujours du début de son cycle ; visible ; largeur et hauteur fournies,
//           que la forme occupe.
// Sorties : anime, vrai si les animations doivent tourner, et marche, qui le suit un tour de boucle plus tard et les
//           mène ; accent, la couleur de la forme ; dessin, l'élément chargé (son animation, et selon la forme
//           trace et courbe, repeteur, ou pastille), lu par les essais.
// Erreurs : aucune ; une forme inconnue ne dessine rien ; avant le chargement des tokens et du mouvement, les cotes
//           sont nulles, les couleurs transparentes et rien ne s'anime.
// Dépendances : QtQuick.Shapes (arc), Theme (icons.sizes, density, elevation, stateColors, motion.periods),
//               etats.js (herite) ; le rôle (dnRole) et le modificateur (dnInactive) viennent de la Surface englobante.
// Cotes : arc, carré de icons.sizes.default, trait du dixième du côté ; grains, points du tiers de
//         icons.sizes.default espacés d'un demi-point, sur la hauteur icons.sizes.default ; sable, largeur
//         implicite density.sliderWidth, épaisseur density.sliderTrack, pastille du quart de la piste. Les
//         grains au repos tombent à l'échelle 0,6 et à l'opacité 0,35 : des proportions du dessin, non des cotes.
Item {
    id: activite

    property string forme: "arc"
    property bool running: true
    property real phase: 0
    readonly property bool anime: visible && running && periode > 0
    // marche suit anime un tour de boucle plus tard : au chargement du mouvement, la période change en même temps
    // qu'anime, et un Animator qui partirait avant que sa durée ait suivi la période lirait une durée nulle.
    property bool marche: false
    readonly property real periode: Theme.motion?.periods?.spinner ?? 0
    readonly property real cote: Theme.icons?.sizes.default ?? 0
    readonly property real bas: 0.6
    readonly property real creux: 0.35
    readonly property string role: Etats.herite(activite, "dnRole", "surfaceWindow")
    readonly property bool inactif: Etats.herite(activite, "dnInactive", false)
    readonly property color accent: Theme.stateColors(role, inactif ? "activeMuted" : "active", "rest")?.fill
                                    ?? "transparent"
    readonly property Item dessin: chargeur.item

    // douceur — avancée adoucie d'une étape, la courbe InOutSine des Animators.
    // Entrée : t, fraction de l'étape écoulée, de 0 à 1. Sortie : fraction du chemin parcouru, de 0 à 1.
    // Erreurs : aucune. Dépendances : aucune.
    function douceur(t: real): real {
        return (1 - Math.cos(Math.PI * t)) / 2
    }

    // vague — hauteur d'un grain dans sa vague : 0 au repos, 1 au sommet. Son cycle enchaîne une montée, une
    // descente et un repos d'un tiers chacun, décalé d'un tiers par rang.
    // Entrées : rang, 0 à 2 de gauche à droite ; p, phase dans le cycle. Sortie : fraction de 0 à 1.
    // Erreurs : aucune. Dépendances : douceur.
    function vague(rang: int, p: real): real {
        const e = Math.floor(3 * p), s = ((e - rang) % 3 + 3) % 3, de = [0, 1, 0][s]
        return de + ([1, 0, 0][s] - de) * douceur(3 * p - e)
    }

    Binding on marche { value: activite.anime; delayed: true }

    implicitWidth: chargeur.item?.implicitWidth ?? 0
    implicitHeight: chargeur.item?.implicitHeight ?? 0

    // Pas — une étape du cycle d'un grain : son échelle et son opacité vont ensemble d'une pose à l'autre.
    // Entrées : cible, le grain ; de et a, poses [échelle, opacité] de départ et d'arrivée ; duree, en ms.
    // Sortie : l'animation de l'étape, sur le fil de rendu. Erreurs : aucune. Dépendances : aucune.
    component Pas: ParallelAnimation {
        id: pas
        required property Item cible
        required property var de
        required property var a
        required property real duree
        ScaleAnimator {
            target: pas.cible; from: pas.de[0]; to: pas.a[0]; duration: pas.duree; easing.type: Easing.InOutSine
        }
        OpacityAnimator {
            target: pas.cible; from: pas.de[1]; to: pas.a[1]; duration: pas.duree; easing.type: Easing.InOutSine
        }
    }

    Loader {
        id: chargeur
        anchors.fill: parent
        sourceComponent: ({ arc: arc, grains: grains, sable: sable })[activite.forme] ?? null
    }

    // Forme « arc » : un anneau ouvert de 270°, tracé une fois, que la rotation de l'élément fait tourner. Le
    // tracé est porté par un Item, car une Shape impose sa propre taille implicite, celle de ses chemins.
    Component {
        id: arc

        Item {
            id: dessinArc

            readonly property alias animation: tour
            readonly property alias trace: trace
            readonly property alias courbe: courbe

            implicitWidth: activite.cote
            implicitHeight: activite.cote
            rotation: 360 * activite.phase

            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    id: trace
                    strokeColor: activite.accent
                    strokeWidth: Math.min(dessinArc.width, dessinArc.height) / 10
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap

                    PathAngleArc {
                        id: courbe
                        centerX: dessinArc.width / 2
                        centerY: dessinArc.height / 2
                        radiusX: (Math.min(dessinArc.width, dessinArc.height) - trace.strokeWidth) / 2
                        radiusY: radiusX
                        startAngle: -90
                        sweepAngle: 270
                    }
                }
            }

            // Arrêté, l'arc reprend la pose de sa phase : la liaison est rétablie après la recopie de l'Animator.
            RotationAnimator {
                id: tour
                target: dessinArc
                from: 0
                to: 360
                duration: activite.periode
                loops: Animation.Infinite
                running: activite.marche
                onRunningChanged: if (!running) dessinArc.rotation = Qt.binding(() => 360 * activite.phase)
            }
        }
    }

    // Forme « grains » : trois points en ligne, chacun porteur de sa propre vague de trois étapes.
    Component {
        id: grains

        Item {
            id: dessinGrains

            readonly property alias repeteur: repeteur
            readonly property real diametre: activite.cote / 3

            implicitWidth: 4 * diametre
            implicitHeight: activite.cote

            Row {
                anchors.centerIn: parent
                spacing: dessinGrains.diametre / 2

                Repeater {
                    id: repeteur
                    model: 3

                    Rectangle {
                        id: grain

                        required property int index
                        readonly property alias animation: cycle
                        readonly property real tiers: activite.periode / 3

                        // pose — échelle et opacité du grain à une phase de son cycle.
                        // Entrée : p, phase. Sortie : [échelle, opacité]. Erreurs : aucune.
                        // Dépendances : activite (vague, bas, creux).
                        function pose(p: real): var {
                            const v = activite.vague(index, p)
                            return [activite.bas + (1 - activite.bas) * v, activite.creux + (1 - activite.creux) * v]
                        }

                        width: dessinGrains.diametre
                        height: width
                        radius: width / 2
                        color: activite.accent
                        scale: pose(activite.phase)[0]
                        opacity: pose(activite.phase)[1]

                        // Arrêté, le grain reprend la pose de sa phase, comme l'arc.
                        SequentialAnimation {
                            id: cycle
                            loops: Animation.Infinite
                            running: activite.marche
                            onRunningChanged: if (!running) {
                                grain.scale = Qt.binding(() => grain.pose(activite.phase)[0])
                                grain.opacity = Qt.binding(() => grain.pose(activite.phase)[1])
                            }
                            Pas { cible: grain; de: grain.pose(0); a: grain.pose(1 / 3); duree: grain.tiers }
                            Pas { cible: grain; de: grain.pose(1 / 3); a: grain.pose(2 / 3); duree: grain.tiers }
                            Pas { cible: grain; de: grain.pose(2 / 3); a: grain.pose(1); duree: grain.tiers }
                        }
                    }
                }
            }
        }
    }

    // Forme « sable » : une piste enfoncée, comme celle d'un champ, et une pastille qui la parcourt.
    Component {
        id: sable

        Rectangle {
            id: piste

            readonly property alias animation: allerRetour
            readonly property alias pastille: pastille
            readonly property real course: width - pastille.width

            implicitWidth: Theme.density?.sliderWidth ?? 0
            implicitHeight: Theme.density?.sliderTrack ?? 0
            radius: height / 2
            color: Theme.elevation?.field?.fill ?? "transparent"
            // Les Animators lisent leurs bornes au départ : une piste redimensionnée relance le va-et-vient.
            onCourseChanged: if (allerRetour.running) allerRetour.restart()

            Rectangle {
                id: pastille
                width: piste.width / 4
                height: piste.height
                radius: height / 2
                color: activite.accent
                x: piste.course * activite.douceur(activite.phase)
            }

            SequentialAnimation {
                id: allerRetour
                loops: Animation.Infinite
                running: activite.marche
                onRunningChanged: if (!running)
                    pastille.x = Qt.binding(() => piste.course * activite.douceur(activite.phase))
                XAnimator {
                    target: pastille; from: 0; to: piste.course; duration: activite.periode
                    easing.type: Easing.InOutSine
                }
                XAnimator {
                    target: pastille; from: piste.course; to: 0; duration: activite.periode
                    easing.type: Easing.InOutSine
                }
            }
        }
    }
}
