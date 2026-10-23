import QtQuick
import QtQuick.Templates as T
import "../Theme"

// Onglet — onglet d'une barre d'onglets, l'accent sur l'onglet actif et non sur la barre.
// Rôle : habille le gabarit sans style T.TabButton (conception, § 7.1). L'onglet coché est sélectionné : il
// prend l'accent quand sa barre a le focus, le fond neutre teinté sinon, et l'accent sans chroma sous le
// modificateur inactive (§ 7.5). T.TabBar, comme tout T.Control, est une portée de focus : il a activeFocus dès
// qu'un de ses onglets l'a. Hors d'une barre, l'onglet se comporte comme si son groupe avait le focus.
// Anneau de focus sur visualFocus ; un clic ne vole pas le focus d'un champ (focusPolicy Qt.TabFocus, § 7.3).
// Entrées : text, checked et le reste de l'API de T.TabButton.
// Sorties : etat, l'Etat de l'onglet (rôle, interaction, sélection, couleurs) ; focusDansGroupe, vrai quand la
// barre a le focus ou que l'onglet n'est dans aucune barre.
// Erreurs : aucune ; avant le chargement des tokens, les cotes sont nulles et les couleurs transparentes.
// Dépendances : QtQuick.Templates (TabButton, propriété attachée TabBar.tabBar), Theme (density, radius,
// space), Etat, AnneauFocus, Texte.
// Cotes : retrait horizontal space.scale[2] (12), comme le bouton.
T.TabButton {
    id: onglet

    readonly property alias etat: etat
    // La propriété attachée se lit ici, dans la portée de l'onglet : lue dans Etat, elle viserait Etat.
    readonly property bool focusDansGroupe: T.TabBar.tabBar?.activeFocus ?? true

    focusPolicy: Qt.TabFocus
    implicitWidth: implicitContentWidth + leftPadding + rightPadding
    implicitHeight: Theme.density?.controlHeight ?? 0
    horizontalPadding: Theme.space?.scale[2] ?? 0

    Etat {
        id: etat
        controle: onglet
        selectionne: onglet.checked
        focusDansGroupe: onglet.focusDansGroupe
    }

    background: Rectangle {
        radius: Theme.radius?.control ?? 0
        color: etat.fond

        AnneauFocus {
            cible: parent
            montre: onglet.visualFocus
            inactif: etat.inactif
        }
    }

    contentItem: Texte {
        text: onglet.text
        color: etat.texte
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
}
