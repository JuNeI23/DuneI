pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import "applications.js" as Logique

// Applications — trouver, amener ou lancer une application (L2-69).
// Rôle : relie la logique pure d'applications.js aux entrées de bureau de Quickshell (DesktopEntries, qui exclut déjà
// les entrées NoDisplay) et aux fenêtres de Hyprland. Les notifications s'en servent pour leur « Ouvrir » propre ;
// le lanceur (L2-16) emploie toplevels, amenerOuLancer et lancerAction.
// Entrées : aucune. Sorties : aucune. Fonctions : icone, resoudre, toplevels, amenerOuLancer, lancerAction.
// Erreurs : aucune ; une application introuvable n'est ni amenée ni lancée.
// Dépendances : Quickshell (Singleton, DesktopEntries, execDetached), Quickshell.Hyprland (Hyprland.toplevels,
// Hyprland.dispatch), applications.js, uwsm à l'exécution.
Singleton {
    id: applications

    // Adresses des fenêtres activées depuis la création du singleton, la plus récente en tête (applications.js,
    // recentes). Elles priment sur focusHistoryID, que Quickshell ne relit qu'au rafraîchissement de Hyprland.
    property var recentes: []

    // onActiveToplevelChanged — met en tête de recentes la fenêtre que Hyprland vient d'activer.
    // Entrées : aucune (Hyprland.activeToplevel). Sortie : aucune. Erreurs : aucune ; sans fenêtre active, rien ne
    // change. Dépendances : Hyprland.activeToplevel, Logique.recentes. Hors affichage Wayland (coque d'essai hors
    // écran), aucune cible : Hyprland n'est pas interrogé.
    Connections {
        target: Quickshell.env("WAYLAND_DISPLAY") ? Hyprland : null
        function onActiveToplevelChanged() {
            const a = Hyprland.activeToplevel?.address
            if (a) applications.recentes = Logique.recentes(applications.recentes, a)
        }
    }

    // Component.onCompleted — amorçage. Entrées : WAYLAND_DISPLAY. Sorties : aucune. Erreurs : aucune.
    // Dépendances : DesktopEntries, Hyprland.toplevels.
    // Quickshell ne lit les entrées de bureau et les fenêtres qu'au premier accès, de façon asynchrone : le singleton
    // les amorce dès sa création. Une liaison qui appelle resoudre se réévalue quand les entrées arrivent. Les fenêtres
    // ne s'amorcent que sous un affichage Wayland : une coque d'essai hors écran n'a pas de compositeur à interroger.
    Component.onCompleted: {
        DesktopEntries.applications.values
        if (Quickshell.env("WAYLAND_DISPLAY")) Hyprland.toplevels.values
    }

    // icone — source d'une icône en couleur (application, fenêtre, action de bureau), commune au lanceur et au
    // sélecteur de fenêtres.
    // Entrée : nom, nom freedesktop ou chemin absolu. Sortie : url de l'image, l'icône d'exécutable du thème à défaut,
    // « » sans nom. Erreurs : aucune. Dépendances : Quickshell.iconPath.
    function icone(nom) {
        return !nom ? "" : nom.startsWith("/") ? "file://" + nom : Quickshell.iconPath(nom, "application-x-executable")
    }

    // resoudre — entrée de bureau désignée par les indices d'une notification, si elle est sûre.
    // Entrées : desktopEntry, appName, chaînes éventuellement vides. Sortie : la DesktopEntry trouvée, ou null.
    // Erreurs : aucune. Dépendances : DesktopEntries.applications, Logique.resoudre.
    function resoudre(desktopEntry, appName) {
        const entrees = DesktopEntries.applications.values.map(e => ({id: e.id, name: e.name,
            startupClass: e.startupClass, runInTerminal: e.runInTerminal, source: e}))
        return Logique.resoudre(desktopEntry, appName, entrees)?.source ?? null
    }

    // toplevels — fenêtres de Hyprland projetées pour applications.js et le lanceur (L2-16).
    // Entrées : aucune (Hyprland.toplevels, recentes). Sortie : tableau de {adresse, classe (appId Wayland, sinon
    // classe puis classe initiale de Hyprland), titre, bureau (nom de l'espace de travail, « » s'il manque),
    // historique (Logique.rang)}. Appelée dans une liaison, elle la fait réévaluer quand les fenêtres, leurs titres ou
    // recentes changent. Erreurs : aucune. Dépendances : Hyprland.toplevels, recentes, Logique.rang.
    function toplevels() {
        return Hyprland.toplevels.values.map(t => ({adresse: t.address,
            classe: t.wayland?.appId || t.lastIpcObject?.class || t.lastIpcObject?.initialClass || "",
            titre: t.title, bureau: t.workspace?.name ?? "",
            historique: Logique.rang(t.address, recentes, t.lastIpcObject?.focusHistoryID)}))
    }

    // amenerOuLancer — donne le focus à la fenêtre la plus récemment utilisée de l'application, bureau compris, ou la
    // lance dans sa propre unité systemd si aucune n'est ouverte.
    // Entrée : entree, DesktopEntry (ou objet {id, startupClass}). Sortie : aucune. Erreurs : aucune.
    // Dépendances : toplevels, Hyprland.dispatch, Quickshell.execDetached, Logique (fenetres, commandeFocus,
    // commandeLancement).
    function amenerOuLancer(entree) {
        const adresses = Logique.fenetres(entree, toplevels())
        if (adresses.length > 0) Hyprland.dispatch(Logique.commandeFocus(adresses[0]))
        else Quickshell.execDetached(Logique.commandeLancement(entree))
    }

    // lancerAction — lance une action de bureau d'une application (« Nouvelle fenêtre privée ») dans sa propre unité
    // systemd, hors de l'arbre de processus de la coque, jamais par DesktopAction.execute().
    // Entrée : cible, « <id de l'entrée>:<id de l'action> ». Sortie : aucune. Erreurs : aucune ; uwsm écrit son échec
    // dans son journal. Dépendances : Quickshell.execDetached, Logique.commandeAction, uwsm à l'exécution.
    function lancerAction(cible) { Quickshell.execDetached(Logique.commandeAction(cible)) }
}
