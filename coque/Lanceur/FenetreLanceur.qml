import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../Theme"

// FenetreLanceur — fenêtre d'attention du lanceur (L2-16) : voile plein écran et cadre qui monte du bas.
// Rôle : PanelWindow plein écran sur l'écran figé à l'ouverture (Lanceur.ecran), couche overlay, namespace
// « dunei-attention » (flouté par le compositeur, le voile restant net sous ignore_alpha), clavier exclusif si
// clavierExclusif, aucun espace réservé. Le calque ne change jamais de taille : seul le cadre intérieur
// (CadreLanceur) s'anime. C'est un cadre propre au lanceur plutôt que celui de FenetreAttention, qui centre un contenu
// à sa taille : il se tient au tiers haut (le centre de la scission sur le tiers de l'écran, bord haut fixe).
// Apparition : le compositeur la porte, par la règle de calque « fade » de dunei-attention (glass.fondu) au ressort
// overlay de fadeLayersIn. Son fondu multiplie le calque entier, flou compris, qui apparaît donc progressivement ; un
// fondu par l'opacité QML faisait au contraire franchir d'un coup aux pixels du verre le seuil glass.ignore_alpha, et
// le flou s'allumait d'un bloc (recette 2). Le voile et le cadre restent donc à l'opacité QML 1. Le cadre part sous le
// bord bas de l'écran, hors champ, et monte jusqu'à sa place au ressort window, translation pure, comme la fenêtre
// Paramètres qui entre par « slide bottom » (D172) ; sous le mouvement réduit, le ressort se pose aussitôt et seul le
// fondu reste. Disparition : sur place, en fondu court (comme Paramètres, D173), par l'opacité que Hyprland applique
// à la surface (HyprlandWindow.opacity, protocole hyprland-surface-v1), qui multiplie elle aussi le flou ; le
// compositeur n'efface pas un calque détruit, qui disparaîtrait d'un coup. À la fermeture, le clavier exclusif est rendu
// et la fenêtre devient transparente au pointeur aussitôt ; le fondu court au ressort overlay en phase de sortie, puis
// la fenêtre signale Lanceur.sortieFinie, qui la décharge. Une réouverture pendant la sortie reprend la même fenêtre.
// Un clic sur le voile ferme.
// Entrées : clavierExclusif (Lanceur.clavierExclusif) ; Lanceur.ouvert. Sorties : cadre, le CadreLanceur (taille relevée par les
// essais) ; vignettes, le nombre de vignettes de l'aperçu.
// Erreurs : aucune ; avant le chargement des tokens, le voile reste transparent.
// Dépendances : Quickshell (PanelWindow, ExclusionMode, Region), Quickshell.Wayland (WlrLayershell),
// Quickshell.Hyprland (HyprlandWindow), Lanceur, CadreLanceur, Ressort, Theme (material).
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

    // Fondu de sortie, appliqué par Hyprland à la surface entière, flou compris ; 1 tant que le lanceur est ouvert.
    Ressort { id: effacement; transition: "overlay"; nature: "fondu"; cible: Lanceur.ouvert ? 1 : 0 }
    HyprlandWindow.opacity: effacement.value

    // eteinte — vraie quand la sortie est posée (lanceur fermé, fondu à zéro et au repos) : le lanceur décharge alors la
    // fenêtre. Entrées : aucune. Sortie : Lanceur.sortieFinie(). Erreurs : aucune. Dépendances : effacement.
    readonly property bool eteinte: !Lanceur.ouvert && effacement.value === 0 && !effacement.moving
    onEteinteChanged: if (eteinte) Lanceur.sortieFinie()

    // Montée du cadre : la cible initiale 0 est posée à la création, puis la cible 1 part au ressort window au tour de
    // boucle suivant. Posée dans onCompleted même, elle arrivait avant que le Ressort, enfant achevé après la fenêtre,
    // soit prêt : il se posait d'un coup sur 1 et le cadre apparaissait à sa place sans monter (recette 2).
    Ressort { id: montee; transition: "window"; cible: 0 }
    Component.onCompleted: Qt.callLater(() => montee.cible = 1)

    // Voile : un clic hors du cadre ferme le lanceur.
    Rectangle {
        id: voile
        anchors.fill: parent
        color: Theme.material?.shade ?? "transparent"

        MouseArea {
            anchors.fill: parent
            onClicked: m => { if (!cadre.contains(cadre.mapFromItem(voile, m.x, m.y))) Lanceur.fermer() }
        }
    }

    CadreLanceur {
        id: cadre
        x: Math.round((fenetre.width - width) / 2)
        y: Math.max(Lanceur.cotes.retrait, Math.round(fenetre.height / 3 - Lanceur.cotes.scission.height / 2))
        // Départ sous le bord bas de l'écran : le haut du cadre y est posé, hors champ.
        depart: fenetre.height - y
        montee: montee.value
    }
}
