import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../Theme"
import "../Composants"
import "galerie.js" as Logique

// Ouvreuse — contrôleur unique de la galerie de fonds d'écran (L2-60) : ouverture, fermeture et application.
// Rôle : expose par IPC (cible « galerie ») basculer(), que lie SUPER + W. Ouvrir monte le module Galerie dans la
// presqu'île de l'écran actif seule, par une demande de priorité 2 à l'arbitre de la presqu'île, libérée à la fermeture ; rien ne s'ouvre si
// l'espace de travail de l'écran actif porte une fenêtre en plein écran (la presqu'île, sur la couche Top, serait
// cachée tout en prenant le clavier). L'ouvreuse est un contextuel exclusif du registre Overlays (D108) : l'ouvrir
// ferme le popover de la barre éventuellement ouvert, et un popover qui s'ouvre la referme. Pendant l'ouverture, un
// HyprlandFocusGrab sur la fenêtre de la presqu'île prend le clavier ; sa levée (clic en dehors) referme la galerie.
// Quand la presqu'île passe en phase « entree », le délai d'abandon de la galerie repart de zéro et le module prend
// le focus : Nicolas dispose de tout le délai une fois la bande visible. Dès qu'une image est choisie (signal choisi),
// son chemin, s'il n'est pas déjà le fond actuel, est passé à dunei-fond, dont un échec s'écrit au journal : la montée
// du fond part pendant que la galerie met le choix en valeur. À la fin de la galerie (signal fini, après cette tenue
// ou aussitôt pour un abandon), elle se referme. Une presqu'île retirée (écran débranché) pendant l'ouverture remet
// l'ouvreuse à l'état fermé. Au démarrage, l'ouvreuse crée puis détruit aussitôt une galerie sans dossier : la première
// instance d'un composant prépare ses types, ce qui coûtait 12 à 19 ms dans l'image où la presqu'île cède l'ancien
// contenu et monte la galerie, contre 1 ou 2 ms ensuite (recette de L2-60) ; aucune galerie ni image ne reste en mémoire.
// Cette galerie de préchauffage donne aussi la hauteur du module (hauteurModule), que chaque presqu'île réserve pour
// que sa surface ne change jamais de taille. Elle est mesurée dès que Theme est prêt, dans la notification même, pour
// que la première taille de la surface soit déjà la bonne, puis remesurée à chaque rechargement des jetons.
// Entrées : les presqu'îles, inscrites par inscrire() et retirées par retirer() ; chacune porte modelData (son écran),
//           module (composant arbitré, lu), demander() et liberer() (par lesquelles l'ouvreuse réclame et rend la presqu'île), contenu et phase (lus), et fenetre (la fenêtre du grab, ou null) ;
//           ecranActif, l'écran du moniteur focalisé d'Hyprland ; pleinEcran, vrai si son espace de travail actif
//           porte une fenêtre en plein écran (HyprlandWorkspace.hasFullscreen, éprouvé sous Quickshell 0.3.2) ;
//           commande, le programme d'application, dunei-fond par défaut ; galerie, le composant du module.
//           Les essais remplacent ecranActif, pleinEcran, commande et galerie.
// Sorties : ouvert ; cible, la presqu'île qui porte la galerie (null fermée) ; famille et exclusif, lus par Overlays ;
//           hauteurModule, hauteur implicite d'une galerie (0 avant la première mesure ou sans jetons) ;
//           un processus « commande <chemin> » à chaque validation d'une autre image que le fond actuel, lancé dès le
//           signal choisi.
// Erreurs : sans presqu'île sur l'écran actif, basculer() n'ouvre rien ; un code de sortie non nul de la commande
//           écrit « galerie : <programme> a échoué (<code>) » au journal (le nom de base du premier élément de la
//           commande, dunei-fond par défaut), le fond reste inchangé.
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
    readonly property real hauteurModule: _hauteurModule
    property real _hauteurModule: 0

    // Écran actif, rapproché par son nom comme dans Overlay et évalué dès la création, car Hyprland.focusedMonitor
    // vaut undefined au premier accès. Une liaison sur Hyprland.monitorFor(s) === focusedMonitor ne se réévalue pas
    // quand focusedMonitor se remplit (constaté sous Quickshell 0.3.2) : elle resterait nulle.
    property var ecranActif: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? null
    property bool pleinEcran: Hyprland.focusedMonitor?.activeWorkspace?.hasFullscreen ?? false
    property var commande: ["dunei-fond"]
    property Component galerie: Component { Galerie {} }

    // Galerie montée et visible pour l'ouvreuse : nulle pendant le fondu de sortie de l'ancien contenu, pour qu'un
    // module sur le départ ne puisse pas refermer une ouverture neuve.
    readonly property var _montee: ouvert && cible?.module === galerie && cible?.phase !== "sortie" ? cible.contenu : null

    // prechauffer — crée une galerie sans dossier, hors de toute fenêtre, en relève la hauteur et la détruit au tour de
    // boucle suivant, pour que la première vraie ouverture ne paie pas la préparation des types du composant.
    // Une galerie sans dossier n'est jamais lue : elle a la hauteur d'une bande de vignettes, pas celle du message de
    // dossier vide. Entrées : aucune (lit galerie). Sortie : met à jour _hauteurModule. Erreurs : sans composant, ou
    // avec un composant invalide (écrit au journal de Quickshell), la hauteur vaut 0.
    // Dépendances : galerie (le module Galerie, dont ecran, dossier et implicitHeight).
    function prechauffer() {
        const g = galerie?.createObject(null, { ecran: null, dossier: "" }) ?? null
        _hauteurModule = g?.implicitHeight ?? 0
        g?.destroy()
    }

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
        p.demander("galerie", galerie, 2)
        ouvert = true
        Overlays.ouvrir(ouvreuse)
    }

    // rendre — défait l'ouverture : quitte le registre et libère la demande de la galerie : la presqu'île revient au module suivant dans l'arbitre.
    // Entrées : aucune ; appelée quand ouvert passe à faux, quelle qu'en soit la cause (basculer, fin de la galerie,
    // popover, clic en dehors, presqu'île retirée). Sortie : aucune. Erreurs : aucune. Dépendances : Overlays.fermer.
    function rendre() {
        Overlays.fermer(ouvreuse)
        cible?.liberer("galerie")
        cible = null
    }

    // appliquer — passe une image à la commande d'application, sauf si elle est déjà le fond actuel.
    // Entrée : chemin, chemin absolu de l'image, transmis intact en un seul argument. Sortie : aucune.
    // Erreurs : un code non nul s'écrit au journal par le processus. Dépendances : Logique.identique, Theme, fabrique.
    function appliquer(chemin) {
        if (!Logique.identique(chemin, Theme.imageBureau)) fabrique.createObject(ouvreuse, { command: [...commande, chemin] })
    }

    onOuvertChanged: if (!ouvert) rendre()
    // Au tour de boucle suivant si Theme est déjà prêt : le démarrage de la coque finit d'abord de créer ses fenêtres.
    // Sinon, la mesure attend Theme : une galerie sans jetons n'a pas de hauteur.
    Component.onCompleted: if (Theme.ready) Qt.callLater(prechauffer)
    // Theme prêt : ready est posé après les données, la mesure peut se faire dans la notification. Jetons rechargés
    // ensuite : la hauteur du module peut changer, elle est remesurée au tour de boucle suivant, une fois les raccourcis
    // de Theme réévalués.
    Connections {
        target: Theme
        function onReadyChanged() { if (Theme.ready) ouvreuse.prechauffer() }
        function onTokensChanged() { if (Theme.ready) Qt.callLater(ouvreuse.prechauffer) }
    }

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
                if (code !== 0) console.warn("galerie : " + ouvreuse.commande[0].split("/").pop() + " a échoué (" + code + ")")
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
