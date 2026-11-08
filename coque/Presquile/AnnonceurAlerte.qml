import QtQuick
import Quickshell
import Quickshell.Hyprland
import "../Theme"
import "../Energie"

// AnnonceurAlerte — contrôleur unique de l'alerte d'énergie dans la presqu'île (L2-13).
// Rôle : à chaque annonce d'EtatEnergie (signal annoncer, palier 1 faible ou 2 critique), retient le palier puis le
// montre dès que la presqu'île de l'écran actif est libre : demande le module Alerte, en priorité 2 (au-dessus du
// volume, 1, en dessous de la galerie, 3). Le délai d'affichage (Theme.motion.delays.alerte, 4 s) ne court qu'à partir
// de la montée effective du module, quand la presqu'île cible porte l'alerte en phase « entree » (ou « repos », pour
// une presqu'île déjà posée), le motif par lequel l'Ouvreuse relance le sien ; il s'arrête si le module cesse d'être
// visible (une galerie ouverte par-dessus) et repart entier à son retour ; à son terme, la demande est libérée et la
// presqu'île se replie seule. La presqu'île n'est pas libre tant que Theme n'est pas prêt (le délai serait sans
// valeur), quand l'espace de travail de l'écran actif porte une fenêtre en plein écran (la presqu'île, sur la couche
// Top, y est cachée), ni quand la galerie est montée sur cet écran : l'alerte attend alors (enAttente), et s'affiche,
// pour son délai entier, dès la sortie du plein écran ou la fermeture de la galerie. La reprise suit la liaison libre,
// sans aucun sondage, et vise l'écran actif au moment de l'affichage, non celui du franchissement ; une galerie ouverte
// sur un autre écran ne retarde rien. Une seule alerte attend à la fois : une nouvelle annonce remplace la précédente
// (le critique remplace le faible), et une annonce reçue pendant l'affichage le prolonge avec le nouveau palier. Le
// signal effacer (branchement) annule l'alerte en attente et libère aussitôt celle qui est affichée. Une demande du
// volume pendant l'alerte ne la déplace pas ; elle est rendue après elle. Une presqu'île retirée (écran débranché) est
// oubliée.
// Entrées : les presqu'îles, inscrites par inscrire() et retirées par retirer() ; chacune porte modelData (son écran),
//           module (composant arbitré, lu), phase (lue ; absente, le module est tenu pour posé), demander() et
//           liberer() ; ecranActif et pleinEcran, lus comme dans l'Ouvreuse (Galerie/Ouvreuse.qml) ; etat, la source
//           des annonces, EtatEnergie par défaut ; galerie, le composant de la galerie (celui de l'Ouvreuse, que lui
//           passe la coque ; null : aucune attente pour elle) ; alerte, le composant du module. Les essais remplacent
//           ecranActif, pleinEcran, etat et galerie.
// Sorties : enAttente, le palier retenu (0 sinon) ; affiche, le palier montré, lu par le module Alerte ; cible, la
//           presqu'île qui porte l'alerte (null sinon) ; demandes « alerte » et leur libération.
// Erreurs : aucune ; sans presqu'île sur l'écran actif, l'alerte attend qu'il en ait une.
// Dépendances : quickshell ≥ 0.3 (Hyprland), Theme (motion.delays.alerte), EtatEnergie, Alerte.
Scope {
    id: annonceur

    property var presquiles: []
    property var cible: null
    property int enAttente: 0
    property int affiche: 0
    // Écran actif et plein écran : mêmes liaisons, et mêmes raisons, que dans l'Ouvreuse.
    property var ecranActif: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? null
    property bool pleinEcran: Hyprland.focusedMonitor?.activeWorkspace?.hasFullscreen ?? false
    property var etat: EtatEnergie
    property Component galerie: null
    property Component alerte: Component { Alerte { palier: annonceur.affiche } }
    // Presqu'île de l'écran actif, et vrai quand elle peut montrer l'alerte : réévaluée à chaque changement d'écran, de
    // plein écran ou de module arbitré, elle porte toute la reprise d'une alerte en attente.
    readonly property var _ile: presquiles.find(q => q.modelData === ecranActif) ?? null
    readonly property bool _libre: Theme.ready && _ile !== null && !pleinEcran
        && (galerie === null || _ile.module !== galerie)
    // Vrai quand l'alerte est effectivement montée et visible sur sa cible : seul moment où le délai court.
    readonly property bool _montee: cible !== null && cible.module === alerte
        && ["entree", "repos"].includes(cible.phase ?? "repos")

    // Au tour de boucle suivant : la presqu'île se libère souvent dans un changement de son propre arbitre (galerie
    // libérée), et une demande posée dans cette notification serait perdue par la garde de boucle des liaisons.
    on_LibreChanged: Qt.callLater(montrer)
    // Montée effective : le délai part entier ; module caché ou cédé : il s'arrête.
    on_MonteeChanged: if (_montee) delai.restart(); else delai.stop()

    // inscrire — fait connaître une presqu'île à l'annonceur. Entrée : p, la presqu'île. Sortie : aucune.
    // Erreurs : aucune ; une presqu'île déjà inscrite ne l'est pas deux fois. Dépendances : presquiles.
    function inscrire(p) { if (!presquiles.includes(p)) presquiles = [...presquiles, p] }

    // retirer — oublie une presqu'île détruite, sans toucher à son arbitre qui disparaît avec elle. Entrée : p.
    // Sortie : aucune. Erreurs : aucune. Dépendances : presquiles, delai.
    function retirer(p) {
        presquiles = presquiles.filter(q => q !== p)
        if (p === cible) { cible = null; delai.stop() }
    }

    // montrer — demande l'alerte en attente à la presqu'île de l'écran actif, si elle est libre ; si l'alerte y est déjà
    // montée (nouvelle annonce pendant l'affichage), relance le délai, qui sinon partira à la montée (_montee).
    // Entrées : aucune (lit enAttente, _libre, _ile). Sortie : aucune ; enAttente repasse à 0 une fois l'alerte demandée.
    // Erreurs : sans effet sans alerte en attente ou si la presqu'île n'est pas libre. Dépendances : alerte, delai.
    function montrer() {
        if (!enAttente || !_libre) return
        if (cible && cible !== _ile) cible.liberer("alerte")
        cible = _ile
        affiche = enAttente
        enAttente = 0
        cible.demander("alerte", alerte, 2)
        if (_montee) delai.restart()
    }

    // effacer — annule l'alerte en attente et libère aussitôt celle qui est affichée. Entrées : aucune.
    // Sortie : aucune. Erreurs : aucune. Dépendances : delai.
    function effacer() {
        enAttente = 0
        delai.stop()
        cible?.liberer("alerte")
        cible = null
    }

    // Délai d'affichage : lancé à la montée effective, il libère l'alerte à son terme. Le repli à 0 ne sert jamais :
    // aucune alerte n'est demandée avant que Theme soit prêt (_libre).
    Timer {
        id: delai
        interval: Theme.motion?.delays?.alerte ?? 0
        onTriggered: { annonceur.cible?.liberer("alerte"); annonceur.cible = null }
    }

    Connections {
        target: annonceur.etat
        function onAnnoncer(palier) { annonceur.enAttente = palier; annonceur.montrer() }
        function onEffacer() { annonceur.effacer() }
    }
}
