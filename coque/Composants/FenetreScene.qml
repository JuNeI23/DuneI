import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../Theme"

// FenetreScene — fenêtre d'une Scene (L2-23) : voile plein écran et cadre centré qui monte du bas.
// Rôle : PanelWindow plein écran sur l'écran figé à l'ouverture (scene.ecran), couche overlay, namespace
// « dunei-attention » (flouté par le compositeur, le voile restant net sous ignore_alpha), clavier exclusif si
// scene.clavierExclusif, aucun espace réservé ; le composant scene.cadre y est instancié au centre de l'écran et
// reçoit le focus. Le calque ne change jamais de taille : seul le cadre s'anime. Reprise de FenetreLanceur.
// Apparition : le compositeur la porte, par la règle de calque « fade » de dunei-attention (glass.fondu) au ressort
// overlay de fadeLayersIn ; son fondu multiplie le calque entier, flou compris, qui apparaît donc progressivement sans
// franchir d'un bloc le seuil glass.ignore_alpha (D192). Le voile et le cadre restent à l'opacité QML 1. Si
// scene.montee, le cadre part sous le bord bas de l'écran, hors champ, et monte jusqu'à sa place au ressort window,
// translation pure (D193) ; sinon, il se pose à sa place. Sous le mouvement réduit, le ressort se pose aussitôt et
// seul le fondu reste. Disparition : sur place, en fondu au ressort overlay, par l'opacité que Hyprland applique à la
// surface (HyprlandWindow.opacity, protocole hyprland-surface-v1), qui multiplie elle aussi le flou ; le compositeur
// n'efface pas un calque détruit, qui disparaîtrait d'un coup. À la fermeture, le clavier exclusif est rendu et la
// fenêtre devient transparente au pointeur aussitôt ; le fondu posé, elle signale scene.sortieFinie, qui la
// décharge. Une réouverture pendant la sortie reprend la même fenêtre. Un clic sur le voile, hors du cadre, ferme la
// scène.
// Entrées : scene, la Scene qui la porte (ecran, cadre, ouvert, clavierExclusif, montee), requise.
// Sorties : cadre, l'élément instancié depuis scene.cadre, ou null (lu par les essais) ; eteinte.
// Erreurs : aucune ; avant le chargement des tokens, le voile reste transparent.
// Dépendances : Quickshell (PanelWindow, ExclusionMode, Region), Quickshell.Wayland (WlrLayershell),
// Quickshell.Hyprland (HyprlandWindow), Scene, Ressort, Theme (material).
PanelWindow {
    id: fenetre

    required property QtObject scene
    readonly property bool clavierExclusif: scene.clavierExclusif && scene.ouvert
    readonly property var cadre: charge.item

    screen: scene.ecran
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "dunei-attention"
    WlrLayershell.keyboardFocus: clavierExclusif ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // Fermée, la fenêtre ne prend plus le pointeur : la sortie ne bloque aucun clic.
    mask: Region { width: fenetre.scene.ouvert ? fenetre.width : 0; height: fenetre.scene.ouvert ? fenetre.height : 0 }

    // Fondu de sortie, appliqué par Hyprland à la surface entière, flou compris ; 1 tant que la scène est ouverte.
    Ressort { id: effacement; transition: "overlay"; nature: "fondu"; cible: fenetre.scene.ouvert ? 1 : 0 }
    HyprlandWindow.opacity: effacement.value

    // eteinte — vraie quand la sortie est posée (scène fermée, fondu à zéro et au repos) : la scène décharge alors la
    // fenêtre. Entrées : aucune. Sortie : scene.sortieFinie(). Erreurs : aucune. Dépendances : effacement, scene.
    readonly property bool eteinte: !scene.ouvert && effacement.value === 0 && !effacement.moving
    onEteinteChanged: if (eteinte) scene.sortieFinie()

    // Montée du cadre : la cible initiale 0 est posée à la création, puis la cible 1 part au ressort window au tour de
    // boucle suivant ; posée dans onCompleted même, elle arriverait avant que le Ressort, enfant achevé après la
    // fenêtre, soit prêt, et le cadre se poserait sans monter (recette 2 du lanceur).
    Ressort { id: montee; transition: "window"; cible: 0 }

    // Component.onCompleted — lance la montée du cadre au tour de boucle suivant. Entrées : aucune. Sortie :
    // montee.cible posé à 1. Erreurs : aucune. Dépendances : montee, Qt.callLater.
    Component.onCompleted: Qt.callLater(() => montee.cible = 1)

    // Voile : un clic hors du cadre ferme la scène.
    Rectangle {
        id: voile
        anchors.fill: parent
        color: Theme.material?.shade ?? "transparent"

        MouseArea {
            anchors.fill: parent
            // onClicked — un clic hors du cadre ferme la scène. Entrée : m, l'événement de souris (position dans le
            // voile). Sortie : scene.ouvert passé à faux ; un clic sur le cadre ne fait rien ici. Erreurs : aucune.
            // Dépendances : charge (contains, mapFromItem), scene.ouvert.
            onClicked: m => { if (!charge.contains(charge.mapFromItem(voile, m.x, m.y))) fenetre.scene.ouvert = false }
        }
    }

    // Cadre : le contenu du client, centré, qui reçoit le focus. Sans montée, il est posé à sa place.
    Loader {
        id: charge
        x: Math.round((fenetre.width - width) / 2)
        y: Math.round((fenetre.height - height) / 2)
        focus: true
        sourceComponent: fenetre.scene.cadre
        // Départ sous le bord bas de l'écran : le haut du cadre y est posé, hors champ.
        transform: Translate { y: fenetre.scene.montee ? (1 - montee.value) * (fenetre.height - charge.y) : 0 }
    }
}
