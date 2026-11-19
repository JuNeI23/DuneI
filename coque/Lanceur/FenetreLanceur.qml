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
// l'ouverture, le voile entre en fondu et le cadre monte du bas de reglages.pageRise en s'éclairant, comme une page de
// Paramètres, au ressort overlay (un ressort de fondu pour l'opacité, un ressort de déplacement pour la montée). À la
// fermeture, le clavier exclusif est rendu et la fenêtre devient transparente au pointeur aussitôt ; le cadre
// redescend et s'efface, le voile s'efface, au même ressort en phase de sortie, puis la fenêtre signale
// Lanceur.sortieFinie, qui la décharge. Une réouverture pendant la sortie reprend l'entrée sur la même fenêtre. Un clic
// sur le voile ferme. Le flou du compositeur derrière le voile suit la règle de calque « fade » de dunei-attention.
// Entrées : clavierExclusif (Lanceur.clavierExclusif) ; Lanceur.ouvert. Sorties : cadre, le CadreLanceur (taille
// relevée par les essais) ; vignettes, le nombre de vignettes de l'aperçu.
// Erreurs : aucune ; avant le chargement des tokens, le voile reste transparent.
// Dépendances : Quickshell (PanelWindow, ExclusionMode, Region), Quickshell.Wayland (WlrLayershell), Lanceur, CadreLanceur,
// Ressort, Theme (material, reglages, mouvementReduit).
PanelWindow {
    id: fenetre

    property bool clavierExclusif: Lanceur.clavierExclusif && Lanceur.ouvert
    readonly property alias cadre: cadre
    readonly property int vignettes: cadre.vignettes

    screen: Lanceur.ecran
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "dunei-attention"
    WlrLayershell.keyboardFocus: clavierExclusif ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // Fermée, la fenêtre ne prend plus le pointeur : la sortie ne bloque aucun clic.
    mask: Region { width: Lanceur.ouvert ? fenetre.width : 0; height: Lanceur.ouvert ? fenetre.height : 0 }

    // Entrée et sortie : la cible initiale 0 est posée à la création, puis la cible suit l'ouverture au ressort overlay
    // (in à l'entrée, out à la sortie). Le fondu porte l'opacité ; la montée, ressort de déplacement séparé, la
    // translation, posée d'un coup sous le mouvement réduit.
    Ressort { id: entree; transition: "overlay"; nature: "fondu"; cible: 0 }
    Ressort { id: montee; transition: "overlay"; cible: 0 }
    Component.onCompleted: { entree.cible = Qt.binding(() => Lanceur.ouvert ? 1 : 0); montee.cible = Qt.binding(() => entree.cible) }

    // eteinte — vraie quand la sortie est posée (lanceur fermé, fondu à zéro et montée au repos) : le lanceur décharge
    // alors la fenêtre. Entrées : aucune. Sortie : Lanceur.sortieFinie(). Erreurs : aucune. Dépendances : entree, montee.
    readonly property bool eteinte: !Lanceur.ouvert && entree.value === 0 && !entree.moving && !montee.moving
    onEteinteChanged: if (eteinte) Lanceur.sortieFinie()

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
        montee: montee.value
    }
}
