import QtQuick
import "../Energie"
import "icones.js" as Icones

// Batterie — niveau de charge de la batterie du portable, icône et pourcentage.
// Rôle : lit EtatEnergie (presente, pourcent, etat), la source unique de l'énergie que partagent le popover et la
// presqu'île ; l'icône marque la charge (etat « charge ») et la batterie pleine (etat « chargee »). Cliquable, un clic
// bascule « ouvert » (la barre y accroche le popover d'énergie, PopoverEnergie) ; l'icône est pleine tant que le
// popover est ouvert. L'élément est nommé « batterie » pour que la barre le désigne dans son masque de saisie.
// Entrées : ouvert (hérité d'ElementBarre), vrai tant que le popover est ouvert. Sorties : clicked.
// Erreurs : sans batterie de portable, l'élément disparaît.
// Dépendances : ElementBarre, EtatEnergie, icones.js.
ElementBarre {
    cliquable: true
    onClicked: ouvert = !ouvert
    readonly property bool presente: EtatEnergie.presente
    readonly property int pourcent: EtatEnergie.pourcent
    readonly property bool enCharge: EtatEnergie.etat === "charge"
    readonly property bool pleine: EtatEnergie.etat === "chargee"

    icone: Icones.iconeBatterie(presente, pourcent, enCharge, pleine)
    texte: presente ? Icones.texteBatterie(pourcent) : ""
}
