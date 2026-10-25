import QtQuick

// Liste — liste de la coque, un seul arrêt de tabulation, parcourue aux flèches.
// Rôle : une ListView qui prend le focus à la tabulation (activeFocusOnTab) et dont les flèches déplacent
// currentIndex (keyNavigationEnabled) ; ses rangées n'acceptent aucun focus (conception, § 7.3). La sélection
// suit currentIndex par défaut (§ 7.5) ; Entrée active la rangée courante. Comme une ListView n'a pas de
// visualFocus, la liste retient la dernière façon dont on l'a atteinte dans focusClavier : une touche reçue ou
// l'arrivée du focus le passent à vrai, un clic dans une rangée le repasse à faux (Rangee s'en charge), et le
// contour de focus de la rangée courante n'est montré que sous ce drapeau, jamais dans un menu
// (selectionSuitSurvol), où la pastille de sélection suffit.
// Entrées : model, delegate (une Rangee) et le reste de l'API de ListView ; selectionSuitCourant, vrai par
// défaut : la rangée courante est la rangée sélectionnée ; faux, chaque rangée lit sa propriété selectionnee,
// fournie par l'appelant ; selectionSuitSurvol, faux par défaut : vrai, la rangée survolée devient la rangée
// courante, comme dans un menu de macOS où la sélection suit le pointeur ; focusClavier, que l'appelant peut
// aussi écrire, par exemple pour masquer le contour après avoir donné le focus à la liste à la suite d'un clic.
// Sorties : focusClavier, vrai quand le focus a été obtenu ou utilisé au clavier.
// Erreurs : aucune ; Entrée sur une liste vide, ou dont le délégué n'est pas une Rangee, n'active rien.
// Dépendances : QtQuick (ListView, Keys), Rangee comme délégué.
// Limite connue : Qt 6.12 n'expose pas de focusReason sur Item ; l'arrivée du focus ne distingue donc pas la
// tabulation d'un forceActiveFocus programmé, qui passe lui aussi focusClavier à vrai.
ListView {
    id: liste

    property bool focusClavier: false
    property bool selectionSuitCourant: true
    property bool selectionSuitSurvol: false

    activeFocusOnTab: true
    keyNavigationEnabled: true

    onActiveFocusChanged: if (activeFocus) focusClavier = true

    // Toute touche montre le contour. Seule Entrée est consommée, pour activer la rangée courante : les autres
    // touches poursuivent vers la ListView, dont la navigation aux flèches reste ainsi active.
    Keys.onPressed: (event) => {
        liste.focusClavier = true
        event.accepted = event.key === Qt.Key_Return || event.key === Qt.Key_Enter
        if (event.accepted) liste.currentItem?.active?.()
    }
}
