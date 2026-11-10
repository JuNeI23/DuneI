import QtQuick
import "../Theme"

// ChampSecret — champ de mot de passe de la coque, avec l'œil de révélation en fin de champ et, s'il est copiable, le
// bouton de copie à sa droite.
// Rôle : un Champ dont il reprend tout le comportement (fond enfoncé, filet, texte indicatif, curseur de texte), en
// saisie masquée tant que revele est faux. L'œil, à droite comme le bouton d'effacement de la Recherche, montre
// view-reveal quand le texte est masqué et view-conceal quand il est révélé ; son clic bascule revele. Si le champ
// est vide et que le parent doit d'abord aller lire le secret enregistré (secretALire), le clic émet
// revelationDemandee au lieu de basculer : le parent remplit text puis pose revele. Le texte saisi n'est jamais
// écrit au journal, et la saisie se déclare sensible (aucune prédiction ni mémoire de la méthode de saisie).
// Copie (copiable vrai) : le bouton edit-copy, au bord droit, pousse l'œil d'une icône et d'un écart vers la gauche ;
// son clic émet copieDemandee, sans rien révéler ni remplir : le parent lit le secret, le copie, puis appelle
// confirmerCopie, et la coche remplace l'icône de copie en fondu jusqu'à la fin de motion.delays.copied, comme
// « Copié » dans Valeur. Sans copiable, le bouton n'existe pas.
// Entrées : text, placeholderText, revele (faux par défaut), secretALire (faux par défaut), copiable (faux par
// défaut) et le reste de l'API de Champ.
// Sorties : celles de Champ (accepted…) ; signaux revelationDemandee() et copieDemandee() ; copie, vrai tant que la
// coche tient la place ; oeil, l'Icone de l'œil ; copieur, le bouton de copie (null sans copiable) ; coche, sa coche
// (null sans copiable) ; fin, le minuteur du retour de copie : lus par les essais.
// Fonctions : basculer, l'action du clic sur l'œil ; copier, celle du bouton de copie ; confirmerCopie, le retour.
// Erreurs : aucune ; avant le chargement des tokens, les cotes sont nulles et les icônes invisibles.
// Dépendances : Champ, Icone, Coche, Theme (space, icons, color, motion.delays.copied, motion.rules.reduced_fade_ms).
// Cotes : icônes de icons.sizes.dense ; le bouton de copie, ou l'œil sans lui, à space.scale[1] (8) du bord droit,
// l'œil à space.scale[1] du bouton de copie ; le texte finit à space.scale[0] (4) de l'œil.
Champ {
    id: champ

    property bool revele: false
    property bool secretALire: false
    property bool copiable: false
    property bool copie: false
    readonly property alias oeil: oeil
    readonly property var copieur: chargeurCopie.item
    readonly property var coche: chargeurCopie.item?.coche ?? null
    readonly property alias fin: fin
    readonly property real marge: Theme.space?.scale[1] ?? 0
    // Place que prend le bouton de copie à droite de l'œil : son icône et l'écart qui l'en sépare.
    readonly property real decalage: copiable ? oeil.taille + marge : 0

    signal revelationDemandee()
    signal copieDemandee()

    echoMode: revele ? TextInput.Normal : TextInput.Password
    inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText | Qt.ImhHiddenText
    rightPadding: marge + decalage + oeil.taille + (Theme.space?.scale[0] ?? 0)

    // basculer — action de l'œil : demande la lecture du secret au parent si le champ est vide et qu'un secret
    // reste à lire, sinon révèle ou masque le texte.
    // Entrées : aucune. Sortie : aucune ; émet revelationDemandee ou change revele. Erreurs : aucune.
    // Dépendances : secretALire, revele, length.
    function basculer(): void {
        if (length === 0 && secretALire) revelationDemandee()
        else revele = !revele
    }

    // copier — action du bouton de copie : demande la copie au parent, qui seul sait lire le secret enregistré.
    // Entrées : aucune. Sortie : aucune ; émet copieDemandee. Erreurs : aucune. Dépendances : aucune.
    function copier(): void { copieDemandee() }

    // confirmerCopie — montre la coche à la place de l'icône de copie jusqu'à la fin du minuteur ; appelée par le
    // parent une fois la copie faite. Entrées : aucune. Sortie : aucune. Erreurs : aucune. Dépendances : fin.
    function confirmerCopie(): void {
        copie = true
        fin.restart()
    }

    // Tenue du retour de copie : un seul coup, armé par confirmerCopie, jamais au repos.
    Timer { id: fin; interval: Theme.motion?.delays?.copied ?? 0; onTriggered: champ.copie = false }

    Icone {
        id: oeil
        x: champ.width - champ.marge - champ.decalage - taille
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

    // Bouton de copie, construit seulement si copiable : l'icône edit-copy, que la coche remplace en fondu pendant le
    // retour de copie.
    Loader {
        id: chargeurCopie
        active: champ.copiable
        x: champ.width - champ.marge - oeil.taille
        anchors.verticalCenter: parent.verticalCenter
        sourceComponent: Item {
            readonly property alias coche: coche
            implicitWidth: oeil.taille
            implicitHeight: oeil.taille
            Icone {
                anchors.fill: parent
                nom: "edit-copy"
                taille: oeil.taille
                couleur: oeil.couleur
                opacity: champ.copie ? 0 : 1
                Behavior on opacity { NumberAnimation { duration: Theme.motion?.rules?.reduced_fade_ms ?? 0 } }
            }
            Coche {
                id: coche
                anchors.fill: parent
                couleur: Theme.color?.accentStandalone ?? "transparent"
                opacity: champ.copie ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.motion?.rules?.reduced_fade_ms ?? 0 } }
            }
            // Saisie exclusive dès l'appui, comme l'œil.
            TapHandler {
                gesturePolicy: TapHandler.ReleaseWithinBounds
                onTapped: champ.copier()
            }
        }
    }
}
