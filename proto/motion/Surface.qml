import QtQuick
import QtQuick.Effects

// Surface — plan de matière à un niveau d'élévation (bible ch. 5).
// Rôle : fond à l'échelon E0–E3, sheen + liseré dès E2 (sheen seulement sous 80 px),
// ombre portée à E3 ; `floating` ajoute l'ombre deux couches de la couche 2.
// Entrées : level (0–3), radius, floating. Sortie : conteneur (propriété par défaut).
// Erreurs : aucune. Dépendances : Theme, QtQuick.Effects (RectangularShadow).
// Limite du prototype : pas de dithering du sheen.
Item {
    id: surf
    property int level: 2
    property real radius: Theme.rPanel
    property bool floating: false
    default property alias content: inner.data
    readonly property var lch: Theme.parse(Theme.tokens.elevation?.["e" + level])
    readonly property bool sheen: level >= 2 && height < 80
    readonly property bool edges: level >= 2

    RectangularShadow {
        anchors.fill: bg; visible: surf.level >= 3 || surf.floating
        radius: bg.radius; blur: 28; offset.y: 8; color: Qt.rgba(0, 0, 0, Theme.shade)
    }
    RectangularShadow {
        anchors.fill: bg; visible: surf.floating
        radius: bg.radius; blur: 4; offset.y: 1; color: Qt.rgba(0, 0, 0, Theme.shade)
    }
    Rectangle {
        id: bg
        anchors.fill: parent; radius: surf.radius
        color: Theme.toColor(surf.lch)
        gradient: surf.sheen ? sheenGradient : null
        Gradient {
            id: sheenGradient
            GradientStop { position: 0; color: Theme.ok(surf.lch.l + 0.02, surf.lch.c, surf.lch.h) }
            GradientStop { position: 1; color: Theme.toColor(surf.lch) }
        }
    }
    Rectangle {   // liseré clair, arête supérieure
        visible: surf.edges; height: 1; y: 0
        x: surf.radius; width: parent.width - 2 * surf.radius
        color: Qt.rgba(1, 1, 1, Theme.edgeLight)
    }
    Rectangle {   // liseré sombre, arête inférieure
        visible: surf.edges; height: 1; y: parent.height - 1
        x: surf.radius; width: parent.width - 2 * surf.radius
        color: Qt.rgba(0, 0, 0, Theme.edgeShadow)
    }
    Item { id: inner; anchors.fill: parent }
}
