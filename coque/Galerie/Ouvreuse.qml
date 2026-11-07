import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../Theme"
import "../Composants"
import "galerie.js" as Logique

// Ouvreuse — contrôleur unique de la galerie de fonds d'écran (L2-60) : ouverture, fermeture et application.
// Rôle : expose par IPC (cible « galerie ») basculer(), que lie SUPER + W. Ouvrir monte le module Galerie dans la
// presqu'île de l'écran actif seule, à la place de son module courant, rendu à la fermeture ; rien ne s'ouvre si
// l'espace de travail de l'écran actif porte une fenêtre en plein écran (la presqu'île, sur la couche Top, serait
// cachée tout en prenant le clavier). L'ouvreuse est un contextuel exclusif du registre Overlays (D108) : l'ouvrir
// ferme le popover de la barre éventuellement ouvert, et un popover qui s'ouvre la referme. Pendant l'ouverture, un
// HyprlandFocusGrab sur la fenêtre de la presqu'île prend le clavier ; sa levée (clic en dehors) referme la galerie.
// Quand la presqu'île passe en phase « entree », le délai d'abandon de la galerie repart de zéro et le module prend
// le focus : Nicolas dispose de tout le délai une fois la bande visible. Dès qu'une image est choisie (signal choisi),
// son chemin, s'il n'est pas déjà le fond actuel, est passé à dunei-fond, dont un échec s'écrit au journal : la montée
// du fond part pendant que la galerie met le choix en valeur. À la fin de la galerie (signal fini, après cette tenue
// ou aussitôt pour un abandon), elle se referme. Une presqu'île retirée (écran débranché) pendant l'ouverture remet
// l'ouvreuse à l'état fermé.
// Entrées : les presqu'îles, inscrites par inscrire() et retirées par retirer() ; chacune porte modelData (son écran),
//           module (composant écrit par l'ouvreuse), contenu et phase (lus), et fenetre (la fenêtre du grab, ou null) ;
//           ecranActif, l'écran du moniteur focalisé d'Hyprland ; pleinEcran, vrai si son espace de travail actif
//           porte une fenêtre en plein écran (HyprlandWorkspace.hasFullscreen, éprouvé sous Quickshell 0.3.2) ;
//           commande, le programme d'application, dunei-fond par défaut ; galerie, le composant du module.
//           Les essais remplacent ecranActif, pleinEcran, commande et galerie.
// Sorties : ouvert ; cible, la presqu'île qui porte la galerie (null fermée) ; famille et exclusif, lus par Overlays ;
//           un processus « commande <chemin> » à chaque validation d'une autre image que le fond actuel, lancé dès le
//           signal choisi.
// Erreurs : sans presqu'île sur l'écran actif, basculer() n'ouvre rien ; un code de sortie non nul de la commande
//           écrit « galerie : dunei-fond a échoué (<code>) » au journal, le fond reste inchangé.
// Dépendances : quickshell ≥ 0.3 (IpcHandler, Process, Hyprland, HyprlandFocusGrab), Theme (imageBureau), Overlays,
//               Galerie, galerie.js (identique).
Scope {
    id: ouvreuse

    // Contrat du registre Overlays : un contextuel exclusif, comme les popovers de la barre.
    readonly property string famille: "contextuel"
    readonly property bool exclusif: true
    property bool ouvert: false
    property var cible: null
    property var presquiles: []

    // Écran actif, rapproché par son nom comme dans Overlay et évalué dès la création, car Hyprland.focusedMonitor
    // vaut undefined au premier accès. Une liaison sur Hyprland.monitorFor(s) === focusedMonitor ne se réévalue pas
    // quand focusedMonitor se remplit (constaté sous Quickshell 0.3.2) : elle resterait nulle.
    property var ecranActif: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? null
    property bool pleinEcran: Hyprland.focusedMonitor?.activeWorkspace?.hasFullscreen ?? false
    property var commande: ["dunei-fond"]
    property Component galerie: Component { Galerie {} }

    // Module que la presqu'île portait avant l'ouverture, rendu à la fermeture.
    property Component _avant: null
    // Galerie montée et visible pour l'ouvreuse : nulle pendant le fondu de sortie de l'ancien contenu, pour qu'un
    // module sur le départ ne puisse pas refermer une ouverture neuve.
    readonly property var _montee: ouvert && cible?.module === galerie && cible?.phase !== "sortie" ? cible.contenu : null

    // inscrire — fait connaître une presqu'île à l'ouvreuse. Entrée : p, la presqu'île. Sortie : aucune.
    // Erreurs : aucune ; une presqu'île déjà inscrite ne l'est pas deux fois. Dépendances : presquiles.
    function inscrire(p) { if (!presquiles.includes(p)) presquiles = [...presquiles, p] }

    // retirer — oublie une presqu'île détruite ; si elle portait la galerie, l'ouvreuse revient à l'état fermé sans
    // toucher à la presqu'île qui disparaît. Entrée : p. Sortie : aucune. Erreurs : aucune. Dépendances : presquiles.
    function retirer(p) {
        presquiles = presquiles.filter(q => q !== p)
        if (p === cible) { cible = null; ouvert = false }
    }

    // basculer — ouvre la galerie si elle est fermée, la referme sinon. Entrées : aucune. Sortie : aucune.
    // Erreurs : aucune. Dépendances : ouvrir, ouvert.
    function basculer() { if (ouvert) ouvert = false; else ouvrir() }

    // ouvrir — monte la galerie dans la presqu'île de l'écran actif et s'inscrit comme popover exclusif.
    // Entrées : aucune (lit ecranActif, pleinEcran, presquiles). Sortie : aucune.
    // Erreurs : sans effet en plein écran, déjà ouverte, ou sans presqu'île sur l'écran actif.
    // Dépendances : Overlays.ouvrir, galerie.
    function ouvrir() {
        const p = presquiles.find(q => q.modelData === ecranActif)
        if (ouvert || pleinEcran || !p) return
        cible = p
        _avant = p.module
        p.module = galerie
        ouvert = true
        Overlays.ouvrir(ouvreuse)
    }

    // rendre — défait l'ouverture : quitte le registre et rend à la presqu'île son module d'avant.
    // Entrées : aucune ; appelée quand ouvert passe à faux, quelle qu'en soit la cause (basculer, fin de la galerie,
    // popover, clic en dehors, presqu'île retirée). Sortie : aucune. Erreurs : aucune. Dépendances : Overlays.fermer.
    function rendre() {
        Overlays.fermer(ouvreuse)
        if (cible) cible.module = _avant
        cible = null
        _avant = null
    }

    // appliquer — passe une image à la commande d'application, sauf si elle est déjà le fond actuel.
    // Entrée : chemin, chemin absolu de l'image, transmis intact en un seul argument. Sortie : aucune.
    // Erreurs : un code non nul s'écrit au journal par le processus. Dépendances : Logique.identique, Theme, fabrique.
    function appliquer(chemin) {
        if (!Logique.identique(chemin, Theme.imageBureau)) fabrique.createObject(ouvreuse, { command: [...commande, chemin] })
    }

    onOuvertChanged: if (!ouvert) rendre()

    // Galerie montée : une image choisie s'applique aussitôt ; la fin (abandon, ou choix après sa tenue) referme.
    Connections {
        target: ouvreuse._montee
        ignoreUnknownSignals: true
        function onChoisi(chemin) { ouvreuse.appliquer(chemin) }
        function onFini() { ouvreuse.ouvert = false }
    }

    // Galerie visible : le délai d'abandon repart, et le module prend le focus clavier de sa fenêtre.
    Connections {
        target: ouvreuse.ouvert ? ouvreuse.cible : null
        function onPhaseChanged() {
            const g = ouvreuse._montee
            if (ouvreuse.cible.phase !== "entree" || !g) return
            g.relancer()
            g.forceActiveFocus()
        }
    }

    // Prise du clavier, motif d'Overlay ; Échap n'est pas traité par le grab mais par le module.
    HyprlandFocusGrab {
        windows: ouvreuse.cible?.fenetre ? [ouvreuse.cible.fenetre] : []
        active: ouvreuse.ouvert && windows.length > 0
        onCleared: ouvreuse.ouvert = false
    }

    // Processus d'application, un par validation, détruit à sa sortie.
    Component {
        id: fabrique
        Process {
            running: true
            onExited: code => {
                if (code !== 0) console.warn("galerie : dunei-fond a échoué (" + code + ")")
                destroy()
            }
        }
    }

    IpcHandler {
        target: "galerie"

        // basculer — voir la fonction de l'ouvreuse. Entrées : aucune. Sortie : aucune. Erreurs : aucune.
        // Dépendances : ouvreuse.basculer.
        function basculer(): void { ouvreuse.basculer() }
    }
}
