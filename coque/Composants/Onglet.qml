import QtQuick
import QtQuick.Templates as T
import Quickshell
import "../Theme"
import "etats.js" as Etats

// Onglet — onglet d'une barre d'onglets, l'accent sur l'onglet actif et non sur la barre.
// Rôle : habille le gabarit sans style T.TabButton (conception, § 7.1). Dans une barre Onglets, c'est un segment
// de contrôle segmenté (§ 7.10) : non coché et hors du curseur, il n'a pas de fond, au repos, au survol ni
// désactivé, et seule la pression le peint ; coché, c'est un rectangle arrondi au rayon radius.control moins le
// retrait de la barre, concentrique à la piste. Hors d'une barre, il garde son fond dans tous les états, au
// rayon radius.control. L'onglet suit le curseur de sa vue (L2-73) : survolé ou focalisé au clavier, il porte
// l'aplat d'accent de la plaque (color.accent, ou l'accent sans chroma sous le modificateur inactive). L'onglet
// coché est la valeur choisie : hors du curseur, il garde le fond neutre teinté de la sélection inactive, si bien
// que le survol d'un autre segment ne laisse jamais deux segments à l'accent ; au focus clavier de la barre, c'est
// lui qui porte le curseur, seul arrêt de tabulation.
// Une barre est un seul arrêt de tabulation, comme une liste (§ 7.3) : seul l'onglet coché accepte la
// tabulation, si bien que Tab et Maj+Tab quittent la barre et rendent à l'onglet coché sa sélection inactive ;
// les flèches gauche et droite cochent l'onglet voisin et y portent le focus, donc le curseur. Si aucun onglet
// n'est coché, ou si l'onglet coché est désactivé et ne peut donc plus prendre le focus, tous les onglets acceptent
// la tabulation : la barre n'est jamais privée d'arrêt. Hors d'une barre, l'onglet est un arrêt ordinaire. Aucun
// anneau de focus : le curseur le remplace. Un clic ne vole pas le focus d'un champ (Qt.TabFocus).
// Quand le thème traite les contrôles blancs (au jour), un fond peint hors accent est cerné du contour
// controls.outline, et le segment coché d'une barre porte en plus l'ombre controls.shadow : blanc sur le rail gris,
// il se lit d'un coup d'œil, comme le contrôle segmenté de macOS.
// Entrées : text, checked et le reste de l'API de T.TabButton.
// Sorties : etat, l'Etat de l'onglet (rôle, interaction, sélection, couleurs) ; barre, la T.TabBar qui le
// porte, null hors d'une barre.
// Erreurs : aucune ; avant le chargement des tokens, les cotes sont nulles et les couleurs transparentes.
// Dépendances : QtQuick.Templates (TabButton, propriété attachée TabBar.tabBar), Quickshell (QsWindow : rapport de
// pixels, pour le filet), Theme (density, radius, space, controls, hairline, ColorSpring), etats.js (contoure), Etat,
// VueCurseur (par Etat), OmbreControle, Texte ; Onglets comme barre, dont la piste et le retrait encadrent le segment.
// Cotes : retrait horizontal space.scale[2] (12), comme le bouton ; rayon radius.control hors d'une barre,
// diminué du retrait de la barre (Onglets.retrait) dans une barre.
T.TabButton {
    id: onglet

    readonly property alias etat: etat
    // La propriété attachée se lit ici, dans la portée de l'onglet : lue dans Etat, elle viserait Etat.
    readonly property T.TabBar barre: T.TabBar.tabBar

    focusPolicy: !barre || checked || !barre.currentItem?.enabled ? Qt.TabFocus : Qt.NoFocus
    Keys.onLeftPressed: voisin(-1)
    Keys.onRightPressed: voisin(1)

    // voisin — coche l'onglet voisin dans la barre et lui donne un focus clavier, puis y pose le curseur, même quand le
    // pointeur l'avait emmené ailleurs dans la vue et que l'onglet coché reste le même (aux extrémités).
    // Entrée : pas, -1 pour l'onglet de gauche, 1 pour celui de droite ; aux extrémités, l'onglet coché reste.
    // Sortie : aucune. Erreurs : aucune ; hors d'une barre, rien ne se passe.
    // Dépendances : barre (T.TabBar : setCurrentIndex, currentIndex, count, currentItem), Etat (suivre).
    function voisin(pas: int): void {
        if (!barre) return
        barre.setCurrentIndex(Math.max(0, Math.min(barre.count - 1, barre.currentIndex + pas)))
        barre.currentItem.forceActiveFocus(Qt.TabFocusReason)
        barre.currentItem.etat.suivre(true)
    }

    implicitWidth: implicitContentWidth + leftPadding + rightPadding
    implicitHeight: Theme.density?.controlHeight ?? 0
    horizontalPadding: Theme.space?.scale[2] ?? 0

    Etat {
        id: etat
        controle: onglet
        selectionne: onglet.checked
        suitCurseur: true
        curseurAplat: true
        // Dans une barre, un segment non coché ne se peint qu'à la pression : son ressort de fond part donc de sa
        // propre teinte rendue transparente, au repos comme au survol, et non du fond opaque, qui paraîtrait au premier
        // instant de la pression avant de s'assombrir (grise, noir, gris constatés à l'écran).
        fondReposTransparent: !!onglet.barre
        fondSurvolTransparent: !!onglet.barre
    }

    // Filet du jour : sa couleur rejoint le contour hors du curseur et le fond visé sous lui, où il se fond dans
    // l'aplat, au ressort des états, comme le fond ; sans contour (la nuit), sa cible reste transparente (sobriété,
    // D80).
    ColorSpring {
        id: filet
        target: (!Theme.controls?.outline ? "transparent" : Etats.contoure(etat.selection)
                 ? Theme.controls.outline : etat.couleurs?.fill) ?? "transparent"
    }

    // Un segment non coché d'une barre, hors du curseur, n'a de fond qu'à la pression : au repos comme au survol, son
    // Etat vise la transparence et la piste se lit ; le fond suit toujours le ressort, pour que la plaque du curseur
    // paraisse et s'efface en fondu. Seul un fond peint (hors barre, coché ou pressé) porte le filet du jour, dont
    // l'épaisseur ne suit pas le curseur : seule sa couleur change, en fondu.
    background: Rectangle {
        radius: (Theme.radius?.control ?? 0) - (onglet.barre?.retrait ?? 0)
        readonly property bool peint: !onglet.barre || onglet.checked || etat.interaction === "pressed"
        color: etat.fond
        border.width: peint && Theme.controls?.outline ? Theme.hairline(QsWindow.window?.devicePixelRatio ?? 1) ?? 0 : 0
        border.color: filet.value

        OmbreControle {
            cible: parent
            montre: !!onglet.barre && onglet.checked
        }
    }

    contentItem: Texte {
        text: onglet.text
        color: etat.texte
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
}
