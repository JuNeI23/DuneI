import QtQuick
import "../Theme"

// ChampSecret — champ de mot de passe de la coque, avec l'œil de révélation en fin de champ.
// Rôle : un Champ dont il reprend tout le comportement (fond enfoncé, filet, texte indicatif, curseur de texte), en
// saisie masquée tant que revele est faux. L'œil, à droite comme le bouton d'effacement de la Recherche, montre
// view-reveal quand le texte est masqué et view-conceal quand il est révélé ; son clic bascule revele. Si le champ
// est vide et que le parent doit d'abord aller lire le secret enregistré (secretALire), le clic émet
// revelationDemandee au lieu de basculer : le parent remplit text puis pose revele. Le texte saisi n'est jamais
// écrit au journal, et la saisie se déclare sensible (aucune prédiction ni mémoire de la méthode de saisie).
// Entrées : text, placeholderText, revele (faux par défaut), secretALire (faux par défaut) et le reste de l'API
// de Champ.
// Sorties : celles de Champ (accepted…) ; signal revelationDemandee() ; oeil, l'Icone de l'œil, lue par les essais.
// Fonction : basculer, l'action du clic sur l'œil.
// Erreurs : aucune ; avant le chargement des tokens, les cotes sont nulles et l'œil invisible.
// Dépendances : Champ, Icone, Theme (space, icons, color).
// Cotes : œil de icons.sizes.dense à space.scale[1] (8) du bord droit ; le texte finit à space.scale[0] (4) de l'œil.
Champ {
    id: champ

    property bool revele: false
    property bool secretALire: false
    readonly property alias oeil: oeil
    readonly property real marge: Theme.space?.scale[1] ?? 0

    signal revelationDemandee()

    echoMode: revele ? TextInput.Normal : TextInput.Password
    inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText | Qt.ImhHiddenText
    rightPadding: marge + oeil.taille + (Theme.space?.scale[0] ?? 0)

    // basculer — action de l'œil : demande la lecture du secret au parent si le champ est vide et qu'un secret
    // reste à lire, sinon révèle ou masque le texte.
    // Entrées : aucune. Sortie : aucune ; émet revelationDemandee ou change revele. Erreurs : aucune.
    // Dépendances : secretALire, revele, length.
    function basculer(): void {
        if (length === 0 && secretALire) revelationDemandee()
        else revele = !revele
    }

    Icone {
        id: oeil
        x: champ.width - champ.marge - taille
        anchors.verticalCenter: parent.verticalCenter
        nom: champ.revele ? "view-conceal" : "view-reveal"
        taille: Theme.icons?.sizes.dense ?? 0
        couleur: champ.enabled ? Theme.color?.textSecondary ?? "transparent" : champ.etat.texte

        // Saisie exclusive dès l'appui : le clic n'atteint pas le champ, qui ne déplace pas son curseur.
        TapHandler {
            gesturePolicy: TapHandler.ReleaseWithinBounds
            onTapped: champ.basculer()
        }
    }
}
