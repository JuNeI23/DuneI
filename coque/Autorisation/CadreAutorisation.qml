import QtQuick
import "../Theme"
import "../Composants" as C

// CadreAutorisation — carte d'une demande d'autorisation (L2-24), posée au centre de l'écran par la Scene du contrôleur.
// Rôle : titre, message et identifiant d'action reçus (texte brut, jamais mis en forme), champ de mot de passe, ligne
// d'état, « Annuler » et « Autoriser », ou « Fermer » seul quand le compte est verrouillé. Le champ et « Autoriser » ne
// sont actifs qu'une fois la garde de frappe écoulée (Autorisation.saisieOuverte) ; avant, le champ inactif laisse le
// clavier à la racine, portée de focus, dont chaque touche relance la garde. Échap annule toujours. Le texte saisi ne
// quitte le champ que par Autorisation.soumettre, et le champ se vide au signal vider. Tout passage d'état s'anime : la
// hauteur au Ressort « reflow », la ligne par un fondu croisé et un ColorSpring, les boutons et l'indicateur en fondu.
// Entrées : aucune (Autorisation).
// Sorties : titre, message, action, ligne, champ, autoriser, annuler, fermer, activite (lus par les essais) ;
//           touche(nom), qu'appellent la racine et la coque d'essai.
// Erreurs : aucune ; avant le chargement des tokens, les cotes sont nulles et les couleurs transparentes.
// Dépendances : Autorisation, C.Surface, C.OmbreElevation, C.Texte, C.ChampSecret, C.Bouton, C.Activite, Ressort,
//           ColorSpring, Theme (autorisation.largeur, space, radius, color, typo).
// Cotes : largeur autorisation.largeur (400), marge space.scale[4] (24), coins radius.window (12) ; un message trop long
//         défile, la carte restant à space.scale[6] (48) des bords haut et bas de l'écran.
FocusScope {
    id: cadre

    readonly property alias titre: titre
    readonly property alias message: message
    readonly property alias action: action
    readonly property alias ligne: ligne
    readonly property alias champ: champ
    readonly property alias autoriser: autoriser
    readonly property alias annuler: annuler
    readonly property alias fermer: fermer
    readonly property alias activite: activite
    readonly property bool verrouille: Autorisation.etat === "verrouille"
    readonly property real marge: Theme.space?.scale[4] ?? 0
    readonly property real ecart: Theme.space?.scale[2] ?? 0
    readonly property real reste: titre.height + action.height + champ.height + etat.height + actions.height + 5 * ecart + 2 * marge
    readonly property real plafond: (Autorisation.ecran?.height ?? 0) - 2 * (Theme.space?.scale[6] ?? 0)

    focus: true
    width: Theme.autorisation?.largeur ?? 0
    height: Math.min(hauteur.value, plafond)

    // touche — touche reçue par la racine. Entrée : nom, « escape » ou une autre. Sortie : annulation, ou garde relancée.
    // Erreurs : aucune. Dépendances : Autorisation (annuler, frappe).
    function touche(nom: string) {
        if (nom === "escape") Autorisation.annuler()
        else Autorisation.frappe()
    }

    // Keys.onPressed — touches que le champ ne prend pas, dont toutes celles de la garde, champ inactif.
    // Entrée : event. Sortie : event.accepted, sauf Tab, qui parcourt les contrôles une fois la garde passée.
    // Erreurs : aucune. Dépendances : touche.
    Keys.onPressed: event => {
        cadre.touche(event.key === Qt.Key_Escape ? "escape" : "autre")
        event.accepted = event.key !== Qt.Key_Tab && event.key !== Qt.Key_Backtab
    }

    Connections {
        target: Autorisation
        // onVider — vide le champ et masque de nouveau la saisie. Entrées : aucune. Sortie : champ vide. Erreurs : aucune.
        function onVider() { champ.clear(); champ.revele = false }
        // onSaisieOuverteChanged — la saisie ouverte prend le clavier. Entrées : aucune. Sortie : focus du champ.
        function onSaisieOuverteChanged() { if (Autorisation.saisieOuverte) champ.forceActiveFocus() }
    }

    Ressort { id: hauteur; transition: "reflow"; cible: Math.min(cadre.reste + message.implicitHeight, cadre.plafond) }
    Ressort { id: verrou; transition: "state"; nature: "fondu"; cible: cadre.verrouille ? 1 : 0 }

    C.OmbreElevation { cible: corps; niveau: "e3"; evidee: true }

    C.Surface {
        id: corps
        anchors.fill: parent
        role: "surfaceRaised"
        radius: Theme.radius?.window ?? 0
        verre: true

        C.Texte {
            id: titre
            x: cadre.marge
            y: cadre.marge
            width: parent.width - 2 * cadre.marge
            text: "Autorisation requise"
            textFormat: Text.PlainText
            echelon: 4
            moyen: true
        }

        // Message reçu : il défile quand il dépasse la place que l'écran lui laisse.
        Flickable {
            id: defile
            x: cadre.marge
            y: titre.y + titre.height + cadre.ecart
            width: titre.width
            height: Math.min(message.implicitHeight, Math.max(0, cadre.height - cadre.reste))
            contentHeight: message.implicitHeight
            clip: true
            interactive: contentHeight > height
            boundsBehavior: Flickable.StopAtBounds
            C.Texte {
                id: message
                width: defile.width
                text: Autorisation.message
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
            }
        }

        C.Texte {
            id: action
            x: cadre.marge
            y: defile.y + defile.height + cadre.ecart
            width: titre.width
            text: Autorisation.action
            textFormat: Text.PlainText
            elide: Text.ElideMiddle
            maximumLineCount: 1
            font: Qt.font({ family: Theme.typo?.mono ?? "", pixelSize: Theme.typo?.scale[0] ?? 0 })
            color: Theme.color?.textSecondary ?? "transparent"
        }

        C.ChampSecret {
            id: champ
            x: cadre.marge
            y: action.y + action.height + cadre.ecart
            width: titre.width
            focus: true
            enabled: Autorisation.saisieOuverte
            placeholderText: "Mot de passe"
            onAccepted: Autorisation.soumettre(text)
        }

        // Ligne d'état, sa hauteur réservée : un fondu croisé de l'ancien texte au nouveau, l'indicateur devant.
        Item {
            id: etat
            x: cadre.marge
            y: champ.y + champ.height + cadre.ecart
            width: titre.width
            height: Math.max(ligne.implicitHeight, activite.implicitHeight)

            property string montre: ""
            property string ancien: ""
            readonly property string texte: Autorisation.ligne.texte
            // onTexteChanged — lance le fondu croisé. Entrées : aucune. Sortie : ancien, montre, croise. Erreurs : aucune.
            onTexteChanged: { ancien = montre; montre = texte; croise.reprendre(0, 0) }
            Component.onCompleted: montre = texte

            Ressort { id: croise; transition: "state"; nature: "fondu"; cible: 1 }
            Ressort { id: travail; transition: "state"; nature: "fondu"; cible: Autorisation.etat === "verification" ? 1 : 0 }
            ColorSpring { id: encre; target: (Autorisation.ligne.erreur ? Theme.color?.error : Theme.color?.textSecondary) ?? "transparent" }

            C.Activite {
                id: activite
                anchors.verticalCenter: parent.verticalCenter
                opacity: travail.value
                visible: opacity > 0
            }
            C.Texte {
                id: ligne
                x: Autorisation.etat === "verification" ? activite.width + (Theme.space?.scale[1] ?? 0) : 0
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - x
                opacity: croise.value
                text: etat.montre
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
                echelon: 1
                color: encre.value
            }
            C.Texte {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                opacity: 1 - croise.value
                visible: opacity > 0
                text: etat.ancien
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
                echelon: 1
                color: encre.value
            }
        }

        Item {
            id: actions
            x: cadre.marge
            y: etat.y + etat.height + cadre.ecart
            width: titre.width
            height: autoriser.implicitHeight

            C.Bouton {
                id: annuler
                anchors.right: autoriser.left
                anchors.rightMargin: Theme.space?.scale[1] ?? 0
                text: "Annuler"
                opacity: 1 - verrou.value
                visible: opacity > 0
                enabled: !cadre.verrouille
                onClicked: Autorisation.annuler()
            }
            C.Bouton {
                id: autoriser
                anchors.right: parent.right
                text: "Autoriser"
                opacity: 1 - verrou.value
                visible: opacity > 0
                enabled: Autorisation.saisieOuverte && champ.length > 0
                onClicked: Autorisation.soumettre(champ.text)
            }
            C.Bouton {
                id: fermer
                anchors.right: parent.right
                text: "Fermer"
                opacity: verrou.value
                visible: opacity > 0
                enabled: cadre.verrouille
                onClicked: Autorisation.annuler()
            }
        }
    }
}
