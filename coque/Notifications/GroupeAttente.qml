import QtQuick
import Quickshell
import "../Theme"
import "../Composants"

// GroupeAttente — les notifications en attente d'une application, dans le panneau (L2-67).
// Rôle : sous un filet (Separateur), une ligne de titre porte le nom de l'application en capitales et, à droite, le
// nombre de ses notifications ; au survol du groupe, deux actions en texte remplacent le nombre, en fondu croisé :
// « Effacer » (écarte le groupe) et « Ne plus garder » (écarte le groupe et retire l'application du panneau ;
// absente pour une application anonyme, que l'on ne peut pas retirer sans faire taire toutes les anonymes). Replié,
// le groupe ne montre que sa notification la plus récente et, s'il en a d'autres, « N autres » ; un clic sur ce
// libellé le déplie : chaque ligne se déplie au ressort « reveal » (LigneAttente). Le groupe garde ses entrées
// sortantes le temps de leur repli ; quand plus aucune ne compte, il se replie tout entier.
// Entrées : identifiant, celui de l'application (garde.js) ; donnees, l'objet { nom, entrees } de garde.js, grouper,
// sortantes comprises, ou null ; attente, l'Attente ; hote, le Panneau (deplies, deplier, effacerGroupe,
// nePlusGarder, pret).
// Sorties : nom ; vivantes ; nombre, celui des entrées qui comptent ; deplie ; retirable ; autres, le libellé « N
// autres » (vide s'il n'y en a pas) ; lignes, nombre de lignes montrées ; height, hauteur montrée.
// Erreurs : aucune. Dépendances : Quickshell (ScriptModel), LigneAttente, Separateur, Texte, Ressort, Theme (space,
// density, color).
// Cotes : ligne de titre de density.rowHeight ; « N autres » en texte tertiaire, aligné sur le texte des lignes ; écart de space.scale[1] (8) entre le filet, le titre et les lignes.
Item {
    id: groupe

    required property QtObject attente
    required property QtObject hote
    property string identifiant
    property var donnees: null
    readonly property string nom: donnees?.nom ?? ""
    readonly property var entrees: donnees?.entrees ?? []
    readonly property var vivantes: entrees.filter(a => !a.sortante)
    readonly property int nombre: vivantes.length
    readonly property bool deplie: hote.deplies[identifiant] ?? false
    readonly property bool retirable: identifiant !== ""
    readonly property string autres: deplie || nombre < 2 ? ""
        : nombre === 2 ? qsTr("1 autre") : qsTr("%1 autres").arg(nombre - 1)
    readonly property int lignes: deplie ? nombre : Math.min(1, nombre)
    readonly property real ecart: Theme.space?.scale[1] ?? 0
    // Dernier nom et dernier libellé non vides, gardés pendant le repli.
    property string _nom: nom
    property string _autres: autres

    onNomChanged: if (nom !== "") _nom = nom
    onAutresChanged: if (autres !== "") _autres = autres

    height: Math.max(0, presence.value) * corps.height
    opacity: Math.max(0, Math.min(1, fondu.value))
    visible: height > 0
    clip: presence.moving

    Ressort { id: presence; transition: "reveal"; cible: groupe.nombre > 0 ? 1 : 0 }
    Ressort { id: fondu; transition: "reveal"; nature: "fondu"; cible: presence.cible }
    Ressort { id: actions; transition: "state"; nature: "fondu"; cible: survol.hovered ? 1 : 0 }
    Ressort { id: suite; transition: "reveal"; cible: groupe.autres !== "" ? 1 : 0 }

    Component.onCompleted: if (hote.pret && nombre > 0) { presence.reprendre(0, 0); fondu.reprendre(0, 0) }

    HoverHandler { id: survol }

    Column {
        id: corps
        width: groupe.width

        Separateur { width: parent.width }
        Item { width: 1; height: groupe.ecart }

        Item {
            width: parent.width
            height: Theme.density?.rowHeight ?? 0

            Texte {
                anchors.verticalCenter: parent.verticalCenter
                x: groupe.ecart
                width: parent.width - 2 * groupe.ecart - Math.max(compte.implicitWidth, gestes.implicitWidth) - groupe.ecart
                echelon: 0
                moyen: true
                elide: Text.ElideRight
                color: Theme.color?.textTertiary ?? "transparent"
                text: groupe._nom.toUpperCase()
            }
            Texte {
                id: compte
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                anchors.rightMargin: groupe.ecart
                opacity: 1 - actions.value
                echelon: 0
                tabulaire: true
                color: Theme.color?.textTertiary ?? "transparent"
                text: groupe.nombre
            }
            Row {
                id: gestes
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                anchors.rightMargin: groupe.ecart
                spacing: Theme.space?.scale[2] ?? 0
                visible: opacity > 0
                opacity: actions.value

                Texte {
                    visible: groupe.retirable
                    echelon: 1
                    moyen: true
                    color: Theme.color?.accentStandalone ?? "transparent"
                    text: qsTr("Ne plus garder")
                    TapHandler {
                        gesturePolicy: TapHandler.ReleaseWithinBounds
                        onTapped: groupe.hote.nePlusGarder(groupe.identifiant)
                    }
                }
                Texte {
                    echelon: 1
                    moyen: true
                    color: Theme.color?.accentStandalone ?? "transparent"
                    text: qsTr("Effacer")
                    TapHandler {
                        gesturePolicy: TapHandler.ReleaseWithinBounds
                        onTapped: groupe.hote.effacerGroupe(groupe.identifiant)
                    }
                }
            }
        }

        Repeater {
            model: ScriptModel { values: groupe.entrees }

            LigneAttente {
                required property QtObject modelData
                width: corps.width
                attendue: modelData
                attente: groupe.attente
                hote: groupe.hote
                montree: groupe.deplie || modelData === groupe.vivantes[0]
            }
        }

        // « N autres » : se replie quand le groupe se déplie ou n'a plus qu'une notification.
        Item {
            width: parent.width
            height: Math.max(0, suite.value) * (Theme.density?.rowHeight ?? 0)
            visible: height > 0
            clip: true

            // Aligné sur la colonne du texte des lignes : retrait, icône, écart (maquette panneau-v1, « .plus »).
            Texte {
                anchors.verticalCenter: parent.verticalCenter
                x: groupe.ecart + (Theme.notifications?.icone ?? 0) + (Theme.space?.scale[2] ?? 0)
                echelon: 1
                color: Theme.color?.textTertiary ?? "transparent"
                text: groupe._autres
                TapHandler {
                    gesturePolicy: TapHandler.ReleaseWithinBounds
                    onTapped: groupe.hote.deplier(groupe.identifiant)
                }
            }
        }
        Item { width: 1; height: groupe.ecart }
    }
}
