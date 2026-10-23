import QtQuick
import QtQuick.Templates as T
import "../Theme"
import "etats.js" as Etats

// Onglets — barre d'onglets de la coque, en contrôle segmenté à la manière de macOS.
// Rôle : habille le gabarit sans style T.TabBar, qui ne fournit aucun élément de contenu (conception, § 7.1 et 7.10).
// La barre est une piste au fond enfoncé, elevation.field.fill comme le champ, au rayon radius.control et haute d'un
// contrôle (density.controlHeight), si bien qu'elle s'aligne sur un bouton voisin. Ses Onglet en sont les
// segments, côte à côte et de largeurs égales, celle du plus large ; ils se tiennent en retrait sur les quatre
// côtés de density.segmentInset (2 px aux deux densités), et le segment coché est un rectangle arrondi au rayon
// radius.control moins ce retrait, concentrique à la piste (règle d'imbrication, § 7.10). L'accent est sur
// l'onglet coché, jamais sur la piste (Onglet, § 7.5) ; T.TabBar est une portée de focus, dont l'Onglet lit
// activeFocus pour choisir entre la sélection active et inactive. La barre est l'unique arrêt de tabulation
// (Onglet) : l'anneau de focus clavier entoure donc toute la piste, dès qu'un de ses segments a visualFocus, et
// non le segment, dont l'anneau chevaucherait le segment voisin (v0.6) ; il passe en focus.colorMuted sous le
// modificateur inactive.
// Entrées : les Onglet déclarés comme enfants ; currentIndex et le reste de l'API de T.TabBar.
// Sorties : currentIndex, l'onglet coché ; retrait, retrait des segments dans la piste ; largeurSegment,
// largeur commune des segments ; anneau, l'anneau de focus de la barre, lu par les essais.
// Erreurs : aucune ; avant le chargement des tokens, les cotes sont nulles et la piste transparente.
// Dépendances : QtQuick.Templates (TabBar, qui donne à chaque segment la largeur de la rangée partagée en parts
// égales et la hauteur contentHeight), Theme (density, elevation, radius), AnneauFocus, etats.js (herite), Onglet
// comme enfants.
T.TabBar {
    id: barre

    readonly property real retrait: Theme.density?.segmentInset ?? 0
    readonly property alias anneau: anneau
    readonly property real largeurSegment: Math.max(0, ...Array.from(contentChildren, o => o.implicitWidth))

    padding: retrait
    contentWidth: count * largeurSegment + Math.max(0, count - 1) * spacing
    contentHeight: (Theme.density?.controlHeight ?? 0) - 2 * retrait
    implicitWidth: contentWidth + leftPadding + rightPadding
    implicitHeight: contentHeight + topPadding + bottomPadding

    background: Rectangle {
        radius: Theme.radius?.control ?? 0
        color: Theme.elevation?.field?.fill ?? "transparent"

        AnneauFocus {
            id: anneau
            cible: parent
            montre: Array.from(barre.contentChildren).some(o => o.visualFocus)
            inactif: Etats.herite(barre, "dnInactive", false)
        }
    }

    contentItem: Row {
        spacing: barre.spacing

        Repeater {
            model: barre.contentModel
        }
    }
}
