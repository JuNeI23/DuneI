import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import "../Theme"
import "etats.js" as Etats

// Carte — plan de réglages d'une fenêtre de réglages : un fond opaque surfaceRaised aux coins arrondis, sans contour,
// dont les rangées s'empilent entre deux gardes.
// Rôle : regroupe des ReglageLigne ou des Ligne en une carte posée sur le plateau de la fenêtre. Bible, « Formes » :
// la carte prend radius.panel, sans bordure (le relief vient du seul écart de plan, pas d'un liseré). Relief « Doux »
// (application Paramètres, écart à la bible validé sur maquette) : la carte est à peine soulevée, par le liseré clair
// d'un pixel en haut (material.edgeLight, nul le jour) et une ombre courte (material.cardShadow, cardShadowBlur,
// cardShadowOffsetY), sans reflet ni liseré sombre ; le fond est alors peint par le Materiau du niveau card, de la
// même couleur surfaceRaised. Sans enfant et à la hauteur posée par l'appelant, la carte sert de simple plaque.
// Entrées : les rangées, déclarées comme enfants ; elles s'empilent sans écart dans une ColumnLayout, si bien que
// ReglageLigne et Ligne (Layout.fillWidth) occupent la largeur de la carte ; la largeur est laissée à
// l'appelant (width, ancres ou Layout.fillWidth) ; relief, vrai pour le relief « Doux », hérité par défaut de la
// propriété dnRelief d'un ancêtre (le conteneur de page de l'application Paramètres la déclare), faux sans elle : les
// cartes des autres fenêtres gardent l'aplat ; garde, la marge au-dessus et au-dessous des rangées, space.scale[0] par
// défaut, nulle pour une carte dont les rangées portent une plaque du curseur d'un bord à l'autre (Ligne.bordABord).
// Sorties : dnRole (« surfaceRaised ») et dnInactive, que lisent les contrôles et les plaques de survol des
// rangées pour se tenir un cran au-dessus du plan ; implicitHeight, rangées et gardes comprises.
// Erreurs : aucune ; avant le chargement des tokens, rayon et gardes sont nuls et le fond transparent.
// Choix : le fond est un aplat opaque de Theme.color.surfaceRaised et non une Surface, car une Surface de rôle
// surfaceRaised peint l'élévation e3 (le verre) : or la carte reste opaque, et ses filets prennent borderSubtle.
// Dépendances : Theme (color.surfaceRaised, radius.panel, space.scale, elevation.card, material), Materiau,
// etats.js (herite), QtQuick.Effects (RectangularShadow, Qt 6.9 et plus), QtQuick.Layouts.
Item {
    id: carte

    default property alias rangees: colonne.data
    readonly property string dnRole: "surfaceRaised"
    property real garde: Theme.space?.scale[0] ?? 0
    property bool relief: Etats.herite(carte, "dnRelief", false)

    implicitHeight: colonne.implicitHeight + 2 * garde

    Rectangle {
        anchors.fill: parent
        visible: !carte.relief
        radius: Theme.radius?.panel ?? 0
        color: Theme.color?.surfaceRaised ?? "transparent"
    }
    ColumnLayout { id: colonne; y: carte.garde; width: parent.width; spacing: 0 }
    // Relief « Doux » : l'ombre courte, sous le plan, puis le plan et son liseré clair. Chargé pour les seules cartes
    // en relief, pour que les autres ne portent ni ombre ni shader. Il est déclaré après la colonne, qui reste le
    // deuxième enfant de la carte (la coque d'essai la lit ainsi), et peint sous elle par son z négatif.
    Loader {
        anchors.fill: parent
        z: -1
        active: carte.relief
        sourceComponent: Item {
            RectangularShadow {
                anchors.fill: parent
                radius: Theme.radius?.panel ?? 0
                blur: Theme.material?.cardShadowBlur ?? 0
                offset.y: Theme.material?.cardShadowOffsetY ?? 0
                color: Theme.material?.cardShadow ?? "transparent"
            }
            Materiau { anchors.fill: parent; niveau: "card"; rayon: Theme.radius?.panel ?? 0; liserBas: false }
        }
    }
}
