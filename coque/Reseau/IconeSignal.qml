import QtQuick
import "../Theme"
import "../Composants"
import "../Barre/icones.js" as Icones

// IconeSignal — force du signal d'un réseau Wi-Fi, suivie d'un cadenas s'il est sécurisé (L2-65).
// Rôle : le glyphe complet du signal en filet discret (borderDefault), puis la force réelle par-dessus en texte
// secondaire, aux paliers de la barre (iconeForce) : la part absente du signal reste lisible, comme dans la maquette
// de la fenêtre Réseau. Hors de portée, seul le glyphe discret paraît. Une seule taille, icons.sizes.dense, pour
// toutes les listes de la fenêtre.
// Entrées : force, de 0 à 100, ou -1 hors de portée ; securise, vrai pour montrer le cadenas (faux par défaut).
// Sorties : aucune. Erreurs : aucune ; avant le chargement des tokens, l'icône est nulle et transparente.
// Dépendances : Icone, Theme (icons, space, color), icones.js (iconeForce).
Row {
    id: iconeSignal

    property int force: -1
    property bool securise: false
    readonly property int taille: Theme.icons?.sizes.dense ?? 0

    spacing: Theme.space?.scale[0] ?? 0

    Item {
        width: iconeSignal.taille
        height: width
        Icone {
            nom: "network-wireless-signal-excellent"
            taille: iconeSignal.taille
            couleur: Theme.color?.borderDefault ?? "transparent"
        }
        Icone {
            visible: iconeSignal.force >= 0
            nom: Icones.iconeForce(iconeSignal.force / 100)
            taille: iconeSignal.taille
            couleur: Theme.color?.textSecondary ?? "transparent"
        }
    }
    Icone {
        visible: iconeSignal.securise
        nom: "network-wireless-encrypted"
        taille: iconeSignal.taille
        couleur: Theme.color?.textTertiary ?? "transparent"
    }
}
