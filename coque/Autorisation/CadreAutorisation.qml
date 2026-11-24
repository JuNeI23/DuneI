import QtQuick
import "../Theme"
import "../Composants" as C
import "../Presquile" as P

// CadreAutorisation — île d'une demande d'autorisation (L2-24), dessinée par la fenêtre de l'agent au bord haut de
// l'écran, à la forme de la presqu'île (P.Encoche), qui s'efface dessous.
// Rôle : part de la taille de repos de la presqu'île, s'étire sur l'annonce (cadenas, « Autorisation requise ») pendant
// delays.gardeFrappe, puis s'ouvre : vignette en verre, titre, message reçu et, sous lui, une ligne toujours présente
// (identifiant de l'action, puis vérification, échec, verrou ou message de PAM) ; en bas, le champ et « Autoriser », ou
// « Fermer » seul quand le compte est verrouillé. Demande accordée, l'île se replie sur « Autorisé », puis sur sa taille
// de repos. Les textes reçus sont peints en texte brut. Le champ et « Autoriser » ne sont actifs qu'une fois la garde de
// frappe écoulée (Autorisation.saisieOuverte) ; avant, le champ inactif laisse le clavier à la racine, portée de focus,
// dont chaque touche relance la garde. Échap annule toujours. Le texte saisi ne quitte le champ que par
// Autorisation.soumettre, et le champ se vide au signal vider.
// Mouvement : largeur, hauteur et rayon au Ressort « window », comme la presqu'île ; contenus, ligne et boutons en fondu ;
// une poussée du champ à l'échec. En mouvement réduit, seuls les fondus restent.
// Entrées : aucune (Autorisation).
// Sorties : encoche, titre, message, ligne, champ, autoriser, fermer, activite, annonce, hauteurOuverte (lus par les
//           essais) ; touche(nom), qu'appellent la racine et la coque d'essai.
// Erreurs : aucune ; avant le chargement des tokens, les cotes sont nulles et les couleurs transparentes.
// Dépendances : Autorisation, P.Encoche, C.VignetteVerre, C.Texte, C.ChampSecret, C.Bouton, C.Activite, C.Icone,
//           C.Coche, Ressort, ColorSpring, Theme (autorisation, tokens.presquile, tokens.bureauxVirtuels, space, radius,
//           icons, color, typo, motion.delays.gardeFrappe).
// Cotes : jetons [autorisation] (largeur 460, vignette 56, rangée 32, rayon 18) ; marge space.scale[3] (16), écart
//         space.scale[2] (12) ; un message trop long défile, l'île restant à space.scale[6] (48) du bas de l'écran.
FocusScope {
    id: cadre

    readonly property alias encoche: encoche
    readonly property alias titre: titre
    readonly property alias message: message
    readonly property alias ligne: ligne
    readonly property alias champ: champ
    readonly property alias autoriser: autoriser
    readonly property alias fermer: fermer
    readonly property alias activite: activite
    readonly property alias annonce: annonce
    // Rôle du fond, lu par les contrôles : l'Encoche peint la matière E3.
    readonly property string dnRole: "surfaceRaised"
    readonly property var cotes: Theme.autorisation
    readonly property var ile: Theme.tokens?.presquile
    readonly property bool verrouille: Autorisation.etat === "verrouille"
    readonly property bool reussi: Autorisation.etat === "succes"
    readonly property bool refus: Autorisation.ligne.erreur
    readonly property real marge: Theme.space?.scale[3] ?? 0
    readonly property real ecart: Theme.space?.scale[2] ?? 0

    // Forme : « repos » à la création et une fois la demande close, « annonce » pendant la garde et au succès, « ouverte ».
    property bool partie: false
    property bool ouverte: false
    readonly property string forme: !Autorisation.ouvert || !partie ? "repos" : ouverte && !reussi ? "ouverte" : "annonce"
    readonly property int bureaux: Theme.tokens?.bureauxVirtuels?.nombre ?? 0
    readonly property real repos: ile ? ile.pilule + (bureaux - 1) * (ile.point + ile.ecart) + 2 * ile.marge : 0
    // Hauteur de l'île sans son message, puis ouverte, bornée par l'écran.
    readonly property real reste: 2 * marge + titre.height + etat.height + ecart + (cotes?.rangee ?? 0)
    readonly property real plafond: (Autorisation.ecran?.height ?? 0) - (Theme.space?.scale[6] ?? 0)
    readonly property real hauteurOuverte: Math.min(plafond, Math.max(reste + message.implicitHeight,
        2 * marge + (cotes?.vignette ?? 0) + ecart + (cotes?.rangee ?? 0)))

    focus: true
    width: (cotes?.largeur ?? 0) + 2 * (ile?.evasement ?? 0)
    height: plafond

    // Component.onCompleted — lance l'annonce au tour de boucle suivant, les ressorts étant prêts, puis l'ouverture au
    // terme de la garde. Entrées : aucune. Sortie : partie, ouverte. Erreurs : aucune. Dépendances : ouverture.
    Component.onCompleted: Qt.callLater(() => { cadre.partie = true; ouverture.restart() })
    Timer { id: ouverture; interval: Theme.motion?.delays.gardeFrappe ?? 0; onTriggered: cadre.ouverte = true }

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
        // onEchecsChanged — un mot de passe refusé pousse le champ une fois ; le ressort le ramène. La vitesse est celle
        // qui porte le ressort « window » à la poussée voulue. Entrées : aucune. Sortie : secousse. Erreurs : aucune.
        function onEchecsChanged() {
            const t = Theme.motion?.transitions?.window?.in
            if (Autorisation.echecs.length && t) secousse.reprendre(0, (cadre.cotes?.secousse ?? 0) * Math.sqrt(t.stiffness / t.mass) * Math.E)
        }
    }

    Ressort { id: largeur; transition: "window"; cible: ({ repos: cadre.repos, annonce: cadre.cotes?.annonce ?? 0, ouverte: cadre.cotes?.largeur ?? 0 })[cadre.forme] }
    Ressort { id: hauteur; transition: "window"; cible: cadre.forme === "ouverte" ? cadre.hauteurOuverte : cadre.ile?.hauteur ?? 0 }
    Ressort { id: rayon; transition: "window"; cible: (cadre.forme === "ouverte" ? cadre.cotes?.rayon : cadre.ile?.rayon) ?? 0 }
    Ressort { id: vue; transition: "state"; nature: "fondu"; cible: cadre.forme === "ouverte" ? 1 : 0 }
    Ressort { id: dit; transition: "state"; nature: "fondu"; cible: cadre.forme === "annonce" ? 1 : 0 }
    Ressort { id: verrou; transition: "state"; nature: "fondu"; cible: cadre.verrouille ? 1 : 0 }
    Ressort { id: secousse; transition: "window"; cible: 0 }

    P.Encoche {
        id: encoche
        x: (cadre.width - implicitWidth) / 2
        largeurCorps: largeur.value
        hauteur: hauteur.value
        rayon: rayon.value
    }

    // Contenus de l'île, rognés à son corps pendant l'étirement.
    Item {
        x: (cadre.width - width) / 2
        width: largeur.value
        height: hauteur.value
        clip: true

        // Annonce, puis « Autorisé ».
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            height: cadre.ile?.hauteur ?? 0
            spacing: Theme.space?.scale[1] ?? 0
            opacity: dit.value
            visible: opacity > 0
            Item {
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.icons?.sizes.dense ?? 0
                height: width
                C.Icone {
                    anchors.fill: parent
                    visible: !cadre.reussi
                    nom: "system-lock-screen"
                    taille: parent.width
                    couleur: Theme.color?.accentStandalone ?? "transparent"
                }
                C.Coche { anchors.fill: parent; visible: cadre.reussi; couleur: Theme.color?.success ?? "transparent" }
            }
            C.Texte {
                id: annonce
                anchors.verticalCenter: parent.verticalCenter
                text: cadre.reussi ? "Autorisé" : "Autorisation requise"
                moyen: true
            }
        }

        // Île ouverte, à sa taille finale : seul le rognage de son parent s'anime.
        Item {
            id: corps
            anchors.horizontalCenter: parent.horizontalCenter
            width: cadre.cotes?.largeur ?? 0
            height: cadre.hauteurOuverte
            opacity: vue.value
            visible: opacity > 0

            C.VignetteVerre {
                x: cadre.marge
                y: cadre.marge
                glyphe: "system-lock-screen"
                couleurTeinte: (cadre.refus ? Theme.color?.error : Theme.color?.accent) ?? null
                pleine: false
                taille: cadre.cotes?.vignette ?? 0
                tailleGlyphe: cadre.cotes?.glyphe ?? 0
                rayon: Theme.radius?.window ?? 0
            }

            Item {
                id: textes
                x: 2 * cadre.marge + (cadre.cotes?.vignette ?? 0)
                y: cadre.marge
                width: parent.width - x - cadre.marge
                height: champ.y - cadre.ecart - y

                C.Texte {
                    id: titre
                    width: parent.width
                    text: "Autorisation requise"
                    textFormat: Text.PlainText
                    echelon: 3
                    moyen: true
                }

                // Message reçu : il défile quand il dépasse la place que l'écran lui laisse.
                Flickable {
                    id: defile
                    y: titre.height
                    width: parent.width
                    height: Math.min(message.implicitHeight, Math.max(0, cadre.plafond - cadre.reste))
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
                        color: Theme.color?.textSecondary ?? "transparent"
                    }
                }

                // Ligne toujours présente : l'identifiant de l'action, ou l'état, en fondu croisé.
                Item {
                    id: etat
                    y: defile.y + defile.height
                    width: parent.width
                    height: Math.max(ligne.implicitHeight, activite.implicitHeight)

                    property string montre: ""
                    property string ancien: ""
                    readonly property string texte: Autorisation.ligne.texte || Autorisation.action
                    // onTexteChanged — lance le fondu croisé. Entrées : aucune. Sortie : ancien, montre, croise.
                    // Erreurs : aucune.
                    onTexteChanged: { ancien = montre; montre = texte; croise.reprendre(0, 0) }
                    Component.onCompleted: montre = texte

                    Ressort { id: croise; transition: "state"; nature: "fondu"; cible: 1 }
                    Ressort { id: travail; transition: "state"; nature: "fondu"; cible: Autorisation.etat === "verification" ? 1 : 0 }
                    ColorSpring { id: encre; target: (cadre.refus ? Theme.color?.error : Theme.color?.textTertiary) ?? "transparent" }

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
                        elide: Text.ElideMiddle
                        maximumLineCount: 1
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
                        elide: Text.ElideMiddle
                        maximumLineCount: 1
                        echelon: 1
                        color: encre.value
                    }
                }
            }

            C.ChampSecret {
                id: champ
                x: cadre.marge + secousse.value
                y: parent.height - cadre.marge - height
                width: parent.width - 2 * cadre.marge - actions.width - (Theme.space?.scale[1] ?? 0)
                height: cadre.cotes?.rangee ?? 0
                focus: true
                enabled: Autorisation.saisieOuverte
                placeholderText: "Mot de passe"
                onAccepted: Autorisation.soumettre(text)
            }

            Item {
                id: actions
                x: parent.width - cadre.marge - width
                y: champ.y
                width: Math.max(autoriser.implicitWidth, fermer.implicitWidth)
                height: champ.height

                C.Bouton {
                    id: autoriser
                    anchors.fill: parent
                    text: "Autoriser"
                    opacity: 1 - verrou.value
                    visible: opacity > 0
                    enabled: Autorisation.saisieOuverte && champ.length > 0
                    onClicked: Autorisation.soumettre(champ.text)
                }
                C.Bouton {
                    id: fermer
                    anchors.fill: parent
                    text: "Fermer"
                    opacity: verrou.value
                    visible: opacity > 0
                    enabled: cadre.verrouille
                    onClicked: Autorisation.annuler()
                }
            }
        }
    }
}
