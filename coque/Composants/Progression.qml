import QtQuick
import "../Theme"
import "etats.js" as Etats

// Progression — barre de progression déterminée de la coque.
// Rôle : une piste en pilule au fond du bureau (elevation.e0, comme celle du Curseur) et sa partie remplie, en
// pilule elle aussi (conception, § 7.10), de l'origine jusqu'à la fraction valeur de la largeur, à l'accent, ou
// à l'accent sans chroma sous le modificateur inactive. Elle n'a pas de mode indéterminé et ne prend jamais le
// focus.
// Entrées : valeur, fraction accomplie ; elle est bornée à [0, 1] et une valeur non numérique vaut 0.
// Sorties : aucune hors l'état visuel ; le remplissage est le premier enfant de la piste.
// Erreurs : aucune ; avant le chargement des tokens, les cotes sont nulles et les couleurs transparentes.
// Dépendances : Theme (density, elevation, stateColors), etats.js (herite) ; le rôle (dnRole) et le
// modificateur (dnInactive) viennent de la Surface englobante.
// Cotes : largeur implicite density.sliderWidth, épaisseur density.sliderTrack, rayons en demi-hauteur.
Rectangle {
    id: progression

    property real valeur: 0
    readonly property real fraction: Math.max(0, Math.min(1, valeur)) || 0
    readonly property string role: Etats.herite(progression, "dnRole", "surfaceWindow")
    readonly property bool inactif: Etats.herite(progression, "dnInactive", false)

    implicitWidth: Theme.density?.sliderWidth ?? 0
    implicitHeight: Theme.density?.sliderTrack ?? 0
    radius: height / 2
    color: Theme.elevation?.e0.fill ?? "transparent"

    Rectangle {
        width: progression.fraction * parent.width
        height: parent.height
        radius: parent.radius
        color: Theme.stateColors(progression.role, progression.inactif ? "activeMuted" : "active", "rest")?.fill
               ?? "transparent"
    }
}
