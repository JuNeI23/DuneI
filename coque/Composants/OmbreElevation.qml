import QtQuick
import QtQuick.Effects
import "../Theme"

// OmbreElevation — ombre portée d'une surface flottante de la coque, qui la détache de ce qu'elle recouvre.
// Rôle : dessine, sous sa cible, un rectangle flouté au rayon de la cible, de la couleur material.shade, de la
// portée et du décalage vertical de l'ombre flottante des fenêtres (material.shadowBlur, material.shadowOffsetY),
// pour que les overlays de la coque aient la même ombre que les fenêtres flottantes que dessine Hyprland. Le
// niveau qui ne donne pas d'ombre (elevation.<niveau>.shadow faux : e2 la nuit) ne dessine rien ; marge vaut
// alors 0. OmbreControle reste l'ombre des contrôles blancs.
// Entrées : cible, élément ombré, dont l'ombre est un enfant ou une sœur : elle le recouvre et passe dessous
// (z négatif) ; niveau, niveau d'élévation qui décide de l'ombre, "e3" par défaut.
// Sorties : marge, espace que l'ombre déborde de la cible de chaque côté (portée plus décalage, 0 si l'ombre est
// invisible), à réserver autour de la cible dans une fenêtre qui la porte ; sinon celles de RectangularShadow.
// Erreurs : aucune ; avant le chargement des tokens, l'ombre est invisible et la marge nulle.
// Dépendances : QtQuick.Effects (RectangularShadow, Qt 6.9 et plus), Theme (elevation, material).
RectangularShadow {
    required property Item cible
    property string niveau: "e3"
    readonly property bool ombree: !!Theme.elevation?.[niveau]?.shadow
    readonly property real marge: ombree ? blur + Math.abs(offset.y) : 0

    visible: ombree
    anchors.fill: cible
    z: -1
    radius: cible.radius ?? 0
    blur: Theme.material?.shadowBlur ?? 0
    offset.y: Theme.material?.shadowOffsetY ?? 0
    color: Theme.material?.shade ?? "transparent"
}
