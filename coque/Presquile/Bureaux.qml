import QtQuick
import Quickshell.Hyprland
import "../Composants"
import "../Theme"
import "bureaux.js" as Logique

// Bureaux — module « bureaux » de la presqu'île : une rangée centrée de points, dont celui du bureau actif
// s'allonge en pilule.
// Rôle : montre le bureau actif de son écran et l'état de son bureau spécial, et en commande le changement. Chaque
// point a un Ressort (transition « navigate ») sur sa largeur et un ColorSpring sur sa couleur : au changement de
// bureau, l'ancienne pilule redevient un point et la nouvelle s'allonge, une interruption en vol repartant de la
// position courante ; en mouvement réduit, les largeurs se posent aussitôt et la couleur reste animée. Points inactifs
// en Theme.color.textDisabled ; pilule en Theme.color.accentDiscret, ou, sous
// un bureau spécial ouvert, dans la couleur des points inactifs. Survol (D92) : le point visé passe à
// Theme.color.textTertiary, un cran d'emphase de la rampe du thème, lue sur la surface de la coque (et non le texte
// du bureau, choisi sur la luminance du fond d'écran), sans capsule ; la pilule grisée par un spécial réagit de même,
// puisqu'un clic la referme. Une zone de clic par point, contiguë aux voisines (un demi-écart de chaque côté, la marge aux
// extrémités) ; la molette passe par pasMolette puis cibleMolette, le clic par commandesClic. Aucun minuteur.
// Entrées : ecran, écran de la presqu'île (obligatoire) ; idActif, identifiant du bureau actif, lié par défaut au
//           bureau actif du moniteur de l'écran (0 si inconnu) ; special, nom du bureau spécial ouvert
//           (« special:… ») ou "", lié par défaut à PleinEcran pour le moniteur de l'écran.
//           L'essai écrit idActif et special directement : leurs liaisons par défaut se remplacent sans effet.
// Sorties : implicitWidth, nombre × point + (pilule − point) + (nombre − 1) × écart + 2 × marge ; implicitHeight,
//           hauteur de la presqu'île (contrat de tout module de contenu, seule chose que Presquile lit) ; points,
//           le répéteur des points, dont chaque délégué porte largeurCible et couleurCible (lus par les essais).
// Erreurs : aucune ; avant le chargement des jetons, les dimensions sont nulles et rien n'est peint. Une commande
//           Hyprland refusée se lit au journal de Quickshell.
// Dépendances : Theme (tokens, color), Ressort, ColorSpring, PleinEcran, bureaux.js, Quickshell.Hyprland.
Item {
    id: bureaux

    required property var ecran
    property int idActif: Hyprland.monitorFor(ecran)?.activeWorkspace?.id ?? 0
    property string special: PleinEcran.special(ecran?.name ?? "")

    readonly property var gabarit: Theme.tokens?.presquile
    readonly property int nombre: Theme.tokens?.bureauxVirtuels?.nombre ?? 0
    readonly property int indexActif: Logique.indexPilule(idActif, nombre)
    readonly property Repeater points: repeteur
    property int survol: -1
    property real cumul: 0
    property int viseEmise: 0
    onIdActifChanged: viseEmise = 0

    implicitWidth: nombre * (gabarit?.point ?? 0) + ((gabarit?.pilule ?? 0) - (gabarit?.point ?? 0))
        + Math.max(0, nombre - 1) * (gabarit?.ecart ?? 0) + 2 * (gabarit?.marge ?? 0)
    implicitHeight: gabarit?.hauteur ?? 0

    // Les points, alignés depuis la marge (la rangée ne glisse pas quand la pilule apparaît ou disparaît) ;
    // la largeur de chacun est portée par un Ressort, sa couleur par un ColorSpring.
    Row {
        anchors.verticalCenter: parent.verticalCenter
        x: bureaux.gabarit?.marge ?? 0
        spacing: bureaux.gabarit?.ecart ?? 0

        Repeater {
            id: repeteur
            model: bureaux.nombre

            Item {
                id: point
                required property int index
                readonly property bool pilule: index === bureaux.indexActif
                readonly property color repos: Theme.color?.textDisabled ?? "transparent"
                readonly property color emphase: bureaux.survol === index ? Theme.color?.textTertiary ?? "transparent" : repos
                readonly property real largeurCible: pilule ? bureaux.gabarit?.pilule ?? 0 : bureaux.gabarit?.point ?? 0
                readonly property color couleurCible: pilule ? (bureaux.special === "" ? Theme.color?.accentDiscret ?? "transparent" : emphase)
                    : emphase

                width: etirement.value
                height: bureaux.gabarit?.point ?? 0
                anchors.verticalCenter: parent.verticalCenter

                readonly property Item zoneClic: zone

                Ressort { id: etirement; transition: "navigate"; nature: "deplacement"; cible: point.largeurCible }
                ColorSpring { id: teinte; target: point.couleurCible }

                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: teinte.value
                }

                // Zone de clic et de survol du point : toute la hauteur du module, étendue d'un demi-écart de chaque côté
                // (de la marge pour le premier et le dernier point), de sorte que les zones se touchent, suivent le
                // ressort et que le centre de chaque point reste dans la sienne.
                MouseArea {
                    id: zone
                    readonly property real avant: point.index === 0 ? bureaux.gabarit?.marge ?? 0 : (bureaux.gabarit?.ecart ?? 0) / 2
                    readonly property real apres: point.index === bureaux.nombre - 1 ? bureaux.gabarit?.marge ?? 0 : (bureaux.gabarit?.ecart ?? 0) / 2
                    x: -avant
                    width: point.width + avant + apres
                    height: bureaux.height
                    anchors.verticalCenter: parent.verticalCenter
                    hoverEnabled: true
                    onEntered: bureaux.survol = point.index
                    onExited: if (bureaux.survol === point.index) bureaux.survol = -1
                    onClicked: Logique.commandesClic(point.index + 1, bureaux.idActif, bureaux.special).forEach(c => Hyprland.dispatch(c))
                }
            }
        }
    }

    // Molette sur toute la presqu'île : bureau suivant ou précédent, borné, en partant du dernier bureau visé tant
    // que Hyprland n'a pas confirmé le changement (plusieurs pas peuvent précéder la mise à jour de idActif), sinon
    // du bureau actif (celui qui est sous le bureau spécial éventuel).
    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            const r = Logique.pasMolette(bureaux.cumul, event.angleDelta.y)
            bureaux.cumul = r.reste
            const depart = bureaux.viseEmise > 0 ? bureaux.viseEmise : bureaux.idActif
            const cible = Logique.cibleMolette(depart, r.pas, bureaux.nombre)
            if (cible > 0) {
                bureaux.viseEmise = cible
                Hyprland.dispatch(Logique.commandeBureau(cible))
            }
        }
    }
}
