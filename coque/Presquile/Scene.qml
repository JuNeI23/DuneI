import QtQuick
import "../Theme"

// Scene — contenu de la presqu'île : le module monté, sa taille animée et le changement de module (L2-46, L2-48).
// Rôle : instancie le module de contenu pour l'écran, centré dans son cadre, et porte la taille du corps de l'encoche
// par deux Ressorts « window » de nature « deplacement » dont la cible suit la taille du module. Au premier montage,
// la taille se pose d'un coup. Ensuite, changer de module déroule une séquence en trois temps : l'ancien contenu
// s'efface par un Ressort d'opacité « reveal » de nature « fondu » (phase « sortie ») ; dès que son opacité passe sous
// seuilSortie (jeton presquile.sortie), il est confié au conteneur de départ, découpé à la forme, où il finit son fondu
// toujours centré puis est détruit, pendant que le nouveau module est monté, invisible, et que la forme s'étire vers sa
// taille (phase « forme ») : sortie et étirement se chevauchent. Quand le reste à parcourir des deux ressorts de taille
// passe sous la part seuilEntree (jeton presquile.entree) de leur écart de référence, le nouveau contenu apparaît
// (phase « entree ») ; cet écart est pris au montage, puis repris depuis la position courante si la taille du module
// change pendant la forme (contenu chargé après coup) ; la scène revient au « repos » quand plus rien ne bouge et que
// l'ancien contenu est détruit. Un changement pendant la forme ou l'entrée reprend en sortie depuis l'opacité et la
// taille courantes, sans saut ; un changement pendant la sortie la laisse finir et monte le dernier module demandé.
// Un seul ancien contenu part à la fois : tant qu'il n'est pas détruit, la sortie suivante attend, sous le seuil, que
// son conteneur soit libre. Mouvement réduit : la taille se pose aussitôt, seuls les fondus restent.
// La scène donne aussi la hauteur que doit réserver la surface (hauteurSurface) : elle monte d'un coup à la cible du
// ressort de hauteur quand elle est plus grande, et ne redescend qu'à son arrêt, jamais image par image : chaque
// changement de taille d'une surface de calque passe par un aller-retour avec le compositeur.
// Entrées : ecran, l'écran transmis au module ; module, le composant de contenu, un Item déclarant implicitWidth et
//           implicitHeight et recevant ecran.
// Sorties : contenu, le module monté (null avant le premier montage ou si le composant échoue) ; phase, « repos »,
//           « sortie », « forme » ou « entree » ; ressortLargeur, ressortHauteur et ressortOpacite, les trois ressorts,
//           lus par la surface et les essais ; sortant, l'ancien contenu qui finit de s'effacer (null sinon), et
//           ressortSortant, le ressort de son opacité ; width et height suivent les ressorts de taille ; hauteurSurface, la
//           hauteur que la surface réserve à l'encoche, stable pendant tout mouvement de la hauteur.
// Erreurs : un composant sans Item valide laisse contenu nul, se lit au journal de Quickshell, et la séquence se
//           termine sur une forme de largeur nulle ; un module sans hauteur laisse la hauteur des jetons.
// Dépendances : Ressort, Theme (tokens.presquile.hauteur, entree et sortie, motion.json par Ressort).
Item {
    id: scene

    property var ecran: null
    property Component module: null
    property Item contenu: null
    readonly property string phase: _phase
    readonly property alias ressortLargeur: largeur
    readonly property alias ressortHauteur: hauteur
    readonly property alias ressortOpacite: opacite
    readonly property real hauteurSurface: _hauteurSurface
    // Part de l'écart de taille sous laquelle le nouveau contenu commence d'apparaître (jeton presquile.entree,
    // réglable à la recette) ; sans jeton, 0 : l'entrée attend que la forme soit posée.
    readonly property real seuilEntree: Theme.tokens?.presquile?.entree ?? 0
    // Opacité de l'ancien contenu sous laquelle la forme commence de s'étirer (jeton presquile.sortie) ; sans jeton, 0 :
    // l'étirement attend que l'ancien contenu soit effacé.
    readonly property real seuilSortie: Theme.tokens?.presquile?.sortie ?? 0
    // Ancien contenu qui finit de s'effacer pendant l'étirement (null sinon), et le ressort de son opacité.
    readonly property Item sortant: _sortant
    readonly property alias ressortSortant: effacement

    property string _phase: "repos"
    property bool _pret: false
    property bool _montage: false
    property real _ecartLargeur: 0
    property real _ecartHauteur: 0
    property real _hauteurSurface: 0
    property Item _sortant: null

    width: largeur.value
    height: hauteur.value

    Ressort {
        id: largeur
        transition: "window"
        nature: "deplacement"
        cible: scene.contenu?.implicitWidth ?? 0
        // Une taille du module connue après coup, pendant la forme, redéfinit l'écart depuis la position courante.
        onCibleChanged: if (scene._phase === "forme") scene._ecartLargeur = Math.abs(cible - value)
        onValueChanged: scene.avancer()
        onMovingChanged: Qt.callLater(scene.avancer)
    }
    Ressort {
        id: hauteur
        transition: "window"
        nature: "deplacement"
        cible: scene.contenu?.implicitHeight || (Theme.tokens?.presquile?.hauteur ?? 0)
        onCibleChanged: if (scene._phase === "forme") scene._ecartHauteur = Math.abs(cible - value)
        onValueChanged: scene.avancer()
        onMovingChanged: Qt.callLater(scene.avancer)
    }
    // Hauteur réservée par la surface, recalculée à chaque changement du ressort de hauteur.
    Connections {
        target: hauteur
        function onCibleChanged() { scene.tenir() }
        function onValueChanged() { scene.tenir() }
        function onMovingChanged() { scene.tenir() }
    }
    Ressort {
        id: opacite
        transition: "reveal"
        nature: "fondu"
        cible: 1
        // Au tour de boucle suivant : céder l'ancien contenu pose ce même ressort, ce qui ne peut se faire pendant le
        // signal de sa propre valeur.
        onValueChanged: if (scene._phase === "sortie") Qt.callLater(scene.avancer)
        onMovingChanged: Qt.callLater(scene.avancer)
    }
    Ressort { id: effacement; transition: "reveal"; nature: "fondu"; cible: 0; onMovingChanged: Qt.callLater(scene.avancer) }

    // Conteneur de l'ancien contenu pendant le chevauchement : découpé à la forme, pour qu'un contenu plus large que
    // l'encoche qui se rétracte n'en déborde pas.
    Item {
        id: depart
        anchors.fill: parent
        clip: true
        opacity: effacement.value
    }

    // Conteneur du module, dont l'opacité porte les fondus.
    Item {
        id: montage
        anchors.fill: parent
        opacity: opacite.value
    }

    // monter — instancie le module pour l'écran, centré dans la scène, à la place du précédent.
    // Entrées : aucune (lit module et ecran). Sortie : met à jour contenu. Erreurs : un composant sans Item valide
    // laisse contenu nul et se lit au journal de Quickshell. Dépendances : module, montage.
    function monter() {
        _montage = true
        if (contenu !== _sortant) contenu?.destroy()
        const m = module?.createObject(montage, { ecran: scene.ecran }) ?? null
        contenu = m
        if (m) {
            m.x = Qt.binding(() => (scene.width - m.implicitWidth) / 2)
            m.y = Qt.binding(() => (scene.height - m.implicitHeight) / 2)
        }
        _montage = false
    }

    // changer — répond à un nouveau module : premier montage posé, ou séquence relancée en sortie.
    // Entrées : aucune (lit module, contenu). Sortie : monte le module ou passe en phase « sortie ». Erreurs : aucune.
    // Dépendances : monter, avancer, Ressort.poser.
    function changer() {
        if (!_pret) return
        // Au premier montage, l'encoche prend sa taille d'un coup : elle ne naît pas de la largeur nulle.
        if (!contenu) { monter(); largeur.poser(); hauteur.poser(); return }
        _phase = "sortie"
        opacite.cible = 0
        avancer()
    }

    // tenir — met à jour la hauteur réservée par la surface : tant que le ressort de hauteur avance, la plus grande
    // des hauteurs déjà réservées et de sa cible ; à l'arrêt, la plus grande de sa valeur et de sa cible, donc sa
    // cible une fois posé, ou sa valeur d'avant tant qu'un rétrécissement n'a pas démarré.
    // Entrées : aucune ; appelée à chaque changement de valeur, de cible ou de mouvement du ressort de hauteur.
    // Sortie : met à jour _hauteurSurface, qui ne change donc qu'au départ d'un mouvement (s'il agrandit) et à son
    // arrêt (s'il rétrécit). Le léger dépassement du ressort « window » au-dessus de sa cible n'est pas suivi : il
    // déborde de moins d'un pixel dans la marge de l'ombre, que la surface réserve sous l'encoche.
    // Erreurs : aucune. Dépendances : hauteur.
    function tenir() {
        _hauteurSurface = Math.max(hauteur.cible, hauteur.moving ? _hauteurSurface : hauteur.value)
    }

    // ceder — confie le contenu courant au conteneur de départ, où il finit son fondu depuis son opacité courante
    // (le ressort de départ reprend la position et la vitesse de celui du module : le fondu continue sans palier),
    // toujours centré dans la scène ; le conteneur du module repasse
    // à l'opacité 0 pour le contenu suivant.
    // Entrées : aucune. Sortie : met à jour _sortant. Erreurs : aucune ; appelée seulement quand aucun ancien contenu
    // n'est en train de partir. Dépendances : depart, effacement, opacite.
    function ceder() {
        _sortant = contenu
        if (contenu) contenu.parent = depart
        effacement.reprendre(opacite.value, opacite.vitesse())
        opacite.cible = 0
        opacite.poser()
        Qt.callLater(avancer)
    }

    // proche — dit si un ressort de taille a parcouru tout son écart de référence sauf la part seuilEntree.
    // Entrées : r, le ressort ; ecart, l'écart à sa cible au montage, ou au dernier changement de cible pendant la
    // forme. Sortie : booléen. Erreurs : aucune.
    // Dépendances : seuilEntree.
    function proche(r, ecart) { return Math.abs(r.cible - r.value) <= seuilEntree * ecart }

    // avancer — fait progresser la séquence d'autant de phases que l'état des ressorts le permet.
    // Entrées : aucune ; appelée à chaque image des ressorts de taille et, pendant la sortie, de l'opacité, et après
    // chaque arrêt ou départ d'un ressort,
    // au tour de boucle suivant (Qt.callLater) : relancer un ressort pendant le signal de son propre arrêt formerait
    // une boucle de liaison sur moving.
    // Sortie : met à jour _phase ; sous le seuil de sortie, cède l'ancien contenu et monte le nouveau module ; lance le
    // fondu d'entrée ; détruit l'ancien contenu une fois effacé.
    // Erreurs : aucune ; sans effet pendant un montage, dont les ressorts posés en mouvement réduit la rappellent.
    // Dépendances : monter, ceder, proche, les quatre ressorts.
    function avancer() {
        if (_montage) return
        // L'ancien contenu effacé est détruit ; tant qu'il ne l'est pas, aucun autre ne peut partir.
        if (_sortant && !effacement.moving && effacement.value === 0) {
            const s = _sortant
            _sortant = null
            if (s !== contenu) s.destroy()
        }
        if (_phase === "sortie" && !_sortant && opacite.value <= seuilSortie) {
            const l = largeur.value, h = hauteur.value
            _phase = "forme"
            ceder()
            monter()
            _ecartLargeur = Math.abs(largeur.cible - l)
            _ecartHauteur = Math.abs(hauteur.cible - h)
        }
        if (_phase === "forme" && proche(largeur, _ecartLargeur) && proche(hauteur, _ecartHauteur)) {
            _phase = "entree"
            opacite.cible = 1
        }
        if (_phase === "entree" && !opacite.moving && opacite.value === 1 && !largeur.moving && !hauteur.moving
                && !_sortant)
            _phase = "repos"
    }

    onModuleChanged: changer()
    Component.onCompleted: { _pret = true; changer(); tenir() }
}
