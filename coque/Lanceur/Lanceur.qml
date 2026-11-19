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
// Rôle : tient l'état du lanceur (ouvert, saisie, sélection, confirmation en attente), interroge les sources à chaque
// changement de la saisie, du calcul, des états des commandes, des fenêtres ou du relevé d'usage (liaisons de
// accueil et resultats), et exécute l'action choisie avant de se fermer. C'est une attention du registre Overlays
// (famille « attention ») : l'ouvrir ferme l'attention déjà ouverte, et une autre qui s'ouvre le ferme. Sa fenêtre,
// FenetreLanceur, n'existe que pendant l'ouverture (LazyLoader) : fermé, le lanceur ne garde en mémoire que son relevé
// d'usage. Le clavier est traité ici, par touche(), qu'appellent la fenêtre et l'IPC des essais : un seul chemin.
// Entrées : ouvert ; saisie ; clavierExclusif, vrai par défaut, que la fenêtre applique (une coque d'essai le met à
//           faux pour ne jamais prendre le clavier de Nicolas) ; executeur, null par défaut : une fonction qui reçoit
//           l'action à la place de son exécution réelle (coques d'essai). IPC « lanceur » : basculer, ouvrir, fermer,
//           etat, taper, touche.
// Sorties : vue (« accueil » ou « scission »), accueil ({medaillons, puces}), resultats (classés), sel ({zone, rang,
//           index}, forme de lanceur.js deplacer), choisi (le résultat de la ligne retenue), elements (ceux de son
//           aperçu), confirmation, libellePrincipal, ecran (figé à l'ouverture), fenetre (la FenetreLanceur ouverte,
//           ou null), cotes (mesures de la maquette v3 rapportées aux jetons), famille.
// Erreurs : aucune ; une fenêtre qui ne peut être construite est journalisée et le lanceur se referme ; une action
//           inconnue ne fait que fermer.
// Dépendances : Quickshell (Singleton, LazyLoader, execDetached, clipboardText, iconPath), Quickshell.Io
//           (IpcHandler), Quickshell.Hyprland (focusedMonitor, dispatch), Theme, Overlays, Applications, Sources,
//           Calcul, MemoireLanceur, FenetreLanceur.qml, lanceur.js, applications.js.
Singleton {
    id: lanceur

    property bool ouvert: false
    readonly property string famille: "attention"
    property string saisie: ""
    property var sel: ({ zone: "medaillons", rang: 0, index: 0 })
    property bool confirmation: false
    property bool clavierExclusif: true
    property var executeur: null
    readonly property alias sources: sources
    readonly property var fenetre: chargeur.item?.fenetre ?? null

    readonly property string vue: saisie === "" ? "accueil" : "scission"
    readonly property var accueil: ouvert ? sources.accueil() : ({ medaillons: [], puces: [] })
    readonly property var resultats: ouvert && saisie !== "" ? Logique.classer(sources.chercher(saisie), sources.poids) : []
    readonly property var choisi: sel.zone === "liste" || sel.zone === "apercu" ? resultats[sel.rang] : undefined
    readonly property var elements: Logique.elementsApercu(choisi)
    readonly property string libellePrincipal: confirmation ? "Confirmer" : choisi?.principale?.libelle ?? ""

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

    // icone — source d'une icône en couleur (application, fenêtre, action de bureau).
    // Entrée : nom, nom freedesktop ou chemin absolu. Sortie : url de l'image, l'icône d'exécutable du thème à défaut, « » sans nom.
    // Erreurs : aucune. Dépendances : Quickshell.iconPath.
    function icone(nom) {
        return !nom ? "" : nom.startsWith("/") ? "file://" + nom : Quickshell.iconPath(nom, "application-x-executable")
    }

    // fenetreDe — fenêtre des sources désignée par son adresse. Entrée : adresse. Sortie : {adresse, classe, titre,
    // bureau, historique} ou undefined si elle a disparu. Erreurs : aucune. Dépendances : sources.fenetres.
    function fenetreDe(adresse) { return sources.fenetres.find(f => f.adresse === adresse) }

    // dispo — nombre d'éléments de chaque zone, pour Logique.deplacer. Entrées : aucune. Sortie : {medaillons, puces,
    // lignes, apercu}. Erreurs : aucune. Dépendances : accueil, resultats, elements.
    function dispo() {
        return { medaillons: accueil.medaillons.length, puces: accueil.puces.length, lignes: resultats.length,
            apercu: elements.length }
    }

    // borner — garde la sélection dans ce qui existe quand l'accueil ou les résultats changent (fenêtre fermée,
    // réponse du calcul) : la ligne retenue est bornée à la dernière, et une sélection d'aperçu qui ne tient plus
    // revient à la liste. Entrées : aucune. Sortie : aucune ; sel est remplacée si elle sort des bornes.
    // Erreurs : aucune. Dépendances : sel, accueil, resultats, Logique.elementsApercu.
    function borner() {
        const z = sel.zone, n = z === "medaillons" ? accueil.medaillons.length : z === "puces" ? accueil.puces.length
            : resultats.length
        const i = Math.max(0, Math.min(n - 1, z === "apercu" ? sel.rang : sel.index))
        if (z === "apercu" && (i !== sel.rang || sel.index >= Logique.elementsApercu(resultats[i]).length))
            sel = { zone: "liste", rang: i, index: i }
        else if (z !== "apercu" && i !== sel.index) sel = { zone: z, rang: z === "liste" ? i : sel.rang, index: i }
    }

    // touche — traite une touche du lanceur. Entrée : nom, « escape », « return », « backspace », « up », « down »,
    // « left », « right », « tab », « shift+tab », « ctrl+j » ou « ctrl+k ». Sortie : vrai si la touche est prise
    // (← et → sont laissées au champ dans la liste). Échap ramène l'aperçu à la liste, sinon vide la saisie, sinon
    // ferme ; toute touche de déplacement annule une confirmation en attente. Erreurs : aucune.
    // Dépendances : Logique.deplacer, dispo, entree, fermer.
    function touche(nom) {
        if (nom === "escape") {
            if (sel.zone === "apercu") sel = Logique.deplacer(sel, nom, dispo())
            else if (saisie !== "") saisie = ""
            else fermer()
            return true
        }
        if (nom === "return") { entree(); return true }
        if (nom === "backspace") { saisie = saisie.slice(0, -1); return true }
        if (!["up", "down", "left", "right", "tab", "shift+tab", "ctrl+j", "ctrl+k"].includes(nom)) return false
        if ((nom === "left" || nom === "right") && sel.zone === "liste") return false
        confirmation = false
        sel = Logique.deplacer(sel, nom, dispo())
        return true
    }

    // choix — résultat et action désignés par la sélection. Entrées : aucune. Sortie : {resultat, action, cle} ou
    // null si rien n'est choisi ; la clé notée est celle du résultat, ou « fen:<adresse> » pour une vignette.
    // Erreurs : aucune. Dépendances : sel, accueil, resultats, elements.
    function choix() {
        const z = sel.zone
        const r = z === "medaillons" ? accueil.medaillons[sel.index] : z === "puces" ? accueil.puces[sel.index] : choisi
        const e = z === "apercu" ? elements[sel.index] : null
        if (!r || (z === "apercu" && !e)) return null
        return { resultat: r, action: e ? e.action : r.principale, cle: e?.genre === "vignette" ? "fen:" + e.adresse : r.cle }
    }

    // entree — Entrée : exécute ce qui est choisi ; une action à confirmer demande d'abord un second Entrée.
    // Entrées : aucune. Sortie : aucune. Erreurs : aucune ; sans choix, rien. Dépendances : choix, executer.
    function entree() {
        const c = choix()
        if (!c) return
        if (c.action.confirmer && !confirmation) { confirmation = true; return }
        executer(c.action, c.cle)
    }

    // choisir — sélectionne un élément au pointeur, puis l'exécute. Entrées : zone, index (rang de la liste pour
    // « apercu », qui garde sa ligne). Sortie : aucune. Erreurs : aucune. Dépendances : sel, entree.
    function choisir(zone, index) {
        if (zone !== sel.zone || index !== sel.index) confirmation = false
        sel = { zone, rang: zone === "liste" ? index : sel.rang, index }
        entree()
    }

    // executer — exécute une action, note l'usage et ferme le lanceur. Le texte copié l'est avant la fermeture : sous
    // Wayland, le presse-papiers n'est écrit que depuis une fenêtre qui a le focus.
    // Entrées : action, {libelle, genre (« amener », « lancer », « action », « commande », « copier »), cible} ; cle,
    // la clé notée au relevé d'usage (facultative). Sortie : aucune. Erreurs : aucune ; une commande inconnue ne lance
    // rien. Dépendances : memoire, executeur, Hyprland.dispatch, Apps.commandeFocus, Applications (amenerOuLancer,
    // lancerAction), sources (entrees, commande, ipc), Quickshell (execDetached, clipboardText).
    function executer(action, cle) {
        if (cle) memoire.noter(cle)
        if (executeur) executeur(action)
        else if (action.genre === "amener") Hyprland.dispatch(Apps.commandeFocus(action.cible))
        else if (action.genre === "lancer")
            Applications.amenerOuLancer(Array.from(sources.entrees).find(e => e.id === action.cible) ?? { id: action.cible })
        else if (action.genre === "action") Applications.lancerAction(action.cible)
        else if (action.genre === "copier") Quickshell.clipboardText = action.cible
        else if (action.genre === "commande") {
            const k = sources.commande(action.cible)
            if (k?.ipc) Quickshell.execDetached(sources.ipc.concat(k.ipc))
            else if (k?.commande) Quickshell.execDetached(k.commande)
        }
        ouvert = false
    }

    // onOuvertChanged — à l'ouverture, fige l'écran, repart d'une saisie vide sur l'accueil, relit les états des
    // commandes et s'inscrit au registre des attentions ; à la fermeture, vide la saisie (la prochaine fenêtre naît
    // sur l'accueil, sans passer par la scission) et s'en retire. Entrées : aucune. Sortie :
    // aucune. Erreurs : aucune. Dépendances : ecranFocalise, sources.rafraichir, Overlays.
    onOuvertChanged: {
        if (ouvert) {
            ecran = ecranFocalise
            saisie = ""
            sel = { zone: "medaillons", rang: 0, index: 0 }
            confirmation = false
            sources.rafraichir()
            Overlays.ouvrir(lanceur)
        } else {
            saisie = ""
            Overlays.fermer(lanceur)
        }
    }

    // onSaisieChanged — soumet la saisie au calcul et pose la sélection en tête de la vue. Entrées : aucune.
    // Sortie : aucune. Erreurs : aucune. Dépendances : calcul.demander.
    onSaisieChanged: {
        calcul.demander(saisie)
        confirmation = false
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
        active: lanceur.ouvert
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
        // de l'accueil), apercu (genres de ses éléments), principal (libellé du bouton principal), confirmation,
        // fenetre (vrai si elle existe), largeur et hauteur du cadre, vignettes (affichées dans l'aperçu).
        // Sortie : texte. Erreurs : aucune. Dépendances : lanceur, fenetre.
        function etat(): string {
            const f = lanceur.fenetre
            return JSON.stringify({ ouvert: lanceur.ouvert, saisie: lanceur.saisie, vue: lanceur.vue, sel: lanceur.sel,
                cles: lanceur.resultats.map(r => r.cle), medaillons: lanceur.accueil.medaillons.map(r => r.cle),
                puces: lanceur.accueil.puces.map(r => r.cle), apercu: lanceur.elements.map(e => e.genre),
                principal: lanceur.libellePrincipal, confirmation: lanceur.confirmation, fenetre: f !== null,
                largeur: f?.cadre.width ?? 0, hauteur: f?.cadre.height ?? 0, vignettes: f?.vignettes ?? 0 })
        }
    }
}
