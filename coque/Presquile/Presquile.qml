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
    implicitWidth: encoche.implicitWidth + 2 * encoche.marge
    implicitHeight: encoche.implicitHeight + encoche.marge
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
        x: encoche.marge
        largeurCorps: largeur.value
        hauteur: hauteur.value

        // Le module, instancié pour l'écran de la surface ; remonté si le composant change.
        Item {
            id: montage
        }
    }

    // monter — instancie le module de contenu pour l'écran, centré dans le corps de l'encoche.
    // Entrées : aucune (lit module et modelData). Sortie : met à jour contenu. Erreurs : un composant sans Item
    // valide laisse contenu nul et se lit au journal de Quickshell. Dépendances : module, encoche.
    function monter() {
        contenu?.destroy()
        contenu = module.createObject(montage, { ecran: modelData })
        if (!contenu) return
        contenu.x = Qt.binding(() => encoche.evasement + (encoche.largeurCorps - contenu.implicitWidth) / 2)
        contenu.y = Qt.binding(() => (encoche.hauteur - contenu.implicitHeight) / 2)
    }

    onModuleChanged: monter()
    Component.onCompleted: monter()
}
