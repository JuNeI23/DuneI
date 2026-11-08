import QtQuick
import Quickshell
import Quickshell.Hyprland
import "../Theme"
import "../Audio"

// Annonceur — contrôleur unique de la jauge du son dans la presqu'île (L2-12).
// Rôle : à chaque annonce d'EtatAudio (signal annoncer), demande le module Volume, en priorité 1, à la presqu'île de
// l'écran actif et relance le délai de retour (Theme.motion.delays.dismiss, 1,5 s) ; à son terme, libère la demande :
// la presqu'île rend le module suivant de son arbitre (les bureaux, ou la galerie si elle est ouverte). Une rafale
// d'annonces ne monte le module qu'une fois : une demande renouvelée est sans effet dans l'arbitre, et le module lit
// lui-même l'annonce courante. Rien ne s'ouvre si l'espace de travail de l'écran actif porte une fenêtre en plein
// écran (la presqu'île, sur la couche Top, y est cachée). Si l'écran actif change pendant l'affichage, la demande
// quitte l'ancienne presqu'île pour la nouvelle. Une presqu'île retirée (écran débranché) est oubliée.
// Entrées : les presqu'îles, inscrites par inscrire() et retirées par retirer() ; chacune porte modelData (son écran),
//           demander() et liberer() ; ecranActif et pleinEcran, lus comme dans l'Ouvreuse (Galerie/Ouvreuse.qml) ;
//           etat, la source des annonces, EtatAudio par défaut ; volume, le composant du module. Les essais
//           remplacent ecranActif, pleinEcran, etat et volume.
// Sorties : cible, la presqu'île qui porte la jauge (null sinon) ; demandes « volume » et leur libération.
// Erreurs : aucune ; sans presqu'île sur l'écran actif, ou en plein écran, une annonce ne montre rien.
// Dépendances : quickshell ≥ 0.3 (Hyprland), Theme (motion.delays.dismiss), EtatAudio, Volume.
Scope {
    id: annonceur

    property var presquiles: []
    property var cible: null
    // Écran actif et plein écran : mêmes liaisons, et mêmes raisons, que dans l'Ouvreuse.
    property var ecranActif: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? null
    property bool pleinEcran: Hyprland.focusedMonitor?.activeWorkspace?.hasFullscreen ?? false
    property var etat: EtatAudio
    property Component volume: Component { Volume {} }

    // inscrire — fait connaître une presqu'île à l'annonceur. Entrée : p, la presqu'île. Sortie : aucune.
    // Erreurs : aucune ; une presqu'île déjà inscrite ne l'est pas deux fois. Dépendances : presquiles.
    function inscrire(p) { if (!presquiles.includes(p)) presquiles = [...presquiles, p] }

    // retirer — oublie une presqu'île détruite, sans toucher à son arbitre qui disparaît avec elle. Entrée : p.
    // Sortie : aucune. Erreurs : aucune. Dépendances : presquiles, delai.
    function retirer(p) {
        presquiles = presquiles.filter(q => q !== p)
        if (p === cible) { cible = null; delai.stop() }
    }

    // montrer — demande la jauge à la presqu'île de l'écran actif et relance le délai de retour.
    // Entrées : aucune (lit ecranActif, pleinEcran, presquiles). Sortie : aucune.
    // Erreurs : sans effet en plein écran ou sans presqu'île sur l'écran actif. Dépendances : volume, delai.
    function montrer() {
        const p = presquiles.find(q => q.modelData === ecranActif)
        if (pleinEcran || !p) return
        if (cible && cible !== p) cible.liberer("volume")
        cible = p
        p.demander("volume", volume, 1)
        delai.restart()
    }

    // Délai de retour : relancé à chaque annonce, il libère la jauge après la dernière.
    Timer {
        id: delai
        interval: Theme.motion?.delays?.dismiss ?? 0
        onTriggered: { annonceur.cible?.liberer("volume"); annonceur.cible = null }
    }

    Connections {
        target: annonceur.etat
        function onAnnoncer(annonce) { annonceur.montrer() }
    }
}
