import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../Theme"
import "../Composants"
import "../Composants/ancrage.js" as Ancrage

// HotePopovers — ESSAI JETABLE (lot de mouvement) : fenêtre unique et permanente des popovers de la barre.
// Rôle : un seul cadre de verre, sans fondu sur le verre, qui se déploie depuis l'icône, se retire dans l'icône et
// passe d'un popover à l'autre en glissant et en changeant de taille, pendant que les contenus se croisent.
// Entrées : barre, la fenêtre de la barre ; popovers, les Overlay hébergés (heberge: true).
// Sorties : aucune. Erreurs : aucune ; sans popover ouvert, le masque est vide et les clics traversent la fenêtre.
// Dépendances : Quickshell (PanelWindow, Region), Quickshell.Wayland, Quickshell.Hyprland (HyprlandFocusGrab), Theme,
// Ressort, Surface, OmbreElevation, ancrage.js. Le namespace « dunei-attention » est emprunté pour son flou.
PanelWindow {
    id: hote

    property var barre
    property var popovers: []
    // L'Overlay ouvert parmi ceux de cette barre, l'Overlay dont le cadre prend la forme, et son contenu construit.
    readonly property var courant: popovers.indexOf(Overlays.popover) >= 0 ? Overlays.popover : null
    property var affiche: null
    property var vueAffichee: null
    property real ancreX: 0
    property real ancreL: 0
    readonly property real retrait: Theme.space?.scale[0] ?? 0
    // Largeur du popover montré, gardée à la fermeture pour que le bord d'appui reste à sa place.
    property real largeurOuverte: 0
    readonly property real gaucheOuverte: Ancrage.gaucheCadre(false, ancreX, ancreL, null, largeurOuverte, screen?.width ?? 0, Theme.space?.scale[1] ?? 0)
    // Fermé, le cadre a la largeur de l'icône, juste sous elle : il naît d'elle et y retourne.
    readonly property real droiteOuverte: gaucheOuverte + largeurOuverte
    readonly property real cibleG: affiche ? gaucheOuverte : ancreX
    readonly property real cibleD: affiche ? droiteOuverte : ancreX + ancreL
    readonly property real cibleH: affiche && vueAffichee?.item ? vueAffichee.item.implicitHeight + 2 * retrait : 0
    // Passage d'un popover à l'autre : le nouveau contenu attend que la forme ait fait l'essentiel de son trajet.
    property bool passage: false
    property real trajet: 0
    readonly property real reste: Math.max(Math.abs(gauche.value - cibleG), Math.abs(droite.value - cibleD), Math.abs(hauteur.value - cibleH))
    onResteChanged: if (passage && reste <= 0.35 * trajet) passage = false

    screen: barre?.screen ?? null
    anchors { top: true; left: true; right: true }
    implicitHeight: screen?.height ?? 0
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "dunei-attention"
    WlrLayershell.keyboardFocus: courant ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    mask: Region {
        x: cadre.x; y: cadre.y
        width: hote.courant ? cadre.width : 0
        height: hote.courant ? cadre.height : 0
    }

    onCourantChanged: if (!courant) affiche = null

    // voiler — applique le fondu du contenu à tout l'arbre d'un popover, sauf à sa bascule d'en-tête.
    // Entrées : item, la branche à parcourir ; vue, le Loader qui porte les fondus. Sortie : vrai si la branche contient
    // la bascule. Erreurs : aucune. Dépendances : objectName « bascule » de l'en-tête des popovers.
    function voiler(item, vue) {
        if (item.objectName === "bascule") {
            item.opacity = Qt.binding(() => vue.opaciteDisque)
            return true
        }
        const enfants = Array.from(item.children ?? [])
        const contient = enfants.map(e => voiler(e, vue))
        if (!contient.some(c => c)) return false
        enfants.forEach((e, i) => { if (!contient[i]) e.opacity = Qt.binding(() => vue.opaciteContenu) })
        return true
    }

    // montrer — fait prendre au cadre la forme d'un popover dont le contenu est construit.
    // Entrées : ov, l'Overlay ; vue, son Loader. Sortie : aucune. Erreurs : aucune.
    // Dépendances : ancre de l'Overlay, Ressort.poser. Fermé, le cadre est d'abord posé sur l'icône.
    function montrer(ov, vue) {
        const ferme = hauteur.value < 0.5 && !hauteur.moving
        ancreX = ov.ancre.mapToItem(null, 0, 0).x
        ancreL = ov.ancre.width
        largeurOuverte = vue.item.implicitWidth + 2 * retrait
        vue.xFixe = gaucheOuverte
        if (ferme) { gauche.poser(); droite.poser() }
        vueAffichee = vue
        affiche = ov
        trajet = Math.max(Math.abs(gauche.value - cibleG), Math.abs(droite.value - cibleD), Math.abs(hauteur.value - cibleH))
        passage = !ferme && trajet > 2
    }

    // Les trois ressorts suivent le même réglage, quel que soit leur sens : les bords avancent ensemble.
    readonly property string sens: affiche ? "in" : "out"
    Ressort { id: gauche; seuil: 0.5; sens: hote.sens; transition: "reveal"; cible: hote.cibleG }
    Ressort { id: droite; seuil: 0.5; sens: hote.sens; transition: "reveal"; cible: hote.cibleD }
    Ressort { id: hauteur; seuil: 0.5; sens: hote.sens; transition: "reveal"; cible: hote.cibleH }

    FocusScope {
        id: cadre
        x: gauche.value
        y: 28 + (Theme.space?.scale[0] ?? 0)
        width: droite.value - gauche.value
        height: hauteur.value
        visible: height >= 0.5
        focus: true
        Keys.onEscapePressed: if (hote.courant) hote.courant.ouvert = false

        OmbreElevation { cible: corps; niveau: "e3"; evidee: true }

        Surface {
            id: corps
            anchors.fill: parent
            role: "surfaceRaised"
            radius: Math.min(Theme.radius?.panel ?? 0, cadre.height / 2, cadre.width / 2)
            verre: true
        }

        Item {
            anchors.fill: parent
            clip: true
            Repeater {
                model: hote.popovers
                Loader {
                    id: vue
                    required property var modelData
                    readonly property bool pret: modelData.ouvert && status === Loader.Ready
                    // Le contenu reste à sa place sur l'écran : le cadre le découvre, il ne le déplace pas.
                    property real xFixe: 0
                    x: xFixe + hote.retrait - cadre.x
                    y: hote.retrait
                    asynchronous: true
                    // Contenu construit une fois pour toutes au démarrage : l'ouverture n'a plus rien à attendre.
                    active: true
                    readonly property real opaciteContenu: fondu.value
                    // Au passage, le disque de l'ancien popover reste plein jusqu'à ce que le nouveau l'ait recouvert :
                    // le disque ne s'éteint jamais et seul son contenu change.
                    readonly property bool couvert: hote.affiche !== null && hote.vueAffichee !== vue && (hote.vueAffichee?.opaciteContenu ?? 1) < 1
                    readonly property real opaciteDisque: couvert ? 1 : fondu.value
                    visible: opaciteContenu > 0 || opaciteDisque > 0
                    z: hote.vueAffichee === vue ? 1 : 0
                    onLoaded: hote.voiler(item, vue)
                    focus: modelData.ouvert
                    sourceComponent: modelData.contenu
                    onPretChanged: if (pret) { hote.montrer(modelData, vue) }
                    Ressort { id: fondu; transition: "reveal"; cible: vue.pret && !(hote.passage && hote.vueAffichee === vue) ? 1 : 0 }
                }
            }
        }

        HoverHandler {
            onHoveredChanged: if (hote.courant) hote.courant.survolCadre = hovered
        }
    }

    HyprlandFocusGrab {
        windows: hote.barre ? [hote, hote.barre] : [hote]
        active: hote.courant !== null
        onCleared: if (hote.courant) hote.courant.ouvert = false
    }
}
