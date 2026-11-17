pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import "applications.js" as Logique

// Applications — trouver, amener ou lancer une application (L2-69).
// Rôle : relie la logique pure d'applications.js aux entrées de bureau de Quickshell (DesktopEntries, qui exclut déjà
// les entrées NoDisplay) et aux fenêtres de Hyprland. Les notifications s'en servent pour leur « Ouvrir » propre ;
// le lanceur (L2-16) appellera amenerOuLancer directement.
// Entrées : aucune. Sorties : aucune. Fonctions : resoudre, amenerOuLancer.
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

    // resoudre — entrée de bureau désignée par les indices d'une notification, si elle est sûre.
    // Entrées : desktopEntry, appName, chaînes éventuellement vides. Sortie : la DesktopEntry trouvée, ou null.
    // Erreurs : aucune. Dépendances : DesktopEntries.applications, Logique.resoudre.
    function resoudre(desktopEntry, appName) {
        const entrees = DesktopEntries.applications.values.map(e => ({id: e.id, name: e.name,
            startupClass: e.startupClass, runInTerminal: e.runInTerminal, source: e}))
        return Logique.resoudre(desktopEntry, appName, entrees)?.source ?? null
    }

    // amenerOuLancer — donne le focus à la fenêtre la plus récemment utilisée de l'application, bureau compris, ou la
    // lance dans sa propre unité systemd si aucune n'est ouverte.
    // Entrée : entree, DesktopEntry (ou objet {id, startupClass}). Sortie : aucune. Erreurs : aucune.
    // Dépendances : Hyprland.toplevels, Hyprland.dispatch, Quickshell.execDetached, recentes, Logique (rang, fenetres,
    // commandeFocus, commandeLancement).
    function amenerOuLancer(entree) {
        const toplevels = Hyprland.toplevels.values.map(t => ({adresse: t.address,
            classe: t.wayland?.appId || t.lastIpcObject?.class || t.lastIpcObject?.initialClass || "",
            historique: Logique.rang(t.address, recentes, t.lastIpcObject?.focusHistoryID)}))
        const adresses = Logique.fenetres(entree, toplevels)
        if (adresses.length > 0) Hyprland.dispatch(Logique.commandeFocus(adresses[0]))
        else Quickshell.execDetached(Logique.commandeLancement(entree))
    }
}
