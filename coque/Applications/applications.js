.pragma library

// applications.js — logique pure du module Applications (L2-69), sans dépendance à Quickshell.
// Rôle : retrouve l'entrée de bureau d'une application à partir d'indices (desktopEntry, appName), rattache des
// fenêtres à cette entrée, et écrit les commandes qui amènent une fenêtre ou lancent l'application. Le singleton
// Applications la nourrit de DesktopEntries et de Hyprland.toplevels ; le lanceur (L2-16) s'en servira tel quel.
// Une entrée est un objet {id, name, startupClass, runInTerminal} ; une fenêtre un objet {adresse, classe, historique}
// (historique : focusHistoryID de Hyprland, 0 pour la fenêtre la plus récemment utilisée).
// Entrées, sorties, erreurs : voir chaque fonction. Dépendances : aucune.

// pareil — égalité sans casse de deux chaînes, une chaîne vide n'étant égale à rien.
// Entrées : a, b, chaînes (ou undefined). Sortie : booléen. Erreurs : aucune. Dépendances : aucune.
function pareil(a, b) {
    return !!a && !!b && a.toLowerCase() === b.toLowerCase()
}

// resoudre — entrée de bureau de l'application désignée par les indices d'une notification, si elle est sûre.
// Entrées : desktopEntry, indice desktop-entry (suffixe .desktop toléré) ; appName, nom de l'application ; entrees,
// entrées connues. Sortie : l'entrée trouvée, par ordre de confiance (id exact, id sans casse, StartupWMClass exacte
// puis sans casse, sur desktopEntry puis sur appName, enfin nom affiché sans casse contre appName), ou null. Une
// entrée lancée en terminal n'est jamais retenue. Erreurs : aucune. Dépendances : pareil.
function resoudre(desktopEntry, appName, entrees) {
    const bureau = (desktopEntry || "").replace(/\.desktop$/i, "")
    const e = entrees.filter(x => !x.runInTerminal)
    const regles = [
        x => !!bureau && x.id === bureau,
        x => pareil(x.id, bureau),
        x => !!bureau && x.startupClass === bureau,
        x => pareil(x.startupClass, bureau),
        x => !!appName && x.startupClass === appName,
        x => pareil(x.startupClass, appName),
        x => pareil(x.name, appName)
    ]
    for (const regle of regles) {
        const trouvee = e.find(regle)
        if (trouvee) return trouvee
    }
    return null
}

// fenetres — adresses des fenêtres d'une application, de la plus récemment utilisée à la plus ancienne.
// Entrées : entree, entrée de bureau ; toplevels, fenêtres connues. Sortie : tableau d'adresses ; une fenêtre est
// retenue si sa classe, sans casse, vaut l'id de l'entrée, sa StartupWMClass ou le dernier segment de son id en
// domaine inversé (org.kde.dolphin → dolphin). Erreurs : aucune. Dépendances : pareil.
function fenetres(entree, toplevels) {
    const noms = [entree.id, entree.startupClass, entree.id.split(".").pop()]
    return toplevels.filter(t => noms.some(n => pareil(n, t.classe)))
        .sort((a, b) => a.historique - b.historique)
        .map(t => t.adresse)
}

// recentes — liste des fenêtres activées, la plus récente en tête, tenue par la coque elle-même : le relevé de
// Hyprland (focusHistoryID) n'est à jour qu'au dernier rafraîchissement.
// Entrées : liste, adresses déjà vues ; adresse, celle de la fenêtre qui vient d'être activée. Sortie : nouvelle
// liste, l'adresse en tête et sans doublon, bornée à 64 adresses. Erreurs : aucune. Dépendances : aucune.
function recentes(liste, adresse) {
    return [adresse].concat(liste.filter(a => a !== adresse)).slice(0, 64)
}

// rang — rang d'usage d'une fenêtre, 0 pour la plus récente, à poser dans le champ historique d'une fenêtre.
// Entrées : adresse ; liste, adresses activées vues par la coque (recentes) ; focusHistoryID, relevé de Hyprland
// (null ou undefined s'il manque). Sortie : sa position dans liste si elle y figure ; sinon 1000 plus focusHistoryID,
// ou 1000 plus un million sans relevé. Erreurs : aucune. Dépendances : aucune.
function rang(adresse, liste, focusHistoryID) {
    const i = liste.indexOf(adresse)
    return i >= 0 ? i : 1000 + (focusHistoryID ?? 1e6)
}

// commandeFocus — expression Lua qui donne le focus à une fenêtre, bureau compris, à passer à Hyprland.dispatch.
// Entrée : adresse, hexadécimale avec ou sans 0x. Sortie : l'expression hl.dsp.focus. Erreurs : aucune.
// Dépendances : aucune.
function commandeFocus(adresse) {
    return `hl.dsp.focus({ window = "address:0x${adresse.replace(/^0x/, "")}" })`
}

// commandeLancement — commande qui lance une application dans sa propre unité systemd, par uwsm.
// Entrée : entree, entrée de bureau. Sortie : tableau d'arguments pour Quickshell.execDetached. Erreurs : aucune.
// Dépendances : aucune (uwsm à l'exécution).
function commandeLancement(entree) {
    return ["uwsm", "app", "--", entree.id + ".desktop"]
}

// commandeAction — commande qui lance une action de bureau (Desktop Action) dans sa propre unité systemd, par uwsm,
// dont la syntaxe est « <id>.desktop:<id de l'action> » (uwsm(1), sous-commande app).
// Entrée : cible, « <id de l'entrée>:<id de l'action> », coupée au dernier deux-points. Sortie : tableau d'arguments
// pour Quickshell.execDetached. Erreurs : aucune. Dépendances : aucune (uwsm à l'exécution).
function commandeAction(cible) {
    const i = cible.lastIndexOf(":")
    return ["uwsm", "app", "--", cible.slice(0, i) + ".desktop:" + cible.slice(i + 1)]
}
