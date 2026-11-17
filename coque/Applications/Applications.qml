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
    // Quickshell ne lit les entrées de bureau et les fenêtres qu'au premier accès, de façon asynchrone : le singleton
    // les amorce dès sa création. Une liaison qui appelle resoudre se réévalue quand les entrées arrivent.
    Component.onCompleted: [DesktopEntries.applications.values, Hyprland.toplevels.values]

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
    // Dépendances : Hyprland.toplevels, Hyprland.dispatch, Quickshell.execDetached, Logique (fenetres, commandeFocus,
    // commandeLancement).
    function amenerOuLancer(entree) {
        const toplevels = Hyprland.toplevels.values.map(t => ({adresse: t.address,
            classe: t.wayland?.appId || t.lastIpcObject?.class || t.lastIpcObject?.initialClass || "",
            historique: t.lastIpcObject?.focusHistoryID ?? 1e9}))
        const adresses = Logique.fenetres(entree, toplevels)
        if (adresses.length > 0) Hyprland.dispatch(Logique.commandeFocus(adresses[0]))
        else Quickshell.execDetached(Logique.commandeLancement(entree))
    }
}
