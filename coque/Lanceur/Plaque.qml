import QtQuick
import QtQuick.Effects
import "../Theme"

// Plaque — plaque d'accent qui dit la sélection du lanceur (ligne, médaillon, puce, bouton, vignette).
// Rôle : un aplat color.accent (ou la teinte demandée, color.error pour une confirmation), au reflet des médaillons
// (dégradé de material.highlight, à l'opacité material.medallionSheen, sur la part material.medallionSheenReach de
// la hauteur), au liseré haut material.edgeLight et au halo de sa teinte (ombre material.shadowBlur, décalée de
// material.shadowOffsetY, à 40 % comme la maquette v3). Elle glisse vers la géométrie cible au ressort reflow, et
// s'étire un peu dans le sens du trajet tant qu'elle va vite, puis se pose. Sa première cible valable est posée sans
// trajet, pour qu'elle n'arrive pas du coin du conteneur à l'ouverture.
// Entrées : cible, rect (x, y, largeur, hauteur) dans le repère du parent ; rayon, rayon des coins ; teinte,
// color.accent par défaut. Sorties : aucune autre que celles d'Item. Erreurs : aucune ; une cible de largeur nulle
// masque la plaque. Dépendances : Ressort, ColorSpring, Theme (color, material), QtQuick.Effects (RectangularShadow).
Item {
    id: plaque

    property rect cible
    property real rayon: 0
    property color teinte: Theme.color?.accent ?? "transparent"
    property bool posee: false

    x: rx.value
    y: ry.value
    width: rw.value
    height: rh.value
    visible: cible.width > 0

    // onCibleChanged — pose la plaque sur sa première cible valable, sans trajet. Entrées : aucune. Sortie : aucune.
    // Erreurs : aucune. Dépendances : rx, ry, rw, rh (poser).
    onCibleChanged: if (!posee && cible.width > 0) { posee = true; Qt.callLater(() => [rx, ry, rw, rh].forEach(r => r.poser())) }

    // La teinte (accent, ou erreur d'une confirmation) change en fondu, au ressort des états.
    ColorSpring { id: fondu; target: plaque.teinte }
    Ressort { id: rx; transition: "reflow"; cible: plaque.cible.x }
    Ressort { id: ry; transition: "reflow"; cible: plaque.cible.y }
    Ressort { id: rw; transition: "reflow"; cible: plaque.cible.width }
    Ressort { id: rh; transition: "reflow"; cible: plaque.cible.height }

    // Étirement dans le sens du trajet, proportionné à la vitesse, au plus 14 % en hauteur et 6 % en largeur.
    transform: Scale {
        origin.x: plaque.width / 2
        origin.y: plaque.height / 2
        yScale: (ry.value, 1 + Math.min(0.14, Math.abs(ry.vitesse()) / 3000))
        xScale: (rx.value, 1 + Math.min(0.06, Math.abs(rx.vitesse()) / 6000))
    }

    RectangularShadow {
        anchors.fill: parent
        radius: plaque.rayon
        blur: Theme.material?.shadowBlur ?? 0
        offset.y: Theme.material?.shadowOffsetY ?? 0
        color: fondu.value
        opacity: 0.4
    }
    Rectangle {
        anchors.fill: parent
        radius: plaque.rayon
        color: fondu.value
    }
    Rectangle {
        anchors.fill: parent
        radius: plaque.rayon
        opacity: Theme.material?.medallionSheen ?? 0
        gradient: Gradient {
            GradientStop { position: 0; color: Theme.material?.highlight ?? "transparent" }
            GradientStop { position: Theme.material?.medallionSheenReach ?? 0; color: "transparent" }
        }
    }
    Rectangle {
        x: plaque.rayon
        width: parent.width - 2 * plaque.rayon
        height: 1
        color: Theme.material?.edgeLight ?? "transparent"
    }
}
