import QtQuick
import Quickshell
import Quickshell.Wayland
import "../Theme"

// Presquile — surface de la presqu'île, posée au centre du bord haut de chaque écran (L2-46).
// Rôle : fenêtre de calque transparente, ancrée en haut seulement (donc centrée), qui porte l'encoche continue et,
// dedans, le module de contenu. La taille de l'encoche suit celle du module par deux Ressorts (transition « window ») :
// immobile tant que le module garde sa taille, elle s'étire sans saut quand il en change. La fenêtre réserve en plus
// de l'encoche la marge de son ombre, pour qu'elle ne soit pas coupée. Le masque de saisie ne couvre que le corps de
// l'encoche : partout ailleurs, les clics traversent. Elle ne réserve aucune place et ne prend jamais le focus clavier.
// Entrées : modelData, l'écran que lui donne le Variants de la coque (obligatoire) ; module, le composant de contenu,
//           Bureaux par défaut ; il doit être un Item déclarant implicitWidth et implicitHeight, et recevoir ecran.
// Sorties : une fenêtre de calque au namespace « dunei-presquile » (floutée par les règles de calque générées).
// Erreurs : sans jeton de thème, l'encoche est vide et la fenêtre reste posée ; un module sans taille laisse l'encoche
//           à la hauteur des jetons.
// Dépendances : quickshell ≥ 0.3 (PanelWindow, Region, WlrLayershell), Encoche, Bureaux, Ressort, Theme.
PanelWindow {
    id: surface

    required property var modelData
    property Component module: Component { Bureaux {} }

    // Module instancié pour l'écran de la surface (null tant que le composant n'est pas monté).
    property Item contenu: null

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

    Ressort { id: largeur; transition: "window"; cible: surface.contenu?.implicitWidth ?? 0 }
    Ressort {
        id: hauteur
        transition: "window"
        cible: surface.contenu?.implicitHeight || (Theme.tokens?.presquile?.hauteur ?? 0)
    }

    Encoche {
        id: encoche
        x: (surface.implicitWidth - implicitWidth) / 2
        largeurCorps: largeur.value
        hauteur: hauteur.value

        // Le module, instancié pour l'écran de la surface ; remonté si le composant change.
        Item {
            id: montage
        }
    }

    // monter — instancie le module de contenu pour l'écran, centré dans le corps de l'encoche.
    // Entrées : aucune (lit module et modelData).
    // Sortie : met à jour contenu ; au premier montage, pose les ressorts de taille sur leur cible.
    // Erreurs : un composant sans Item valide laisse contenu nul et se lit au journal de Quickshell.
    // Dépendances : module, encoche, Ressort.poser.
    function monter() {
        const premier = !contenu
        contenu?.destroy()
        const m = module.createObject(montage, { ecran: modelData })
        contenu = m
        if (!m) return
        m.x = Qt.binding(() => encoche.evasement + (encoche.largeurCorps - m.implicitWidth) / 2)
        m.y = Qt.binding(() => (encoche.hauteur - m.implicitHeight) / 2)
        // Au premier montage, l'encoche prend sa taille d'un coup : elle ne naît pas de la largeur nulle.
        if (premier) { largeur.poser(); hauteur.poser() }
    }

    onModuleChanged: monter()
    Component.onCompleted: monter()
}
