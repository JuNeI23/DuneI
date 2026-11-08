import QtQuick
import "../Audio"
import "icones.js" as Icones

// Audio — indicateur du volume de sortie : icône de seuil, barrée quand le son est coupé (L2-12).
// Rôle : lit EtatAudio (présence d'une sortie, sourdine, volume) ; cliquable, un clic bascule « ouvert » (la barre y
// accroche le popover audio, PopoverAudio). « ouvert » est aussi reporté sur EtatAudio, sous la clé de l'indicateur :
// tant qu'un popover audio est ouvert, sur quelque écran que ce soit, la presqu'île ne s'ouvre pas, puisqu'il montre
// déjà le niveau (spec, décision 12). Détruit popover ouvert (écran débranché), l'indicateur retire sa clé. L'élément
// est nommé « audio » pour que la barre le désigne dans son masque de saisie.
// Entrées : ouvert (hérité d'ElementBarre), vrai tant que le popover est ouvert. Sorties : clicked ;
// EtatAudio.tenirPopover, appelé à chaque changement d'« ouvert » et à la destruction.
// Erreurs : sans sortie audio, l'icône est vide : l'élément disparaît et ne reçoit plus de clic.
// Dépendances : ElementBarre, icones.js (iconeAudio), EtatAudio (module Audio, tenirPopover).
ElementBarre {
    id: indicateur
    cliquable: true
    icone: Icones.iconeAudio(EtatAudio.presente, EtatAudio.muet, EtatAudio.volume)
    onClicked: ouvert = !ouvert
    onOuvertChanged: EtatAudio.tenirPopover(indicateur, ouvert)
    Component.onDestruction: EtatAudio.tenirPopover(indicateur, false)
}
