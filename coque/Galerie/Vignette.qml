import QtQuick
import Quickshell
import Quickshell.Widgets
import "../Theme"
import "../Theme/fichiers.js" as Fichiers

// Vignette — une image du dossier des fonds, réduite et recadrée au centre, dans la bande de la galerie (L2-60).
// Rôle : affiche l'image en 16:9 aux dimensions des jetons (galerie.largeur × galerie.hauteur), recadrée comme le
// calque Fond (PreserveAspectCrop, rotation EXIF), décodée directement à la taille affichée multipliée par le rapport
// de pixels de la fenêtre, de façon asynchrone et sans cache ; angles radius.control, liseré d'un pixel physique en
// border-subtle. Le relief « mélange » (décision 6 de la fiche) porte sur deux grandeurs : la vignette sélectionnée
// grandit à l'échelle galerie.echelle, les autres sont couvertes d'un voile surface-base d'opacité galerie.voile ;
// aucune couleur n'est recalculée. L'échelle suit un Ressort « state » de nature « deplacement » (posé aussitôt en
// mouvement réduit), le voile un Ressort « state » de nature « fondu ». Pendant le décodage, ou si l'image est
// illisible, la vignette reste transparente : on y voit l'échelon de la presqu'île, sans indicateur.
// Entrées : chemin, chemin absolu de l'image ; selectionnee, vrai pour la vignette sélectionnée.
// Sorties : implicitWidth et implicitHeight, dimensions des jetons ; echelle et voile, valeurs courantes des deux
//           ressorts ; statut, « attente », « pret » ou « erreur », état du décodage (lus par les essais).
// Erreurs : aucune ; une image illisible donne le statut « erreur » et une vignette vide, la navigation continue.
//           Avant le chargement des jetons, la vignette est de taille nulle.
// Dépendances : Quickshell (QsWindow), Quickshell.Widgets (ClippingRectangle), Theme (galerie, radius, color,
//               hairline), Ressort, fichiers.js.
Item {
    id: vignette

    property string chemin: ""
    property bool selectionnee: false
    readonly property real echelle: grandeur.value
    readonly property real voile: attenuation.value
    readonly property string statut: image.status === Image.Ready ? "pret" : image.status === Image.Error ? "erreur" : "attente"
    readonly property real dpr: QsWindow.window?.devicePixelRatio ?? 1

    implicitWidth: Theme.galerie?.largeur ?? 0
    implicitHeight: Theme.galerie?.hauteur ?? 0
    scale: grandeur.value

    Ressort { id: grandeur; transition: "state"; nature: "deplacement"; cible: vignette.selectionnee ? Theme.galerie?.echelle ?? 1 : 1 }
    Ressort { id: attenuation; transition: "state"; nature: "fondu"; cible: vignette.selectionnee ? 0 : Theme.galerie?.voile ?? 0 }

    // L'image, découpée aux angles arrondis ; le fond du rectangle de découpe est transparent (blanc par défaut).
    ClippingRectangle {
        anchors.fill: parent
        radius: Theme.radius?.control ?? 0
        color: "transparent"

        Image {
            id: image
            anchors.fill: parent
            source: vignette.chemin === "" ? "" : Fichiers.url(vignette.chemin)
            fillMode: Image.PreserveAspectCrop
            autoTransform: true
            asynchronous: true
            cache: false
            sourceSize: Qt.size(vignette.width * vignette.dpr, vignette.height * vignette.dpr)
        }
    }

    // Voile d'atténuation des vignettes non sélectionnées : la surface de base du thème, en transparence.
    Rectangle {
        anchors.fill: parent
        radius: Theme.radius?.control ?? 0
        color: Theme.color?.surfaceBase ?? "transparent"
        opacity: attenuation.value
    }

    // Liseré, tracé à part : la bordure du rectangle de découpe n'accepte que des pixels logiques entiers.
    Rectangle {
        anchors.fill: parent
        radius: Theme.radius?.control ?? 0
        color: "transparent"
        border.color: Theme.color?.borderSubtle ?? "transparent"
        border.width: Theme.hairline(vignette.dpr) ?? 0
    }
}
