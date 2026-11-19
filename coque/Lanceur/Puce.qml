import QtQuick
import "../Theme"
import "../Composants"

// Puce — bouton en pilule du lanceur : suggestion de l'accueil ou bouton d'action de l'aperçu.
// Rôle : un bouton neutre (fond controlRaised au repos, reflet des médaillons, filet material.glassLine) portant une
// icône symbolique facultative, un libellé et, pour l'action principale, le rappel ↵. Choisie, la puce s'efface sur
// la plaque d'accent qui passe dessous : son fond s'éteint en fondu et son texte rejoint color.onAccent au ressort des
// états. Un clic l'active.
// Entrées : texte, libellé ; icone, nom freedesktop symbolique, vide par défaut ; rappel, vrai pour montrer « ↵ » ;
// choisie, vrai quand la plaque est dessous. Sorties : activee(), émis au clic. Erreurs : aucune ; avant le
// chargement des tokens, la puce est nulle et transparente.
// Dépendances : Icone, Texte, Ressort, ColorSpring, Theme (density, space, typo, icons, color, stateColors, material).
// Cotes : hauteur density.controlHeight (28, maquette 30), retrait space.scale[2] (12, maquette 14), écart
// space.scale[0] entre icône, libellé et rappel, icône de icons.sizes.dense (16, maquette 14), libellé à
// l'échelon 2 (13) en graisse moyenne, rappel à l'échelon 0 (11).
Item {
    id: puce

    property string texte
    property string icone
    property bool rappel: false
    property bool choisie: false
    signal activee()

    implicitHeight: Theme.density?.controlHeight ?? 0
    implicitWidth: rangee.implicitWidth + 2 * (Theme.space?.scale[2] ?? 0)

    Ressort { id: efface; transition: "state"; nature: "fondu"; cible: puce.choisie ? 1 : 0 }
    // Rappel ↵ : texte secondaire sur une puce neutre, sur-accent sur la plaque (aucune opacité sur une couleur de rôle).
    ColorSpring { id: rappelEncre; target: (puce.choisie ? Theme.color?.onAccent : Theme.color?.textSecondary) ?? "transparent" }
    ColorSpring { id: encre; target: (puce.choisie ? Theme.color?.onAccent : Theme.color?.textPrimary) ?? "transparent" }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        opacity: 1 - efface.value
        color: Theme.stateColors("controlRaised", "none", "rest")?.fill ?? "transparent"
        border.width: 1
        border.color: Theme.material?.glassLine ?? "transparent"

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            opacity: Theme.material?.medallionSheen ?? 0
            gradient: Gradient {
                GradientStop { position: 0; color: Theme.material?.highlight ?? "transparent" }
                GradientStop { position: Theme.material?.medallionSheenReach ?? 0; color: "transparent" }
            }
        }
    }

    Row {
        id: rangee
        anchors.centerIn: parent
        spacing: Theme.space?.scale[0] ?? 0

        Icone {
            anchors.verticalCenter: parent.verticalCenter
            visible: puce.icone !== ""
            nom: puce.icone
            taille: Theme.icons?.sizes.dense ?? 0
            couleur: encre.value
        }
        Texte {
            anchors.verticalCenter: parent.verticalCenter
            text: puce.texte
            moyen: true
            color: encre.value
        }
        Texte {
            anchors.verticalCenter: parent.verticalCenter
            visible: puce.rappel
            text: "↵"
            echelon: 0
            color: rappelEncre.value
        }
    }

    TapHandler { onTapped: puce.activee() }
    HoverHandler { cursorShape: Qt.PointingHandCursor }
}
