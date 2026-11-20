import QtQuick
import Quickshell
import Quickshell.Io
import "../Applications"
import "../Parametres"
import "lanceur.js" as Logique
import "calcul.js" as CalculLogique
import "../Applications/applications.js" as Apps

// Sources — ce que le lanceur sait trouver, rendu en résultats d'une même forme (L2-16).
// Rôle : transforme une saisie en résultats non classés (applications, leurs fenêtres, actions de bureau, commandes
// DuneI, pages de Paramètres, calcul) et compose l'accueil (six médaillons, trois puces). Le classement reste à
// lanceur.js (classer). Forme d'un résultat : {cle, genre, titre, sousTitre, icone, type, retrait, app, pertinence,
// principale, secondaires, apercu} ; une action : {libelle, genre, cible, confirmer}.
// Entrées : entrees (entrées de bureau, DesktopEntries par défaut) ; fenetres ({adresse, classe, titre, bureau,
// historique}, Applications.toplevels() sous Wayland) ; poids (usage, lanceur.js poids) ; calcul (un Calcul, ou
// null) ; cheminRoles (roles.lua) ; ipc (préfixe d'appel IPC de la coque). Les coques d'essai les remplacent.
// Sorties : commandes (déclarées puis pages de Paramètres), etats ({id: état lisible}) ; fonctions chercher,
// accueil, commande, rafraichir.
// Erreurs : aucune ; un commandes.json ou un roles.lua illisible laisse sa liste vide.
// Dépendances : Quickshell (DesktopEntries, env), Quickshell.Io (FileView, Process, StdioCollector),
// Applications (toplevels, applications.js), Registre (Parametres),
// lanceur.js, calcul.js, commandes.json ; qs à l'exécution pour lire les états.
Scope {
    id: sources

    property var entrees: DesktopEntries.applications.values
    property var fenetres: Quickshell.env("WAYLAND_DISPLAY") ? Applications.toplevels() : []
    property var poids: ({})
    property var calcul: null
    property string cheminRoles: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config")
        + "/hypr/donnees/roles.lua"
    property var ipc: ["qs", "ipc", "-c", "dunei", "call"]

    property var etats: ({})
    property var declarees: []
    property var motsRoles: []
    // Pages de Paramètres, en commandes : leur libellé, leur groupe et leur index de recherche servent de mots-clés.
    readonly property var commandes: declarees.concat(Registre.pages.map(p => ({
        id: "parametres-" + p.id, libelle: "Paramètres › " + p.libelle,
        motsCles: [p.libelle, p.groupe].concat(...p.index.map(i => [i.libelle].concat(i.motsCles))),
        icone: p.glyphe, ipc: ["parametres", "ouvrir", p.id], commande: null, etat: null, confirmer: false })))

    // action — une action de résultat.
    // Entrées : libelle, genre (« amener », « lancer », « nouvelle », « action », « commande », « copier »), cible,
    // confirmer.
    // Sortie : {libelle, genre, cible, confirmer}. Erreurs : aucune. Dépendances : aucune.
    function action(libelle, genre, cible, confirmer) { return { libelle, genre, cible, confirmer: !!confirmer } }

    // ouvertes — fenêtres d'une application, de la plus récemment utilisée à la plus ancienne.
    // Entrée : e, entrée de bureau. Sortie : tableau de fenêtres. Erreurs : aucune.
    // Dépendances : fenetres, Apps.fenetres.
    function ouvertes(e) {
        return Apps.fenetres(e, fenetres).map(a => fenetres.find(f => f.adresse === a))
    }

    // application — résultat d'une application : ouverte, elle s'amène sur sa fenêtre la plus récente et porte
    // « n fenêtres » ; fermée, elle se lance. Ses secondaires sont, si elle a une fenêtre et ne déclare pas d'action
    // « new-window » (qui tient alors ce rôle), « Nouvelle fenêtre » (genre « nouvelle » : une nouvelle instance de son
    // entrée, même chemin que « Lancer » mais sans amener), puis ses actions de bureau.
    // Entrées : e, entrée de bureau ; pertinence ; ouv, ses fenêtres (ouvertes). Sortie : le résultat.
    // Erreurs : aucune. Dépendances : action.
    function application(e, pertinence, ouv) {
        const n = ouv.length
        return { cle: "app:" + e.id, genre: "application", titre: e.name, sousTitre: e.comment || e.genericName || "",
            icone: e.icon, type: n === 0 ? "Application" : n === 1 ? "1 fenêtre" : n + " fenêtres", retrait: false,
            app: "", pertinence,
            principale: n ? action("Amener", "amener", ouv[0].adresse) : action("Lancer", "lancer", e.id),
            secondaires: (n && !Array.from(e.actions || []).some(a => a.id === "new-window")
                ? [action("Nouvelle fenêtre", "nouvelle", e.id)] : [])
                .concat(Array.from(e.actions || []).map(a => action(a.name, "action", e.id + ":" + a.id))),
            apercu: { fenetres: ouv.map(f => f.adresse) } }
    }

    // fenetre — résultat d'une fenêtre, rangée sous son application (type « bureau n ») ou isolée (« Fenêtre »).
    // Entrées : f, fenêtre ; e, son entrée de bureau ou null ; pertinence ; app, clé de l'application qui la range,
    // ou « » pour une fenêtre isolée. Sortie : le résultat. Erreurs : aucune. Dépendances : action.
    function fenetre(f, e, pertinence, app) {
        return { cle: "fen:" + f.adresse, genre: "fenetre", titre: f.titre, sousTitre: e ? e.name : f.classe,
            icone: e ? e.icon : f.classe, type: app ? "bureau " + f.bureau : "Fenêtre", retrait: !!app, app,
            pertinence, principale: action("Amener", "amener", f.adresse), secondaires: [],
            apercu: { fenetres: [f.adresse], bureau: f.bureau } }
    }

    // commandeResultat — résultat d'une commande DuneI, avec son état présent lu par rafraichir.
    // Entrées : c, commande ; pertinence. Sortie : le résultat (cible de la principale : l'id de la commande).
    // Erreurs : aucune. Dépendances : action, etats.
    function commandeResultat(c, pertinence) {
        return { cle: "cmd:" + c.id, genre: "commande", titre: c.libelle, sousTitre: "", icone: c.icone,
            type: "Commande", retrait: false, app: "", pertinence,
            principale: action("Exécuter", "commande", c.id, c.confirmer), secondaires: [],
            apercu: { etat: etats[c.id] || "" } }
    }

    // chercher — résultats d'une saisie, non classés.
    // Entrée : saisie. Sortie : tableau de résultats : le calcul si celui publié répond à cette saisie ; chaque
    // application qui correspond, suivie de ses fenêtres en retrait (une fenêtre déjà rangée sous une autre
    // application ne se répète pas) ; les actions de bureau visées ; les fenêtres
    // dont seul le titre correspond ; les commandes. Une saisie vide ne donne rien. Erreurs : aucune.
    // Dépendances : Logique (pertinence, score, actionVisee), CalculLogique (aEnvoyer, traduire), Apps.fenetres,
    // application, fenetre, commandeResultat.
    function chercher(saisie) {
        const r = [], prises = new Set(), c = calcul
        if (c && c.valeur && CalculLogique.aEnvoyer(saisie) && c.expression === CalculLogique.traduire(saisie))
            r.push({ cle: "calc", genre: "calcul", titre: c.valeur, sousTitre: c.expression,
                icone: "accessories-calculator", type: "Calcul", retrait: false, app: "", pertinence: 4,
                principale: action("Copier", "copier", c.valeur), secondaires: [],
                apercu: { expression: c.expression, valeur: c.valeur } })
        for (const e of Array.from(entrees)) {
            const p = Logique.pertinence([e.name, e.genericName].concat(Array.from(e.keywords || [])), saisie)
            if (p > 0) {
                const ouv = ouvertes(e)
                r.push(application(e, p, ouv))
                for (const f of ouv.filter(f => !prises.has(f.adresse))) {
                    prises.add(f.adresse)
                    r.push(fenetre(f, e, p, "app:" + e.id))
                }
            }
            for (const a of Array.from(e.actions || []))
                if (Logique.actionVisee(e.name, a.name, saisie))
                    r.push({ cle: "act:" + e.id + ":" + a.id, genre: "action", titre: a.name, sousTitre: e.name,
                        icone: a.icon || e.icon, type: "Action", retrait: false, app: "",
                        pertinence: Math.max(1, Logique.score(a.name, saisie)),
                        principale: action(a.name, "action", e.id + ":" + a.id), secondaires: [], apercu: {} })
        }
        for (const f of fenetres) {
            const p = prises.has(f.adresse) ? 0 : Logique.score(f.titre, saisie)
            if (p > 0) r.push(fenetre(f, Array.from(entrees).find(e => Apps.fenetres(e, [f]).length > 0) || null, p, ""))
        }
        for (const k of commandes) {
            const p = Logique.pertinence([k.libelle].concat(k.motsCles), saisie)
            if (p > 0) r.push(commandeResultat(k, p))
        }
        return r
    }

    // accueil — ce que montre le lanceur sans saisie.
    // Entrées : aucune. Sortie : {medaillons, puces} : six applications au plus (usage, puis rôles navigateur, terminal et fichiers de roles.lua, puis
    // ordre alphabétique) et trois commandes déclarées (usage, puis ordre du fichier). Erreurs : aucune.
    // Dépendances : Logique.frequentes, Apps.resoudre, entrees, poids, motsRoles, declarees, application,
    // commandeResultat.
    function accueil() {
        const e = Array.from(entrees)
        const roles = motsRoles.map(m => Apps.resoudre(m, m, e)).filter(x => x).map(x => "app:" + x.id)
        const medaillons = Logique.frequentes(e.map(x => ({ cle: "app:" + x.id, titre: x.name })), poids, roles, 6)
            .map(cle => { const x = e.find(y => "app:" + y.id === cle); return application(x, 0, ouvertes(x)) })
        const cles = declarees.map(k => "cmd:" + k.id)
        const puces = Logique.frequentes(declarees.map(k => ({ cle: "cmd:" + k.id, titre: k.libelle })), poids, cles, 3)
            .map(cle => commandeResultat(declarees[cles.indexOf(cle)], 0))
        return { medaillons, puces }
    }

    // commande — commande désignée par son id, pour l'exécuter.
    // Entrée : id. Sortie : la commande ({id, libelle, motsCles, icone, ipc, commande, etat, confirmer}) ou undefined.
    // Erreurs : aucune. Dépendances : commandes.
    function commande(id) { return commandes.find(k => k.id === id) }

    // rafraichir — relit, par IPC, l'état présent de chaque commande qui en déclare un (à l'ouverture du lanceur).
    // Entrées : aucune. Sortie : aucune ; chaque état relu est d'abord effacé, puis etats se met à jour à chaque
    // réponse (« true » → « Activé », « false » → « Désactivé », sinon le texte rendu). Erreurs : aucune ; un appel
    // qui échoue ou ne démarre pas laisse l'état vide. Dépendances : lecture, ipc, commandes, ecrireEtat.
    function rafraichir() {
        for (const k of commandes) if (k.etat) {
            ecrireEtat(k.id, "")
            lecture.createObject(sources, { cle: k.id, command: ipc.concat(k.etat) })
        }
    }

    // ecrireEtat — pose l'état présent d'une commande. Entrées : cle, id de la commande ; texte, réponse brute.
    // Sortie : aucune ; etats est remplacé (« true » → « Activé », « false » → « Désactivé », sinon le texte).
    // Erreurs : aucune. Dépendances : aucune.
    function ecrireEtat(cle, texte) {
        etats = Object.assign({}, etats, { [cle]: ({ "true": "Activé", "false": "Désactivé" })[texte] ?? texte })
    }

    // Lecteur d'état, un par commande et par rafraîchissement, détruit à sa sortie.
    Component {
        id: lecture
        Process {
            property string cle
            property bool demarre: false
            running: true
            stdout: StdioCollector { id: sortie }
            // onRunningChanged — retient le démarrage ; un processus qui s'arrête sans avoir démarré (qs introuvable)
            // n'émet pas exited et se détruit ici. Entrées : aucune. Sortie : aucune. Erreurs : aucune.
            // Dépendances : aucune.
            onRunningChanged: if (running) demarre = true; else if (!demarre) destroy()
            // onExited — pose l'état lu, vide si l'appel a échoué, puis détruit le lecteur.
            // Entrée : code, code de sortie de qs. Sortie : aucune. Erreurs : aucune. Dépendances : ecrireEtat, sortie.
            onExited: code => {
                try { sources.ecrireEtat(cle, code === 0 ? sortie.text.trim() : "") }
                finally { destroy() }
            }
        }
    }

    // Commandes déclarées, lues une fois.
    FileView {
        path: Qt.resolvedUrl("commandes.json").toString().replace(/^file:\/\//, "")
        blockLoading: true
        // onLoaded — lit les commandes déclarées. Entrées : aucune. Sortie : declarees ([] si le JSON est invalide).
        // Erreurs : aucune (l'exception d'analyse est rattrapée). Dépendances : aucune.
        onLoaded: { try { sources.declarees = JSON.parse(text()) } catch (e) { sources.declarees = [] } }
    }

    // Rôles applicatifs de l'accueil, dans l'ordre de la fiche (navigateur, terminal, fichiers), relus si le chemin
    // change.
    FileView {
        path: sources.cheminRoles
        printErrors: false
        blockLoading: true
        // onLoaded — lit les logiciels des rôles. Entrées : aucune. Sortie : motsRoles. Erreurs : aucune.
        // Dépendances : Logique.lireRoles.
        onLoaded: sources.motsRoles = Logique.lireRoles(text(), ["navigateur", "terminal", "fichiers"])
    }
}
