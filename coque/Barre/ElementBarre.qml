import QtQuick
import QtQuick.Templates as T
import "../Theme"
import "../Composants"

// ElementBarre — élément générique de la barre système : une icône ou une image, et un texte, sans fond.
// Rôle : affiche un état ou une action de la barre. Sans fond ni capsule, la couleur porte tout l'état : repos
// Theme.texteBureau, survol (éléments cliquables seuls) Theme.texteBureauSurvol, appui ou menu ouvert
// Theme.color.accentStandalone, chaque changement lissé par un ColorSpring. Tant que le menu de l'élément est ouvert,
// l'icône passe aussi à sa variante pleine, en fondu enchaîné, pour lier la barre au popover qu'elle a ouvert (D103).
// L'icône et son texte descendent de Theme.motion.popover.icon_travel_px tant que le menu est ouvert. À l'appui, à
// l'ouverture comme à la fermeture, la couleur, la descente et le passage à l'icône pleine suivent le ressort
// « overlay » ; le survol seul garde le ressort « state ». Mouvement réduit : l'icône ne descend pas (la descente est
// un déplacement), la variante pleine paraît en fondu court et les couleurs restent animées.
// « pleine » montre la variante pleine sans ouvrir de menu : ni accent ni descente (la cloche qui a des notifications
// à traiter, L2-67). « fondu » fait passer un changement de nom d'icône par un fondu croisé au ressort « state » :
// l'ancien glyphe reste peint, sur une couche sortante, le temps que le nouveau paraisse ; sans lui, le glyphe change
// d'un coup, comme pour les indicateurs dont l'icône suit une mesure (force du signal, charge).
// Entrées : icone, nom d'icône sans « -symbolic » ; source, image recolorée à la place d'une icône nommée (le
// logo) ; texte ; cliquable, faux par défaut (un élément d'affichage ne réagit ni au survol ni à l'appui) ;
// ouvert, vrai tant que le menu de l'élément est ouvert ; pleine et fondu, faux par défaut (voir ci-dessus) ; taille, côté de l'icône en pixels logiques,
// Theme.icons.sizes.dense par défaut (le logo la fixe à Theme.icons.sizes.default). Le texte suit l'échelon 3
// de l'échelle typographique (15 px), en chiffres tabulaires.
// Sorties : celles de T.AbstractButton (clicked, hovered, down) ; couleurRessort, le ColorSpring de la couleur, lu par
// les essais ; remplissage, part de la variante pleine (0 creuse, 1 pleine) ; sortant, la couche du glyphe sortant
// d'un fondu ; cadreIcone, l'Item du glyphe, où un indicateur pose une surcouche qui le suit (pastille de la cloche).
// L'élément est invisible, et donc absent de la rangée, quand ni icône, ni image, ni texte ne sont fournis
// (matériel absent).
// Erreurs : aucune ; avant le chargement des jetons, la couleur est transparente.
// Dépendances : Theme (texteBureau, color, typo), Composants (Icone, qui porte l'image recolorée, et Texte),
// ColorSpring, Ressort.
T.AbstractButton {
    id: element

    property string icone
    property url source
    property string texte
    property bool cliquable: false
    property bool ouvert: false
    property bool pleine: false
    property bool fondu: false
    property int taille: Theme.icons?.sizes.dense ?? 0

    focusPolicy: Qt.NoFocus
    hoverEnabled: true
    enabled: cliquable
    visible: icone !== "" || source != "" || texte !== ""
    implicitWidth: rangee.implicitWidth
    implicitHeight: 24

    readonly property alias couleurRessort: ressort
    readonly property alias remplissage: plein.value
    readonly property alias sortant: sortant
    readonly property alias cadreIcone: cadre
    // Nom de l'icône montrée avant le dernier changement, peint par la couche sortante pendant un fondu.
    property string ancienne: ""
    property string _montree: icone

    onIconeChanged: {
        if (fondu && _montree !== "" && icone !== "") { ancienne = _montree; croise.reprendre(0, 0) }
        _montree = icone
    }

    // Descente de l'icône, en pixels : icon_travel_px tant que son menu est ouvert, et jamais en mouvement réduit. Le
    // seuil de repos est celui du cadre des popovers (rest_threshold_px) : il supprime la fin du mouvement qui rampe.
    Ressort {
        id: abaisse
        transition: "overlay"
        seuil: Theme.motion?.popover.rest_threshold_px ?? 0
        cible: element.ouvert && !Theme.mouvementReduit ? Theme.motion?.popover.icon_travel_px ?? 0 : 0
    }

    // La couleur suit le ressort « overlay » à l'appui, tant que le menu est ouvert et tant que l'icône bouge (y compris
    // à la fermeture) ; le survol seul garde « state ».
    ColorSpring {
        id: ressort
        params: element.down || element.ouvert || abaisse.moving ? Theme.motion?.transitions.overlay.in : Theme.motion?.transitions.state.in
        target: element.down || element.ouvert ? Theme.color?.accentStandalone ?? "transparent"
              : element.cliquable && element.hovered ? Theme.texteBureauSurvol : Theme.texteBureau
    }

    contentItem: Row {
        id: rangee
        transform: Translate { y: abaisse.value }
        spacing: Theme.space?.scale[0] ?? 0

        // Icône creuse et icône pleine superposées ; le ressort plein va de 0 (creuse) à 1 (pleine : menu ouvert, ou
        // « pleine »). Le ressort croise va de 0 à 1 à chaque fondu d'un changement d'icône : la couche courante
        // paraît à sa mesure pendant que la couche sortante, qui peint l'ancien nom, s'efface.
        Item {
            id: cadre
            anchors.verticalCenter: parent.verticalCenter
            visible: element.icone !== "" || element.source != ""
            implicitWidth: element.taille
            implicitHeight: element.taille

            Ressort {
                id: plein
                transition: element.ouvert || abaisse.moving ? "overlay" : "state"
                nature: "fondu"
                cible: (element.ouvert || element.pleine) && element.icone !== "" ? 1 : 0
            }
            Ressort { id: croise; transition: "state"; nature: "fondu"; cible: 1 }

            Item {
                anchors.fill: parent
                opacity: croise.value
                Icone {
                    anchors.fill: parent
                    opacity: 1 - plein.value
                    taille: element.taille
                    nom: element.icone
                    image: element.source
                    couleur: ressort.value
                }
                Icone {
                    anchors.fill: parent
                    visible: plein.value > 0
                    opacity: plein.value
                    taille: element.taille
                    nom: element.icone
                    pleine: true
                    couleur: ressort.value
                }
            }
            Item {
                id: sortant
                anchors.fill: parent
                visible: opacity > 0
                opacity: 1 - croise.value
                Icone {
                    anchors.fill: parent
                    opacity: 1 - plein.value
                    taille: element.taille
                    nom: element.ancienne
                    couleur: ressort.value
                }
                Icone {
                    anchors.fill: parent
                    visible: plein.value > 0
                    opacity: plein.value
                    taille: element.taille
                    nom: element.ancienne
                    pleine: true
                    couleur: ressort.value
                }
            }
        }

        Texte {
            anchors.verticalCenter: parent.verticalCenter
            visible: element.texte !== ""
            echelon: 3
            tabulaire: true
            text: element.texte
            color: ressort.value
        }
    }
}
