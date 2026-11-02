import QtQuick
import Quickshell.Hyprland

// PastillesFenetre — les pastilles de fenêtre branchées sur la fenêtre Hyprland qui les porte.
// Rôle : une Pastilles dont les trois disques agissent sur la fenêtre de la coque titrée titre (proposition de L2-42,
// retenue par Nicolas) : rouge, fermer() est émis et la fenêtre se ferme elle-même (sa destruction lui appartient,
// D80) ; orange, la fenêtre part au bureau spécial sans le suivre ; vert, elle bascule en plein écran. Les deux
// derniers passent par Hyprland.dispatch, sur l'adresse de la fenêtre, jamais sur la fenêtre active. Le nom du bureau
// spécial n'est pas recopié ici : l'expression Lua le lit dans la configuration de Hyprland
// (require("donnees.raccourcis").special), sa seule source. Les disques sont neutres quand la fenêtre n'est pas la
// fenêtre active de Hyprland, comme une fenêtre inactive de macOS.
// Entrées : titre, requis, le titre de la fenêtre ; appId, sa classe Wayland, « org.quickshell » (celle de toute
// fenêtre de Quickshell) par défaut ; adresse, l'adresse Hyprland de la fenêtre, lue dans Hyprland.toplevels par
// défaut (un essai peut la poser) ; et les entrées de Pastilles.
// Sorties : toplevel, le HyprlandToplevel trouvé, null avant que Hyprland l'ait annoncé ; commande(action), l'expression
// passée à Hyprland.dispatch ; signal fermer(), hérité de Pastilles.
// Erreurs : aucune ; sans fenêtre trouvée (avant l'annonce de Hyprland, ou sous la plateforme offscreen des essais),
// les disques orange et vert n'émettent rien et les pastilles restent colorées.
// Dépendances : Pastilles, Quickshell.Hyprland (Hyprland.toplevels, dispatch ; HyprlandToplevel : title, address,
// activated, wayland.appId), API Lua hl.dsp de Hyprland ≥ 0.56, config/hypr/donnees/raccourcis.lua (special).
Pastilles {
    id: racine

    required property string titre
    property string appId: "org.quickshell"
    readonly property var toplevel: trouver(Hyprland.toplevels.values, titre, appId)
    property string adresse: toplevel?.address ?? ""

    inactif: toplevel !== null && !toplevel.activated
    onReduire: envoyer("reduire")
    onAgrandir: envoyer("agrandir")

    // trouver — fenêtre Hyprland de ce titre et de cette classe ; la fenêtre active l'emporte sur une homonyme.
    // Entrées : toplevels, liste de HyprlandToplevel (ou d'objets de même forme) ; titre ; appId.
    // Sortie : le toplevel trouvé, ou null. Erreurs : aucune ; un toplevel sans poignée Wayland est écarté.
    // Dépendances : aucune.
    function trouver(toplevels, titre, appId) {
        const l = toplevels.filter(t => t.title === titre && t.wayland?.appId === appId)
        return l.find(t => t.activated) ?? l[0] ?? null
    }

    // commande — expression Lua d'une action sur la fenêtre, à passer à Hyprland.dispatch.
    // Entrée : action, « reduire » (bureau spécial, sans le suivre) ou « agrandir » (bascule du plein écran).
    // Sortie : l'expression hl.dsp.*, ou "" sans adresse connue ou pour une action inconnue. Erreurs : aucune.
    // Dépendances : adresse.
    function commande(action) {
        if (adresse === "") return ""
        const fenetre = `"address:0x${adresse.replace(/^0x/, "")}"`
        return {
            reduire: `hl.dsp.window.move({ window = ${fenetre}, workspace = "special:" .. require("donnees.raccourcis").special, follow = false })`,
            agrandir: `hl.dsp.window.fullscreen({ window = ${fenetre}, mode = "fullscreen", action = "toggle" })`
        }[action] ?? ""
    }

    // envoyer — passe l'expression d'une action à Hyprland. Entrée : action. Sortie : aucune.
    // Erreurs : aucune ; sans adresse, rien n'est envoyé. Dépendances : commande, Hyprland.dispatch.
    function envoyer(action) {
        const c = commande(action)
        if (c !== "") Hyprland.dispatch(c)
    }
}
