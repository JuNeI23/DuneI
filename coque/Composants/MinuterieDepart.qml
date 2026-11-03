import QtQuick
import "../Theme"

// MinuterieDepart — attente qui ferme un popover de la barre quand la souris l'a quitté (D108).
// Rôle : tant qu'elle est active, non retenue et non survolée, et que le pointeur a été vu au moins une fois depuis
// son activation, elle compte motion.delays.dismiss (1,5 s) puis émet echeance(). Un retour du pointeur annule le
// compte, qui repart de zéro au départ suivant. Un popover ouvert au clavier, que le pointeur n'a jamais survolé ni
// lui ni son icône, ne compte donc pas : ce n'est pas la souris qui l'a quitté. Séparée d'Overlay pour s'éprouver
// sans pointeur, par la coque d'essai des composants.
// Entrées : actif, vrai tant que le popover est ouvert et demande la fermeture au départ ; retenu, vrai tant qu'une
// saisie ou une action en cours suspend la fermeture ; survole, vrai tant que le pointeur est sur le popover ou sur
// son icône.
// Sorties : echeance(), émis quand le délai s'écoule.
// Erreurs : aucune ; sans mouvement chargé (Theme.motion absent), le délai vaut 0 et la minuterie ne compte jamais.
// Dépendances : Theme (motion.delays.dismiss).
QtObject {
    id: minuterie

    property bool actif: false
    property bool retenu: false
    property bool survole: false
    signal echeance()

    // Vrai dès que le pointeur a été vu depuis l'activation ; remis à faux quand la minuterie se désactive.
    property bool vu: false
    onActifChanged: vu = actif && survole
    onSurvoleChanged: if (actif && survole) vu = true

    readonly property Timer attente: Timer {
        interval: Theme.motion?.delays?.dismiss ?? 0
        running: interval > 0 && minuterie.actif && minuterie.vu && !minuterie.retenu && !minuterie.survole
        onTriggered: minuterie.echeance()
    }
}
