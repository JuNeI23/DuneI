import QtQuick
import QtQuick.Layouts
import "../Theme"
import "../Composants"

// EnTetePage — carte d'en-tête d'une page de réglages : grande vignette, titre, phrase d'état, contrôle à droite.
// Rôle : ouvre chaque page de l'application Paramètres. La carte est un aplat surfaceRaised au rayon radius.panel,
// sur lequel une lueur discrète de la teinte de la page part du coin de la vignette, à l'intensité
// material.headerGlow (relief « Doux » de la fiche). L'état de la page, que la barre latérale ne montre plus, se lit
// ici.
// Entrées : glyphe et teinte, transmis à la Vignette ; titre ; etat, phrase d'état, vide par défaut (la ligne
// disparaît) ; le contrôle (un Interrupteur, par exemple), déclaré comme enfant, se pose à droite.
// Sorties : dnRole (« surfaceRaised »), que lisent les contrôles posés dans la carte ; vignette, la Vignette.
// Erreurs : aucune ; avant le chargement des tokens, les cotes sont nulles et le fond transparent.
// Dépendances : Vignette, Lueur, Texte, Theme (color, radius, space, reglages, icons, material.headerGlow),
// QtQuick.Layouts.
// Cotes : vignette du double de reglages.thumb, au rayon radius.panel, glyphe de icons.sizes.comfortable ; retraits
// de space.scale[3] à l'horizontale et de space.scale[2] à la verticale ; titre en échelon 4, état en échelon 1.
Item {
    id: enTete

    property string glyphe
    property int teinte: 0
    property string titre
    property string etat
    default property alias controle: emplacement.data
    readonly property string dnRole: "surfaceRaised"
    readonly property alias vignette: vignette

    implicitHeight: rangee.implicitHeight + 2 * (Theme.space?.scale[2] ?? 0)

    Rectangle { anchors.fill: parent; radius: Theme.radius?.panel ?? 0; color: Theme.color?.surfaceRaised ?? "transparent" }
    Lueur {
        anchors.fill: parent
        rayon: Theme.radius?.panel ?? 0
        teinte: vignette.couleur
        portee: 0.42 * width
        opacity: Theme.material?.headerGlow ?? 0
    }

    RowLayout {
        id: rangee
        x: Theme.space?.scale[3] ?? 0
        y: Theme.space?.scale[2] ?? 0
        width: parent.width - 2 * x
        spacing: Theme.space?.scale[3] ?? 0

        Vignette {
            id: vignette
            glyphe: enTete.glyphe
            teinte: enTete.teinte
            taille: 2 * (Theme.reglages?.thumb ?? 0)
            tailleGlyphe: Theme.icons?.sizes.comfortable ?? 0
            rayon: Theme.radius?.panel ?? 0
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            Texte { Layout.fillWidth: true; text: enTete.titre; echelon: 4; moyen: true; elide: Text.ElideRight; color: Theme.color?.textEmphasis ?? "transparent" }
            Texte {
                Layout.fillWidth: true
                visible: text !== ""
                text: enTete.etat
                echelon: 1
                elide: Text.ElideRight
                color: Theme.color?.textSecondary ?? "transparent"
            }
        }
        Item { id: emplacement; implicitWidth: childrenRect.width; implicitHeight: childrenRect.height }
    }
}
