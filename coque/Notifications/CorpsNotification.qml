import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications
import "../Theme"
import "../Composants"

// CorpsNotification — contenu d'une notification, partagé par la carte de la pile et l'entrée du panneau (L2-67).
// Rôle : dessine la notification d'après la maquette validée (notifications-v1) : icône à gauche, puis le titre sur
// une ligne et le corps sur « lignes » lignes au plus ; une rangée d'actions en texte, alignée à droite, se déplie
// quand « survolee » est vrai, sur deux ressorts « reveal » (hauteur et opacité), et se replie ensuite. Avec enTete
// (la carte), une ligne d'en-tête porte le nom de l'application en capitales et l'heure d'arrivée ; sans elle
// (l'entrée du panneau, dont le groupe nomme déjà l'application), l'heure se pose à droite du titre. Le titre passe en
// error pour une notification critique, rien d'autre ne change. Aucun fond : le parent fournit la surface.
// Chaîne d'icône : l'image jointe, en disque, si elle est chargée ; sinon l'icône de l'application (nom résolu par
// Quickshell.iconPath, ou chemin de fichier), dans un carré arrondi ; sinon la cloche de la coque. Une image ou une
// icône introuvable ne laisse qu'un refus de chargement de Qt au journal, et la chaîne passe au maillon suivant. Rien
// n'est jamais téléchargé : seules les sources locales (chemin absolu, file://, image://) sont chargées, et une URL
// distante passe aussitôt au maillon suivant.
// Entrées : notification (objet à l'interface de Notification) ; arrivee, son heure d'arrivée ; lignes, nombre
// maximal de lignes de corps ; enTete, vrai par défaut ; survolee, posé par le parent : déplie les actions. La largeur
// est posée par le parent.
// Sorties : implicitHeight ; sourceIcone (« image », « application » ou « generique ») ; actionsVisibles, vrai tant
// que la rangée d'actions est au moins en partie dépliée ; enMouvement, vrai tant que le dépliant avance ;
// couleurTitre, lignesCorps, libelles (textes des actions affichés), texteApplication et texteHeure, lus par les
// essais ; signal action(a), au clic sur une action (objet à l'interface de NotificationAction).
// Erreurs : aucune ; sans jetons chargés, le contenu est de taille nulle et transparent.
// Dépendances : Quickshell (iconPath, QsWindow), Quickshell.Widgets (ClippingRectangle),
// Quickshell.Services.Notifications (NotificationUrgency), Theme (notifications, color, radius, space, police),
// Composants (Texte, Icone), Ressort.
// Corps : balisage StyledText de Qt, sans ses images (balises <img> retirées) ; ses liens restent inertes (aucun
// gestionnaire de lien) et prennent la couleur du corps.
Item {
    id: carte

    property QtObject notification: null
    property date arrivee
    property int lignes: Theme.notifications?.lignes ?? 1
    property bool enTete: true
    property bool survolee: false

    readonly property real cote: Theme.notifications?.icone ?? 0
    readonly property real ecart: Theme.space?.scale[2] ?? 0
    readonly property real dpr: QsWindow.window?.devicePixelRatio ?? 1
    // Actions dans leur ordre d'envoi, « default » (« Ouvrir ») en tête.
    readonly property var actions: notification
        ? Array.from(notification.actions).filter(a => a.identifier === "default")
            .concat(Array.from(notification.actions).filter(a => a.identifier !== "default"))
        : []
    readonly property string sourceIcone: photo.status === Image.Ready ? "image"
                                        : appli.status === Image.Ready ? "application" : "generique"
    readonly property bool actionsVisibles: depli.value > 0
    readonly property bool enMouvement: depli.moving || fondu.moving
    readonly property color couleurTitre: titre.color
    readonly property int lignesCorps: corps.lineCount
    readonly property var libelles: actions.map(libelle)
    readonly property string texteApplication: application.text
    readonly property string texteHeure: notification ? Qt.formatTime(arrivee, "HH:mm") : ""

    signal action(var a)

    implicitHeight: Math.max(cote, colonne.height)

    Ressort { id: depli; transition: "reveal"; cible: carte.survolee && carte.actions.length > 0 ? 1 : 0 }
    Ressort { id: fondu; transition: "reveal"; nature: "fondu"; cible: depli.cible }

    Item {
        id: icone
        // Centrée sur la hauteur du texte (en-tête, titre, corps), sans la rangée d'actions : l'icône ne bouge pas
        // pendant le dépliant du survol (recette de L2-19).
        y: Math.max(0, (colonne.hauteurTexte - carte.cote) / 2)
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
                source: carte.locale(carte.notification?.image ?? "")
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
        readonly property real hauteurTexte: entete.height + titre.height + (corps.visible ? corps.height : 0)
        x: icone.x + carte.cote + carte.ecart
        width: carte.width - x

        Item {
            id: entete
            width: parent.width
            height: carte.enTete ? application.implicitHeight : 0
            visible: carte.enTete

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
                text: carte.texteHeure
            }
        }

        Texte {
            id: titre
            width: parent.width - (carte.enTete ? 0 : heureTitre.implicitWidth + carte.ecart)
            echelon: 3
            moyen: true
            elide: Text.ElideRight
            maximumLineCount: 1
            color: carte.notification?.urgency === NotificationUrgency.Critical ? Theme.color?.error ?? "transparent"
                                                                               : Theme.color?.textPrimary ?? "transparent"
            text: carte.notification?.summary ?? ""

            // Sans ligne d'en-tête (entrée du panneau), l'heure se pose à droite du titre, sur sa ligne de base.
            Texte {
                id: heureTitre
                visible: !carte.enTete
                x: titre.parent.width - implicitWidth
                anchors.baseline: parent.baseline
                echelon: 0
                tabulaire: true
                color: Theme.color?.textTertiary ?? "transparent"
                text: carte.texteHeure
            }
        }

        Texte {
            id: corps
            width: parent.width
            visible: text !== ""
            // Wrap coupe aux mots, et n'importe où quand un mot dépasse la ligne.
            wrapMode: Text.Wrap
            textFormat: Text.StyledText
            maximumLineCount: carte.lignes
            elide: Text.ElideRight
            color: Theme.color?.textSecondary ?? "transparent"
            // Les liens restent inertes : ils prennent la couleur du corps, pas celle de Qt.
            lineHeightMode: Text.FixedHeight
            lineHeight: Math.round(font.pixelSize * (Theme.typo?.lineHeightBody ?? 1))
            linkColor: color
            // Les balises <img> sont retirées : StyledText chargerait l'image, locale ou distante, sans borne de taille.
            text: (carte.notification?.body ?? "").replace(/<img\b[^>]*>/gi, "")
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
                            onTapped: carte.action(parent.modelData)
                        }
                    }
                }
            }
        }
    }

    // libelle — texte affiché d'une action. Entrée : action, objet à l'interface de NotificationAction.
    // Sortie : « Ouvrir » pour l'action « default », son texte sinon. Erreurs : aucune. Dépendances : aucune.
    function libelle(action) { return action.identifier === "default" ? qsTr("Ouvrir") : action.text }

    // locale — source d'image locale, sans rien qui la ferait télécharger.
    // Entrée : source, chemin absolu ou URL. Sortie : une URL de fichier pour un chemin absolu, l'URL telle quelle pour
    // file:// et image:// (images fournies par Quickshell), « » pour toute autre URL (http, https…) et pour un texte
    // qui n'est ni l'un ni l'autre. Erreurs : aucune. Dépendances : aucune.
    function locale(source) {
        return source.startsWith("/") ? "file://" + source : /^(file|image):\/\//.test(source) ? source : ""
    }

    // cheminIcone — source d'image de l'icône d'une application.
    // Entrée : icone, nom freedesktop, chemin absolu ou URL. Sortie : la source locale (locale) pour un chemin ou une
    // URL, le chemin du thème pour un nom trouvé, « » sinon. Erreurs : aucune.
    // Dépendances : locale, Quickshell.iconPath.
    function cheminIcone(icone) {
        return icone.startsWith("/") || icone.includes("://") ? locale(icone)
            : icone !== "" ? Quickshell.iconPath(icone, true) : ""
    }
}
