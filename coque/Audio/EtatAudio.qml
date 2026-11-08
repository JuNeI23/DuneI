pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import "audio.js" as Audio

// EtatAudio — état et actions de l'audio pour la coque, adossés à Quickshell.Services.Pipewire (L2-12).
// Rôle : lit les sorties et entrées matérielles, la sortie et l'entrée par défaut, leur volume et leur sourdine ; porte
// les actions de la barre et du popover ; et décide seul des annonces de la presqu'île (spec, « Déclenchement »).
// Règles d'annonce :
// - une garde de liaison d'une seconde suit le démarrage, chaque liaison d'un nœud (ready qui passe à vrai, réveil
//   compris) et chaque changement de défaut ; volume et sourdine y sont ignorés ;
// - un défaut est comparé au dernier nœud non nul connu, par son identifiant : une phase nulle suivie du même nœud
//   (micro d'un casque qui s'éteint) n'annonce rien, et le premier défaut connu ne compte pas ;
// - un changement de sortie annonce « sortie » avant de poser la garde ; un changement d'entrée attend 150 ms et
//   s'efface si une annonce de sortie survient dans l'intervalle, ou s'il suit une annonce de sortie de moins d'une
//   seconde (audio.js, fusionner) : la sortie l'emporte, qu'elle arrive avant ou après l'entrée ;
// - volume ou sourdine de la sortie hors garde annoncent « volume », sourdine de l'entrée hors garde « micro » ;
// - popover ouvert, rien n'est annoncé.
// Entrées : popoverOuvert, en écriture par la barre.
// Sorties : sorties, entrees, listes de PwNode ; sortie, entree, défauts courants (null pendant une bascule) ;
// presente, vrai si une sortie existe ; volume, niveauMicro (0 à 100), muet, micMuet, qui gardent leur dernière
// valeur tant que le défaut est nul ; annonceCourante, dernière annonce émise ; signal annoncer(annonce), objet
// { genre, appareil, texte, coupe } construit par audio.js (annonce).
// Erreurs : aucune ; sans défaut, les actions ne font rien.
// Dépendances : Quickshell (Singleton), Quickshell.Services.Pipewire (Pipewire, PwObjectTracker), audio.js (estSortie,
// estEntree, pourcent, dansGarde, fusionner, annonce).
Singleton {
    id: etat

    readonly property var noeuds: Array.from(Pipewire.nodes.values ?? [])
    readonly property var sorties: noeuds.filter(Audio.estSortie)
    readonly property var entrees: noeuds.filter(Audio.estEntree)
    readonly property var sortie: Pipewire.defaultAudioSink
    readonly property var entree: Pipewire.defaultAudioSource
    readonly property bool presente: sorties.length > 0
    readonly property int volume: memoire.volume
    readonly property int niveauMicro: memoire.niveauMicro
    readonly property bool muet: memoire.muet
    readonly property bool micMuet: memoire.micMuet
    property bool popoverOuvert: false
    property var annonceCourante: null
    signal annoncer(var annonce)

    // Mémoire de l'état : dernières valeurs lues sur un défaut lié, identifiants des derniers défauts non nuls (-1 :
    // aucun encore), fin de la garde de liaison et instant de la dernière annonce de sortie.
    QtObject {
        id: memoire
        property int volume: 0
        property int niveauMicro: 0
        property bool muet: false
        property bool micMuet: false
        property int idSortie: -1
        property int idEntree: -1
        property real finGarde: Date.now() + 1000
        property real derniereSortieMs: -Infinity
    }

    // Les valeurs suivent le défaut lié ; défaut nul ou non lié, la liaison se suspend et la valeur reste.
    Binding { target: memoire; property: "volume"; when: etat.sortie?.ready ?? false; restoreMode: Binding.RestoreNone; value: Audio.pourcent(etat.sortie?.audio?.volume) }
    Binding { target: memoire; property: "muet"; when: etat.sortie?.ready ?? false; restoreMode: Binding.RestoreNone; value: etat.sortie?.audio?.muted ?? false }
    Binding { target: memoire; property: "niveauMicro"; when: etat.entree?.ready ?? false; restoreMode: Binding.RestoreNone; value: Audio.pourcent(etat.entree?.audio?.volume) }
    Binding { target: memoire; property: "micMuet"; when: etat.entree?.ready ?? false; restoreMode: Binding.RestoreNone; value: etat.entree?.audio?.muted ?? false }

    // Sans liaison, volume et sourdine des défauts valent 0 et ne se notifient pas.
    PwObjectTracker { objects: [etat.sortie, etat.entree] }

    onSortieChanged: if (sortie && sortie.id !== memoire.idSortie) {
        const premier = memoire.idSortie === -1
        memoire.idSortie = sortie.id
        if (!premier) {
            attenteEntree.stop()
            memoire.derniereSortieMs = Date.now()
            emettre("sortie")
        }
        poserGarde()
    }

    onEntreeChanged: if (entree && entree.id !== memoire.idEntree) {
        const premier = memoire.idEntree === -1
        memoire.idEntree = entree.id
        if (!premier && !Audio.fusionner("entree", memoire.derniereSortieMs, Date.now())) attenteEntree.restart()
        poserGarde()
    }

    // Attente d'une annonce d'entrée, que la sortie du même appareil peut encore effacer.
    Timer { id: attenteEntree; interval: 150; onTriggered: etat.emettre("entree") }

    // Liaison d'un défaut (démarrage, reconnexion, réveil) : WirePlumber rétablit ses valeurs, rien n'est annoncé.
    Connections {
        target: etat.sortie
        function onReadyChanged() { if (etat.sortie.ready) etat.poserGarde() }
    }
    Connections {
        target: etat.entree
        function onReadyChanged() { if (etat.entree.ready) etat.poserGarde() }
    }

    Connections {
        target: etat.sortie?.audio ?? null
        function onVolumesChanged() { etat.signaler("volume") }
        function onMutedChanged() { etat.signaler("volume") }
    }
    Connections {
        target: etat.entree?.audio ?? null
        function onMutedChanged() { etat.signaler("micro") }
    }

    // poserGarde — ouvre la garde de liaison pour une seconde.
    // Entrées : aucune. Sortie : aucune. Erreurs : aucune. Dépendances : memoire.
    function poserGarde(): void {
        memoire.finGarde = Date.now() + 1000
    }

    // signaler — annonce un changement de volume ou de sourdine, sauf pendant la garde de liaison.
    // Entrée : genre, « volume » ou « micro ». Sortie : aucune. Erreurs : aucune.
    // Dépendances : audio.js (dansGarde), emettre.
    function signaler(genre: string): void {
        if (!Audio.dansGarde(Date.now(), memoire.finGarde)) emettre(genre)
    }

    // emettre — construit l'annonce, la retient dans annonceCourante et l'émet, sauf popover ouvert.
    // Entrée : genre, « volume », « micro », « sortie » ou « entree ». Sortie : aucune ; signal annoncer.
    // Erreurs : aucune. Dépendances : audio.js (annonce), sortie, entree, muet, micMuet.
    function emettre(genre: string): void {
        if (popoverOuvert) return
        annonceCourante = Audio.annonce(genre, sortie, entree, sortie?.audio?.muted ?? muet, entree?.audio?.muted ?? micMuet)
        annoncer(annonceCourante)
    }

    // reglerVolume — règle le volume de la sortie par défaut, sans toucher sa sourdine.
    // Entrée : pourcent, de 0 à 100. Sortie : aucune. Erreurs : sans sortie liée, rien. Dépendances : sortie.
    function reglerVolume(pourcent: int): void {
        if (sortie?.audio) sortie.audio.volume = pourcent / 100
    }

    // reglerMicro — règle le niveau de l'entrée par défaut, sans toucher sa sourdine.
    // Entrée : pourcent, de 0 à 100. Sortie : aucune. Erreurs : sans entrée liée, rien. Dépendances : entree.
    function reglerMicro(pourcent: int): void {
        if (entree?.audio) entree.audio.volume = pourcent / 100
    }

    // basculerSon — coupe ou rétablit la sortie par défaut.
    // Entrées : aucune. Sortie : aucune. Erreurs : sans sortie liée, rien. Dépendances : sortie.
    function basculerSon(): void {
        if (sortie?.audio) sortie.audio.muted = !sortie.audio.muted
    }

    // basculerMicro — coupe ou rétablit l'entrée par défaut.
    // Entrées : aucune. Sortie : aucune. Erreurs : sans entrée liée, rien. Dépendances : entree.
    function basculerMicro(): void {
        if (entree?.audio) entree.audio.muted = !entree.audio.muted
    }

    // choisirSortie — fait d'un nœud la sortie par défaut ; WirePlumber l'applique en quelques millisecondes.
    // Entrée : n, un PwNode de sorties. Sortie : aucune. Erreurs : aucune. Dépendances : Pipewire.
    function choisirSortie(n): void {
        Pipewire.preferredDefaultAudioSink = n
    }

    // choisirEntree — fait d'un nœud l'entrée par défaut.
    // Entrée : n, un PwNode de entrees. Sortie : aucune. Erreurs : aucune. Dépendances : Pipewire.
    function choisirEntree(n): void {
        Pipewire.preferredDefaultAudioSource = n
    }
}
