import QtQuick
import QtQuick.Layouts
import "../Theme"
import "../Composants"

// EnTetePage — carte d'en-tête d'une page de réglages : grande vignette, titre, phrase d'état, contrôle à droite.
// Rôle : ouvre chaque page de l'application Paramètres. La carte est une Carte (relief « Doux » hérité du conteneur
// de page), sur laquelle une lueur discrète de la teinte de la page part du coin de la vignette, à l'intensité
// material.headerGlow et jusqu'à la part material.headerGlowReach de sa largeur. L'état de la page, que la barre latérale ne montre plus, se lit
// ici.
// Entrées : glyphe et teinte, transmis à la VignetteVerre ; titre ; etat, phrase d'état, vide par défaut (la ligne
// disparaît), qui passe d'une phrase à l'autre en fondu croisé au ressort « state » (D184) ; le contrôle (un
// Interrupteur, par exemple), déclaré comme enfant, se pose à droite.
// Sorties : dnRole (« surfaceRaised »), que lisent les contrôles posés dans la carte ; vignette, la VignetteVerre ;
// sortante, la phrase sortante d'un fondu, et ancienne, le texte qu'elle peint, lues par les essais.
// Erreurs : aucune ; avant le chargement des tokens, les cotes sont nulles et le fond transparent.
// Dépendances : VignetteVerre, Lueur, Carte, Texte, Theme (color, radius, space, reglages, icons, material.headerGlow,
// material.headerGlowReach), QtQuick.Layouts.
// Cotes : vignette de reglages.thumbLarge, au rayon radius.panel, glyphe de icons.sizes.comfortable ; retraits
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
    readonly property alias sortante: sortante
    // Phrase montrée avant le dernier changement, peinte par la phrase sortante pendant le fondu croisé.
    property string ancienne: ""
    // Phrase montrée, tenue à la main et non par liaison : une liaison pourrait se mettre à jour avant
    // onEtatChanged, qui verrait alors la nouvelle phrase pour l'ancienne.
    property string _montree: ""

    Component.onCompleted: _montree = etat
    onEtatChanged: {
        if (_montree !== "" && etat !== "" && etat !== _montree) { ancienne = _montree; croise.reprendre(0, 0) }
        _montree = etat
    }

    implicitHeight: rangee.implicitHeight + 2 * (Theme.space?.scale[2] ?? 0)

    Carte { anchors.fill: parent }
    Lueur {
        anchors.fill: parent
        rayon: Theme.radius?.panel ?? 0
        teinte: vignette.couleur
        portee: (Theme.material?.headerGlowReach ?? 0) * width
        opacity: Theme.material?.headerGlow ?? 0
    }

    RowLayout {
        id: rangee
        x: Theme.space?.scale[3] ?? 0
        y: Theme.space?.scale[2] ?? 0
        width: parent.width - 2 * x
        spacing: Theme.space?.scale[3] ?? 0

        VignetteVerre {
            id: vignette
            glyphe: enTete.glyphe
            teinte: enTete.teinte
            taille: Theme.reglages?.thumbLarge ?? 0
            tailleGlyphe: Theme.icons?.sizes.comfortable ?? 0
            rayon: Theme.radius?.panel ?? 0
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            Texte { Layout.fillWidth: true; text: enTete.titre; echelon: 4; moyen: true; elide: Text.ElideRight; color: Theme.color?.textEmphasis ?? "transparent" }
            // La phrase d'état et la phrase sortante, superposées : le ressort croise va de 0 à 1 à chaque
            // changement de phrase, la nouvelle paraît pendant que l'ancienne s'efface.
            Item {
                Layout.fillWidth: true
                visible: enTete.etat !== ""
                implicitHeight: phrase.implicitHeight
                Ressort { id: croise; transition: "state"; nature: "fondu"; cible: 1 }
                Texte {
                    id: phrase
                    width: parent.width
                    opacity: croise.value
                    text: enTete.etat
                    echelon: 1
                    elide: Text.ElideRight
                    color: Theme.color?.textSecondary ?? "transparent"
                }
                Texte {
                    id: sortante
                    width: parent.width
                    visible: opacity > 0
                    opacity: 1 - croise.value
                    text: enTete.ancienne
                    echelon: 1
                    elide: Text.ElideRight
                    color: Theme.color?.textSecondary ?? "transparent"
                }
            }
        }
        Item { id: emplacement; implicitWidth: childrenRect.width; implicitHeight: childrenRect.height }
    }
}
