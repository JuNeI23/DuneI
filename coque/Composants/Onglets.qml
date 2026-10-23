import QtQuick
import QtQuick.Templates as T
import "../Theme"

// Onglets — barre d'onglets de la coque, en contrôle segmenté à la manière de macOS.
// Rôle : habille le gabarit sans style T.TabBar, qui ne fournit aucun élément de contenu (conception, § 7.1 et
// 7.10). La barre est une piste en pilule au fond enfoncé, elevation.field.fill comme le champ, haute d'un
// contrôle (density.controlHeight), si bien qu'elle s'aligne sur un bouton voisin. Ses Onglet en sont les
// segments, côte à côte et de largeurs égales, celle du plus large ; ils se tiennent en retrait sur les quatre
// côtés, et la pastille du segment coché, en pilule elle aussi, reste concentrique à la piste (rayon interne =
// rayon externe − retrait). Le retrait n'est pas un token : c'est celui du bouton de l'interrupteur dans sa
// piste, (density.switchHeight − density.switchThumb) / 2 (2 px), qui loge une pilule claire dans une pilule
// pleine. L'accent est sur l'onglet coché, jamais sur la piste (Onglet, § 7.5) ; T.TabBar est une portée de
// focus, dont l'Onglet lit activeFocus pour choisir entre la sélection active et inactive.
// Entrées : les Onglet déclarés comme enfants ; currentIndex et le reste de l'API de T.TabBar.
// Sorties : currentIndex, l'onglet coché ; retrait, retrait des segments dans la piste ; largeurSegment,
// largeur commune des segments.
// Erreurs : aucune ; avant le chargement des tokens, les cotes sont nulles et la piste transparente.
// Dépendances : QtQuick.Templates (TabBar, qui donne à chaque segment la largeur de la rangée partagée en parts
// égales et la hauteur contentHeight), Theme (density, elevation), Onglet comme enfants.
T.TabBar {
    id: barre

    readonly property real retrait: ((Theme.density?.switchHeight ?? 0) - (Theme.density?.switchThumb ?? 0)) / 2
    readonly property real largeurSegment: Math.max(0, ...Array.from(contentChildren, o => o.implicitWidth))

    padding: retrait
    contentWidth: count * largeurSegment + Math.max(0, count - 1) * spacing
    contentHeight: (Theme.density?.controlHeight ?? 0) - 2 * retrait
    implicitWidth: contentWidth + leftPadding + rightPadding
    implicitHeight: contentHeight + topPadding + bottomPadding

    background: Rectangle {
        radius: height / 2
        color: Theme.elevation?.field?.fill ?? "transparent"
    }

    contentItem: Row {
        spacing: barre.spacing

        Repeater {
            model: barre.contentModel
        }
    }
}
