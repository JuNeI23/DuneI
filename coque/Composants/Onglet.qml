import QtQuick
import QtQuick.Templates as T
import "../Theme"

// Onglet — onglet d'une barre d'onglets, l'accent sur l'onglet actif et non sur la barre.
// Rôle : habille le gabarit sans style T.TabButton (conception, § 7.1). Dans une barre Onglets, c'est un segment
// de contrôle segmenté (§ 7.10) : non coché, il n'a pas de fond, au repos, au survol (comme sur macOS) ni
// désactivé, et seule la pression le peint ; coché, c'est une pastille en pilule, concentrique à la piste de la
// barre. Hors d'une barre, il garde son fond dans tous les états, au rayon radius.control. L'onglet coché est
// sélectionné : il prend l'accent quand sa barre a le focus, le fond neutre teinté sinon, et l'accent sans
// chroma sous le modificateur inactive (§ 7.5). T.TabBar, comme tout T.Control, est une portée de focus : il a
// activeFocus dès qu'un de ses onglets l'a. Hors d'une barre, l'onglet se comporte comme si son groupe avait le
// focus.
// Une barre est un seul arrêt de tabulation, comme une liste (§ 7.3) : seul l'onglet coché accepte la
// tabulation, si bien que Tab et Maj+Tab quittent la barre et rendent à l'onglet coché sa sélection inactive ;
// les flèches gauche et droite cochent l'onglet voisin et y portent le focus. Si aucun onglet n'est coché, ou si
// l'onglet coché est désactivé et ne peut donc plus prendre le focus, tous les onglets acceptent la tabulation :
// la barre n'est jamais privée d'arrêt. Hors d'une barre, l'onglet est un arrêt ordinaire. Anneau de focus sur
// visualFocus ; un clic ne vole pas le focus d'un champ (Qt.TabFocus).
// Entrées : text, checked et le reste de l'API de T.TabButton.
// Sorties : etat, l'Etat de l'onglet (rôle, interaction, sélection, couleurs) ; barre, la T.TabBar qui le
// porte, null hors d'une barre ; focusDansGroupe, vrai quand la barre a le focus ou que l'onglet n'est dans
// aucune barre.
// Erreurs : aucune ; avant le chargement des tokens, les cotes sont nulles et les couleurs transparentes.
// Dépendances : QtQuick.Templates (TabButton, propriété attachée TabBar.tabBar), Theme (density, radius,
// space), Etat, AnneauFocus, Texte ; Onglets comme barre, dont la piste et le retrait encadrent le segment.
// Cotes : retrait horizontal space.scale[2] (12), comme le bouton ; rayon en demi-hauteur dans une barre,
// radius.control hors d'une barre.
T.TabButton {
    id: onglet

    readonly property alias etat: etat
    // La propriété attachée se lit ici, dans la portée de l'onglet : lue dans Etat, elle viserait Etat.
    readonly property T.TabBar barre: T.TabBar.tabBar
    readonly property bool focusDansGroupe: barre?.activeFocus ?? true

    focusPolicy: !barre || checked || !barre.currentItem?.enabled ? Qt.TabFocus : Qt.NoFocus
    Keys.onLeftPressed: voisin(-1)
    Keys.onRightPressed: voisin(1)

    // voisin — coche l'onglet voisin dans la barre et lui donne un focus clavier, qui montre son anneau.
    // Entrée : pas, -1 pour l'onglet de gauche, 1 pour celui de droite ; aux extrémités, l'onglet coché reste.
    // Sortie : aucune. Erreurs : aucune ; hors d'une barre, rien ne se passe.
    // Dépendances : barre (T.TabBar : setCurrentIndex, currentIndex, count, currentItem).
    function voisin(pas: int): void {
        if (!barre) return
        barre.setCurrentIndex(Math.max(0, Math.min(barre.count - 1, barre.currentIndex + pas)))
        barre.currentItem.forceActiveFocus(Qt.TabFocusReason)
    }
    implicitWidth: implicitContentWidth + leftPadding + rightPadding
    implicitHeight: Theme.density?.controlHeight ?? 0
    horizontalPadding: Theme.space?.scale[2] ?? 0

    Etat {
        id: etat
        controle: onglet
        selectionne: onglet.checked
        focusDansGroupe: onglet.focusDansGroupe
    }

    // Un segment non coché d'une barre n'a de fond qu'à la pression : au repos comme au survol, la piste se lit.
    background: Rectangle {
        radius: onglet.barre ? height / 2 : Theme.radius?.control ?? 0
        color: !onglet.barre || onglet.checked || etat.interaction === "pressed" ? etat.fond : "transparent"

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
