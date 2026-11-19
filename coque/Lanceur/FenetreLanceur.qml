import QtQuick
import Quickshell
import Quickshell.Wayland
import "../Theme"

// FenetreLanceur — fenêtre d'attention du lanceur (L2-16) : voile plein écran et cadre animé.
// Rôle : PanelWindow plein écran sur l'écran figé à l'ouverture (Lanceur.ecran), couche overlay, namespace
// « dunei-attention » (flouté par le compositeur, le voile restant net sous ignore_alpha), clavier exclusif si
// clavierExclusif, aucun espace réservé. Le calque ne change jamais de taille : seul le cadre intérieur
// (CadreLanceur) s'anime. C'est un cadre propre au lanceur plutôt que celui de FenetreAttention, qui centre un contenu
// à sa taille : il se tient au tiers haut (le centre de la scission sur le tiers de l'écran, bord haut fixe). À
// l'ouverture, voile et cadre entrent au ressort overlay ; un clic sur le voile ferme.
// Entrées : clavierExclusif (Lanceur.clavierExclusif). Sorties : cadre, le CadreLanceur (taille relevée par les
// essais) ; vignettes, le nombre de vignettes de l'aperçu.
// Erreurs : aucune ; avant le chargement des tokens, le voile reste transparent.
// Dépendances : Quickshell (PanelWindow, ExclusionMode), Quickshell.Wayland (WlrLayershell), Lanceur, CadreLanceur,
// Ressort, Theme (material).
PanelWindow {
    id: fenetre

    property bool clavierExclusif: Lanceur.clavierExclusif
    readonly property alias cadre: cadre
    readonly property int vignettes: cadre.vignettes

    screen: Lanceur.ecran
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "dunei-attention"
    WlrLayershell.keyboardFocus: clavierExclusif ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // Entrée de la fenêtre : la cible initiale 0 est posée à la création, puis la cible 1 part au ressort.
    Ressort { id: entree; transition: "overlay"; nature: "fondu"; cible: 0 }
    Component.onCompleted: entree.cible = 1

    // Voile : un clic hors du cadre ferme le lanceur.
    Rectangle {
        id: voile
        anchors.fill: parent
        color: Theme.material?.shade ?? "transparent"
        opacity: entree.value

        MouseArea {
            anchors.fill: parent
            onClicked: m => { if (!cadre.contains(cadre.mapFromItem(voile, m.x, m.y))) Lanceur.fermer() }
        }
    }

    CadreLanceur {
        id: cadre
        x: Math.round((fenetre.width - width) / 2)
        y: Math.max(Lanceur.cotes.retrait, Math.round(fenetre.height / 3 - Lanceur.cotes.scission.height / 2))
        apparition: entree.value
    }
}
