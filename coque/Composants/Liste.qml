import QtQuick
import "../Theme"
import "etats.js" as Etats

// Liste — liste de la coque, un seul arrêt de tabulation, parcourue aux flèches, marquée par la plaque du curseur.
// Rôle : une ListView qui prend le focus à la tabulation (activeFocusOnTab) et dont les flèches déplacent
// currentIndex (keyNavigationEnabled) ; ses rangées n'acceptent aucun focus (conception, § 7.3). La sélection
// suit currentIndex par défaut (§ 7.5) ; Entrée active la rangée courante. Le survol d'une rangée en fait la rangée
// courante (Rangee s'en charge), comme dans un menu de macOS. Une seule Plaque, celle du lanceur, se tient sous la
// rangée courante et glisse d'une rangée à l'autre : à l'accent quand le curseur de la vue est dans la liste (une
// rangée survolée, ou la liste atteinte ou parcourue au clavier), au fond neutre controlRaised sinon ; les rangées
// ne peignent pas leur propre fond (conception L2-73). Le curseur suit l'arbitre de la vue (dnVue, VueCurseur)
// hérité des ancêtres ; une liste hors de toute vue munie d'un arbitre porte le sien, pour elle seule. Comme une
// ListView n'a pas de visualFocus, la liste retient la dernière façon dont on l'a atteinte dans focusClavier : une
// touche reçue ou l'arrivée du focus le passent à vrai, un clic dans une rangée le repasse à faux (Rangee s'en
// charge). Le focus obtenu au clavier donne le curseur à la rangée courante, toute touche le lui rend, et une
// nouvelle rangée courante le reprend tant qu'il est dans la liste ; à la perte de ce focus, la rangée courante le
// lâche, sauf si le pointeur la survole.
// Entrées : model, delegate (une Rangee) et le reste de l'API de ListView ; selectionSuitCourant, vrai par
// défaut : la rangée courante est la rangée sélectionnée ; faux, chaque rangée lit sa propriété selectionnee,
// fournie par l'appelant ; focusClavier, que l'appelant peut aussi écrire, par exemple pour retirer le curseur après
// avoir donné le focus à la liste à la suite d'un clic ; navigation, faux par défaut : vrai, la liste est une colonne
// de navigation (la barre latérale de la fenêtre Réseau, celle de l'écran de réglages) et sa rangée sélectionnée ne
// prend jamais l'accent hors du curseur, mais le fond neutre levé d'un cran (controlRaised, voir Etat.selectionNeutre),
// avec un libellé en graisse moyenne ; c'est une exception bornée à la règle « Sélectionné actif » de la bible.
// Sorties : focusClavier, vrai quand le focus a été obtenu ou utilisé au clavier ; dnVue, l'arbitre du curseur que
// lisent les rangées ; curseurDedans, vrai quand le porteur du curseur est une rangée de la liste ; plaque, la Plaque
// (cible, teinte), pour les essais.
// Erreurs : aucune ; Entrée sur une liste vide, ou dont le délégué n'est pas une Rangee, n'active rien ; une liste
// vide ne montre pas de plaque.
// Dépendances : QtQuick (ListView, Keys), Rangee comme délégué, Plaque, VueCurseur, Theme (space, radius,
// stateColors), etats.js (herite).
// Cotes : la plaque reprend la pastille d'une rangée, en retrait de space.scale[0] de chaque bord, au rayon
// radius.control.
// Limite connue : Qt 6.12 n'expose pas de focusReason sur Item ; l'arrivée du focus ne distingue donc pas la
// tabulation d'un forceActiveFocus programmé, qui passe lui aussi focusClavier à vrai.
ListView {
    id: liste

    property bool focusClavier: false
    property bool selectionSuitCourant: true
    property bool navigation: false

    readonly property VueCurseur dnVue: Etats.herite(liste, "dnVue", null) ?? propre
    readonly property VueCurseur propre: VueCurseur {}
    readonly property bool curseurDedans: dnVue.porteur !== null && dnVue.porteur.parent === contentItem
    readonly property bool auClavier: activeFocus && focusClavier
    readonly property alias plaque: plaque

    activeFocusOnTab: true
    keyNavigationEnabled: true

    onActiveFocusChanged: if (activeFocus) focusClavier = true
    // La liste atteinte au clavier donne le curseur à sa rangée courante ; quittée, elle le reprend à cette rangée,
    // sauf si le pointeur la survole encore.
    onAuClavierChanged: if (currentItem) auClavier ? dnVue.prendre(currentItem) : currentItem.hovered || dnVue.lacher(currentItem)
    // Une nouvelle rangée courante (flèche, survol) reprend le curseur s'il est dans la liste, ou si la liste a le focus
    // du clavier : la ListView retire le focus à l'ancienne rangée courante, qui lâche alors le curseur, avant de
    // changer currentItem.
    onCurrentItemChanged: if (currentItem && (curseurDedans || auClavier)) dnVue.prendre(currentItem)

    // Toute touche reçue rend le curseur à la rangée courante. Seule Entrée est consommée, pour activer la rangée
    // courante : les autres touches poursuivent vers la ListView, dont la navigation aux flèches reste ainsi active.
    Keys.onPressed: (event) => {
        liste.focusClavier = true
        if (liste.currentItem) liste.dnVue.prendre(liste.currentItem)
        event.accepted = event.key === Qt.Key_Return || event.key === Qt.Key_Enter
        if (event.accepted) liste.currentItem?.active?.()
    }

    // La plaque vit dans le contenu défilé, comme les rangées, sous elles : elle défile avec elles et sa cible est
    // dans le repère de leur y.
    Plaque {
        id: plaque
        readonly property real retrait: Theme.space?.scale[0] ?? 0
        readonly property string role: Etats.herite(liste, "dnRole", "surfaceWindow")
        parent: liste.contentItem
        z: -1
        rayon: Theme.radius?.control ?? 0
        cible: liste.currentItem ? Qt.rect(liste.currentItem.x + retrait, liste.currentItem.y,
            liste.currentItem.width - 2 * retrait, liste.currentItem.height) : Qt.rect(0, 0, 0, 0)
        teinte: (liste.curseurDedans
            ? Theme.stateColors(role, Etats.herite(liste, "dnInactive", false) ? "activeMuted" : "active", "rest")?.fill
            : Theme.stateColors("controlRaised", "none", "rest")?.fill) ?? "transparent"
    }
}
