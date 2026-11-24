pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../Theme"
import "../Composants" as C
import "../Applications"
import "selecteur.js" as Logique
import "../Applications/applications.js" as Apps

// Selecteur — contrôleur unique du sélecteur de fenêtres (L2-17) : geste tenu de SUPER + Tab, état, exécution et IPC.
// Rôle : au premier SUPER + Tab, relève les fenêtres des bureaux 1 à 4 de la plus récente à la plus ancienne
// (selecteur.js fenetres sur Applications.toplevels()), fige cette liste pour tout le geste, pose la sélection sur la
// deuxième (la première est la fenêtre active) et ouvre aussitôt sa Scene (L2-80), clavier exclusif, sans rien
// montrer : c'est ce clavier qui reçoit le relâchement de SUPER. Si SUPER est encore tenu au délai delays.selecteur
// (Scene.delai), la scène se montre. Chaque SUPER + Tab suivant avance d'un cran, en boucle ; Maj + Tab, SUPER tenu,
// recule ; relâcher SUPER valide ; Échap et un clic sur le voile annulent. Valider passe par Scene.executer : le
// sélecteur se ferme et la fenêtre choisie, bureau compris, n'est amenée qu'au retrait de son calque par le
// compositeur (closelayer de son propre namespace, espace, D194), pour qu'elle garde le clavier que Hyprland lui rend
// à ce retrait ; une fenêtre fermée pendant le geste n'est pas amenée. La Scene porte l'ouverture, le délai, le fondu
// de sortie, l'inscription au registre Overlays (famille « attention » : l'ouvrir ferme le lanceur, et le lanceur qui
// s'ouvre le ferme) et la garde d'une seconde ; son cadre est CadreSelecteur. Le clavier est traité ici, par touche(),
// qu'appellent le cadre et l'IPC des essais : un seul chemin.
// Entrées : clavierExclusif, vrai par défaut, transmis à la scène (une coque d'essai le met à faux pour ne jamais
//           prendre le clavier de Nicolas) ; executeur, null par défaut : une fonction qui reçoit l'action à la place
//           de son exécution réelle (coques d'essai) ; fenetree, vrai par défaut : faux, aucune fenêtre n'est
//           construite et l'action part aussitôt ; source, null par défaut : un tableau de fenêtres qui remplace
//           Applications.toplevels() (coques d'essai ; chaque fenêtre peut y porter taille, [largeur, hauteur], à la
//           place du relevé de Hyprland).
//           IPC « selecteur » : avancer, valider, annuler, touche, etat. Le raccourci global dunei:selecteur, qui
//           appelle avancer(1), est déclaré par la coque de session (coque/shell.qml) : le protocole des raccourcis
//           globaux refuse deux clients sur la même paire appid:nom, et une coque d'essai qui chargerait ce singleton
//           à côté de la coque installée ferait tomber l'une des deux.
// Sorties : ouvert (alias de la scène, s'affecte) ; montre, sortant, differee et fenetre (lus sur la scène :
//           montrée après le délai, fenêtre en sortie, action en attente du retrait du calque ou null, FenetreScene
//           ouverte ou null) ; espace (« dunei-attention-selecteur », le namespace de son calque) ; liste (fenêtres
//           figées à l'ouverture) ; index (la sélection) ; choisie (la fenêtre sous la sélection, ou null) ; largeurs
//           (de chaque vignette, selecteur.js largeur).
// Erreurs : aucune ; une fenêtre qui ne peut être construite est journalisée par la scène, qui se referme ; moins de
//           deux fenêtres, avancer ne fait rien.
// Dépendances : Quickshell (Singleton), Quickshell.Io (IpcHandler), Quickshell.Hyprland (toplevels, dispatch,
//           refreshToplevels), Theme (selecteur, motion.delays), C.Scene, CadreSelecteur, Applications, selecteur.js,
//           applications.js (commandeFocus).
Singleton {
    id: selecteur

    property alias ouvert: scene.ouvert
    readonly property bool montre: scene.montre
    readonly property bool sortant: scene.sortant
    readonly property var differee: scene.differee
    readonly property var fenetre: scene.fenetre
    // Namespace du calque du sélecteur, propre à lui (L2-80), lu par la coque d'essai.
    readonly property string espace: "dunei-attention-selecteur"
    property var liste: []
    property int index: 0
    property bool clavierExclusif: true
    property var executeur: null
    property bool fenetree: true
    property var source: null
    readonly property var choisie: liste[index] ?? null
    readonly property var largeurs: liste.map(f => {
        const t = taille(f)
        return Theme.selecteur ? Logique.largeur(t[0], t[1], Theme.selecteur) : 0
    })

    C.Scene {
        id: scene
        cadre: Component { CadreSelecteur {} }
        clavierExclusif: selecteur.clavierExclusif
        executeur: selecteur.executeur
        fenetree: selecteur.fenetree
        espace: selecteur.espace
        delai: Theme.motion?.delays.selecteur ?? 0

        // onRealiser — l'action part, aucun exécuteur n'étant posé : amener donne le focus à la fenêtre, bureau
        // compris. Entrée : action, {genre (« amener »), cible (adresse)}. Sortie : aucune. Erreurs : aucune ; un
        // genre inconnu ne fait rien. Dépendances : Hyprland.dispatch, Apps.commandeFocus.
        onRealiser: action => { if (action.genre === "amener") Hyprland.dispatch(Apps.commandeFocus(action.cible)) }
    }

    // releve — fenêtres vues par le sélecteur à cet instant. Entrées : aucune. Sortie : tableau de {adresse, classe,
    // titre, bureau, historique}, source s'il est posé, sinon Applications.toplevels(). Erreurs : aucune.
    // Dépendances : source, Applications.toplevels.
    function releve() { return source ?? Applications.toplevels() }

    // taille — dimensions d'une fenêtre, pour la largeur de sa vignette. Entrée : f, une fenêtre de liste. Sortie :
    // [largeur, hauteur], f.taille s'il est posé (essais), sinon la taille relevée par Hyprland, [0, 0] à défaut.
    // Erreurs : aucune. Dépendances : Hyprland.toplevels (lastIpcObject).
    function taille(f) {
        return f.taille ?? Hyprland.toplevels.values.find(t => t.address === f.adresse)?.lastIpcObject?.size ?? [0, 0]
    }

    // avancer — SUPER + Tab : ouvre le sélecteur fermé, sinon déplace la sélection en boucle. Entrée : pas, +1 pour
    // avancer, -1 pour reculer. Sortie : aucune. Erreurs : aucune ; fermé et avec moins de deux fenêtres retenues, rien.
    // Dépendances : liste, index, ouvert, releve, source, Hyprland.refreshToplevels (relève la taille des fenêtres, dont
    // dépend la largeur des vignettes, sans attendre : la liaison de largeurs suit), Logique (fenetres, avancer).
    function avancer(pas: int) {
        if (ouvert) { index = Logique.avancer(index, liste.length, pas); return }
        if (!source) Hyprland.refreshToplevels()
        const l = Logique.fenetres(releve())
        if (l.length < 2) return
        liste = l
        index = Logique.avancer(0, l.length, pas)
        ouvert = true
    }

    // choisir — pose la sélection sur une vignette (survol, clic). Entrée : i, son rang dans liste. Sortie : aucune.
    // Erreurs : aucune ; fermé ou hors de la liste, rien. Dépendances : ouvert, liste, index.
    function choisir(i: int) { if (ouvert && i >= 0 && i < liste.length) index = i }

    // valider — ferme le sélecteur et amène la fenêtre choisie, si elle est encore ouverte. Entrées : aucune.
    // Sortie : aucune. Erreurs : aucune ; fermé, rien ; une fenêtre fermée pendant le geste n'est pas amenée.
    // Dépendances : ouvert, choisie, releve, scene.executer.
    function valider() {
        if (!ouvert) return
        const f = choisie
        if (f && releve().some(x => x.adresse === f.adresse)) scene.executer({ genre: "amener", cible: f.adresse })
        else ouvert = false
    }

    // annuler — ferme le sélecteur sans rien amener (Échap, clic sur le voile). Entrées : aucune. Sortie : aucune.
    // Erreurs : aucune. Dépendances : ouvert.
    function annuler() { ouvert = false }

    // touche — entrée clavier unique du sélecteur, appelée par le cadre et par l'IPC des essais.
    // Entrées : nom, « ReleaseSuper » (relâchement de SUPER), « Backtab » (Maj + Tab), « Tab », « Escape » ou le nom
    // de toute autre touche ; superTenu, vrai si le modificateur SUPER accompagne l'événement. Sortie : aucune.
    // Le relâchement de SUPER valide ; Maj + Tab, SUPER tenu, recule ; Tab, SUPER tenu, avance ; Échap annule ; toute
    // autre touche reçue sans SUPER tenu, Maj + Tab compris, valide, en secours d'un relâchement perdu ; avec SUPER
    // tenu, elle est ignorée.
    // Erreurs : aucune ; fermé, rien. Dépendances : ouvert, valider, avancer, annuler.
    function touche(nom: string, superTenu: bool) {
        if (!ouvert) return
        if (nom === "ReleaseSuper") valider()
        else if (nom === "Backtab" && superTenu) avancer(-1)
        else if (nom === "Escape") annuler()
        else if (nom === "Tab" && superTenu) avancer(1)
        else if (!superTenu) valider()
    }

    IpcHandler {
        target: "selecteur"

        // avancer — ouvre le sélecteur ou déplace la sélection (voir Selecteur.avancer). Entrée : pas. Sortie : aucune.
        function avancer(pas: int): void { selecteur.avancer(pas) }

        // valider, annuler — valident ou annulent le geste en cours. Sortie : aucune.
        function valider(): void { selecteur.valider() }
        function annuler(): void { selecteur.annuler() }

        // touche — presse une touche dans le sélecteur (essais). Entrées : nom, superTenu (voir Selecteur.touche).
        // Sortie : aucune.
        function touche(nom: string, superTenu: bool): void { selecteur.touche(nom, superTenu) }

        // etat — état du sélecteur en JSON : ouvert, montre, index, adresses (de la liste figée), fenetre (vrai si elle
        // existe), sortant (fenêtre en sortie), differee (vrai si une action attend le retrait du calque).
        // Sortie : texte. Erreurs : aucune. Dépendances : selecteur, lu sur sa scène.
        function etat(): string {
            return JSON.stringify({ ouvert: selecteur.ouvert, montre: selecteur.montre, index: selecteur.index,
                adresses: selecteur.liste.map(f => f.adresse), fenetre: selecteur.fenetre !== null,
                sortant: selecteur.sortant, differee: selecteur.differee !== null })
        }
    }
}
