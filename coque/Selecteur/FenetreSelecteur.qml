import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../Theme"

// FenetreSelecteur — fenêtre d'attention du sélecteur de fenêtres (L2-17) : voile plein écran et cadre centré.
// Rôle : PanelWindow plein écran sur l'écran figé à l'ouverture (Selecteur.ecran), couche overlay, namespace
// « dunei-attention » (flouté par le compositeur, comme le lanceur), clavier exclusif si clavierExclusif, aucun
// espace réservé. Le calque est posé dès l'ouverture, car c'est son clavier qui reçoit le relâchement de SUPER, mais
// il reste invisible jusqu'au délai (Selecteur.montre) : l'opacité que Hyprland applique à la surface
// (HyprlandWindow.opacity, protocole hyprland-surface-v1), qui multiplie aussi le flou, vaut 0, et le masque d'entrée
// est vide, pour qu'aucun clic ne soit pris. Le fondu d'entrée du compositeur (règle « fade » de dunei-attention)
// joue donc sur une surface d'opacité nulle et ne montre rien. Au délai, un ressort overlay de nature fondu porte
// cette opacité à 1 : le calque entier, flou compris, apparaît progressivement, sans franchir d'un bloc le seuil
// glass.ignore_alpha (D192). Le cadre monte alors du bas de l'écran jusqu'au centre au ressort window, translation
// pure (D193) ; sous le mouvement réduit, il se pose aussitôt et seul le fondu reste. Disparition : sur place, en
// fondu au même ressort overlay, comme le lanceur ; à la fermeture, le clavier exclusif est rendu et la fenêtre devient
// transparente au pointeur aussitôt, puis, le fondu posé, elle signale Selecteur.sortieFinie, qui la décharge. Fermée
// avant le délai (tap bref), son opacité est déjà nulle : elle est déchargée sans fondu. Un clic sur le voile annule.
// Entrées : clavierExclusif (Selecteur.clavierExclusif) ; Selecteur.ouvert, Selecteur.montre.
// Sorties : cadre, le CadreSelecteur (lu par les essais) ; affiche, vrai quand le sélecteur est ouvert et montré.
// Erreurs : aucune ; avant le chargement des tokens, le voile reste transparent.
// Dépendances : Quickshell (PanelWindow, ExclusionMode, Region), Quickshell.Wayland (WlrLayershell),
// Quickshell.Hyprland (HyprlandWindow), Selecteur, CadreSelecteur, Ressort, Theme (material).
PanelWindow {
    id: fenetre

    property bool clavierExclusif: Selecteur.clavierExclusif && Selecteur.ouvert
    readonly property bool affiche: Selecteur.ouvert && Selecteur.montre
    readonly property alias cadre: cadre

    screen: Selecteur.ecran
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "dunei-attention"
    WlrLayershell.keyboardFocus: clavierExclusif ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // Avant le délai comme après la fermeture, la fenêtre ne prend pas le pointeur.
    mask: Region { width: fenetre.affiche ? fenetre.width : 0; height: fenetre.affiche ? fenetre.height : 0 }

    // Opacité de la surface entière, flou compris : 0 avant le délai, 1 une fois montrée, 0 à la sortie.
    Ressort { id: effacement; transition: "overlay"; nature: "fondu"; cible: fenetre.affiche ? 1 : 0 }
    HyprlandWindow.opacity: effacement.value

    // eteinte — vraie quand la sortie est posée (sélecteur fermé, opacité nulle et au repos) : le sélecteur décharge
    // alors la fenêtre. Entrées : aucune. Sortie : Selecteur.sortieFinie(). Erreurs : aucune. Dépendances : effacement.
    readonly property bool eteinte: !Selecteur.ouvert && effacement.value === 0 && !effacement.moving
    onEteinteChanged: if (eteinte) Selecteur.sortieFinie()

    // Montée du cadre, lancée à l'apparition : le ressort, créé sur la cible 0, est prêt bien avant le délai.
    Ressort { id: montee; transition: "window"; cible: 0 }
    // onAfficheChanged — à l'apparition, lance la montée du cadre. Entrées : aucune (affiche, devenu vrai). Sortie :
    // montee.cible posé à 1. Erreurs : aucune ; à la disparition, rien : le cadre reste posé pendant le fondu.
    // Dépendances : affiche, montee.
    onAfficheChanged: if (affiche) montee.cible = 1

    // Voile : un clic hors du cadre annule.
    Rectangle {
        id: voile
        anchors.fill: parent
        color: Theme.material?.shade ?? "transparent"

        MouseArea {
            anchors.fill: parent
            // onClicked — un clic hors du cadre annule le sélecteur. Entrée : m, l'événement de souris (position dans le
            // voile). Sortie : Selecteur.annuler() appelé ; un clic sur le cadre ne fait rien ici. Erreurs : aucune.
            // Dépendances : cadre (contains, mapFromItem), Selecteur.annuler.
            onClicked: m => { if (!cadre.contains(cadre.mapFromItem(voile, m.x, m.y))) Selecteur.annuler() }
        }
    }

    CadreSelecteur {
        id: cadre
        largeurDispo: fenetre.width - 2 * (Theme.space?.scale[6] ?? 0)
        x: Math.round((fenetre.width - width) / 2)
        y: Math.round((fenetre.height - height) / 2)
        // Départ sous le bord bas de l'écran : le haut du cadre y est posé, hors champ.
        depart: fenetre.height - y
        montee: montee.value
    }
}
