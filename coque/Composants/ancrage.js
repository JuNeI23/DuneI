.pragma library

// ancrage.js — position horizontale du cadre d'un overlay contextuel ou d'une infobulle sur son écran.
// Rôle : la fenêtre d'un tel overlay dépasse son cadre visible de la marge de l'ombre, de chaque côté. Laisser le
//        compositeur la garder dans l'écran (ajustement Slide ou Flip d'xdg_positioner) déplacerait le cadre dès que
//        la seule marge transparente déborde, près d'un bord. Le serrage se fait donc ici, sur le cadre seul : le
//        cadre reste dans l'écran au pixel près, la marge peut en sortir. Bibliothèque sans état, qui ne lit que ses
//        arguments.
// Dépendances : aucune.

// origine — abscisse du bord gauche d'une fenêtre de calque (PanelWindow) sur son écran.
// Rôle : Wayland ne dit pas à un client où se trouve sa fenêtre ; pour un calque, elle se déduit de ses ancrages et de
//        ses marges, comme le compositeur la pose : ancrée à gauche (ou des deux côtés), à margins.left du bord ;
//        ancrée à droite seulement, à margins.right du bord droit ; sans ancrage horizontal, centrée.
// Entrées : fenetre, la fenêtre de l'ancre (QsWindow.window), avec anchors, margins, width et screen.
// Sortie : l'abscisse, en pixels logiques ; NaN si la fenêtre n'est pas un calque (FloatingWindow) ou n'a pas
//          d'écran : sa position est alors inconnue.
// Erreurs : aucune. Limite : la zone exclusive d'un autre calque, qui décalerait la fenêtre, n'est pas comptée ;
//           la coque n'en pose pas sur les côtés.
// Dépendances : aucune.
function origine(fenetre) {
    const a = fenetre?.anchors, m = fenetre?.margins, l = fenetre?.screen?.width
    if (!a || !m || l === undefined) return NaN
    return a.left ? m.left : a.right ? l - m.right - fenetre.width : (l - fenetre.width) / 2
}

// gaucheCadre — abscisse du bord gauche du cadre sur l'écran, serrée dans l'écran.
// Rôle : sous une ancre, un contextuel aligne son bord gauche sur celui de l'ancre, une infobulle se centre sur
//        elle ; à un point de clic, le cadre part du point vers la droite, ou finit au point s'il n'a pas la place
//        (retournement, comme un menu contextuel de macOS). Le cadre est ensuite serré entre les deux bords de
//        l'écran, sans marge ; plus large que l'écran, il part du bord gauche.
// Entrées : bulle, vrai pour une infobulle ; ancreX, bord gauche de l'ancre sur l'écran ; ancreLargeur, sa
//           largeur ; pointX, abscisse du point de clic dans l'ancre, ou null sous l'ancre ; largeur, largeur du
//           cadre ; ecran, largeur de l'écran ; toutes en pixels logiques.
// Sortie : l'abscisse du bord gauche du cadre sur l'écran.
// Erreurs : aucune. Dépendances : aucune.
function gaucheCadre(bulle, ancreX, ancreLargeur, pointX, largeur, ecran) {
    let x = bulle ? ancreX + (ancreLargeur - largeur) / 2 : ancreX
    if (pointX !== null) {
        x = ancreX + pointX
        if (x + largeur > ecran) x += 1 - largeur
    }
    return Math.max(0, Math.min(x, ecran - largeur))
}
