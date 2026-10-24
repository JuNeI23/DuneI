import QtQuick
import "../Theme"
import "etats.js" as Etats

// Activite — indicateur d'activité indéterminée de la coque : il dit « ça travaille » dans l'interface.
// Rôle : se pose là où un travail sans durée connue est en cours (une recherche de réseaux dans un popover, un
// chargement dans un panneau), à côté de ce qu'il concerne. Il ne remplace pas le curseur de la souris : le
// curseur d'attente reste l'affaire du système et des applications, l'indicateur ne parle que de sa zone. Une
// progression mesurable prend la Progression. Trois grains en ligne grossissent et s'éclairent tour à tour, en
// vague continue de gauche à droite (conception, § 7.10) : le cycle d'un grain, d'une période, enchaîne une
// montée, une descente et un repos d'un tiers chacun, décalé d'un tiers sur son voisin. Chaque étape est un Pas,
// un ScaleAnimator et un OpacityAnimator sur le fil de rendu, image par image, sans pas discrets, selon la courbe
// InOutSine, que douceur() reproduit pour les poses. La couleur est l'accent du rôle de son conteneur (sélection
// active), ou activeMuted sous le modificateur inactive hérité (§ 7.5). Sobriété (D80) : les animations ne
// tournent que si l'indicateur est visible, ancêtre masqué compris, et en marche ; arrêté, il reprend aussitôt la
// pose de sa phase et ne coûte rien.
// Entrées : running, vrai par défaut ; phase, fraction du cycle que montre la pose arrêtée (0 par défaut ; la
//           planche fige ainsi l'indicateur à mi-cycle), sans effet en marche, où la vague part toujours du début
//           de son cycle ; visible.
// Sorties : anime, vrai si les animations doivent tourner, et marche, qui le suit un tour de boucle plus tard et les
//           mène ; accent, la couleur des grains ; repeteur, qui porte les trois grains (leur animation), lu par
//           les essais.
// Erreurs : aucune ; avant le chargement des tokens et du mouvement, les cotes sont nulles, les couleurs
//           transparentes et rien ne s'anime.
// Dépendances : Theme (icons.sizes, stateColors, motion.periods), etats.js (herite) ; le rôle (dnRole) et le
//               modificateur (dnInactive) viennent de la Surface englobante.
// Cotes : grains du tiers de icons.sizes.default, espacés d'un demi-grain, sur la hauteur icons.sizes.default. Au
//         repos, un grain tombe à l'échelle 0,6 et à l'opacité 0,35 : des proportions du dessin, non des cotes.
Item {
    id: activite

    property bool running: true
    property real phase: 0
    readonly property bool anime: visible && running && periode > 0
    // marche suit anime un tour de boucle plus tard : au chargement du mouvement, la période change en même temps
    // qu'anime, et un Animator qui partirait avant que sa durée ait suivi la période lirait une durée nulle.
    property bool marche: false
    readonly property real periode: Theme.motion?.periods?.spinner ?? 0
    readonly property real diametre: (Theme.icons?.sizes.default ?? 0) / 3
    readonly property real bas: 0.6
    readonly property real creux: 0.35
    readonly property string role: Etats.herite(activite, "dnRole", "surfaceWindow")
    readonly property bool inactif: Etats.herite(activite, "dnInactive", false)
    readonly property color accent: Theme.stateColors(role, inactif ? "activeMuted" : "active", "rest")?.fill
                                    ?? "transparent"
    readonly property alias repeteur: repeteur

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

    implicitWidth: 4 * diametre
    implicitHeight: 3 * diametre

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

    Row {
        anchors.centerIn: parent
        spacing: activite.diametre / 2

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

                width: activite.diametre
                height: width
                radius: width / 2
                color: activite.accent
                scale: pose(activite.phase)[0]
                opacity: pose(activite.phase)[1]

                // Arrêté, le grain reprend la pose de sa phase : la liaison est rétablie après la recopie des
                // Animators.
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
