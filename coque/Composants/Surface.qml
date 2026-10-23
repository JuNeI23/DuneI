import QtQuick
import "../Theme"
import "etats.js" as Etats

// Surface — fond d'un conteneur de la coque et source des propriétés héritées par ses descendants.
// Rôle : peint le fond de son niveau d'élévation et déclare son rôle de fond (dnRole) et le modificateur
// inactive (dnInactive), que les composants descendants lisent par Etats.herite au lieu de les recevoir à la
// main (conception, § 7.4 et 7.5).
// Entrées : role, rôle de fond (surfaceWindow, surfacePanel, surfaceRaised), surfaceWindow par défaut ;
//           elevation, niveau d'élévation peint (e0 à e3), déduit du rôle par Etats.niveau par défaut
//           (surfaceWindow e1, surfacePanel e2, surfaceRaised e3) ; dnInactive, modificateur inactive,
//           hérité de la Surface englobante par défaut, faux à la racine ; radius, rayon des coins du fond,
//           0 par défaut, à lire dans Theme.radius.
// Sorties : dnRole, rôle lu par les descendants ; dnInactive.
// Erreurs : aucune ; avant le chargement des tokens ou pour un niveau inconnu, le fond reste transparent.
// Dépendances : Theme (elevation), etats.js (herite, niveau).
// Import : "../Theme" désigne le Theme posé à côté de Composants sous la racine de la coque, donc le même
// singleton que celui de la coque.
Item {
    id: surface

    property string role: "surfaceWindow"
    property string elevation: Etats.niveau(role)
    property bool dnInactive: Etats.herite(surface, "dnInactive", false)
    readonly property string dnRole: role
    property alias radius: fond.radius

    Rectangle {
        id: fond
        anchors.fill: parent
        color: Theme.elevation?.[surface.elevation]?.fill ?? "transparent"
    }
}
