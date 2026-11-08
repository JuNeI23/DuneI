import QtQuick
import "../Audio"
import "icones.js" as Icones

// Audio — indicateur du volume de sortie : icône de seuil, barrée quand le son est coupé (L2-12).
// Rôle : lit EtatAudio (présence d'une sortie, sourdine, volume) ; cliquable, un clic bascule « ouvert » (la barre y
// accroche le popover audio, PopoverAudio). « ouvert » est aussi reporté sur EtatAudio.popoverOuvert : tant que le
// popover est ouvert, la presqu'île ne s'ouvre pas, puisqu'il montre déjà le niveau (spec, décision 12). L'élément est
// nommé « audio » pour que la barre le désigne dans son masque de saisie.
// Entrées : ouvert (hérité d'ElementBarre), vrai tant que le popover est ouvert. Sorties : clicked ;
// EtatAudio.popoverOuvert, écrit à chaque changement d'« ouvert ».
// Erreurs : sans sortie audio, l'icône est vide : l'élément disparaît et ne reçoit plus de clic.
// Dépendances : ElementBarre, icones.js (iconeAudio), EtatAudio (module Audio).
ElementBarre {
    cliquable: true
    icone: Icones.iconeAudio(EtatAudio.presente, EtatAudio.muet, EtatAudio.volume)
    onClicked: ouvert = !ouvert
    onOuvertChanged: EtatAudio.popoverOuvert = ouvert
}
