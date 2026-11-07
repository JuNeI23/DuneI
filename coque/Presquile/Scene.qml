import QtQuick
import "../Theme"

// Scene — contenu de la presqu'île : le module monté, sa taille animée et le changement de module (L2-46, L2-48).
// Rôle : instancie le module de contenu pour l'écran, centré dans son cadre, et porte la taille du corps de l'encoche
// par deux Ressorts « window » de nature « deplacement » dont la cible suit la taille du module. Au premier montage,
// la taille se pose d'un coup. Ensuite, changer de module déroule une séquence en trois temps : l'ancien contenu
// s'efface par un Ressort d'opacité « reveal » de nature « fondu » (phase « sortie ») ; à opacité nulle, le nouveau
// module est monté, invisible, et la forme s'étire vers sa taille (phase « forme ») ; quand le reste à parcourir des
// deux ressorts de taille passe sous la part seuilEntree de leur écart initial, le nouveau contenu apparaît (phase
// « entree ») ; la scène revient au « repos » quand plus rien ne bouge. Un changement pendant la forme ou l'entrée
// reprend en sortie depuis l'opacité et la taille courantes, sans saut ; un changement pendant la sortie la laisse
// finir et monte le dernier module demandé. Mouvement réduit : la taille se pose aussitôt, seuls les fondus restent.
// Entrées : ecran, l'écran transmis au module ; module, le composant de contenu, un Item déclarant implicitWidth et
//           implicitHeight et recevant ecran.
// Sorties : contenu, le module monté (null avant le premier montage ou si le composant échoue) ; phase, « repos »,
//           « sortie », « forme » ou « entree » ; ressortLargeur, ressortHauteur et ressortOpacite, les trois ressorts,
//           lus par la surface et les essais ; width et height suivent les ressorts de taille.
// Erreurs : un composant sans Item valide laisse contenu nul, se lit au journal de Quickshell, et la séquence se
//           termine sur une forme de largeur nulle ; un module sans hauteur laisse la hauteur des jetons.
// Dépendances : Ressort, Theme (tokens.presquile.hauteur, motion.json par Ressort).
Item {
    id: scene

    property var ecran: null
    property Component module: null
    property Item contenu: null
    readonly property string phase: _phase
    readonly property alias ressortLargeur: largeur
    readonly property alias ressortHauteur: hauteur
    readonly property alias ressortOpacite: opacite
    // Part de l'écart de taille initial sous laquelle le nouveau contenu commence d'apparaître ; choisie par le plan,
    // réglable à la recette.
    readonly property real seuilEntree: 0.1

    property string _phase: "repos"
    property bool _pret: false
    property bool _montage: false
    property real _ecartLargeur: 0
    property real _ecartHauteur: 0

    width: largeur.value
    height: hauteur.value

    Ressort {
        id: largeur
        transition: "window"
        nature: "deplacement"
        cible: scene.contenu?.implicitWidth ?? 0
        onValueChanged: scene.avancer()
        onMovingChanged: Qt.callLater(scene.avancer)
    }
    Ressort {
        id: hauteur
        transition: "window"
        nature: "deplacement"
        cible: scene.contenu?.implicitHeight || (Theme.tokens?.presquile?.hauteur ?? 0)
        onValueChanged: scene.avancer()
        onMovingChanged: Qt.callLater(scene.avancer)
    }
    Ressort { id: opacite; transition: "reveal"; nature: "fondu"; cible: 1; onMovingChanged: Qt.callLater(scene.avancer) }

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
        contenu?.destroy()
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

    // proche — dit si un ressort de taille a parcouru tout son écart initial sauf la part seuilEntree.
    // Entrées : r, le ressort ; ecart, l'écart à sa cible au début de la forme. Sortie : booléen. Erreurs : aucune.
    // Dépendances : seuilEntree.
    function proche(r, ecart) { return Math.abs(r.cible - r.value) <= seuilEntree * ecart }

    // avancer — fait progresser la séquence d'autant de phases que l'état des ressorts le permet.
    // Entrées : aucune ; appelée à chaque image des ressorts de taille, et après chaque arrêt ou départ d'un ressort,
    // au tour de boucle suivant (Qt.callLater) : relancer un ressort pendant le signal de son propre arrêt formerait
    // une boucle de liaison sur moving.
    // Sortie : met à jour _phase, monte le nouveau module à la fin de la sortie, lance le fondu d'entrée.
    // Erreurs : aucune ; sans effet pendant un montage, dont les ressorts posés en mouvement réduit la rappellent.
    // Dépendances : monter, proche, les trois ressorts.
    function avancer() {
        if (_montage) return
        if (_phase === "sortie" && !opacite.moving && opacite.value === 0) {
            const l = largeur.value, h = hauteur.value
            _phase = "forme"
            monter()
            _ecartLargeur = Math.abs(largeur.cible - l)
            _ecartHauteur = Math.abs(hauteur.cible - h)
        }
        if (_phase === "forme" && proche(largeur, _ecartLargeur) && proche(hauteur, _ecartHauteur)) {
            _phase = "entree"
            opacite.cible = 1
        }
        if (_phase === "entree" && !opacite.moving && opacite.value === 1 && !largeur.moving && !hauteur.moving)
            _phase = "repos"
    }

    onModuleChanged: changer()
    Component.onCompleted: { _pret = true; changer() }
}
