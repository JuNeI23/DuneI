import QtQuick
import "../Parametres"

// Parametres — entrée des réglages, icône fixe à droite de la barre.
// Rôle : affiche « emblem-system » ; un clic ouvre l'application Paramètres sur la dernière page vue de la session
// (Wi-Fi à la première ouverture), ou la laisse ouverte.
// Entrées : aucune. Sorties : aucune. Erreurs : aucune. Dépendances : ElementBarre, EtatParametres (ouvrir).
ElementBarre {
    cliquable: true
    icone: "emblem-system"
    onClicked: EtatParametres.ouvrir("", [])
}
