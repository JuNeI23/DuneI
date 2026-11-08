import QtQuick
import Quickshell
import Quickshell.Wayland
import "../Theme"

// Presquile — surface de la presqu'île, posée au centre du bord haut de chaque écran (L2-46).
// Rôle : fenêtre de calque transparente, ancrée en haut, à gauche et à droite (toute la largeur de l'écran), qui porte
// l'encoche continue, centrée, et, dedans, la Scene qui monte le module de contenu. La largeur de la fenêtre ne change
// donc jamais, et sa hauteur suit la hauteurSurface de la scène, stable pendant tout mouvement : la surface n'est
// jamais reconfigurée image par image, ce qui ferait attendre chaque image l'aller-retour avec le compositeur
// (saccades de la rétractation, décalage d'une image à l'ouverture, constatés à la recette de L2-60). La taille de
// l'encoche suit celle du module par les deux Ressorts « window » de la scène : immobile tant que le module garde sa
// taille, elle s'étire sans saut quand il en change.
// Changer de module déroule la séquence de la scène (L2-48) : fondu de sortie, étirement, fondu d'entrée ; en
// mouvement réduit, la taille se pose aussitôt et seuls les fondus restent. La fenêtre réserve en plus
// de l'encoche la marge de son ombre, pour qu'elle ne soit pas coupée. Le masque de saisie ne couvre que le corps de
// l'encoche : partout ailleurs, les clics traversent. Elle ne réserve aucune place et ne prend jamais le focus clavier.
// Entrées : modelData, l'écran que lui donne le Variants de la coque (obligatoire) ; demander(cle, composant,
//           priorite) et liberer(cle), par lesquels les modules (galerie 2, volume 1) réclament la presqu'île, que
//           tranche un Arbitre : le composant de contenu est un Item déclarant implicitWidth et implicitHeight, et
//           recevant ecran. C'est l'unique manière de changer de contenu. reserve, hauteur minimale réservée à l'encoche
//           (0 par défaut) : la coque y passe celle du plus grand module connu, pour que la surface garde toujours la
//           même taille (voir Scene.hauteurSurface).
// Sorties : une fenêtre de calque au namespace « dunei-presquile » (floutée par les règles de calque générées) ;
//           module, le composant arbitré (lecture seule, Bureaux sans demande) ; contenu, le module monté ; phase,
//           celle de la séquence de changement (« repos », « sortie », « forme » ou « entree »), lue par les essais et l'ouvreuse de la galerie ; fenetre, la surface elle-même, que
//           l'ouvreuse de la galerie passe à sa prise du clavier (HyprlandFocusGrab).
// Erreurs : sans jeton de thème, l'encoche est vide et la fenêtre reste posée ; un module sans taille laisse l'encoche
//           à la hauteur des jetons.
// Dépendances : quickshell ≥ 0.3 (PanelWindow, Region, WlrLayershell), Arbitre, Encoche, Scene, Bureaux, Ressort, Theme.
PanelWindow {
    id: surface

    required property var modelData
    // Module arbitré : la demande de plus haute priorité, les bureaux sans demande.
    readonly property Component module: arbitre.module
    property real reserve: 0

    // demander — voir Arbitre.demander. Entrées : cle, composant, priorite. Sortie : aucune. Erreurs : aucune.
    // Dépendances : Arbitre.
    function demander(cle: string, composant: Component, priorite: int): void {
        arbitre.demander(cle, composant, priorite)
    }

    // liberer — voir Arbitre.liberer. Entrée : cle. Sortie : aucune. Erreurs : aucune. Dépendances : Arbitre.
    function liberer(cle: string): void { arbitre.liberer(cle) }

    Arbitre { id: arbitre }

    // Module instancié pour l'écran de la surface (null tant que le composant n'est pas monté).
    readonly property alias contenu: scene.contenu
    readonly property alias phase: scene.phase
    // Fenêtre à prendre dans le HyprlandFocusGrab de l'ouvreuse (contrat partagé avec les presqu'îles d'essai).
    readonly property var fenetre: surface
    // Ressorts de taille de la scène, lus pour dimensionner la fenêtre et le corps de l'encoche.
    readonly property Ressort largeur: scene.ressortLargeur
    readonly property Ressort hauteur: scene.ressortHauteur

    screen: modelData
    anchors { top: true; left: true; right: true }
    // Pleine largeur, et hauteur tenue par la scène pendant le mouvement : seule la forme s'anime, jamais la fenêtre.
    // Les zones transparentes ne sont pas floutées (ignore_alpha des règles de calque), et le masque laisse passer
    // les clics.
    implicitHeight: scene.hauteurSurface + encoche.marge
    // Quickshell n'envoie la nouvelle taille au compositeur qu'au polissage de l'image suivante, et une surface au repos
    // n'en rend aucune : sans cette demande d'image, une réserve posée au repos ne s'appliquerait qu'au prochain
    // mouvement, avec l'étirement d'un ancien tampon par Hyprland (recette de L2-60).
    onImplicitHeightChanged: Qt.callLater(() => encoche.Window.window?.update())
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    mask: Region { item: encoche.corps }
    WlrLayershell.namespace: "dunei-presquile"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    Encoche {
        id: encoche
        x: (surface.width - implicitWidth) / 2
        // Noms qualifiés : dans ce bloc, « hauteur » désignerait la propriété de l'Encoche elle-même.
        largeurCorps: surface.largeur.value
        hauteur: surface.hauteur.value

        // Le module, monté et changé par la scène, posée sur le corps de l'encoche.
        Scene {
            id: scene
            x: encoche.evasement
            ecran: surface.modelData
            module: surface.module
            reserve: surface.reserve
        }
    }
}
