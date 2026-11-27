pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../Composants" as C
import "../Theme"
import "verrou.js" as Logique

// Verrou — contrôleur unique du bloc du verrou (L2-22) : chute, pose, apparition, cession et remontée, que le lanceur
// dunei-verrou commande par l'IPC « verrou ».
// Rôle : tient l'état partagé par les calques de chaque écran (Bloc.qml, Apparition.qml) : la position du bloc
// (descente, ressort « spectacle », interrompue depuis sa position courante), son opacité (fondu, seul mouvement en
// mouvement réduit), la matière de sa presqu'île (image pendant le mouvement, verre au repos), le contenu montré au
// dessus du verrou (vu) et sous lui (contenuBloc), et le clavier, pris de la chute au déverrouillage. Chaque ordre
// reçu est comparé au courant par ordreValable : un ordre périmé est ignoré. À la chute, popover et attention ouverts
// se ferment et le signal tombe() laisse la coque de session fermer lanceur, sélecteur et menu de déconnexion.
// Overlays.verrou est vrai de la chute à la fin de la remontée, presqu'île revenue au verre : la vraie presqu'île
// s'efface dessous, les notifications et les demandes d'autorisation attendent. Sans lanceur, tant que le bloc est
// posé, la coque lit l'état du compositeur chaque seconde : deux lectures franches « rendu » de suite, sans lanceur
// vivant, rendent le clavier et font remonter le bloc. Un lanceur vivant (le script dunei-verrou, dans son unité
// dunei-verrou.scope ou hors d'elle) mène le verrou : ses relances de hyprlock laissent la session un temps
// « rendue », et le bloc doit alors rester. Dans le doute, le bloc reste : seule l'absence certaine d'un lanceur
// compte. demarrer(), appelé par la coque de session, pose le bloc sans chute si la session
// est déjà tenue. Le calque d'apparition se retire d'office après 2,5 s.
// Entrées : IPC « verrou » : tomber, poserSec, apparaitre, ceder, remonter (chacun à ordre, entier), abreger (sans
//           ordre : il ne fait qu'abréger ce qui est en cours) et etat ; demarrer() ; fenetree, vrai par défaut (faux :
//           aucun calque, pour les essais) ; clavierExclusif, vrai par défaut ; lecture, commande qui écrit l'état du
//           compositeur en JSON ({"locked": bool}), hyprctl -j locked borné à 1 s par défaut ; presence, commande
//           qui cherche un lanceur de l'utilisateur (uid de id -u), pgrep borné de même (0 : un lanceur vit, 1 : aucun, tout autre code :
//           indécidable) ; toutes deux remplacées par les essais ; motifLanceur, le motif de pgrep.
// Sorties : ordre ; couvre (bloc voulu posé) ; enPlace (voulu posé, à sa place) ; pose (posé et immobile) ;
//           remonte (remontée demandée, pas finie) ; position (1 posé, 0 caché ; fixe à 1 en mouvement réduit) ;
//           opacite ; matiere (1 image, 0 verre) ;
//           actif (vaut Overlays.verrou) ; montre (calque du bloc mappé : vrai dès actif, faux un tour de boucle après
//           la fin d'actif, s'il ne l'est pas redevenu) ;
//           apparition (calque d'apparition mappé) ; vu ; contenuBloc ; prendClavier ; signal tombe().
// Erreurs : ordre périmé : ignoré ; lecture illisible ou commande absente : la lecture ne compte pas comme rendue ;
//           recherche d'un lanceur indécidable (délai dépassé, erreur de pgrep, commande absente) : le « rendu » ne
//           compte pas et la série n'avance pas ; le bloc reste.
// Dépendances : Quickshell (Singleton, Variants), Quickshell.Io (Process, StdioCollector, IpcHandler), Ressort, Theme
//           (motion.delays : verrouRetrait ; mouvementReduit), C.Overlays (popover, attention, verrou),
//           verrou.js (ordreValable), Bloc.qml, Apparition.qml.
Singleton {
    id: verrou

    property int ordre: 0
    property bool couvre: false
    property bool remonte: false
    property bool apparition: false
    property bool vu: false
    property bool contenuBloc: false
    property bool clavier: false
    property bool fenetree: true
    property bool clavierExclusif: true
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

    // onActifChanged — actif : le calque se mappe aussitôt (une tenue en attente est annulée) ; la remontée finie, plus
    // rien n'est en cours, et le calque tient encore un tour de boucle avant que tenue ne le démappe, s'il est toujours
    // inactif. Entrées : aucune. Sortie : montre, remonte, tenue. Erreurs : aucune.
    onActifChanged: {
        if (actif) { tenue.stop(); montre = true; return }
        remonte = false
        tenue.restart()
    }

    // accepter — retient un ordre s'il n'est pas périmé. Entrée : o, ordre reçu. Sortie : vrai s'il est accepté (ordre
    // devient o). Erreurs : aucune. Dépendances : Logique.ordreValable.
    function accepter(o) {
        if (!Logique.ordreValable(o, ordre)) return false
        ordre = o
        return true
    }

    // couvrir — part vers le bloc posé : clavier pris, contenu retiré, retrait annulé, reste de la coque fermé.
    // Entrées : aucune. Sortie : couvre, clavier, vu, contenuBloc, apparition ; signal tombe(). Erreurs : aucune.
    // Dépendances : retrait, secours, C.Overlays.
    function couvrir() {
        retrait.stop()
        secours.stop()
        remonte = false
        apparition = false
        vu = false
        contenuBloc = false
        clavier = true
        couvre = true
        if (C.Overlays.popover) C.Overlays.popover.ouvert = false
        if (C.Overlays.attention) C.Overlays.attention.ouvert = false
        tombe()
    }

    // tomber — lance la chute du bloc. Entrée : o, ordre. Sortie : aucune. Erreurs : ordre périmé ignoré.
    // Dépendances : accepter, couvrir.
    function tomber(o) { if (accepter(o)) couvrir() }

    // poserSec — pose le bloc sans mouvement, contenu compris (verrou sec : veille, ouverture de session).
    // Entrée : o, ordre. Sortie : aucune. Erreurs : ordre périmé ignoré. Dépendances : accepter, couvrir, poserBloc.
    function poserSec(o) {
        if (!accepter(o)) return
        couvrir()
        poserBloc()
    }

    // poserBloc — pose le bloc et sa presqu'île d'un coup et montre le contenu sous le verrou.
    // Entrées : aucune. Sortie : aucune. Erreurs : aucune. Dépendances : Ressort.poser.
    function poserBloc() {
        descente.poser()
        fondu.poser()
        image.poser()
        contenuBloc = true
    }

    // abreger — une veille est annoncée : la chute se pose et l'apparition se retire, contenu posé dans le bloc.
    // Entrées : aucune. Sortie : aucune. Erreurs : aucune ; hors chute ou pendant une remontée, rien.
    // Dépendances : poserBloc, secours.
    function abreger() {
        if (!couvre) return
        poserBloc()
        secours.stop()
        apparition = false
        vu = false
    }

    // apparaitre — montre le calque d'apparition au-dessus du verrou et y joue l'apparition du contenu ; il se retire
    // d'office après 2,5 s. Entrée : o, ordre. Sortie : aucune. Erreurs : ordre périmé ignoré.
    // Dépendances : accepter, secours.
    function apparaitre(o) {
        if (!accepter(o)) return
        apparition = true
        vu = true
        secours.restart()
    }

    // ceder — hyprlock montre le même contenu : le contenu est posé dans le bloc, sous le verrou, et le calque
    // d'apparition se retire. Entrée : o, ordre. Sortie : aucune. Erreurs : ordre périmé ignoré.
    // Dépendances : accepter, secours.
    function ceder(o) {
        if (!accepter(o)) return
        secours.stop()
        contenuBloc = true
        apparition = false
    }

    // remonter — la session est rendue : clavier rendu aussitôt, contenu retiré en verrouRetrait s'il est montré, puis
    // le bloc remonte depuis sa position. Entrée : o, ordre. Sortie : aucune. Erreurs : ordre périmé ignoré.
    // Dépendances : accepter, relever.
    function remonter(o) { if (accepter(o)) relever() }

    // relever — voir remonter, sans ordre (suivi du compositeur). Entrées : aucune. Sortie : aucune.
    // Erreurs : aucune ; bloc déjà remonté, rien. Dépendances : retrait, secours.
    function relever() {
        clavier = false
        if (!couvre) return
        secours.stop()
        remonte = true
        const montre = vu || contenuBloc
        vu = false
        contenuBloc = false
        if (montre) retrait.restart()
        else finirRetrait()
    }

    // finirRetrait — le contenu retiré, le calque d'apparition part et le bloc remonte. Entrées : aucune. Sortie :
    // couvre, apparition. Erreurs : aucune.
    function finirRetrait() {
        apparition = false
        couvre = false
    }

    // demarrer — lit l'état du compositeur au démarrage de la coque de session ; tenu, le bloc se pose sans chute.
    // Entrées : aucune. Sortie : aucune (voir lire). Erreurs : voir lire. Dépendances : lire.
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

    // compter — un « rendu » lu : compté seulement si la recherche dit qu'aucun lanceur ne vit ; deux de suite font
    // remonter le bloc. Entrée : code, code de sortie de la recherche (0 : lanceur vivant, 1 : aucun lanceur).
    // Sortie : rendus ; clavier rendu et remontée au second. Erreurs : tout autre code (124 au délai, 2 ou 3 en erreur
    // de pgrep) est indécidable : rien ne compte, la série reste où elle est ; bloc qui n'est plus posé, ou lanceur
    // vivant, la série repart de zéro. Dépendances : relever.
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

    Timer { id: retrait; interval: Theme.motion?.delays.verrouRetrait ?? 0; onTriggered: verrou.finirRetrait() }

    // Retrait d'office du calque d'apparition : le contenu est alors posé dans le bloc. Durée provisoire, fixée ici
    // depuis le retrait du délai verrouSecours des jetons ; ce calque disparaît à la réécriture du contrôleur (L2-22).
    Timer {
        id: secours
        interval: 2500
        onTriggered: {
            verrou.contenuBloc = verrou.couvre || verrou.contenuBloc
            verrou.vu = false
            verrou.apparition = false
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
        function apparaitre(ordre: int): void { verrou.apparaitre(ordre) }
        function ceder(ordre: int): void { verrou.ceder(ordre) }
        function remonter(ordre: int): void { verrou.remonter(ordre) }
        function abreger(): void { verrou.abreger() }

        // etat — état rendu au lanceur, en JSON : {pose, ordre, apparition, remonte}. Entrées : aucune. Sortie :
        // texte. Erreurs : aucune.
        function etat(): string {
            return JSON.stringify({ pose: verrou.pose, ordre: verrou.ordre, apparition: verrou.apparition,
                                    remonte: verrou.remonte })
        }
    }
}
