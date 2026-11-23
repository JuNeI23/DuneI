pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../Composants" as C
import "deconnexion.js" as Logique

// Deconnexion — contrôleur unique du menu de déconnexion (L2-23) : actions, curseur, double appui, exécution et IPC.
// Rôle : lit les actions déclarées dans actions.json (validées par deconnexion.js valider), tient le curseur (index)
// et le bouton armé (arme, -1 si aucun), et porte une Scene (famille « attention » du registre Overlays) dont le
// cadre est CadreDeconnexion. Verrouiller et Veille partent au premier appui ; Déconnexion, Redémarrer et Éteindre
// (confirmer) s'arment au premier et partent au second sur le même bouton, quel que soit le moyen (lettre, Entrée,
// Espace, clic). Tout déplacement du curseur vers un autre bouton, et toute fermeture, désarment. L'action choisie
// passe par Scene.executer : le menu se ferme, et la commande ne part qu'au retrait du calque dunei-attention, pour
// que hyprlock ou la veille ne trouvent pas le calque encore posé. Le clavier est traité ici, par touche(), qu'appellent
// le cadre et l'IPC : un seul chemin.
// Entrées : clavierExclusif, vrai par défaut, transmis à la scène (une coque d'essai le met à faux pour ne jamais
//           prendre le clavier de Nicolas) ; executeur, null par défaut : une fonction qui reçoit l'action à la place
//           de son exécution réelle (coques d'essai) ; fenetree, vrai par défaut : faux, aucune fenêtre n'est
//           construite et l'action part aussitôt. IPC « deconnexion » : basculer, ouvrir, touche, etat.
// Sorties : ouvert (alias de la scène, s'affecte) ; actions (tableau validé) ; index ; arme ; fenetre (la fenêtre
//           de la scène, ou null) ; basculer(), ouvrir(id), annuler(), choisir(i), appuyer(i), touche(nom).
// Erreurs : un actions.json illisible laisse actions vide (journalisé) ; une commande qui échoue (code non nul) ou
//           qui ne démarre pas est journalisée par console.warn, le menu étant déjà fermé.
// Dépendances : Quickshell (Singleton), Quickshell.Io (FileView, Process, IpcHandler), C.Scene, CadreDeconnexion,
//           deconnexion.js, actions.json.
Singleton {
    id: deconnexion

    property alias ouvert: scene.ouvert
    property var actions: []
    property int index: 0
    property int arme: -1
    property bool clavierExclusif: true
    property var executeur: null
    property bool fenetree: true
    readonly property var fenetre: scene.fenetre

    C.Scene {
        id: scene
        cadre: Component { CadreDeconnexion {} }
        clavierExclusif: deconnexion.clavierExclusif
        executeur: deconnexion.executeur
        fenetree: deconnexion.fenetree

        // onRealiser — l'action part, aucun exécuteur n'étant posé : sa commande est lancée.
        // Entrée : action, une entrée de actions. Sortie : aucune. Erreurs : voir lancer. Dépendances : lancer.
        onRealiser: action => deconnexion.lancer(action)

        // onOuvertChanged — toute fermeture désarme (Échap, clic sur le voile, autre attention, exécution).
        // Entrées : aucune. Sortie : arme remis à -1 à la fermeture. Erreurs : aucune. Dépendances : arme.
        onOuvertChanged: if (!ouvert) deconnexion.arme = -1
    }

    // basculer — ouvre le menu sur le premier bouton, désarmé, ou le ferme (logo de la barre, SUPER + Échap).
    // Entrées : aucune. Sortie : aucune. Erreurs : aucune ; sans action valide, le menu ne s'ouvre pas.
    // Dépendances : ouvert, actions, index, arme.
    function basculer() {
        if (ouvert) { ouvert = false; return }
        if (!actions.length) return
        index = 0
        arme = -1
        ouvert = true
    }

    // ouvrir — ouvre le menu, ou le garde ouvert, avec l'action nommée sous le curseur, armée si elle demande
    // confirmation (chemin du lanceur : un appui de plus exécute).
    // Entrée : id, l'identifiant d'une action. Sortie : aucune.
    // Erreurs : aucune ; un id inconnu pose le curseur sur le premier bouton, désarmé ; sans action valide, rien.
    // Dépendances : actions, index, arme, ouvert.
    function ouvrir(id: string) {
        if (!actions.length) return
        const i = actions.findIndex(a => a.id === id)
        index = Math.max(i, 0)
        arme = i >= 0 && actions[i].confirmer ? i : -1
        ouvert = true
    }

    // annuler — ferme le menu sans rien exécuter (Échap). Entrées : aucune. Sortie : aucune ; la fermeture désarme.
    // Erreurs : aucune. Dépendances : ouvert.
    function annuler() { ouvert = false }

    // choisir — pose le curseur sur un bouton (flèches, survol) ; un déplacement vers un autre bouton désarme.
    // Entrée : i, rang du bouton. Sortie : aucune. Erreurs : aucune ; fermé ou hors des actions, rien.
    // Dépendances : ouvert, actions, index, arme.
    function choisir(i: int) {
        if (!ouvert || i < 0 || i >= actions.length) return
        if (i !== index) arme = -1
        index = i
    }

    // appuyer — appui sur un bouton (lettre, Entrée, Espace, clic) : le curseur s'y pose, puis le bouton s'arme ou
    // son action part (deconnexion.js appui).
    // Entrée : i, rang du bouton. Sortie : aucune. Erreurs : aucune ; fermé ou hors des actions, rien.
    // Dépendances : choisir, Logique.appui, arme, scene.executer.
    function appuyer(i: int) {
        if (!ouvert || i < 0 || i >= actions.length) return
        choisir(i)
        const r = Logique.appui(actions, arme, i)
        arme = r.arme
        if (r.executer) scene.executer(actions[i])
    }

    // touche — entrée clavier unique du menu, appelée par le cadre et par l'IPC.
    // Entrée : nom, « Left » ou « Backtab » (reculer), « Right » ou « Tab » (avancer), « Return », « Enter » ou
    // « space » (appuyer sur le bouton sous le curseur), « Escape » (annuler), ou le texte d'une touche : une lettre
    // d'accès appuie sur son bouton. Sortie : aucune. Erreurs : aucune ; fermé ou touche inconnue, rien.
    // Dépendances : ouvert, index, actions, choisir, appuyer, annuler, Logique (suivant, indexLettre).
    function touche(nom: string) {
        if (!ouvert) return
        if (nom === "Left" || nom === "Backtab") choisir(Logique.suivant(index, -1, actions.length))
        else if (nom === "Right" || nom === "Tab") choisir(Logique.suivant(index, 1, actions.length))
        else if (["Return", "Enter", "space"].includes(nom)) appuyer(index)
        else if (nom === "Escape") annuler()
        else if (nom.length === 1) appuyer(Logique.indexLettre(actions, nom))
    }

    // lancer — exécute pour de bon la commande d'une action, par un Process qui journalise son échec.
    // Entrée : action, une entrée de actions (commande). Sortie : aucune.
    // Erreurs : aucune levée ; un échec est journalisé par le Process (voir commande). Dépendances : commande.
    function lancer(action) { commande.createObject(deconnexion, { ident: action.id, command: action.commande }) }

    // Un Process par action lancée, détruit à sa sortie : execDetached ne rend pas le code de sortie, que la fiche
    // demande de journaliser.
    Component {
        id: commande
        Process {
            property string ident
            property bool demarre: false
            running: true
            // onStarted — retient le démarrage effectif du processus. Entrées : aucune. Sortie : demarre. Erreurs :
            // aucune. Dépendances : aucune.
            onStarted: demarre = true
            // onRunningChanged — un processus qui s'arrête sans avoir démarré (commande introuvable) n'émet ni
            // started ni exited : il est journalisé et détruit ici. Entrées : aucune. Sortie : aucune.
            // Erreurs : l'avertissement « Déconnexion : <id> n'a pas démarré ». Dépendances : demarre.
            onRunningChanged: if (!running && !demarre) { console.warn("Déconnexion : " + ident + " n'a pas démarré"); destroy() }
            // onExited — journalise un code de sortie non nul, puis détruit le processus. Entrée : code. Sortie :
            // aucune. Erreurs : l'avertissement « Déconnexion : <id> a échoué (code <n>) ». Dépendances : aucune.
            onExited: code => {
                if (code !== 0) console.warn("Déconnexion : " + ident + " a échoué (code " + code + ")")
                destroy()
            }
        }
    }

    // Actions déclarées, lues une fois.
    FileView {
        path: Qt.resolvedUrl("actions.json").toString().replace(/^file:\/\//, "")
        blockLoading: true
        // onLoaded — lit et valide les actions déclarées. Entrées : aucune. Sortie : actions ([] si le JSON est
        // invalide). Erreurs : l'avertissement « Déconnexion : actions.json illisible » avec l'erreur d'analyse.
        // Dépendances : Logique.valider.
        onLoaded: {
            try { deconnexion.actions = Logique.valider(JSON.parse(text())) }
            catch (e) { console.warn("Déconnexion : actions.json illisible. " + e.message); deconnexion.actions = [] }
        }
        // onLoadFailed — actions.json introuvable ou illisible : le menu reste sans action et ne s'ouvre pas.
        // Entrée : error, le code FileViewError. Sortie : aucune. Erreurs : l'avertissement « Déconnexion :
        // actions.json introuvable » ou « illisible », avec le code. Dépendances : FileViewError.
        onLoadFailed: error => console.warn("Déconnexion : actions.json "
            + (error === FileViewError.FileNotFound ? "introuvable" : "illisible") + " (" + FileViewError.toString(error) + ")")
    }

    IpcHandler {
        target: "deconnexion"

        // basculer — ouvre ou ferme le menu (voir Deconnexion.basculer). Sortie : aucune.
        function basculer(): void { deconnexion.basculer() }

        // ouvrir — ouvre le menu sur une action, armée si elle demande confirmation (voir Deconnexion.ouvrir).
        // Entrée : id. Sortie : aucune.
        function ouvrir(id: string): void { deconnexion.ouvrir(id) }

        // touche — presse une touche dans le menu (voir Deconnexion.touche). Entrée : nom. Sortie : aucune.
        function touche(nom: string): void { deconnexion.touche(nom) }

        // etat — état du menu en JSON : ouvert, index, arme, ids (des actions validées), fenetre (vrai si elle
        // existe), sortant (fenêtre en sortie), differee (id de l'action qui attend le retrait du calque, ou null).
        // Sortie : texte. Erreurs : aucune. Dépendances : deconnexion, scene.
        function etat(): string {
            return JSON.stringify({ ouvert: deconnexion.ouvert, index: deconnexion.index, arme: deconnexion.arme,
                ids: deconnexion.actions.map(a => a.id), fenetre: scene.fenetre !== null, sortant: scene.sortant,
                differee: scene.differee?.id ?? null })
        }
    }
}
