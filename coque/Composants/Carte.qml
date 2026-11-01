import QtQuick
import "../Theme"

// Carte — plan de réglages de la fenêtre Réseau : un fond opaque surfaceRaised aux coins arrondis, sans contour,
// dont les rangées s'empilent entre deux gardes.
// Rôle : regroupe des ReglageLigne ou des Ligne en une carte posée sur le plateau de la fenêtre. Bible, « Formes » :
// la carte prend radius.panel, sans bordure (le relief vient du seul écart de plan, pas d'un liseré).
// Entrées : les rangées, déclarées comme enfants ; elles s'empilent sans écart ; la largeur est laissée à
// l'appelant (width, ancres ou Layout.fillWidth).
// Sorties : dnRole (« surfaceRaised ») et dnInactive, que lisent les contrôles et les plaques de survol des
// rangées pour se tenir un cran au-dessus du plan ; implicitHeight, rangées et gardes comprises.
// Erreurs : aucune ; avant le chargement des tokens, rayon et gardes sont nuls et le fond transparent.
// Choix : le fond est un aplat opaque de Theme.color.surfaceRaised et non une Surface, car une Surface de rôle
// surfaceRaised peint l'élévation e3 (le verre) : or la carte reste opaque, et ses filets prennent borderSubtle.
// Dépendances : Theme (color.surfaceRaised, radius.panel, space.scale), etats.js (herite).
Item {
    id: carte

    default property alias rangees: colonne.data
    readonly property string dnRole: "surfaceRaised"
    readonly property real garde: Theme.space?.scale[0] ?? 0

    implicitHeight: colonne.implicitHeight + 2 * garde

    Rectangle {
        anchors.fill: parent
        radius: Theme.radius?.panel ?? 0
        color: Theme.color?.surfaceRaised ?? "transparent"
    }
    Column { id: colonne; y: carte.garde; width: parent.width }
}
