import QtQuick
import QtQuick.Effects
import "../Theme"

// OmbreElevation — ombre portée d'une surface flottante de la coque, qui la détache de ce qu'elle recouvre.
// Rôle : dessine, sous sa cible, un rectangle flouté au rayon de la cible, de la couleur material.shade, de la
// portée et du décalage vertical de l'ombre flottante des fenêtres (material.shadowBlur, material.shadowOffsetY),
// pour que les overlays de la coque aient la même ombre que les fenêtres flottantes que dessine Hyprland. Sous une
// surface de verre, l'ombre est évidée sous la cible (D103) : sans cela, elle transparaîtrait à travers le verre et
// assombrirait la surface ; elle ne paraît alors qu'au-delà du bord. Le niveau qui ne donne pas d'ombre
// (elevation.<niveau>.shadow faux : e2 la nuit) ne dessine rien ; marge vaut alors 0. OmbreControle reste l'ombre
// des contrôles blancs.
// Entrées : cible, élément ombré, dont l'ombre est un enfant ou une sœur : elle le déborde de sa marge et passe
// dessous (z négatif) ; niveau, niveau d'élévation qui décide de l'ombre, "e3" par défaut ; evidee, vrai pour
// retirer l'ombre sous la cible (surface de verre), faux par défaut.
// Sorties : marge, espace que l'ombre déborde de la cible de chaque côté (portée plus décalage, 0 si l'ombre est
// invisible), à réserver autour de la cible dans une fenêtre qui la porte ; ombree, vrai si le niveau porte une
// ombre.
// Erreurs : aucune ; avant le chargement des tokens, l'ombre est invisible et la marge nulle.
// Dépendances : QtQuick.Effects (RectangularShadow, Qt 6.9 et plus ; MultiEffect pour l'évidement), Theme
// (elevation, material).
Item {
    id: ombre

    required property Item cible
    property string niveau: "e3"
    property bool evidee: false
    readonly property bool ombree: !!Theme.elevation?.[niveau]?.shadow
    readonly property real flou: Theme.material?.shadowBlur ?? 0
    readonly property real decalage: Theme.material?.shadowOffsetY ?? 0
    readonly property real marge: ombree ? flou + Math.abs(decalage) : 0
    readonly property real rayon: cible.radius ?? 0

    visible: ombree
    anchors.fill: cible
    anchors.margins: -marge
    z: -1

    // L'ombre pleine ; évidée, elle n'est que la source de l'effet, rendue dans une couche de la taille de l'ombre.
    Item {
        id: pleine
        anchors.fill: parent
        visible: !ombre.evidee
        layer.enabled: ombre.evidee
        RectangularShadow {
            anchors.fill: parent
            anchors.margins: ombre.marge
            radius: ombre.rayon
            blur: ombre.flou
            offset.y: ombre.decalage
            color: Theme.material?.shade ?? "transparent"
        }
    }

    // Masque de l'évidement : la forme de la cible, en noir opaque, retranchée de l'ombre (maskInverted).
    Item {
        id: forme
        anchors.fill: parent
        visible: false
        layer.enabled: ombre.evidee
        Rectangle { anchors.fill: parent; anchors.margins: ombre.marge; radius: ombre.rayon; color: "black" }
    }

    MultiEffect {
        anchors.fill: parent
        visible: ombre.evidee
        source: pleine
        maskEnabled: true
        maskSource: forme
        maskInverted: true
    }
}
