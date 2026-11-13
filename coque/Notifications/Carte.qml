import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications
import "../Theme"
import "../Composants"

// Carte — une notification affichée dans la pile, en verre e3 comme les popovers.
// Rôle : dessine la notification courante d'une entrée d'après la maquette validée (notifications-v1) : icône à
// gauche, puis en tête le nom de l'application en capitales avec l'heure d'arrivée, le titre sur une ligne et le corps
// sur Theme.notifications.lignes lignes au plus ; une rangée d'actions en texte, alignée à droite, se déplie au survol
// sur deux ressorts « reveal » (hauteur et opacité) et se replie à sa sortie. Le titre passe en error pour une
// notification critique, rien d'autre ne change. Le survol est écrit dans l'entrée, qui suspend sa minuterie.
// Chaîne d'icône : l'image jointe, en disque, si elle est chargée ; sinon l'icône de l'application (nom résolu par
// Quickshell.iconPath, ou chemin de fichier), dans un carré arrondi ; sinon la cloche de la coque. Une image ou une
// icône introuvable ne laisse qu'un refus de chargement de Qt au journal, et la chaîne passe au maillon suivant.
// Entrées : entree, l'Entree tenue par la pile ; pile, la Pile, qui reçoit les clics.
// Sorties : implicitHeight, contenu et marges compris (la largeur est fixée à Theme.notifications.largeur) ;
// survolee ; sourceIcone (« image », « application » ou « generique ») ; actionsVisibles, vrai tant que la rangée
// d'actions est au moins en partie dépliée ; enMouvement, vrai tant que le dépliant avance ; couleurTitre,
// lignesCorps, libelles (textes des actions affichés), texteApplication et texteHeure, lus par les essais.
// Erreurs : aucune ; sans jetons chargés, la carte est de taille nulle et transparente.
// Dépendances : Quickshell (iconPath, QsWindow), Quickshell.Widgets (ClippingRectangle),
// Quickshell.Services.Notifications (NotificationUrgency), Theme (notifications, color, radius, space, police),
// Composants (Surface, OmbreElevation, Texte, Icone), Ressort, Entree, Pile.
// Corps : balisage StyledText de Qt ; ses liens restent inertes (aucun gestionnaire de lien).
Item {
    id: carte

    required property QtObject entree
    required property QtObject pile

    readonly property QtObject notification: entree?.notification ?? null
    readonly property real interieur: Theme.notifications?.interieur ?? 0
    readonly property real cote: Theme.notifications?.icone ?? 0
    readonly property real ecart: Theme.space?.scale[2] ?? 0
    readonly property real dpr: QsWindow.window?.devicePixelRatio ?? 1
    readonly property var actions: notification ? Array.from(notification.actions) : []
    readonly property bool survolee: entree?.survolee ?? false
    readonly property string sourceIcone: photo.status === Image.Ready ? "image"
        : appli.status === Image.Ready ? "application" : "generique"
    readonly property bool actionsVisibles: depli.value > 0
    readonly property bool enMouvement: depli.moving || fondu.moving
    readonly property color couleurTitre: titre.color
    readonly property int lignesCorps: corps.lineCount
    readonly property var libelles: actions.map(libelle)
    readonly property string texteApplication: application.text
    readonly property string texteHeure: heure.text

    width: Theme.notifications?.largeur ?? 0
    implicitHeight: Math.max(cote, colonne.height) + 2 * interieur

    // Le survol de la carte est celui de l'entrée : la pile en déduit l'arrêt de la minuterie.
    HoverHandler { id: survol }
    Binding { target: carte.entree; property: "survolee"; value: survol.hovered; when: carte.entree !== null }

    // Clic hors des actions : la notification est écartée. Chaque action saisit son propre clic dès l'appui
    // (ReleaseWithinBounds), si bien qu'il n'atteint pas ce gestionnaire.
    TapHandler { gesturePolicy: TapHandler.ReleaseWithinBounds; onTapped: carte.pile.cliquer(carte.entree) }

    Ressort { id: depli; transition: "reveal"; cible: carte.survolee && carte.actions.length > 0 ? 1 : 0 }
    Ressort { id: fondu; transition: "reveal"; nature: "fondu"; cible: depli.cible }

    OmbreElevation { cible: verre; niveau: "e3"; evidee: true }

    Surface {
        id: verre
        anchors.fill: parent
        role: "surfaceRaised"
        verre: true
        radius: Theme.radius?.panel ?? 0
    }

    Item {
        id: icone
        x: carte.interieur
        y: carte.interieur
        width: carte.cote
        height: carte.cote

        ClippingRectangle {
            anchors.fill: parent
            radius: width / 2
            color: "transparent"
            visible: carte.sourceIcone === "image"

            Image {
                id: photo
                anchors.fill: parent
                source: carte.notification?.image ?? ""
                fillMode: Image.PreserveAspectCrop
                sourceSize: Qt.size(carte.cote * carte.dpr, carte.cote * carte.dpr)
                cache: true
                asynchronous: false
            }
        }

        ClippingRectangle {
            anchors.fill: parent
            radius: Theme.radius?.small ?? 0
            color: "transparent"
            visible: carte.sourceIcone === "application"

            Image {
                id: appli
                anchors.fill: parent
                // Rien n'est chargé tant que l'image jointe suffit.
                source: photo.status === Image.Ready ? "" : carte.cheminIcone(carte.notification?.appIcon ?? "")
                fillMode: Image.PreserveAspectFit
                sourceSize: Qt.size(carte.cote * carte.dpr, carte.cote * carte.dpr)
                cache: true
                asynchronous: false
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: Theme.radius?.small ?? 0
            color: Theme.color?.accent ?? "transparent"
            visible: carte.sourceIcone === "generique"

            Icone { anchors.centerIn: parent; nom: "preferences-system-notifications"; couleur: Theme.color?.onAccent ?? "transparent" }
        }
    }

    Column {
        id: colonne
        x: icone.x + carte.cote + carte.ecart
        y: carte.interieur
        width: carte.width - x - carte.interieur

        Item {
            width: parent.width
            height: application.implicitHeight

            Texte {
                id: application
                width: parent.width - heure.implicitWidth - carte.ecart
                echelon: 0
                moyen: true
                elide: Text.ElideRight
                color: Theme.color?.textTertiary ?? "transparent"
                text: (carte.notification?.appName ?? "").toUpperCase()
            }
            Texte {
                id: heure
                anchors.right: parent.right
                echelon: 0
                tabulaire: true
                color: Theme.color?.textTertiary ?? "transparent"
                text: carte.entree ? Qt.formatTime(carte.entree.arrivee, "HH:mm") : ""
            }
        }

        Texte {
            id: titre
            width: parent.width
            moyen: true
            elide: Text.ElideRight
            maximumLineCount: 1
            color: carte.notification?.urgency === NotificationUrgency.Critical ? Theme.color?.error ?? "transparent"
                                                                               : Theme.color?.textPrimary ?? "transparent"
            text: carte.notification?.summary ?? ""
        }

        Texte {
            id: corps
            width: parent.width
            visible: text !== ""
            // Wrap coupe aux mots, et n'importe où quand un mot dépasse la ligne.
            wrapMode: Text.Wrap
            textFormat: Text.StyledText
            maximumLineCount: Theme.notifications?.lignes ?? 1
            elide: Text.ElideRight
            color: Theme.color?.textSecondary ?? "transparent"
            text: carte.notification?.body ?? ""
        }

        // Rangée d'actions : hauteur et opacité suivent le dépliant ; le ressort peut dépasser, la hauteur reste
        // positive.
        Item {
            width: parent.width
            height: Math.max(0, depli.value) * (rangee.implicitHeight + (Theme.space?.scale[0] ?? 0))
            clip: true
            visible: carte.actions.length > 0 && height > 0

            Row {
                id: rangee
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                spacing: carte.ecart
                opacity: Math.max(0, fondu.value)

                Repeater {
                    model: carte.actions

                    Texte {
                        required property QtObject modelData
                        moyen: true
                        color: Theme.color?.accentStandalone ?? "transparent"
                        text: carte.libelle(modelData)

                        TapHandler {
                            gesturePolicy: TapHandler.ReleaseWithinBounds
                            onTapped: carte.pile.agir(carte.entree, parent.modelData)
                        }
                    }
                }
            }
        }
    }

    // libelle — texte affiché d'une action. Entrée : action, objet à l'interface de NotificationAction.
    // Sortie : « Ouvrir » pour l'action « default », son texte sinon. Erreurs : aucune. Dépendances : aucune.
    function libelle(action) { return action.identifier === "default" ? qsTr("Ouvrir") : action.text }

    // cheminIcone — source d'image de l'icône d'une application.
    // Entrée : icone, nom freedesktop, chemin absolu ou URL. Sortie : une URL de fichier pour un chemin, l'URL telle
    // quelle, le chemin du thème pour un nom trouvé, « » sinon. Erreurs : aucune. Dépendances : Quickshell.iconPath.
    function cheminIcone(icone) {
        return icone.startsWith("/") ? "file://" + icone : icone.includes("://") ? icone
            : icone !== "" ? Quickshell.iconPath(icone, true) : ""
    }
}
