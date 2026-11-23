import QtQuick
import "../Theme"
import "../Composants"

// Puce — bouton en pilule du lanceur : suggestion de l'accueil ou bouton d'action de l'aperçu.
// Rôle : un bouton neutre (fond controlRaised au repos, reflet des médaillons, filet material.glassLine) portant une
// icône symbolique facultative, un libellé et un rappel de touche (« ↵ » par défaut, « Ctrl ↵ » pour Nouvelle fenêtre),
// qui apparaît et s'efface en fondu au ressort des états ; sa place est gardée si reserveRappel est vrai, pour que la
// largeur de la puce ne saute pas quand le rappel passe d'un bouton à l'autre. Le curseur se montre comme sur les
// médaillons de l'accueil, sur l'élément lui-même : choisie, la puce prend le fond color.accent, son contenu passe à
// color.onAccent et elle grandit à galerie.echelle, au ressort des états ; seule la puce sous le curseur porte
// l'accent. En danger, son fond passe à color.error, contenu en color.onAccent, choisie ou
// non : c'est un état de danger, pas une sélection. Un clic l'active.
// Entrées : texte, libellé ; icone, nom freedesktop symbolique, vide par défaut ; rappel, vrai pour montrer le rappel ;
// texteRappel, « ↵ » par défaut ; reserveRappel, vrai pour garder la place du rappel caché ; choisie, vrai sous le
// curseur ; danger, vrai pour une action destructrice. Sorties : activee(), émis au clic. Erreurs : aucune ; avant le
// chargement des tokens, la puce est nulle et transparente.
// Dépendances : Icone, Texte, Ressort, ColorSpring, Theme (density, space, typo, icons, color, stateColors, material,
// galerie).
// Cotes : hauteur density.controlHeight (28, maquette 30), retrait space.scale[2] (12, maquette 14), écart
// space.scale[0] entre icône, libellé et rappel, icône de icons.sizes.dense (16, maquette 14), libellé à
// l'échelon 2 (13) en graisse moyenne, rappel à l'échelon 0 (11).
Item {
    id: puce

    property string texte
    property string icone
    property bool rappel: false
    property string texteRappel: "↵"
    property bool reserveRappel: false
    property bool choisie: false
    property bool danger: false
    // Vrai quand le fond porte une couleur pleine (accent ou erreur) : le contenu passe alors à color.onAccent.
    readonly property bool pleine: choisie || danger
    signal activee()

    implicitHeight: Theme.density?.controlHeight ?? 0
    implicitWidth: rangee.implicitWidth + 2 * (Theme.space?.scale[2] ?? 0)

    transform: Scale { origin.x: puce.width / 2; origin.y: puce.height / 2; xScale: grandeur.value; yScale: xScale }

    Ressort { id: montreRappel; transition: "state"; nature: "fondu"; cible: puce.rappel ? 1 : 0 }
    // Croissance de la puce choisie, à l'échelle des éléments choisis (galerie.echelle), comme les médaillons.
    Ressort { id: grandeur; transition: "state"; cible: puce.choisie ? Theme.galerie?.echelle ?? 1 : 1 }
    // Fond : neutre au repos, accent sous le curseur, erreur en danger.
    ColorSpring {
        id: fond
        target: (puce.danger ? Theme.color?.error : puce.choisie ? Theme.color?.accent
                 : Theme.stateColors("controlRaised", "none", "rest")?.fill) ?? "transparent"
    }
    // Rappel ↵ : texte secondaire sur une puce neutre, sur-accent sur un fond plein (aucune opacité sur une couleur de rôle).
    ColorSpring { id: rappelEncre; target: (puce.pleine ? Theme.color?.onAccent : Theme.color?.textSecondary) ?? "transparent" }
    ColorSpring { id: encre; target: (puce.pleine ? Theme.color?.onAccent : Theme.color?.textPrimary) ?? "transparent" }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: fond.value
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
            visible: puce.rappel || puce.reserveRappel
            opacity: montreRappel.value
            text: puce.texteRappel
            echelon: 0
            color: rappelEncre.value
        }
    }

    TapHandler { onTapped: puce.activee() }
    HoverHandler { cursorShape: Qt.PointingHandCursor }
}
