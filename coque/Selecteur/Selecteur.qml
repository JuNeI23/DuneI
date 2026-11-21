pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../Theme"
import "../Composants"
import "../Applications"
import "selecteur.js" as Logique
import "../Applications/applications.js" as Apps

// Selecteur — contrôleur unique du sélecteur de fenêtres (L2-17) : geste tenu de SUPER + Tab, état, exécution et IPC.
// Rôle : au premier SUPER + Tab, relève les fenêtres des bureaux 1 à 4 de la plus récente à la plus ancienne
// (selecteur.js fenetres sur Applications.toplevels()), fige cette liste pour tout le geste, pose la sélection sur la
// deuxième (la première est la fenêtre active) et ouvre aussitôt sa fenêtre de calque, clavier exclusif, sans rien
// montrer : c'est ce clavier qui reçoit le relâchement de SUPER. Si SUPER est encore tenu au délai delays.selecteur,
// montre passe à vrai et la fenêtre apparaît. Chaque SUPER + Tab suivant avance d'un cran, en boucle ; Maj + Tab,
// SUPER tenu, recule ; relâcher SUPER valide ; Échap et un clic sur le voile annulent. Valider ferme le sélecteur et
// amène la fenêtre choisie, bureau compris, une fois le calque retiré par le compositeur (événement closelayer de
// dunei-attention, D194), pour que la fenêtre amenée garde le clavier que Hyprland lui rend à ce retrait ; une fenêtre
// fermée pendant le geste n'est pas amenée. C'est une attention du registre Overlays (famille « attention ») :
// l'ouvrir ferme le lanceur, et le lanceur qui s'ouvre le ferme. Sa fenêtre, FenetreSelecteur, n'existe que pendant
// l'ouverture et son fondu de sortie (LazyLoader, present). Le clavier est traité ici, par touche(), qu'appellent le
// cadre et l'IPC des essais : un seul chemin.
// Entrées : ouvert ; clavierExclusif, vrai par défaut, que la fenêtre applique (une coque d'essai le met à faux pour
//           ne jamais prendre le clavier de Nicolas) ; executeur, null par défaut : une fonction qui reçoit l'action à
//           la place de son exécution réelle (coques d'essai) ; fenetree, vrai par défaut : faux, aucune fenêtre n'est
//           construite ; source, null par défaut : un tableau de fenêtres qui remplace Applications.toplevels() (coques
//           d'essai ; chaque fenêtre peut y porter taille, [largeur, hauteur], à la place du relevé de Hyprland).
//           IPC « selecteur » : avancer, valider, annuler, touche, etat. Le raccourci global dunei:selecteur, qui
//           appelle avancer(1), est déclaré par la coque de session (coque/shell.qml) : le protocole des raccourcis
//           globaux refuse deux clients sur la même paire appid:nom, et une coque d'essai qui chargerait ce singleton
//           à côté de la coque installée ferait tomber l'une des deux.
// Sorties : famille ; montre (vrai après le délai) ; liste (fenêtres figées à l'ouverture) ; index (la sélection) ;
//           choisie (la fenêtre sous la sélection, ou null) ; largeurs (de chaque vignette, selecteur.js largeur) ;
//           present (ouvert, ou fenêtre encore en sortie) ; sortant ; differee (l'action en attente du retrait du
//           calque, ou null) ; ecran (figé à l'ouverture) ; fenetre (la FenetreSelecteur ouverte, ou null).
// Erreurs : aucune ; une fenêtre qui ne peut être construite est journalisée et le sélecteur se referme ; moins de
//           deux fenêtres, avancer ne fait rien.
// Dépendances : Quickshell (Singleton, LazyLoader), Quickshell.Io (IpcHandler), Quickshell.Hyprland (focusedMonitor,
//           toplevels, dispatch, rawEvent), QtQuick (Timer), Theme (selecteur, motion.delays), Overlays, Applications,
//           FenetreSelecteur.qml, selecteur.js, applications.js (commandeFocus).
Singleton {
    id: selecteur

    property bool ouvert: false
    readonly property string famille: "attention"
    property bool montre: false
    property var liste: []
    property int index: 0
    property bool clavierExclusif: true
    property var executeur: null
    property bool fenetree: true
    property var source: null
    // Vrai entre la fermeture et la fin du fondu de sortie de la fenêtre ; la fenêtre reste chargée jusque-là.
    property bool sortant: false
    readonly property bool present: ouvert || sortant
    // Action choisie qui attend le retrait du calque du sélecteur par le compositeur (voir executer).
    property var differee: null
    readonly property var fenetre: chargeur.item?.fenetre ?? null
    readonly property var choisie: liste[index] ?? null
    readonly property var largeurs: liste.map(f => {
        const t = taille(f)
        return Theme.selecteur ? Logique.largeur(t[0], t[1], Theme.selecteur) : 0
    })

    // Écran du moniteur focalisé, suivi en continu, et écran de la fenêtre, figé à l'ouverture.
    readonly property var ecranFocalise: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name)
        ?? Quickshell.screens[0]
    property var ecran: null

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
    // Dépendances : liste, index, ouvert, releve, Logique (fenetres, avancer).
    function avancer(pas: int) {
        if (ouvert) { index = Logique.avancer(index, liste.length, pas); return }
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
    // Dépendances : ouvert, choisie, releve, executer.
    function valider() {
        if (!ouvert) return
        const f = choisie
        if (f && releve().some(x => x.adresse === f.adresse)) executer({ genre: "amener", cible: f.adresse })
        else ouvert = false
    }

    // annuler — ferme le sélecteur sans rien amener (Échap, clic sur le voile). Entrées : aucune. Sortie : aucune.
    // Erreurs : aucune. Dépendances : ouvert.
    function annuler() { ouvert = false }

    // touche — entrée clavier unique du sélecteur, appelée par le cadre et par l'IPC des essais.
    // Entrées : nom, « ReleaseSuper » (relâchement de SUPER), « Backtab » (Maj + Tab), « Tab », « Escape » ou le nom
    // de toute autre touche ; superTenu, vrai si le modificateur SUPER accompagne l'événement. Sortie : aucune.
    // Le relâchement de SUPER valide ; Maj + Tab recule ; Tab, SUPER tenu, avance ; Échap annule ; toute autre touche
    // reçue sans SUPER tenu valide, en secours d'un relâchement perdu ; avec SUPER tenu, elle est ignorée.
    // Erreurs : aucune ; fermé, rien. Dépendances : ouvert, valider, avancer, annuler.
    function touche(nom: string, superTenu: bool) {
        if (!ouvert) return
        if (nom === "ReleaseSuper") valider()
        else if (nom === "Backtab") avancer(-1)
        else if (nom === "Escape") annuler()
        else if (nom === "Tab" && superTenu) avancer(1)
        else if (!superTenu) valider()
    }

    // sortieFinie — appelée par la fenêtre quand son fondu de sortie est posé : la fenêtre est déchargée (son calque
    // retiré, ce qui fait partir l'action en attente) et montre retombe. Entrées : aucune. Sortie : aucune ; sans effet
    // si le sélecteur a été rouvert entre-temps. Erreurs : aucune. Dépendances : ouvert, sortant, montre.
    function sortieFinie() {
        if (ouvert || !sortant) return
        sortant = false
        montre = false
    }

    // executer — ferme le sélecteur et fait exécuter l'action : aussitôt sans fenêtre (fenetree faux, ou fenêtre non
    // construite), sinon une fois le calque retiré par le compositeur (differee, voir la connexion à Hyprland).
    // Entrée : action, {genre (« amener »), cible (adresse)}. Sortie : aucune. Erreurs : aucune.
    // Dépendances : fenetre, realiser, differee, garde, ouvert.
    function executer(action) {
        if (!fenetre) realiser(action)
        else { differee = action; garde.restart() }
        ouvert = false
    }

    // realiserDifferee — exécute l'action en attente, une seule fois, et jamais sous une attention ouverte (le
    // sélecteur rouvert, ou le lanceur ouvert entre-temps : c'est changer d'avis). Entrées : aucune. Sortie : aucune.
    // Erreurs : aucune ; sans action en attente, rien. Dépendances : differee, realiser, garde, Overlays.attention.
    function realiserDifferee() {
        const a = differee
        differee = null
        garde.stop()
        if (a && !Overlays.attention) realiser(a)
    }

    // realiser — exécute une action : amener donne le focus à la fenêtre, bureau compris. Entrée : action (voir
    // executer). Sortie : aucune. Erreurs : aucune ; un genre inconnu ne fait rien.
    // Dépendances : executeur, Hyprland.dispatch, Apps.commandeFocus.
    function realiser(action) {
        if (executeur) executeur(action)
        else if (action.genre === "amener") Hyprland.dispatch(Apps.commandeFocus(action.cible))
    }

    // Retrait du calque par le compositeur : l'action en attente part. Hyprland émet closelayer>>dunei-attention au
    // démappage du calque, après lui avoir retiré le clavier.
    Connections {
        target: Hyprland
        function onRawEvent(e) { if (selecteur.differee && e.name === "closelayer" && e.data === "dunei-attention") selecteur.realiserDifferee() }
    }
    // Garde : si l'événement de retrait ne vient pas (connexion à Hyprland perdue), l'action part quand même, au plus
    // une seconde après la fermeture ; ce délai technique, bien au-delà du fondu de sortie, n'est jamais atteint quand
    // le compositeur répond.
    Timer { id: garde; interval: 1000; onTriggered: selecteur.realiserDifferee() }

    // Délai d'affichage : un tap bref (relâchement avant lui) valide sans rien montrer.
    Timer { id: delai; interval: Theme.motion?.delays.selecteur ?? 0; onTriggered: if (selecteur.ouvert) selecteur.montre = true }

    // onOuvertChanged — à l'ouverture, fige l'écran (sauf si la fenêtre, encore en sortie, est reprise sur le sien),
    // annule l'action qui attendait le retrait du calque, cache la fenêtre jusqu'au délai et s'inscrit au registre des
    // attentions ; à la fermeture, arrête le délai, s'en retire et laisse la fenêtre jouer son fondu de sortie
    // (sortant). Entrées : aucune. Sortie : aucune. Erreurs : aucune.
    // Dépendances : ecranFocalise, Overlays, fenetre, differee, garde, delai, montre.
    onOuvertChanged: {
        if (ouvert) {
            if (!sortant) ecran = ecranFocalise
            sortant = false
            differee = null
            garde.stop()
            montre = false
            delai.restart()
            Overlays.ouvrir(selecteur)
        } else {
            delai.stop()
            sortant = fenetre !== null
            if (!sortant) montre = false
            Overlays.fermer(selecteur)
        }
    }

    // La fenêtre vit dans FenetreSelecteur.qml, que ce porteur ne compile qu'à l'ouverture, comme le lanceur : un
    // fichier qui nomme PanelWindow ne se charge pas sous une plateforme sans dorsale de couches. Si la création
    // échoue, l'échec est journalisé et le sélecteur se referme.
    LazyLoader {
        id: chargeur
        active: selecteur.present && selecteur.fenetree
        component: Component {
            QtObject {
                id: porteur
                readonly property Component composant: Qt.createComponent("FenetreSelecteur.qml")
                readonly property var fenetre: composant.status === Component.Ready ? composant.createObject(porteur) : null

                Component.onCompleted: {
                    if (fenetre) return
                    console.warn("Sélecteur : fenêtre non construite. " + composant.errorString())
                    Qt.callLater(() => selecteur.ouvert = false)
                }
            }
        }
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
        // Sortie : texte. Erreurs : aucune. Dépendances : selecteur.
        function etat(): string {
            return JSON.stringify({ ouvert: selecteur.ouvert, montre: selecteur.montre, index: selecteur.index,
                adresses: selecteur.liste.map(f => f.adresse), fenetre: selecteur.fenetre !== null,
                sortant: selecteur.sortant, differee: selecteur.differee !== null })
        }
    }
}
