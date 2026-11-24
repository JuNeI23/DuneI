import QtQuick
import Quickshell
import Quickshell.Hyprland
import "../Theme"

// Scene — contrôleur d'une attention plein écran qui sort en fondu (L2-23) : socle du menu de déconnexion, puis du
// sélecteur et du lanceur.
// Rôle : tient l'ouverture d'une attention, son inscription au registre Overlays (famille « attention » : l'ouvrir
// ferme le lanceur ou le sélecteur, et l'ouverture de l'un d'eux la ferme), sa fenêtre FenetreScene chargée à la
// demande et son fondu de sortie, puis l'exécution différée de l'action choisie. Le comportement est repris du
// sélecteur de L2-17 : executer ferme la scène et ne fait partir l'action qu'au retrait du calque de la scène
// (namespace espace) par le compositeur (événement closelayer, D194), pour que la fenêtre visée garde le clavier que
// Hyprland rend à ce retrait ; une garde d'une seconde la fait partir si l'événement ne vient pas. Chaque client a son
// propre namespace (L2-80) : le retrait d'un autre calque d'attention, la galerie en fondu par exemple, ne fait rien
// partir. Un délai d'affichage optionnel (delai) garde la fenêtre construite, clavier compris, mais invisible jusqu'à
// son terme : le geste tenu du sélecteur ; une fermeture avant ce terme ne montre rien et n'a pas de fondu.
// L'action en attente est abandonnée si une autre attention s'ouvre ou si la scène est rouverte : c'est changer
// d'avis. Sobriété (D80) : la fenêtre n'existe que pendant l'ouverture et son fondu de sortie (LazyLoader, present).
// Instancié comme enfant par un contrôleur client, qui déclare le cadre et exécute les actions.
// Entrées : ouvert, qui s'affecte et ne se lie pas (le registre Overlays et la fenêtre l'écrivent) ; cadre, le
//           composant posé au centre de l'écran, qui reçoit le focus (le Loader de la fenêtre est une portée de
//           focus : la racine du cadre, ou l'élément qui doit recevoir les touches, porte focus: true) ;
//           clavierExclusif, vrai par défaut, que la fenêtre applique (une coque d'essai le met à faux pour ne jamais
//           prendre le clavier de Nicolas) ;
//           executeur, null par défaut : une fonction qui reçoit l'action à la place du signal realiser (coques
//           d'essai) ; fenetree, vrai par défaut : faux, aucune fenêtre n'est construite et l'action part aussitôt ;
//           montee, vrai par défaut : le cadre monte du bas de l'écran au ressort window ; faux, il grandit depuis
//           son centre, de l'échelle window.echelleApparition à 1, au même ressort, pendant le fondu du compositeur ;
//           espace, « dunei-attention » par défaut : le namespace du calque, qui doit figurer dans glass.namespaces et
//           glass.fondu de tokens.toml pour être flouté et paraître en fondu ; delai, 0 par défaut : le délai
//           d'affichage, en millisecondes ; positionner, null par défaut (cadre centré) : une fonction
//           (hauteurFenetre, hauteurCadre) → y qui rend le haut du cadre dans la fenêtre, pour un client qui le tient
//           ailleurs qu'au centre (le lanceur, au tiers haut, L2-81).
// Sorties : famille, « attention » ; present (ouvert, ou fenêtre encore en sortie) ; sortant ; ecran (figé à
//           l'ouverture) ; montre (vrai dès l'ouverture sans délai, au terme du délai sinon si la scène est encore
//           ouverte ; gardé vrai par une réouverture pendant la sortie, remis à faux à la fin de celle-ci) ; fenetre
//           (la FenetreScene construite, ou null) ; differee (l'action en attente du retrait du calque, ou null) ;
//           executer(action), sortieFinie(), surEvenement(nom, donnee) ; signal realiser(action), émis quand une
//           action doit partir et qu'aucun executeur n'est posé : le client l'exécute.
// Erreurs : aucune ; une fenêtre qui ne peut être construite est journalisée (« Scène : fenêtre non construite ») et
//           la scène se referme.
// Dépendances : Quickshell (LazyLoader, screens), Quickshell.Hyprland (focusedMonitor, rawEvent), QtQuick (Timer,
//           Connections), Overlays, Theme (motion.delays.garde), FenetreScene.qml (chargée par son adresse, comme
//           FenetreAttention).
QtObject {
    id: scene

    property bool ouvert: false
    property Component cadre: null
    property bool clavierExclusif: true
    property var executeur: null
    property bool fenetree: true
    property bool montee: true
    property string espace: "dunei-attention"
    property int delai: 0
    property var positionner: null
    readonly property string famille: "attention"
    // Vrai entre la fermeture et la fin du fondu de sortie de la fenêtre ; la fenêtre reste chargée jusque-là.
    property bool sortant: false
    readonly property bool present: ouvert || sortant
    // Vrai quand la fenêtre doit être visible (voir delai) ; la fenêtre affiche ouvert && montre.
    property bool montre: false
    // Action choisie qui attend le retrait du calque de la scène par le compositeur (voir executer).
    property var differee: null
    readonly property var fenetre: chargeur.item?.fenetre ?? null
    signal realiser(var action)

    // Écran du moniteur focalisé, suivi en continu dès la création (Hyprland.focusedMonitor ne se remplit qu'après le
    // premier accès, voir Overlay), et écran de la fenêtre, figé à l'ouverture.
    readonly property var ecranFocalise: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name)
        ?? Quickshell.screens[0]
    property var ecran: null

    // executer — ferme la scène et fait partir l'action : aussitôt sans fenêtre (fenetree faux, ou fenêtre non
    // construite), sinon une fois le calque retiré par le compositeur (differee, voir la connexion à Hyprland).
    // Entrée : action, valeur quelconque que le client sait exécuter. Sortie : aucune. Erreurs : aucune.
    // Dépendances : fenetre, partir, differee, garde, ouvert.
    function executer(action) {
        if (!fenetre) partir(action)
        else { differee = action; garde.restart() }
        ouvert = false
    }

    // sortieFinie — appelée par la fenêtre quand son fondu de sortie est posé : la fenêtre est déchargée, son calque
    // retiré, ce qui fait partir l'action en attente, et montre retombe. Entrées : aucune. Sortie : aucune ; sans
    // effet si la scène a été rouverte entre-temps. Erreurs : aucune. Dépendances : ouvert, sortant, montre.
    function sortieFinie() {
        if (ouvert || !sortant) return
        sortant = false
        montre = false
    }

    // surEvenement — reçoit un événement brut de Hyprland : le retrait du calque de la scène (closelayer de son
    // namespace) fait partir l'action en attente ; celui d'un autre calque n'y touche pas. Entrées : nom, le nom de
    // l'événement ; donnee, sa donnée (le namespace pour closelayer). Sortie : aucune. Erreurs : aucune ; sans action
    // en attente, rien. Dépendances : differee, espace, realiserDifferee.
    function surEvenement(nom: string, donnee: string) {
        if (differee !== null && nom === "closelayer" && donnee === espace) realiserDifferee()
    }

    // realiserDifferee — fait partir l'action en attente, une seule fois, et jamais sous une attention ouverte (la
    // scène rouverte, ou le lanceur ouvert entre-temps : c'est changer d'avis). Entrées : aucune. Sortie : aucune.
    // Erreurs : aucune ; sans action en attente, rien. Dépendances : differee, partir, garde, Overlays.attention.
    function realiserDifferee() {
        const a = differee
        differee = null
        garde.stop()
        if (a !== null && !Overlays.attention) partir(a)
    }

    // partir — remet l'action à qui l'exécute : l'executeur s'il est posé, le client sinon, par le signal realiser.
    // Entrée : action (voir executer). Sortie : aucune. Erreurs : aucune. Dépendances : executeur, realiser.
    function partir(action) {
        if (executeur) executeur(action)
        else realiser(action)
    }

    // onOuvertChanged — à l'ouverture, fige l'écran et lance le délai d'affichage (sauf si la fenêtre, encore en
    // sortie, est reprise sur son écran et reste montrée), annule l'action qui attendait le retrait du calque et
    // s'inscrit au registre des attentions ; à la fermeture, arrête le délai, s'en retire et laisse la fenêtre jouer son
    // fondu de sortie (sortant) si elle a été montrée ; sinon, rien n'est visible, et la fenêtre est déchargée aussitôt.
    // Entrées : aucune. Sortie : aucune. Erreurs : aucune.
    // Dépendances : ecranFocalise, Overlays, fenetre, differee, garde, attente, delai, montre.
    onOuvertChanged: {
        if (ouvert) {
            if (!sortant) {
                ecran = ecranFocalise
                montre = delai === 0
                if (!montre) attente.restart()
            }
            sortant = false
            differee = null
            garde.stop()
            Overlays.ouvrir(scene)
        } else {
            attente.stop()
            sortant = fenetre !== null && montre
            if (!sortant) montre = false
            Overlays.fermer(scene)
        }
    }

    // onRawEvent — transmet chaque événement brut de Hyprland à surEvenement : Hyprland émet closelayer>><espace> au
    // démappage du calque, après lui avoir retiré le clavier. Entrée : e, l'événement brut (name, data). Sortie :
    // aucune. Erreurs : aucune. Dépendances : Hyprland.rawEvent, surEvenement.
    readonly property Connections retrait: Connections {
        target: Hyprland
        function onRawEvent(e) { scene.surEvenement(e.name, e.data) }
    }

    // onAttentionChanged — quand une autre attention que la scène s'ouvre (le lanceur, le sélecteur), l'action en
    // attente est abandonnée : c'est changer d'avis, et elle ne doit pas écraser le choix du nouveau geste en partant à
    // son tour au retrait du calque. Entrées : aucune. Sortie : differee remis à null. Erreurs : aucune ; sans autre
    // attention ouverte, rien. Dépendances : Overlays.attention, differee.
    readonly property Connections abandon: Connections {
        target: Overlays
        function onAttentionChanged() { if (Overlays.attention && Overlays.attention !== scene) scene.differee = null }
    }

    // Garde : si l'événement de retrait ne vient pas (connexion à Hyprland perdue), l'action part quand même, au plus
    // delays.garde (une seconde) après la fermeture ; ce délai technique, bien au-delà du fondu de sortie, n'est jamais
    // atteint quand le compositeur répond.
    readonly property Timer garde: Timer {
        interval: Theme.motion?.delays.garde ?? 0
        onTriggered: scene.realiserDifferee()
    }

    // Délai d'affichage : à son terme, la scène encore ouverte est montrée ; une fermeture avant l'arrête.
    readonly property Timer attente: Timer { interval: scene.delai; onTriggered: if (scene.ouvert) scene.montre = true }

    // La fenêtre vit dans FenetreScene.qml, que ce porteur ne compile qu'à l'ouverture, comme FenetreAttention : un
    // fichier qui nomme PanelWindow ne se charge pas sous une plateforme sans dorsale de couches. Si la création
    // échoue, l'échec est journalisé et la scène se referme.
    readonly property LazyLoader chargeur: LazyLoader {
        active: scene.present && scene.fenetree
        component: Component {
            QtObject {
                id: porteur
                readonly property Component composant: Qt.createComponent("FenetreScene.qml")
                readonly property var fenetre: composant.status === Component.Ready
                    ? composant.createObject(porteur, { scene }) : null

                // Component.onCompleted — vérifie que la fenêtre a été construite ; sinon journalise l'échec et referme
                // la scène. Entrées : aucune. Sortie : aucune ; sans fenêtre, ouvert repasse à faux au tour de boucle
                // suivant. Erreurs : l'avertissement « Scène : fenêtre non construite » avec l'erreur du composant.
                // Dépendances : fenetre, composant, scene.ouvert, Qt.callLater.
                Component.onCompleted: {
                    if (fenetre) return
                    console.warn("Scène : fenêtre non construite. " + composant.errorString())
                    Qt.callLater(() => scene.ouvert = false)
                }
            }
        }
    }
}
