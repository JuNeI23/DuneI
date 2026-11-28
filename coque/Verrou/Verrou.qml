pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../Composants" as C
import "../Theme"
import "verrou.js" as Logique

// Verrou — contrôleur unique de l'écran verrouillé (L2-22, voie B) : chute du bloc, prise du verrou de session derrière
// lui, déverrouillage par PAM et remontée, que le lanceur dunei-verrou commande par l'IPC « verrou ».
// Rôle : tient l'état partagé par les calques de chaque écran (Bloc.qml) et par le verrou de session : la position du
// bloc (descente, ressort « spectacle », interrompue depuis sa position courante), son opacité (fondu, seul mouvement en
// mouvement réduit), la matière de sa presqu'île (image pendant le mouvement, verre au repos), le contenu montré dans
// la surface du verrou (vu, animé ou non selon anime), la saisie du mot de passe et le média, partagés par les écrans,
// et le clavier, pris par le bloc de la chute à la prise du verrou. Chaque ordre reçu est comparé au courant par
// ordreValable : un ordre périmé est ignoré. À la chute, popover et attention ouverts se ferment et le signal tombe()
// laisse la coque de session fermer lanceur, sélecteur et menu de déconnexion.
// Déroulé : le bloc posé et dessiné (une image de chaque écran, signalée par dessine, plus verrouRelais, au plus
// verrouRelaisMax après la pose, car un écran qui ne bouge pas ne rend plus d'image), le verrou est demandé (voulu) ;
// tenu (secure), le clavier passe à la surface du verrou et le contenu s'y montre. Le succès de PAM retire le contenu,
// puis, verrouRetrait plus tard, rend le verrou et fait remonter le bloc. Seuls ce succès et le suivi du compositeur
// rendent le verrou : remonter est sans effet tant qu'il est tenu ; il ne vaut que pour une chute sans verrou ou un
// verrou refusé.
// Overlays.verrou est vrai de la chute à la fin de la remontée, presqu'île revenue au verre : la vraie presqu'île
// s'efface dessous, les notifications et les demandes d'autorisation attendent. Sans lanceur, tant que le bloc est
// posé, la coque lit l'état du compositeur chaque seconde : deux lectures franches « rendu » de suite, sans lanceur
// vivant, rendent le verrou et le clavier et font remonter le bloc (la session est déjà ouverte). Un lanceur vivant (le
// script dunei-verrou, dans son unité dunei-verrou.scope ou hors d'elle) mène le verrou : ses relances de hyprlock
// laissent la session un temps « rendue », et le bloc doit alors rester. Dans le doute, le bloc reste : seule l'absence
// certaine d'un lanceur compte. demarrer(), appelé par la coque de session, pose le bloc sans chute si la session est
// déjà tenue, puis prend le verrou derrière lui.
// Entrées : IPC « verrou » : tomber, poserSec, remonter (chacun à ordre, entier), abreger (sans ordre : il ne fait
//           qu'abréger ce qui est en cours) et etat ; demarrer() ; dessine(nom), appelé par le bloc d'un écran à chaque
//           image posée ; fenetree, vrai par défaut (faux : aucun calque et aucun verrou de session, pour les essais) ;
//           clavierExclusif, vrai par défaut ; attendreImages (vrai par défaut avec les fenêtres) et refuserEssai (faux
//           par défaut ; sans fenêtre, il fait passer le verrou pour refusé), modes d'essai ; lecture, commande qui écrit
//           l'état du compositeur en JSON ({"locked": bool}), hyprctl -j locked borné à 1 s par défaut ; presence,
//           commande qui cherche un lanceur de l'utilisateur (uid de id -u), pgrep borné de même (0 : un lanceur vit,
//           1 : aucun, tout autre code : indécidable) ; toutes deux remplacées par les essais ; motifLanceur, le motif
//           de pgrep.
// Sorties : ordre ; couvre (bloc voulu posé) ; enPlace (voulu posé, à sa place) ; pose (posé et immobile) ;
//           remonte (remontée demandée, pas finie) ; voulu (verrou demandé) ; tient (verrou acquis : secure du
//           WlSessionLock, ou voulu sans fenêtre) ; depuis (heure de la dernière prise du verrou, ms, 0 sans verrou
//           tenu) ; anime (l'apparition du contenu se joue : faux en verrou sec ou
//           abrégé) ; position (1 posé, 0 caché ; fixe à 1 en mouvement réduit) ; opacite ; matiere (1 image, 0 verre) ;
//           actif (vaut Overlays.verrou) ; montre (calque du bloc mappé : vrai dès actif, faux un tour de boucle après
//           la fin d'actif, s'il ne l'est pas redevenu) ; vu ; prendClavier ; saisie (Saisie, prête quand tient) ; media
//           (Media) ; signal tombe().
// Erreurs : ordre périmé : ignoré ; lecture illisible ou commande absente : la lecture ne compte pas comme rendue ;
//           recherche d'un lanceur indécidable (délai dépassé, erreur de pgrep, commande absente) : le « rendu » ne
//           compte pas et la série n'avance pas ; le bloc reste ; écran qui ne dessine pas : le verrou est demandé au
//           plafond verrouRelaisMax.
// Dépendances : Quickshell (Singleton, Variants, screens), Quickshell.Io (Process, StdioCollector, IpcHandler),
//           Quickshell.Wayland (WlSessionLock), Ressort, Theme (motion.delays : verrouRelais, verrouRelaisMax,
//           verrouRetrait ; mouvementReduit), C.Overlays (popover, attention, verrou), verrou.js (ordreValable),
//           Bloc.qml, Saisie.qml, Media.qml.
Singleton {
    id: verrou

    property int ordre: 0
    property bool couvre: false
    property bool remonte: false
    property bool voulu: false
    property bool anime: false
    property bool vu: false
    property bool clavier: false
    property bool fenetree: true
    property bool clavierExclusif: true
    // Modes d'essai : sans fenêtre, attendre les images de chaque écran, ou faire passer le verrou pour refusé.
    property bool attendreImages: fenetree
    property bool refuserEssai: false
    property var lecture: ["timeout", "1", "hyprctl", "-j", "locked"]
    // Lanceur lancé par son shebang, dans son unité comme hors d'elle ; ni un éditeur ouvert sur le script, ni
    // dunei-verrou-initial, ni la commande de recherche elle-même (motif [d]).
    readonly property string motifLanceur: "^(/usr)?/bin/sh [^ ]*/[d]unei-verrou( |$)"
    // L'utilisateur est désigné par son uid, que id -u donne même quand USER manque ; exec garde le code de pgrep, et un
    // id en échec (-u vide) fait échouer pgrep : indécidable, jamais « aucun lanceur ».
    property var presence: ["timeout", "1", "sh", "-c", 'exec pgrep -u "$(id -u)" -f "$1"', "sh", motifLanceur]
    // Lectures franches « rendu » consécutives du suivi ; mode de la lecture en cours (« suivi » ou « demarrage »).
    property int rendus: 0
    property string pour: "suivi"
    // Écrans dont le bloc a posé une image depuis la pose, par nom.
    property var dessines: ({})

    readonly property bool reduit: Theme.mouvementReduit
    readonly property real position: reduit ? 1 : descente.value
    readonly property real opacite: reduit ? fondu.value : 1
    // Bloc à sa place, séparé de l'opacité : la position vient du ressort de déplacement, qui ne porte aucune opacité.
    readonly property bool enPlace: couvre && position === 1
    readonly property bool pose: enPlace && opacite === 1
    readonly property real matiere: image.value
    readonly property bool actif: couvre || descente.value > 0 || fondu.value > 0 || image.value > 0
    // Calque du bloc mappé : posé à vrai dès actif, rendu faux par tenue seulement, jamais par une liaison dont l'ordre
    // de réévaluation, face à onActifChanged, pourrait le faire tomber à faux une image avant la tenue.
    property bool montre: false
    readonly property bool prendClavier: clavier && clavierExclusif
    // Verrou acquis : le compositeur le dit sûr ; sans fenêtre, aucun verrou réel n'est demandé et la demande en tient
    // lieu, sauf en mode d'essai « refuser ».
    readonly property bool tient: fenetree ? session.secure : voulu && !refuserEssai
    // Heure (ms, horloge Unix) à laquelle tient est devenu vrai pour la dernière fois, 0 sans verrou tenu : le lanceur
    // la compare à la prise de hyprlock, pour ne jamais lui rendre un verrou que hyprlock a supplanté.
    property double depuis: 0
    // Relais en cours : le bloc est posé, le verrou n'est pas encore demandé ; images : chaque écran a dessiné.
    readonly property bool attend: pose && !voulu && !remonte
    readonly property bool images: !attendreImages || Quickshell.screens.every(e => verrou.dessines[e.name] === true)

    readonly property Saisie saisie: Saisie { pret: verrou.tient }
    readonly property Media media: Media {}

    signal tombe()

    // Seuil d'un millième de la hauteur (un pixel environ) : le ressort se pose sans attendre que sa vitesse s'éteigne.
    Ressort { id: descente; transition: "spectacle"; seuil: 0.001; cible: verrou.couvre ? 1 : 0 }
    Ressort { id: fondu; transition: "spectacle"; nature: "fondu"; cible: verrou.couvre ? 1 : 0 }
    // Matière de la presqu'île du bloc : l'image dès que le bloc quitte le repos, le verre une fois remonté.
    Ressort { id: image; transition: "state"; nature: "fondu"
              cible: !verrou.reduit && (verrou.couvre || descente.value > 0) ? 1 : 0 }
    // Le calque du bloc reste mappé jusqu'au tour de boucle suivant la fin : la vraie presqu'île, reposée d'un coup à
    // l'identique, est déjà demandée. Relevé au banc : ni vide ni verre doublé, alors qu'une tenue de 32 ms doublait
    // le verre une image.
    Timer { id: tenue; interval: 0; onTriggered: if (!verrou.actif) verrou.montre = false }

    Binding { target: C.Overlays; property: "verrou"; value: verrou.actif }

    // Verrou de session : demandé seulement avec les fenêtres (jamais dans les coques d'essai), et seulement par voulu.
    // Sa surface (Surface.qml) montre le contenu, une par écran.
    WlSessionLock {
        id: session
        locked: verrou.fenetree && verrou.voulu
        surface: Component { Surface {} }
    }

    // surveillerFichiers — règle la surveillance des fichiers de la coque : coupée tant que le verrou est actif. Un
    // rechargement à chaud libère le verrou de session (relevé au banc, tâche 1) ; seule l'affectation impérative
    // a été éprouvée, d'où ce gestionnaire plutôt qu'une liaison déclarative. La rallumer ne rejoue pas les
    // changements faits pendant le verrou : c'est accepté. Entrées : aucune. Sortie : Quickshell.watchFiles. Erreurs :
    // aucune. Dépendances : actif, Quickshell.
    function surveillerFichiers() { Quickshell.watchFiles = !verrou.actif }
    Component.onCompleted: surveillerFichiers()

    // onActifChanged — actif : le calque se mappe aussitôt (une tenue en attente est annulée) ; la remontée finie, plus
    // rien n'est en cours, et le calque tient encore un tour de boucle avant que tenue ne le démappe, s'il est toujours
    // inactif. Entrées : aucune. Sortie : montre, remonte, tenue. Erreurs : aucune.
    onActifChanged: {
        surveillerFichiers()
        if (actif) { tenue.stop(); montre = true; return }
        remonte = false
        tenue.restart()
    }

    // onTientChanged — le verrou acquis, le bloc rend le clavier (la surface du verrou le reçoit), le contenu se
    // montre dans la surface et l'heure de la prise est notée. Entrées : aucune. Sortie : clavier, vu, depuis.
    // Erreurs : aucune ; verrou perdu, depuis revient à 0, rien d'autre (le lanceur le constate). Dépendances : tient.
    onTientChanged: {
        depuis = tient ? Date.now() : 0
        if (tient) { clavier = false; vu = true }
    }

    // accepter — retient un ordre s'il n'est pas périmé. Entrée : o, ordre reçu. Sortie : vrai s'il est accepté (ordre
    // devient o). Erreurs : aucune. Dépendances : Logique.ordreValable.
    function accepter(o) {
        if (!Logique.ordreValable(o, ordre)) return false
        ordre = o
        return true
    }

    // couvrir — part vers le bloc posé : clavier pris, contenu retiré, saisie annulée (vérification comprise), retrait
    // et libération d'un verrou précédent annulés, images du relais oubliées, reste de la coque fermé. Entrées : aucune.
    // Sortie : couvre, clavier, vu, dessines ; signal tombe(). Erreurs : aucune.
    // Dépendances : retrait, liberation, saisie, C.Overlays.
    function couvrir() {
        retrait.stop()
        liberation.stop()
        dessines = ({})
        remonte = false
        vu = false
        saisie.annuler()
        clavier = true
        couvre = true
        if (C.Overlays.popover) C.Overlays.popover.ouvert = false
        if (C.Overlays.attention) C.Overlays.attention.ouvert = false
        tombe()
    }

    // recouvert — vrai si le bloc est déjà voulu posé et ne remonte pas. Entrées : aucune. Sortie : booléen.
    // Erreurs : aucune.
    function recouvert() { return couvre && !remonte }

    // tomber — lance la chute du bloc ; sous un bloc déjà voulu, l'ordre seul est pris. Entrée : o, ordre. Sortie :
    // aucune. Erreurs : ordre périmé ignoré. Dépendances : accepter, recouvert, couvrir.
    function tomber(o) {
        if (!accepter(o) || recouvert()) return
        anime = true
        couvrir()
    }

    // poserSec — pose le bloc sans mouvement, le contenu ne s'animant pas (verrou sec : veille, ouverture de session) ;
    // sous un bloc déjà voulu, il vaut abreger. Entrée : o, ordre. Sortie : aucune. Erreurs : ordre périmé ignoré.
    // Dépendances : accepter, recouvert, abreger, couvrir, poserBloc.
    function poserSec(o) {
        if (!accepter(o)) return
        if (recouvert()) { abreger(); return }
        anime = false
        couvrir()
        poserBloc()
    }

    // poserBloc — pose le bloc et sa presqu'île d'un coup. Entrées : aucune. Sortie : aucune. Erreurs : aucune.
    // Dépendances : Ressort.poser.
    function poserBloc() {
        descente.poser()
        fondu.poser()
        image.poser()
    }

    // abreger — une veille est annoncée : la chute se pose à l'instant et le contenu ne s'animera pas.
    // Entrées : aucune. Sortie : anime. Erreurs : aucune ; hors chute ou pendant une remontée, rien.
    // Dépendances : recouvert, poserBloc.
    function abreger() {
        if (!recouvert()) return
        poserBloc()
        anime = false
    }

    // dessine — le bloc d'un écran a posé une image : comptée pour le relais si le bloc est posé.
    // Entrée : nom, le nom de l'écran. Sortie : dessines. Erreurs : aucune ; avant la pose, ou image déjà comptée, rien.
    function dessine(nom) {
        if (!pose || dessines[nom] === true) return
        dessines = Object.assign({}, dessines, { [nom]: true })
    }

    // demander — fin du relais : le verrou de session est demandé. Entrées : aucune. Sortie : voulu.
    // Erreurs : aucune ; hors relais (déjà demandé, remontée), rien. Dépendances : attend.
    function demander() { if (attend) voulu = true }

    // remonter — la session est rendue par un autre (hyprlock) ou la chute est annulée : clavier rendu, contenu retiré,
    // puis le bloc remonte depuis sa position. Sans effet tant que la coque tient le verrou : seul le succès de PAM le
    // rend, et l'ordre n'est alors pas même pris. Entrée : o, ordre. Sortie : aucune. Erreurs : ordre périmé ignoré.
    // Dépendances : tient, accepter, relever.
    function remonter(o) { if (!tient && accepter(o)) relever() }

    // relever — rend le verrou et le clavier ; le contenu montré se retire en verrouRetrait, puis le bloc remonte.
    // Appelé par remonter, par le succès de PAM et par le suivi du compositeur, seuls autorisés à rendre le verrou.
    // Entrées : aucune. Sortie : remonte, voulu, clavier, vu. Erreurs : aucune ; bloc non voulu ou remontée déjà
    // demandée, rien d'autre que le clavier rendu. La libération en attente et la saisie (vérification comprise) sont
    // annulées : rien ne passe au verrou suivant. Dépendances : retrait, liberation, saisie, finirRetrait.
    function relever() {
        clavier = false
        liberation.stop()
        if (!recouvert()) return
        remonte = true
        voulu = false
        saisie.annuler()
        if (vu) { vu = false; retrait.restart() }
        else finirRetrait()
    }

    // finirRetrait — le contenu retiré, le bloc remonte. Entrées : aucune. Sortie : couvre. Erreurs : aucune.
    function finirRetrait() { couvre = false }

    // demarrer — lit l'état du compositeur au démarrage de la coque de session ; tenu, le bloc se pose sans chute et le
    // verrou est pris derrière lui. Entrées : aucune. Sortie : aucune (voir lire). Erreurs : voir lire.
    // Dépendances : lire.
    function demarrer() { lire("demarrage") }

    // lire — lance une lecture de l'état du compositeur, sauf si une autre court. Entrée : mode, « suivi » ou
    // « demarrage ». Sortie : aucune ; le résultat arrive à conclure. Erreurs : aucune. Dépendances : lecteur.
    function lire(mode) {
        if (lecteur.running) return
        pour = mode
        lecteur.running = true
    }

    // conclure — tire la conséquence d'une lecture. Entrée : texte, la sortie de la commande. Sortie : bloc posé au
    // démarrage si la session est tenue ; au suivi, un « rendu » lance la recherche d'un lanceur (compter).
    // Erreurs : texte illisible : ni tenu ni rendu, la série repart de zéro. Dépendances : poserSec, chercheur.
    function conclure(texte) {
        let locked = null
        try { locked = JSON.parse(texte).locked } catch (e) { locked = null }
        if (pour === "demarrage") { if (locked === true && !couvre) poserSec(ordre); return }
        if (!pose || locked !== false) { rendus = 0; return }
        if (!chercheur.running) chercheur.running = true
    }

    // compter — un « rendu » lu : compté seulement si la recherche dit qu'aucun lanceur ne vit ; deux de suite rendent
    // le verrou et font remonter le bloc, même tenu (la session est déjà ouverte). Entrée : code, code de sortie de la
    // recherche (0 : lanceur vivant, 1 : aucun lanceur). Sortie : rendus ; remontée au second. Erreurs : tout autre code
    // (124 au délai, 2 ou 3 en erreur de pgrep) est indécidable : rien ne compte, la série reste où elle est ; bloc qui
    // n'est plus posé, ou lanceur vivant, la série repart de zéro. Dépendances : relever.
    function compter(code) {
        if (!pose || code === 0) { rendus = 0; return }
        if (code !== 1) return
        rendus++
        if (rendus >= 2) { rendus = 0; relever() }
    }

    Process {
        id: lecteur
        command: verrou.lecture
        stdout: StdioCollector {
            // onStreamFinished — remet la sortie de la commande à conclure. Entrées : aucune. Sortie : aucune.
            onStreamFinished: verrou.conclure(text)
        }
    }

    Process {
        id: chercheur
        command: verrou.presence
        // onExited — remet le code de la recherche à compter. Entrées : code, statut. Sortie : voir compter.
        onExited: (code, statut) => verrou.compter(code)
    }

    // Suivi du compositeur, une lecture par seconde tant que le bloc est posé ; la série repart à chaque pose.
    Timer {
        interval: 1000
        repeat: true
        running: verrou.pose
        onRunningChanged: verrou.rendus = 0
        onTriggered: verrou.lire("suivi")
    }

    // Relais vers le verrou : verrouRelais après la dernière image attendue, et au plus verrouRelaisMax après la pose,
    // car un écran éteint ou immobile ne rend plus d'image.
    Timer { interval: Theme.motion?.delays.verrouRelais ?? 50; running: verrou.attend && verrou.images
            onTriggered: verrou.demander() }
    Timer { interval: Theme.motion?.delays.verrouRelaisMax ?? 250; running: verrou.attend
            onTriggered: verrou.demander() }

    Timer { id: retrait; interval: Theme.motion?.delays.verrouRetrait ?? 0; onTriggered: verrou.finirRetrait() }

    // Déverrouillage : le contenu se retire dans la surface du verrou, puis le verrou est rendu et le bloc remonte.
    Timer { id: liberation; interval: Theme.motion?.delays.verrouRetrait ?? 0; onTriggered: verrou.relever() }

    Connections {
        target: verrou.saisie
        // onReussi — PAM a accepté le mot de passe : le contenu se retire, et le verrou sera rendu verrouRetrait plus
        // tard. Entrées : aucune. Sortie : vu, liberation. Erreurs : aucune ; sans verrou tenu, rien.
        // Dépendances : tient, liberation.
        function onReussi() {
            if (!verrou.tient) return
            verrou.vu = false
            liberation.restart()
        }
    }

    Variants {
        model: verrou.fenetree ? Quickshell.screens : []
        delegate: Scope {
            id: ecran
            required property var modelData
            Bloc { modelData: ecran.modelData }
        }
    }

    IpcHandler {
        target: "verrou"

        // Commandes du lanceur, voir les fonctions du même nom. Entrée : ordre. Sortie : aucune.
        function tomber(ordre: int): void { verrou.tomber(ordre) }
        function poserSec(ordre: int): void { verrou.poserSec(ordre) }
        function remonter(ordre: int): void { verrou.remonter(ordre) }
        function abreger(): void { verrou.abreger() }

        // etat — état rendu au lanceur, en JSON : {pose, ordre, tient, depuis, couvre, remonte}. Entrées : aucune.
        // Sortie : texte. Erreurs : aucune.
        function etat(): string {
            return JSON.stringify({ pose: verrou.pose, ordre: verrou.ordre, tient: verrou.tient, depuis: verrou.depuis,
                                    couvre: verrou.couvre, remonte: verrou.remonte })
        }
    }
}
