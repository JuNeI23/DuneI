import QtQuick
import "../Theme"
import "../Composants"

// Alerte — module « alerte » de la presqu'île : l'avertissement de batterie (L2-13, décision 10).
// Rôle : montre, centrés, le symbole d'attention (Phosphor warning en bold, D101, sous le nom freedesktop
// battery-caution) puis le message du palier : « Batterie faible », le tout en warning, au palier 1 ; « Branchez le
// chargeur », le tout en error, au palier 2. Le texte suit le style des libellés du module Volume (échelon de base,
// graisse moyenne) ; l'écart de 6 px est celui des maquettes validées. La hauteur est celle de la presqu'île, comme
// Volume : la surface ne change jamais de taille (D132), seule la largeur de l'encoche s'étire, par le ressort de la
// scène, quand le message change.
// Entrées : ecran, écran de la presqu'île (obligatoire, contrat de tout module de contenu, inutilisé ici) ; palier,
//           1 (faible) ou 2 (critique), que lie l'AnnonceurAlerte.
// Sorties : implicitWidth, le symbole, l'écart et le texte, plus une marge du gabarit de chaque côté ; implicitHeight,
//           hauteur de la presqu'île ; symbole et message, l'icône et le texte, lus par les essais.
// Erreurs : aucune ; un palier autre que 2 montre le message faible ; avant le chargement des jetons, les cotes sont
//           nulles et les couleurs transparentes.
// Dépendances : Theme (tokens.presquile, color, icons), Icone, Texte.
Item {
    id: alerte

    required property var ecran
    property int palier: 1
    readonly property var gabarit: Theme.tokens?.presquile
    readonly property color encre: palier === 2 ? Theme.color?.error ?? "transparent"
        : Theme.color?.warning ?? "transparent"
    readonly property alias symbole: symbole
    readonly property alias message: message

    implicitWidth: rangee.implicitWidth + 2 * (gabarit?.marge ?? 0)
    implicitHeight: gabarit?.hauteur ?? 0

    Row {
        id: rangee
        anchors.centerIn: parent
        spacing: 6

        Icone {
            id: symbole
            anchors.verticalCenter: parent.verticalCenter
            nom: "battery-caution"
            taille: Theme.icons?.sizes?.dense ?? 0
            couleur: alerte.encre
        }
        Texte {
            id: message
            anchors.verticalCenter: parent.verticalCenter
            moyen: true
            text: alerte.palier === 2 ? "Branchez le chargeur" : "Batterie faible"
            color: alerte.encre
        }
    }
}
