import QtQuick
import Quickshell
import Quickshell.Hyprland
import "../Composants"

// FenetrePanneau — panneau des notifications, presqu'île latérale ouverte par la cloche de la barre (L2-67).
// Rôle : porte l'état du panneau (ouvert, écran) et crée sa fenêtre de calque (CalquePanneau), unique, posée sur
// l'écran de la cloche cliquée.
// Le panneau est un contextuel exclusif du registre Overlays, comme les popovers de la barre (D108) : en ouvrir un
// ferme l'autre. Il se ferme par la cloche, par un clic hors de la forme (prise du clavier, que la barre de la cloche
// partage : un clic sur la cloche ferme par la cloche, sans réouverture) et par Échap. Il ne s'ouvre pas en plein
// écran, et se ferme si son écran disparaît.
// Entrées : centre, le Centre (obligatoire) ; ecrans, les écrans présents (Quickshell.screens) et pleinEcran, lus
// d'Hyprland, tous deux remplaçables par une coque d'essai ; fenetree, vrai par défaut : faux, la fenêtre de calque
// n'est pas construite (coque d'essai sous offscreen, qui n'en a pas).
// Sorties : attente, celle du centre, que lit la cloche (nombre, critique) ; ouvert ; ecran, l'écran du panneau ;
// barre, la fenêtre de la barre dont la cloche l'a ouvert ; famille et exclusif, contrat du registre Overlays.
// Fonction : basculer.
// Erreurs : aucune ; sans écran, Quickshell pose la fenêtre sur l'écran par défaut.
// Dépendances : quickshell ≥ 0.3 (Scope, Hyprland), CalquePanneau, Overlays.
Scope {
    id: racine

    required property QtObject centre
    readonly property QtObject attente: centre?.attente ?? null
    readonly property string famille: "contextuel"
    readonly property bool exclusif: true
    property bool ouvert: false
    property var ecran: null
    property var barre: null
    property var ecrans: Quickshell.screens
    property bool pleinEcran: Hyprland.focusedMonitor?.activeWorkspace?.hasFullscreen ?? false
    property bool fenetree: true

    // basculer — clic sur la cloche d'une barre : ferme le panneau s'il est ouvert sur l'écran de cette barre,
    // sinon l'ouvre sur lui (un panneau ouvert ailleurs y passe). Entrée : b, la fenêtre de la barre (modelData : son
    // écran). Sortie : aucune. Erreurs : aucune ; sans effet en plein écran. Dépendances : ouvert, ecran, barre.
    function basculer(b) {
        const e = b?.modelData ?? null
        if (ouvert && ecran === e) return void (ouvert = false)
        if (pleinEcran) return
        barre = b
        ecran = e
        ouvert = true
    }

    onOuvertChanged: ouvert ? Overlays.ouvrir(racine) : Overlays.fermer(racine)
    onEcransChanged: if (ouvert && ecran && !Array.from(ecrans).includes(ecran)) ouvert = false
    onPleinEcranChanged: if (pleinEcran) ouvert = false

    // La fenêtre de calque vit dans son propre fichier, créé à la demande : sous la plateforme offscreen, le type
    // PanelWindow ne se compile même pas (« No PanelWindow backend loaded »), et le nommer ici rendrait ce fichier
    // inchargeable par les coques d'essai.
    Component.onCompleted: {
        if (!fenetree) return
        const c = Qt.createComponent("CalquePanneau.qml")
        if (c.status === Component.Ready) c.createObject(racine, {racine: racine})
        else console.warn("panneau : calque indisponible : " + c.errorString())
    }
}
