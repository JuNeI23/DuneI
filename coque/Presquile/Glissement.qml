import QtQuick
import "../Theme"

// Glissement — présence animée de la presqu'île : hors de l'écran, au-dessus du bord haut, ou en place (L2-48).
// Rôle : porte le ressort qui fait descendre l'encoche à son arrivée et la fait remonter à son départ, sans fenêtre, pour
// être éprouvé seul. Une interruption en vol repart de la position et de la vitesse courantes. En mouvement réduit,
// rien ne se déplace : le même ressort devient un fondu.
// Entrées : presente, vrai quand l'encoche doit être en place ; course, distance à parcourir pour la sortir entièrement
//           de l'écran, ombre comprise (px logiques).
// Sorties : decalage, ordonnée de l'encoche, de −course (hors de l'écran) à 0 (en place), toujours 0 en mouvement
//           réduit ; opacite, 1, ou celle du fondu en mouvement réduit ; mobile, vrai tant que le ressort avance.
// Erreurs : aucune ; à la création et avant que Theme soit prêt, la présence se pose d'un coup.
// Dépendances : Ressort (transition « overlay », celle du fondu des calques de Hyprland), Theme (mouvementReduit).
Item {
    id: glissement

    property bool presente: false
    property real course: 0
    // Le décalage est borné à 0 : un dépassement du ressort détacherait l'encoche du bord.
    readonly property real decalage: Theme.mouvementReduit ? 0 : Math.min(0, (presence.value - 1) * course)
    readonly property real opacite: Theme.mouvementReduit ? presence.value : 1
    readonly property bool mobile: presence.moving

    visible: false

    // Part de présence, de 0 à 1 : la course peut changer sans animer une encoche repliée ou en place.
    Ressort {
        id: presence
        transition: "overlay"
        nature: Theme.mouvementReduit ? "fondu" : "deplacement"
        cible: glissement.presente ? 1 : 0
    }
}
