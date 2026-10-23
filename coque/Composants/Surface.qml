import QtQuick
import "../Theme"
import "etats.js" as Etats

// Surface — fond d'un conteneur de la coque et source des propriétés héritées par ses descendants.
// Rôle : peint le fond de son niveau d'élévation et déclare son rôle de fond (dnRole) et le modificateur
// inactive (dnInactive), que les composants descendants lisent par Etats.herite au lieu de les recevoir à la
// main (conception, § 7.4 et 7.5).
// Entrées : role, rôle de fond (surfaceWindow, surfacePanel, surfaceRaised), surfaceWindow par défaut ;
//           elevation, niveau d'élévation peint (e0 à e3), e0 par défaut ; dnInactive, modificateur inactive,
//           hérité de la Surface englobante par défaut, faux à la racine.
// Sorties : dnRole, rôle lu par les descendants ; dnInactive.
// Erreurs : aucune ; avant le chargement des tokens ou pour un niveau inconnu, le fond reste transparent.
// Dépendances : Theme (elevation), etats.js (herite).
// Import : "../Theme" désigne le Theme posé à côté de Composants sous la racine de la coque, donc le même
// singleton que celui de la coque.
Item {
    id: surface

    property string role: "surfaceWindow"
    property string elevation: "e0"
    property bool dnInactive: Etats.herite(surface, "dnInactive", false)
    readonly property string dnRole: role

    Rectangle {
        anchors.fill: parent
        color: Theme.elevation?.[surface.elevation]?.fill ?? "transparent"
    }
}
