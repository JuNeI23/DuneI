import QtQuick
import "../Theme"

// CadreDeconnexion — contenu du menu de déconnexion (L2-23), posé au centre de l'écran par la Scene du contrôleur.
// Rôle : version minimale de la tâche 3, une rangée des libellés des actions, celle sous le curseur en accent, celle
// armée en error ; le rendu en vignettes vient à la tâche 4. Il reçoit le clavier : sa racine porte focus: true, car le
// Loader de FenetreScene est une portée de focus, et chaque appui passe par Deconnexion.touche.
// Entrées : aucune (Deconnexion : actions, index, arme, touche). Sorties : nomTouche(event).
// Erreurs : aucune ; avant le chargement des tokens, les libellés restent transparents.
// Dépendances : Deconnexion, Theme (color, space, police).
Row {
    id: cadre

    focus: true
    spacing: Theme.space?.scale[4] ?? 0

    // nomTouche — nom d'une touche pour Deconnexion.touche, comme CadreSelecteur.nomTouche. Entrée : event, KeyEvent
    // d'appui. Sortie : « Backtab » (Maj + Tab), « Tab », « Left », « Right », « Return », « Enter », « space »,
    // « Escape », ou le texte de la touche (une lettre d'accès), « » s'il n'y en a pas. Erreurs : aucune.
    // Dépendances : aucune.
    function nomTouche(event) {
        const k = event.key
        if (k === Qt.Key_Backtab || (k === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier))) return "Backtab"
        const noms = { [Qt.Key_Tab]: "Tab", [Qt.Key_Left]: "Left", [Qt.Key_Right]: "Right", [Qt.Key_Return]: "Return",
                       [Qt.Key_Enter]: "Enter", [Qt.Key_Space]: "space", [Qt.Key_Escape]: "Escape" }
        return noms[k] ?? event.text
    }

    // Keys.onPressed — chaque appui passe par Deconnexion.touche. Entrée : event. Sortie : event.accepted.
    // Erreurs : aucune. Dépendances : nomTouche, Deconnexion.touche.
    Keys.onPressed: event => {
        const nom = cadre.nomTouche(event)
        if (nom) Deconnexion.touche(nom)
        event.accepted = true
    }

    Repeater {
        model: Deconnexion.actions
        Text {
            required property var modelData
            required property int index
            text: modelData.libelle
            font: Theme.police(4, Deconnexion.index === index)
            color: Deconnexion.arme === index ? (Theme.color?.error ?? "transparent")
                 : Deconnexion.index === index ? (Theme.color?.accent ?? "transparent")
                 : (Theme.color?.textPrimary ?? "transparent")
        }
    }
}
