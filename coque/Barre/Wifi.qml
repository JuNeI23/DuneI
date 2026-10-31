import QtQuick
import "../Reseau"

// Wifi — état du réseau dans la barre : coupé, déconnecté, filaire ou force du signal en cinq paliers.
// Rôle : affiche EtatReseau.icone, calculée à partir de Quickshell.Networking par le singleton.
// Entrées : aucune. Sorties : aucune. Erreurs : sans carte Wi-Fi ni lien filaire, l'élément disparaît.
// Dépendances : ElementBarre, EtatReseau.
ElementBarre {
    icone: EtatReseau.icone
}
