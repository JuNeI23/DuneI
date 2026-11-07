import QtQuick
import Quickshell
import Quickshell.Wayland
import "../Theme"

// Presquile — surface de la presqu'île, posée au centre du bord haut de chaque écran (L2-46).
// Rôle : fenêtre de calque transparente, ancrée en haut seulement (donc centrée), qui porte l'encoche continue et,
// dedans, la Scene qui monte le module de contenu. La taille de l'encoche suit celle du module par les deux Ressorts
// « window » de la scène : immobile tant que le module garde sa taille, elle s'étire sans saut quand il en change.
// Changer de module déroule la séquence de la scène (L2-48) : fondu de sortie, étirement, fondu d'entrée ; en
// mouvement réduit, la taille se pose aussitôt et seuls les fondus restent. La fenêtre réserve en plus
// de l'encoche la marge de son ombre, pour qu'elle ne soit pas coupée. Le masque de saisie ne couvre que le corps de
// l'encoche : partout ailleurs, les clics traversent. Elle ne réserve aucune place et ne prend jamais le focus clavier.
// Entrées : modelData, l'écran que lui donne le Variants de la coque (obligatoire) ; module, le composant de contenu,
//           Bureaux par défaut ; il doit être un Item déclarant implicitWidth et implicitHeight, et recevoir ecran.
//           Le changer est l'unique manière de changer de contenu.
// Sorties : une fenêtre de calque au namespace « dunei-presquile » (floutée par les règles de calque générées) ;
//           contenu, le module monté ; phase, celle de la séquence de changement (« repos », « sortie », « forme »
//           ou « entree »), lue par les essais et l'ouvreuse de la galerie ; fenetre, la surface elle-même, que
//           l'ouvreuse de la galerie passe à sa prise du clavier (HyprlandFocusGrab).
// Erreurs : sans jeton de thème, l'encoche est vide et la fenêtre reste posée ; un module sans taille laisse l'encoche
//           à la hauteur des jetons.
// Dépendances : quickshell ≥ 0.3 (PanelWindow, Region, WlrLayershell), Encoche, Scene, Bureaux, Ressort, Theme.
PanelWindow {
    id: surface

    required property var modelData
    property Component module: Component { Bureaux {} }

    // Module instancié pour l'écran de la surface (null tant que le composant n'est pas monté).
    readonly property alias contenu: scene.contenu
    readonly property alias phase: scene.phase
    // Fenêtre à prendre dans le HyprlandFocusGrab de l'ouvreuse (contrat partagé avec les presqu'îles d'essai).
    readonly property var fenetre: surface
    // Ressorts de taille de la scène, lus pour dimensionner la fenêtre et le corps de l'encoche.
    readonly property Ressort largeur: scene.ressortLargeur
    readonly property Ressort hauteur: scene.ressortHauteur

    screen: modelData
    anchors { top: true }
    // La fenêtre se dimensionne sur la cible (ou sur la valeur courante si elle est plus grande, pour ne rien couper
    // pendant un rétrécissement) : elle n'est donc pas reconfigurée à chaque image, seule la forme s'anime.
    implicitWidth: Math.max(largeur.value, largeur.cible) + 2 * (encoche.evasement + encoche.marge)
    implicitHeight: Math.max(hauteur.value, hauteur.cible) + encoche.marge
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    mask: Region { item: encoche.corps }
    WlrLayershell.namespace: "dunei-presquile"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    Encoche {
        id: encoche
        x: (surface.implicitWidth - implicitWidth) / 2
        // Noms qualifiés : dans ce bloc, « hauteur » désignerait la propriété de l'Encoche elle-même.
        largeurCorps: surface.largeur.value
        hauteur: surface.hauteur.value

        // Le module, monté et changé par la scène, posée sur le corps de l'encoche.
        Scene {
            id: scene
            x: encoche.evasement
            ecran: surface.modelData
            module: surface.module
        }
    }
}
