pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../Theme"
import "../Composants"
import "../Applications"
import "lanceur.js" as Logique
import "../Applications/applications.js" as Apps

// Lanceur — contrôleur unique du lanceur d'applications (L2-16) : état, clavier, exécution et IPC.
// Rôle : tient l'état du lanceur (ouvert, saisie, sélection), interroge les sources à chaque
// changement de la saisie, du calcul, des états des commandes, des fenêtres ou du relevé d'usage (liaisons de
// accueil et resultats), et exécute l'action choisie avant de se fermer. C'est une attention du registre Overlays
// (famille « attention ») : l'ouvrir ferme l'attention déjà ouverte, et une autre qui s'ouvre le ferme. Sa fenêtre,
// FenetreLanceur, n'existe que pendant l'ouverture et son fondu de sortie (LazyLoader, present) : fermé, le lanceur ne
// garde en mémoire que son relevé d'usage. Le clavier est traité ici, par touche(), qu'appellent la fenêtre et l'IPC
// des essais : un seul chemin. Une action choisie n'est exécutée qu'une fois le calque du lanceur retiré par le
// compositeur (événement closelayer de dunei-attention), à la fin du fondu de sortie : c'est à ce retrait que Hyprland
// rend le clavier à la fenêtre précédente, et une surface de la coque ouverte avant lui (galerie) perdait aussitôt le
// clavier qu'elle venait de prendre (recette 2). La copie fait exception : sous Wayland, le presse-papiers ne s'écrit
// que depuis une fenêtre qui a le focus, elle se fait donc avant la fermeture.
// Entrées : ouvert ; saisie ; clavierExclusif, vrai par défaut, que la fenêtre applique (une coque d'essai le met à
//           faux pour ne jamais prendre le clavier de Nicolas) ; executeur, null par défaut : une fonction qui reçoit
//           l'action à la place de son exécution réelle (coques d'essai) ; fenetree, vrai par défaut : faux,
//           aucune fenêtre n'est construite (coque d'essai hors écran, qui pose elle-même un CadreLanceur).
//           IPC « lanceur » : basculer, ouvrir, fermer, etat, taper, touche.
// Sorties : present (ouvert, ou fenêtre encore en sortie), sortant, differee (l'action en attente du retrait du
//           calque, ou null), vue (« accueil » ou « scission »), accueil ({medaillons, puces}), resultats (classés),
//           sel ({zone, rang, index, rangee}, forme de lanceur.js deplacer ; rangee pour l'aperçu seulement),
//           choisi (le résultat de la ligne retenue), elements (ceux de son aperçu), libellePrincipal,
//           ecran (figé à l'ouverture), fenetre (la FenetreLanceur ouverte, ou null), cotes (mesures de la maquette
//           v3 rapportées aux jetons), famille.
// Erreurs : aucune ; une fenêtre qui ne peut être construite est journalisée et le lanceur se referme ; une action
//           inconnue ne fait que fermer.
// Dépendances : Quickshell (Singleton, LazyLoader, execDetached, clipboardText), Quickshell.Io
//           (IpcHandler), Quickshell.Hyprland (focusedMonitor, dispatch, rawEvent), QtQuick (Timer), Theme, Overlays, Applications, Sources,
//           Calcul, MemoireLanceur, FenetreLanceur.qml, lanceur.js, applications.js.
Singleton {
    id: lanceur

    property bool ouvert: false
    readonly property string famille: "attention"
    property string saisie: ""
    property var sel: ({ zone: "medaillons", rang: 0, index: 0 })
    property bool clavierExclusif: true
    property var executeur: null
    property bool fenetree: true
    // Vrai entre la fermeture et la fin du fondu de sortie de la fenêtre ; la fenêtre reste chargée jusque-là.
    property bool sortant: false
    readonly property bool present: ouvert || sortant
    // Action choisie qui attend le retrait du calque du lanceur par le compositeur (voir executer).
    property var differee: null
    readonly property alias sources: sources
    readonly property var fenetre: chargeur.item?.fenetre ?? null

    readonly property string vue: saisie === "" ? "accueil" : "scission"
    readonly property var accueil: present ? sources.accueil() : ({ medaillons: [], puces: [] })
    readonly property var resultats: present && saisie !== "" ? Logique.classer(Logique.filtrer(sources.chercher(saisie)), sources.poids) : []
    readonly property var choisi: sel.zone === "liste" || sel.zone === "apercu" ? resultats[sel.rang] : undefined
    readonly property var elements: Logique.elementsApercu(choisi)

    // boutons — actions des boutons de l'aperçu de la ligne retenue. Entrées : aucune. Sortie : tableau d'actions.
    // Erreurs : aucune. Dépendances : elements.
    function boutons() { return elements.filter(e => e.genre === "bouton").map(e => e.action) }
    readonly property string libellePrincipal: choisi?.principale?.libelle ?? ""

    // Mesures de la maquette v3, rapportées aux jetons les plus proches ; celles qu'aucun jeton ne porte (tailles du
    // cadre, colonne de la liste, tuile) sont écrites ici, une fois.
    readonly property var cotes: ({
        accueil: Qt.size(700, 330), scission: Qt.size(900, 470),
        rayonAccueil: 2 * (Theme.radius?.window ?? 0), rayonScission: Theme.radius?.window ?? 0,
        retrait: Theme.space?.scale[2] ?? 0, champ: Theme.space?.scale[6] ?? 0,
        liste: 340, ligne: Theme.reglages?.row ?? 0, tuile: 92,
        medaillonAccueil: Theme.reglages?.rowLead ?? 0, medaillonApercu: Theme.space?.scale[7] ?? 0,
        resultat: Theme.space?.scale[7] ?? 0
    })

    // Écran du moniteur focalisé, suivi en continu (voir Overlay), et écran de la fenêtre, figé à l'ouverture.
    readonly property var ecranFocalise: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name)
        ?? Quickshell.screens[0]
    property var ecran: null

    // basculer — ouvre le lanceur fermé, ferme le lanceur ouvert. Entrées : aucune. Sortie : aucune.
    // Erreurs : aucune. Dépendances : ouvert.
    function basculer() { ouvert = !ouvert }

    // fermer — ferme le lanceur. Entrées : aucune. Sortie : aucune. Erreurs : aucune. Dépendances : ouvert.
    function fermer() { ouvert = false }

    // sortieFinie — appelée par la fenêtre quand son fondu de sortie est posé : la fenêtre est déchargée (son calque
    // retiré, ce qui fait partir l'action en attente) et la saisie vidée, pour que la prochaine fenêtre naisse sur
    // l'accueil. Entrées : aucune. Sortie : aucune ; sans effet si le lanceur a été rouvert entre-temps. Erreurs : aucune.
    // Dépendances : ouvert, sortant, saisie.
    function sortieFinie() {
        if (ouvert || !sortant) return
        sortant = false
        saisie = ""
    }

    // fenetreDe — fenêtre des sources désignée par son adresse. Entrée : adresse. Sortie : {adresse, classe, titre,
    // bureau, historique} ou undefined si elle a disparu. Erreurs : aucune. Dépendances : sources.fenetres.
    function fenetreDe(adresse) { return sources.fenetres.find(f => f.adresse === adresse) }

    // compter — nombre d'éléments de l'aperçu d'un genre. Entrées : liste, éléments (Logique.elementsApercu) ; genre,
    // « bouton » ou « vignette ». Sortie : entier. Erreurs : aucune. Dépendances : aucune.
    function compter(liste, genre) { return liste.filter(e => e.genre === genre).length }

    // dispo — nombre d'éléments de chaque zone, pour Logique.deplacer. Entrées : aucune. Sortie : {medaillons, puces,
    // lignes, vignettes, boutons}, ces deux derniers pour l'aperçu de la ligne retenue. Erreurs : aucune.
    // Dépendances : accueil, resultats, elements, compter.
    function dispo() {
        return { medaillons: accueil.medaillons.length, puces: accueil.puces.length, lignes: resultats.length,
            vignettes: compter(elements, "vignette"), boutons: compter(elements, "bouton") }
    }

    // borner — garde la sélection dans ce qui existe quand l'accueil ou les résultats changent (fenêtre fermée,
    // réponse du calcul) : la ligne retenue est bornée à la dernière, et une sélection d'aperçu qui ne tient plus
    // revient à la liste. Entrées : aucune. Sortie : aucune ; sel est remplacée si elle sort des bornes.
    // Erreurs : aucune. Dépendances : sel, accueil, resultats, Logique.elementsApercu.
    function borner() {
        const z = sel.zone, n = z === "medaillons" ? accueil.medaillons.length : z === "puces" ? accueil.puces.length
            : resultats.length
        const i = Math.max(0, Math.min(n - 1, z === "apercu" ? sel.rang : sel.index))
        if (z === "apercu" && (i !== sel.rang || !Logique.elementApercu(Logique.elementsApercu(resultats[i]), sel)))
            sel = { zone: "liste", rang: i, index: i }
        else if (z !== "apercu" && i !== sel.index) sel = { zone: z, rang: z === "liste" ? i : sel.rang, index: i }
    }

    // touche — traite une touche du lanceur. Entrée : nom, « escape », « return », « ctrl+return », « backspace »,
    // « up », « down », « left », « right », « tab », « shift+tab », « ctrl+j » ou « ctrl+k ». Sortie : vrai si la
    // touche est prise (← est laissée au champ dans la liste ; → y entre dans l'aperçu, comme Tab). Échap ramène
    // l'aperçu à la liste, sinon vide la saisie, sinon ferme ; Ctrl + Entrée lance une nouvelle instance de
    // l'application retenue dans la liste. Erreurs : aucune.
    // Dépendances : Logique.deplacer, dispo, entree, nouvelleInstance, fermer.
    function touche(nom) {
        if (nom === "escape") {
            if (sel.zone === "apercu") sel = Logique.deplacer(sel, nom, dispo())
            else if (saisie !== "") saisie = ""
            else fermer()
            return true
        }
        if (nom === "return") { entree(); return true }
        if (nom === "ctrl+return") { nouvelleInstance(); return true }
        if (nom === "backspace") { saisie = saisie.slice(0, -1); return true }
        if (!["up", "down", "left", "right", "tab", "shift+tab", "ctrl+j", "ctrl+k"].includes(nom)) return false
        if (nom === "left" && sel.zone === "liste") return false
        sel = Logique.deplacer(sel, nom, dispo())
        return true
    }

    // choix — résultat et action désignés par la sélection. Entrées : aucune. Sortie : {resultat, action, cle} ou
    // null si rien n'est choisi ; la clé notée est celle du résultat, ou « fen:<adresse> » pour une vignette.
    // Erreurs : aucune. Dépendances : sel, accueil, resultats, elements.
    function choix() {
        const z = sel.zone
        const r = z === "medaillons" ? accueil.medaillons[sel.index] : z === "puces" ? accueil.puces[sel.index] : choisi
        const e = z === "apercu" ? Logique.elementApercu(elements, sel) : null
        if (!r || (z === "apercu" && !e)) return null
        return { resultat: r, action: e ? e.action : r.principale, cle: e?.genre === "vignette" ? "fen:" + e.adresse : r.cle }
    }

    // entree — Entrée : exécute ce qui est choisi ; les actions de session ouvrent le menu de déconnexion, qui s'arme seul.
    // Entrées : aucune. Sortie : aucune. Erreurs : aucune ; sans choix, rien. Dépendances : choix, executer.
    function entree() {
        const c = choix()
        if (!c) return
        executer(c.action, c.cle)
    }

    // nouvelleInstance — Ctrl + Entrée : lance une nouvelle instance de l'application de la ligne retenue (qu'elle ait
    // ou non des fenêtres), par le même chemin que « Nouvelle fenêtre », puis ferme. Entrées : aucune. Sortie : aucune.
    // Erreurs : aucune ; hors d'une ligne d'application de la liste, rien. Dépendances : sel, choisi, executer.
    function nouvelleInstance() {
        if (sel.zone === "liste" && choisi?.genre === "application")
            executer({ libelle: "Nouvelle fenêtre", genre: "nouvelle", cible: choisi.cle.slice(4) }, choisi.cle)
    }

    // choisir — sélectionne un élément au pointeur, puis l'exécute. Entrées : zone, index (dans la rangée pour
    // « apercu », qui garde sa ligne) ; rangee, « boutons » ou « vignettes » pour l'aperçu. Sortie : aucune.
    // Erreurs : aucune. Dépendances : sel, entree.
    function choisir(zone, index, rangee) {
        sel = zone === "apercu" ? { zone, rang: sel.rang, index, rangee } : { zone, rang: zone === "liste" ? index : sel.rang, index }
        entree()
    }

    // executer — note l'usage, ferme le lanceur et fait exécuter l'action : aussitôt pour une copie (sous Wayland, le
    // presse-papiers n'est écrit que depuis une fenêtre qui a le focus) ou sans fenêtre (coque d'essai hors écran) ;
    // sinon une fois le fondu de sortie fini et le calque du lanceur retiré par le compositeur (differee, voir la
    // connexion à Hyprland), pour que l'action trouve le clavier rendu, comme si elle partait de son raccourci.
    // Entrées : action, {libelle, genre (« amener », « lancer », « nouvelle », « action », « commande », « copier »),
    // cible} ; cle, la clé notée au relevé d'usage (facultative). Sortie : aucune. Erreurs : aucune.
    // Dépendances : memoire, fenetre, realiser, differee.
    function executer(action, cle) {
        if (cle) memoire.noter(cle)
        if (action.genre === "copier" || !fenetre) realiser(action)
        else { differee = action; garde.restart() }
        ouvert = false
    }

    // realiserDifferee — exécute l'action en attente, une seule fois, et jamais sous une attention ouverte : le lanceur
    // rouvert, ou le sélecteur de fenêtres ouvert pendant le retrait du calque (L2-17), c'est changer d'avis.
    // Entrées : aucune. Sortie : aucune. Erreurs : aucune ; sans action en attente, ou sous une attention ouverte, rien.
    // Dépendances : differee, realiser, garde, Overlays.attention.
    function realiserDifferee() {
        const a = differee
        differee = null
        garde.stop()
        if (a && !Overlays.attention) realiser(a)
    }

    // realiser — exécute une action. « nouvelle » lance toujours une nouvelle instance de l'entrée, sans amener.
    // Entrée : action (voir executer). Sortie : aucune. Erreurs : aucune ; une commande inconnue ne lance rien.
    // Dépendances : executeur, Hyprland.dispatch, Apps.commandeFocus, Applications (amenerOuLancer, lancerAction),
    // Apps.commandeLancement, sources (entrees, ligne), Quickshell (execDetached, clipboardText).
    function realiser(action) {
        if (executeur) executeur(action)
        else if (action.genre === "amener") Hyprland.dispatch(Apps.commandeFocus(action.cible))
        else if (action.genre === "lancer")
            Applications.amenerOuLancer(Array.from(sources.entrees).find(e => e.id === action.cible) ?? { id: action.cible })
        else if (action.genre === "nouvelle") Quickshell.execDetached(Apps.commandeLancement({ id: action.cible }))
        else if (action.genre === "action") Applications.lancerAction(action.cible)
        else if (action.genre === "copier") Quickshell.clipboardText = action.cible
        else if (action.genre === "commande") {
            const l = sources.ligne(action.cible)
            if (l) Quickshell.execDetached(l)
        }
    }

    // onRawEvent — retrait du calque par le compositeur : l'action en attente part. Hyprland émet
    // closelayer>>dunei-attention au démappage du calque, après lui avoir retiré le clavier.
    // Entrée : e, l'événement brut de Hyprland (name, data). Sortie : aucune. Erreurs : aucune ; sans action en attente
    // ou pour un autre événement, rien. Dépendances : Hyprland.rawEvent, differee, realiserDifferee.
    Connections {
        target: Hyprland
        function onRawEvent(e) { if (lanceur.differee && e.name === "closelayer" && e.data === "dunei-attention") lanceur.realiserDifferee() }
    }
    // onAttentionChanged — quand une autre attention que le lanceur s'ouvre (le sélecteur de fenêtres), l'action en
    // attente est abandonnée : c'est changer d'avis, et elle ne doit pas écraser le choix du nouveau geste en partant à
    // son tour au retrait du calque. Entrées : aucune. Sortie : differee remis à null. Erreurs : aucune ; sans autre
    // attention ouverte, rien. Dépendances : Overlays.attention, differee.
    Connections {
        target: Overlays
        function onAttentionChanged() { if (Overlays.attention && Overlays.attention !== lanceur) lanceur.differee = null }
    }
    // Garde : si l'événement de retrait ne vient pas (connexion à Hyprland perdue), l'action part quand même, au plus
    // une seconde après la fermeture ; ce délai technique, bien au-delà du fondu de sortie (201 ms au ressort overlay),
    // n'est jamais atteint quand le compositeur répond.
    Timer { id: garde; interval: 1000; onTriggered: lanceur.realiserDifferee() }

    // onOuvertChanged — à l'ouverture, fige l'écran (sauf si la fenêtre, encore en sortie, est reprise sur le sien),
    // annule l'action qui attendait le retrait du calque (rouvrir pendant la sortie, c'est changer d'avis), repart d'une
    // saisie vide sur l'accueil, relit les états des commandes et s'inscrit au registre des attentions ;
    // à la fermeture, s'en retire et laisse la fenêtre jouer son fondu de sortie (sortant) : la saisie n'est vidée qu'à
    // la fin de celui-ci (sortieFinie), sans quoi le cadre repasserait à l'accueil en s'effaçant ; sans fenêtre
    // (fenetree faux), la saisie est vidée aussitôt. Entrées : aucune. Sortie : aucune. Erreurs : aucune.
    // Dépendances : ecranFocalise, sources.rafraichir, Overlays, fenetre, differee, garde.
    onOuvertChanged: {
        if (ouvert) {
            if (!sortant) ecran = ecranFocalise
            sortant = false
            differee = null
            garde.stop()
            saisie = ""
            sel = { zone: "medaillons", rang: 0, index: 0 }
            sources.rafraichir()
            Overlays.ouvrir(lanceur)
        } else {
            sortant = fenetre !== null
            if (!sortant) saisie = ""
            Overlays.fermer(lanceur)
        }
    }

    // onSaisieChanged — soumet la saisie au calcul et pose la sélection en tête de la vue. Entrées : aucune.
    // Sortie : aucune. Erreurs : aucune. Dépendances : calcul.demander.
    onSaisieChanged: {
        calcul.demander(saisie)
        sel = saisie === "" ? { zone: "medaillons", rang: 0, index: 0 } : { zone: "liste", rang: 0, index: 0 }
    }
    // onResultatsChanged, onAccueilChanged — bornent la sélection quand ce qui est affiché change. Entrées : aucune.
    // Sortie : aucune. Erreurs : aucune. Dépendances : borner.
    onResultatsChanged: borner()
    onAccueilChanged: borner()

    MemoireLanceur { id: memoire }
    Calcul { id: calcul; actif: lanceur.ouvert }
    Sources {
        id: sources
        calcul: calcul
        poids: Logique.poids(memoire.usage, Date.now())
    }

    // La fenêtre vit dans FenetreLanceur.qml, que ce porteur ne compile qu'à l'ouverture (comme Overlay le fait de
    // FenetreAttention) : un fichier qui nomme PanelWindow ne se charge pas sous une plateforme sans dorsale de couches.
    // Si la création échoue, l'échec est journalisé et le lanceur se referme.
    LazyLoader {
        id: chargeur
        active: lanceur.present && lanceur.fenetree
        component: Component {
            QtObject {
                id: porteur
                readonly property Component composant: Qt.createComponent("FenetreLanceur.qml")
                readonly property var fenetre: composant.status === Component.Ready ? composant.createObject(porteur) : null

                Component.onCompleted: {
                    if (fenetre) return
                    console.warn("Lanceur : fenêtre non construite. " + composant.errorString())
                    Qt.callLater(() => lanceur.ouvert = false)
                }
            }
        }
    }

    IpcHandler {
        target: "lanceur"

        // basculer, ouvrir, fermer — ouvrent ou ferment le lanceur (SUPER + R appelle basculer). Sortie : aucune.
        function basculer(): void { lanceur.basculer() }
        function ouvrir(): void { lanceur.ouvert = true }
        function fermer(): void { lanceur.ouvert = false }

        // taper — ajoute du texte à la saisie d'un lanceur ouvert (essais). Entrée : texte. Sortie : aucune.
        function taper(texte: string): void { if (lanceur.ouvert) lanceur.saisie += texte }

        // touche — presse une touche dans un lanceur ouvert (essais). Entrée : nom (voir touche). Sortie : aucune.
        function touche(nom: string): void { if (lanceur.ouvert) lanceur.touche(nom) }

        // etat — état du lanceur en JSON : ouvert, saisie, vue, sel, cles (des résultats), medaillons et puces (clés
        // de l'accueil), apercu (genres de ses éléments), principal (libellé du bouton principal),
        // fenetre (vrai si elle existe), sortant (fenêtre en sortie), differee (vrai si une action attend le retrait du
        // calque), boutons (libellés des actions de l'aperçu),
        // largeur et hauteur du cadre, vignettes (affichées dans l'aperçu), liste (repères de la plaque et de la ligne
        // retenue, voir Liste.reperes).
        // Sortie : texte. Erreurs : aucune. Dépendances : lanceur, fenetre.
        function etat(): string {
            const f = lanceur.fenetre
            return JSON.stringify({ ouvert: lanceur.ouvert, saisie: lanceur.saisie, vue: lanceur.vue, sel: lanceur.sel,
                cles: lanceur.resultats.map(r => r.cle), medaillons: lanceur.accueil.medaillons.map(r => r.cle),
                puces: lanceur.accueil.puces.map(r => r.cle), apercu: lanceur.elements.map(e => e.genre),
                principal: lanceur.libellePrincipal, fenetre: f !== null,
                sortant: lanceur.sortant, differee: lanceur.differee !== null, boutons: lanceur.boutons().map(a => a.libelle),
                largeur: f?.cadre.width ?? 0, hauteur: f?.cadre.height ?? 0, vignettes: f?.vignettes ?? 0,
                liste: f?.cadre.reperes() ?? null })
        }
    }
}
