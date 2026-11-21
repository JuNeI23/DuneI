import QtQuick
import QtQuick.Templates as T
import "../Theme"

// Onglets — barre d'onglets de la coque, en contrôle segmenté à la manière de macOS.
// Rôle : habille le gabarit sans style T.TabBar, qui ne fournit aucun élément de contenu (conception, § 7.1 et 7.10).
// La barre est une piste au fond enfoncé, elevation.field.fill comme le champ, au rayon radius.control et haute d'un
// contrôle (density.controlHeight), si bien qu'elle s'aligne sur un bouton voisin. Ses Onglet en sont les
// segments, côte à côte et de largeurs égales, celle du plus large ; ils se tiennent en retrait sur les quatre
// côtés de density.segmentInset (2 px aux deux densités), et le segment coché est un rectangle arrondi au rayon
// radius.control moins ce retrait, concentrique à la piste (règle d'imbrication, § 7.10). L'accent est sur
// le segment sous le curseur, jamais sur la piste (Onglet, § 7.5, L2-73). La barre est l'unique arrêt de tabulation
// (Onglet) ; elle n'a pas d'anneau de focus : au clavier, le curseur se pose sur le segment coché.
// Quand le thème traite les contrôles blancs (controls.offTrack, au jour), la piste prend le gris plein
// color.controlOff, sur lequel le segment coché, blanc, cerné et ombré, se détache (Onglet).
// Entrées : les Onglet déclarés comme enfants ; currentIndex et le reste de l'API de T.TabBar.
// Sorties : currentIndex, l'onglet coché ; retrait, retrait des segments dans la piste ; largeurSegment,
// largeur commune des segments.
// Erreurs : aucune ; avant le chargement des tokens, les cotes sont nulles et la piste transparente.
// Dépendances : QtQuick.Templates (TabBar, qui donne à chaque segment la largeur de la rangée partagée en parts
// égales et la hauteur contentHeight), Theme (density, elevation, radius, controls, color.controlOff), Onglet comme
// enfants.
T.TabBar {
    id: barre

    readonly property real retrait: Theme.density?.segmentInset ?? 0
    readonly property real largeurSegment: Math.max(0, ...Array.from(contentChildren, o => o.implicitWidth))

    padding: retrait
    contentWidth: count * largeurSegment + Math.max(0, count - 1) * spacing
    contentHeight: (Theme.density?.controlHeight ?? 0) - 2 * retrait
    implicitWidth: contentWidth + leftPadding + rightPadding
    implicitHeight: contentHeight + topPadding + bottomPadding

    background: Rectangle {
        radius: Theme.radius?.control ?? 0
        color: (Theme.controls?.offTrack ? Theme.color?.controlOff : Theme.elevation?.field?.fill) ?? "transparent"
    }

    contentItem: Row {
        spacing: barre.spacing

        Repeater {
            model: barre.contentModel
        }
    }
}
