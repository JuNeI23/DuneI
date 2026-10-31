import QtQuick
import Quickshell.Hyprland
import "../Theme"
import "bureaux.js" as Logique

// Bureaux — module « bureaux » de la presqu'île : une rangée centrée de points, dont celui du bureau actif
// s'allonge en pilule.
// Rôle : montre le bureau actif de son écran et l'état de son bureau spécial, et en commande le changement. Chaque
// point a un Ressort (transition « navigate ») sur sa largeur et un ColorSpring sur sa couleur : au changement de
// bureau, l'ancienne pilule redevient un point et la nouvelle s'allonge, une interruption en vol repartant de la
// position courante. Points inactifs en Theme.color.textDisabled ; pilule en Theme.color.accentDiscret, ou, sous
// un bureau spécial ouvert, dans la couleur des points inactifs. Survol (D92) : le point visé prend
// Theme.texteBureauSurvol, sans capsule. Une zone de clic par point, d'un nombre-ième de la largeur utile (sans les
// marges) ; la molette passe par pasMolette puis cibleMolette, le clic par commandesClic. Aucun minuteur.
// Entrées : ecran, écran de la presqu'île (obligatoire) ; idActif, identifiant du bureau actif, lié par défaut au
//           bureau actif du moniteur de l'écran (0 si inconnu) ; special, nom du bureau spécial ouvert
//           (« special:… ») ou "", tenu à jour par Hyprland.rawEvent (activespecial) pour le moniteur de l'écran.
//           L'essai écrit idActif et special directement : leurs liaisons par défaut se remplacent sans effet.
// Sorties : implicitWidth, nombre × point + (pilule − point) + (nombre − 1) × écart + 2 × marge ; implicitHeight,
//           hauteur de la presqu'île (contrat de tout module de contenu, seule chose que Presquile lit) ; points,
//           le répéteur des points, dont chaque délégué porte largeurCible et couleurCible (lus par les essais).
// Erreurs : aucune ; avant le chargement des jetons, les dimensions sont nulles et rien n'est peint. Une commande
//           Hyprland refusée se lit au journal de Quickshell.
// Dépendances : Theme (tokens, color, texteBureauSurvol), Ressort, ColorSpring, bureaux.js, Quickshell.Hyprland.
Item {
    id: bureaux

    required property var ecran
    property int idActif: Hyprland.monitorFor(ecran)?.activeWorkspace?.id ?? 0
    property string special: ""

    readonly property var gabarit: Theme.tokens?.presquile
    readonly property int nombre: Theme.tokens?.bureauxVirtuels?.nombre ?? 0
    readonly property int indexActif: Logique.indexPilule(idActif, nombre)
    readonly property Repeater points: repeteur
    property int survol: -1
    property real cumul: 0

    implicitWidth: nombre * (gabarit?.point ?? 0) + ((gabarit?.pilule ?? 0) - (gabarit?.point ?? 0))
        + Math.max(0, nombre - 1) * (gabarit?.ecart ?? 0) + 2 * (gabarit?.marge ?? 0)
    implicitHeight: gabarit?.hauteur ?? 0

    // Suit le bureau spécial ouvert sur le moniteur de cet écran : « special:<nom>,<moniteur> », nom vide à la
    // fermeture ; les autres moniteurs et les autres événements sont ignorés.
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "activespecial" && event.data.split(",")[1] === Hyprland.monitorFor(bureaux.ecran)?.name)
                bureaux.special = Logique.lireSpecial(event.data)
        }
    }

    // Les points, centrés ; la largeur de chacun est portée par un Ressort, sa couleur par un ColorSpring.
    Row {
        anchors.centerIn: parent
        spacing: bureaux.gabarit?.ecart ?? 0

        Repeater {
            id: repeteur
            model: bureaux.nombre

            Item {
                id: point
                required property int index
                readonly property bool pilule: index === bureaux.indexActif
                readonly property color repos: Theme.color?.textDisabled ?? "transparent"
                readonly property real largeurCible: pilule ? bureaux.gabarit?.pilule ?? 0 : bureaux.gabarit?.point ?? 0
                readonly property color couleurCible: pilule ? (bureaux.special !== "" ? repos
                    : Theme.color?.accentDiscret ?? "transparent")
                    : bureaux.survol === index ? Theme.texteBureauSurvol : repos

                width: etirement.value
                height: bureaux.gabarit?.point ?? 0
                anchors.verticalCenter: parent.verticalCenter

                Ressort { id: etirement; transition: "navigate"; cible: point.largeurCible }
                ColorSpring { id: teinte; target: point.couleurCible }

                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: teinte.value
                }
            }
        }
    }

    // Zones de clic, une par point, chacune d'un nombre-ième de la largeur utile ; le survol et la molette y passent.
    Row {
        x: bureaux.gabarit?.marge ?? 0
        width: bureaux.width - 2 * (bureaux.gabarit?.marge ?? 0)
        height: parent.height

        Repeater {
            model: bureaux.nombre

            MouseArea {
                required property int index
                width: parent.width / bureaux.nombre
                height: parent.height
                hoverEnabled: true
                onEntered: bureaux.survol = index
                onExited: if (bureaux.survol === index) bureaux.survol = -1
                onClicked: Logique.commandesClic(index + 1, bureaux.idActif, bureaux.special).forEach(Hyprland.dispatch)
            }
        }
    }

    // Molette sur toute la presqu'île : bureau suivant ou précédent, borné, en partant du bureau actif (celui qui
    // est sous le bureau spécial éventuel).
    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            const r = Logique.pasMolette(bureaux.cumul, event.angleDelta.y)
            bureaux.cumul = r.reste
            const cible = Logique.cibleMolette(bureaux.idActif, r.pas, bureaux.nombre)
            if (cible > 0) Hyprland.dispatch(Logique.commandeBureau(cible))
        }
    }
}
