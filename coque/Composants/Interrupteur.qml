import QtQuick
import QtQuick.Templates as T
import "../Theme"

// Interrupteur — interrupteur de la coque : une piste en pilule et son bouton, suivis d'un libellé facultatif.
// Rôle : habille le gabarit sans style T.Switch (conception, § 7.1), à la forme de macOS (§ 7.10). La piste
// prend le fond de son Etat : coché, l'accent (l'accent sans chroma sous le modificateur inactive, § 7.5) ;
// décoché, le fond du cran au-dessus du conteneur. Le bouton est rond et clair dans les deux états : il prend
// le texte non sélectionné du même état, c'est-à-dire color.textPrimary, terni seulement quand l'interrupteur
// est désactivé. Le thème étant sombre, ce texte est clair ; un rôle propre (knob) viendra si un thème clair
// apparaît. La position du bouton est l'indice non coloré : l'état ne se lit jamais par la couleur seule
// (bible, annexe E). Elle suit visualPosition, qui accompagne aussi le glissement. L'anneau de focus entoure la
// piste, sur visualFocus ; un clic ne vole pas le focus d'un champ (focusPolicy Qt.TabFocus, § 7.3).
// Entrées : text, checked et le reste de l'API de T.Switch.
// Sorties : etat, l'Etat de l'interrupteur (rôle, interaction, sélection, couleurs).
// Erreurs : aucune ; avant le chargement des tokens, les cotes sont nulles et les couleurs transparentes.
// Dépendances : QtQuick.Templates, Theme (density, space, stateColors), Etat, AnneauFocus, Texte.
// Cotes : piste de density.switchWidth sur density.switchHeight, bouton de density.switchThumb, centré dans
// la hauteur de la piste, donc à (switchHeight - switchThumb) / 2 de son bord (2 px) ; rayons en
// demi-hauteur ; écart entre la piste et le libellé space.scale[1] (8).
T.Switch {
    id: interrupteur

    readonly property alias etat: etat

    focusPolicy: Qt.TabFocus
    implicitWidth: implicitContentWidth + leftPadding + rightPadding
    implicitHeight: Math.max(Theme.density?.controlHeight ?? 0, implicitIndicatorHeight + topPadding + bottomPadding)
    spacing: Theme.space?.scale[1] ?? 0

    Etat {
        id: etat
        controle: interrupteur
        selectionne: interrupteur.checked
    }

    indicator: Rectangle {
        id: piste
        x: interrupteur.leftPadding
        y: interrupteur.topPadding + (interrupteur.availableHeight - height) / 2
        implicitWidth: Theme.density?.switchWidth ?? 0
        implicitHeight: Theme.density?.switchHeight ?? 0
        radius: height / 2
        color: etat.fond

        // Le bouton, premier enfant de la piste (la coque d'essai le lit ainsi), avec la même marge en tête,
        // en pied et aux deux bouts de sa course.
        Rectangle {
            readonly property real marge: (piste.height - height) / 2
            x: marge + interrupteur.visualPosition * (piste.width - width - 2 * marge)
            y: marge
            width: Theme.density?.switchThumb ?? 0
            height: width
            radius: height / 2
            color: Theme.stateColors(etat.role, "none", etat.interaction)?.text ?? "transparent"
        }

        AnneauFocus {
            cible: piste
            montre: interrupteur.visualFocus
            inactif: etat.inactif
        }
    }

    // Le libellé se tient sur le conteneur, hors de la piste : il prend le texte non sélectionné du même état.
    contentItem: Texte {
        leftPadding: interrupteur.indicator.width + (interrupteur.text ? interrupteur.spacing : 0)
        text: interrupteur.text
        color: Theme.stateColors(etat.role, "none", etat.interaction)?.text ?? "transparent"
        verticalAlignment: Text.AlignVCenter
    }
}
