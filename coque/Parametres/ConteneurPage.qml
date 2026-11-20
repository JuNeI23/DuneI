import QtQuick
import "../Theme"
import "../Composants"

// ConteneurPage — conteneur de page de l'application Paramètres : défilement, molette lissée et pile de sous-pages.
// Rôle : seul endroit où le défilement d'une page se règle ; aucune page ne s'en occupe. Il réserve un emplacement à
// chaque page du registre, ne construit une page qu'à sa première visite, puis la garde. Chaque emplacement porte sa
// pile : une sous-page poussée glisse depuis la droite (ressort « navigate ») et porte en tête la rangée de retour
// « ‹ <libellé de la page mère> » ; revenir la fait repartir et la détruit une fois sortie. La position de
// défilement est retenue par page et par niveau pendant la vie de la fenêtre : on la retrouve en changeant de page
// comme en revenant d'une sous-page, et une page quittée dans une sous-page y est retrouvée. Un changement de page
// se fait par un fondu-glissé court (ressort « reveal »).
// Molette (Theme.motion.wheel) : à la souris, chaque cran déplace une cible cumulée de wheel.step pixels, rejointe
// par une animation de wheel.duration millisecondes relancée à chaque cran ; au pavé tactile (événement portant un
// déplacement en pixels), la page suit le doigt au pixel, sans animation. En mouvement réduit (Theme.mouvementReduit),
// la page se pose sur sa cible sans animation, les sous-pages changent sans glisser et la page entrante ne garde
// qu'un fondu court.
// Contrat d'une page : un Item qui déclare « property var conteneur » (posé à sa création, pour appeler pousser,
// revenir et montrer), « function atteindre(chemin) » (conduit à un réglage : chemin est l'ancre de recherche.js,
// page comprise) et une implicitHeight ; sa largeur est posée par le conteneur. Une sous-page suit le même contrat et
// peut déclarer « titre », qui nomme le retour des sous-pages ouvertes depuis elle.
// Entrées : pages, les entrées du registre (Registre.pages par défaut) ; page, identifiant de la page montrée
// (EtatParametres.page par défaut).
// Sorties : defilement, le Flickable ; cible, position visée par la molette ; anime, vrai tant que la molette ou
// montrer animent ; maximum, plus grande position de défilement ; niveau, profondeur de la pile de la page montrée
// (0 : page mère) ; courante, la page ou sous-page au sommet ; mere, la page mère montrée ; glisse, vrai tant qu'une
// sous-page glisse ; retour, le libellé de la rangée de retour, vide au niveau 0 ; chargees, identifiants des pages
// construites ; enEvidence, l'élément mis en évidence, null sinon. Fonctions : pousser, revenir, montrer, cran.
// Erreurs : aucune ; une page dont le fichier ne charge pas laisse son emplacement vide, l'erreur de Qt au journal.
// Dépendances : Registre, EtatParametres (page, chemin), Ressort, Bouton, Theme (motion.wheel, motion.delays, space,
// color.accentDiscret, reglages.evidence, radius, mouvementReduit), QtQuick (Flickable, WheelHandler, NumberAnimation).
// Cotes : pages en retrait de reglages.pageMargin ; rangée de retour séparée de sa sous-page de space.scale[1] ; la
// page entrante monte de reglages.pageRise.
// Relief : dnRelief, vrai, que les cartes et les médaillons des pages héritent pour prendre le relief « Doux ».
Item {
    id: conteneur

    property var pages: Registre.pages
    property string page: EtatParametres.page
    property real cible: 0
    // Élément mis en évidence par montrer, null au repos, et son cadre dans le repère du contenu.
    property Item enEvidence: null
    property rect cadre: Qt.rect(0, 0, 0, 0)
    // Emplacement dont le défilement est à l'écran ; il ne suit emplacement qu'une fois la position de l'ancien retenue.
    property Item _montre: null
    readonly property alias defilement: defilement
    readonly property bool anime: elan.running
    readonly property real marge: Theme.reglages?.pageMargin ?? 0
    readonly property bool dnRelief: true
    readonly property real maximum: Math.max(0, defilement.contentHeight - defilement.height)
    // Compte des emplacements posés par le Repeater : sa propriété count change avant que l'élément soit lisible par
    // itemAt quand la fenêtre est construite de façon asynchrone, si bien que les liaisons suivent ce compte-ci.
    property int _poses: 0
    readonly property Item emplacement: { _poses; return emplacements.itemAt(pages.findIndex(p => p.id === page)) }
    readonly property int niveau: emplacement?.pile.length ?? 0
    readonly property Item mere: emplacement?.mere.item ?? null
    readonly property Item courante: niveau ? emplacement.pile[niveau - 1].contenu : mere
    readonly property bool glisse: emplacement?.glissement.moving ?? false
    readonly property string retour: niveau ? emplacement.pile[niveau - 1].retour : ""
    readonly property var chargees: { _poses; return pages.filter((p, i) => emplacements.itemAt(i)?.mere.item).map(p => p.id) }
    // Courbes que la molette sait suivre, sous le nom que leur donne motion.toml (wheel.easing).
    readonly property var courbes: ({ OutCubic: Easing.OutCubic })

    // borner — ramène une position dans la course du défilement. Entrée : y. Sortie : y entre 0 et maximum.
    // Erreurs : aucune. Dépendances : maximum.
    function borner(y) { return Math.max(0, Math.min(maximum, y)) }

    // poser — place le défilement d'un coup, toute animation arrêtée. Entrée : y, position. Sortie : aucune.
    // Erreurs : aucune. Dépendances : elan, defilement.
    function poser(y) {
        elan.stop()
        cible = y
        defilement.contentY = y
    }

    // aller — conduit le défilement à une position, par l'animation de la molette, ou d'un coup en mouvement réduit.
    // Entrée : y, position bornée. Sortie : aucune. Erreurs : aucune. Dépendances : elan, poser, Theme.mouvementReduit.
    function aller(y) {
        if (Theme.mouvementReduit) return poser(y)
        cible = y
        elan.to = y
        elan.restart()
    }

    // cran — applique un événement de molette. Entrées : angle, rotation verticale en huitièmes de degré (120 pour un
    // cran de souris, positif vers le haut) ; pixels, déplacement vertical d'un pavé tactile, 0 pour une souris.
    // Sortie : aucune ; déplace cible et le défilement. Erreurs : aucune. Dépendances : poser, aller, borner,
    // Theme.motion.wheel.
    function cran(angle, pixels) {
        if (pixels !== 0) return poser(borner(defilement.contentY - pixels))
        aller(borner((elan.running ? cible : defilement.contentY) - angle / 120 * (Theme.motion?.wheel?.step ?? 0)))
    }

    // retenir — note la position de défilement du niveau montré d'un emplacement. Entrée : e, l'emplacement.
    // Sortie : aucune ; remplace e.positions. Erreurs : aucune. Dépendances : defilement.
    function retenir(e) {
        const p = e.positions.slice()
        p[e.pile.length] = defilement.contentY
        e.positions = p
    }

    // basculer — passe à l'emplacement de la page demandée : retient la position de l'ancien, construit la page à sa
    // première visite, retrouve sa position et joue le fondu-glissé d'entrée, puis suit l'ancre demandée. Entrées :
    // aucune. Sortie : aucune. Erreurs : aucune ; sans changement d'emplacement, ne fait que suivre l'ancre.
    // Dépendances : emplacement, retenir, poser, entree, suivre.
    function basculer() {
        if (emplacement !== _montre) {
            elan.stop()
            if (_montre) { retenir(_montre); entree.reprendre(0, 0); montee.reprendre(0, 0) }
            _montre = emplacement
            emplacement?.charger()
            poser(emplacement?.positions[emplacement.pile.length] ?? 0)
        }
        suivre()
    }

    // suivre — conduit à l'ancre demandée (EtatParametres.chemin) dès que sa page est montrée et construite : revient
    // à la page mère, lui passe l'ancre, puis consomme la demande. Entrées : aucune. Sortie : aucune. Erreurs :
    // aucune ; sans ancre, ou tant que la page n'est pas construite, ne fait rien. Dépendances : EtatParametres,
    // mere, revenir.
    function suivre() {
        const chemin = EtatParametres.chemin
        if (!chemin.length || chemin[0] !== page || !mere || emplacement !== _montre) return
        EtatParametres.chemin = []
        while (niveau) revenir()
        mere.atteindre(chemin)
    }

    // pousser — ouvre une sous-page au-dessus de la page ou sous-page montrée. Entrées : composant, un Component ou
    // l'URL d'un fichier QML qui suit le contrat d'une page ; proprietes, ses propriétés initiales (objet, facultatif).
    // Sortie : la sous-page créée, null sans emplacement ou si sa création échoue. Erreurs : celles de la création, au
    // journal de Qt. Dépendances : gabarit, retenir, poser.
    function pousser(composant, proprietes) {
        const e = emplacement
        if (!e) return null
        e.nettoyer()
        retenir(e)
        const n = e.pile.length
        const etage = gabarit.createObject(e, { rang: n + 1, hote: e, retour: n ? e.pile[n - 1].contenu?.titre ?? "" : e.modelData.libelle })
        const c = composant.createObject ? composant : Qt.createComponent(composant)
        etage.contenu = c.createObject(etage, Object.assign({ conteneur: conteneur }, proprietes))
        if (etage.contenu) etage.contenu.width = Qt.binding(() => etage.width)
        e.pile = e.pile.concat(etage)
        poser(0)
        return etage.contenu
    }

    // revenir — quitte la sous-page montrée pour celle du dessous, dont la position de défilement est retrouvée ; la
    // sous-page quittée glisse hors de la vue, puis est détruite. Entrées : aucune. Sortie : aucune. Erreurs : aucune ;
    // au niveau 0, ne fait rien. Dépendances : retenir, poser, nettoyer de l'emplacement.
    function revenir() {
        const e = emplacement
        const n = e?.pile.length ?? 0
        if (!n) return
        retenir(e)
        e.sortants = e.sortants.concat(e.pile[n - 1])
        e.pile = e.pile.slice(0, n - 1)
        poser(e.positions[n - 1] ?? 0)
        if (!e.glissement.moving) e.nettoyer()
    }

    // montrer — fait défiler jusqu'à un élément de la page montrée et le met en évidence un court instant
    // (motion.delays.copied). Entrée : item, un descendant de la page. Sortie : aucune. Erreurs : aucune ; un
    // élément nul ne fait rien. Dépendances : viser, extinction.
    function montrer(item) {
        if (!item) return
        enEvidence = item
        viser()
        extinction.restart()
    }

    // viser — vise l'élément en évidence : relève son cadre et y conduit le défilement. Rappelée quand la hauteur du
    // contenu change, pour un élément dont la page vient d'être construite et n'est pas encore mise en page.
    // Entrées : aucune. Sortie : aucune. Erreurs : aucune ; sans élément en évidence, ne fait rien.
    // Dépendances : enEvidence, aller, borner.
    function viser() {
        if (!enEvidence) return
        cadre = enEvidence.mapToItem(contenu, 0, 0, enEvidence.width, enEvidence.height)
        aller(borner(cadre.y))
    }

    onEmplacementChanged: basculer()
    Component.onCompleted: basculer()
    Connections {
        target: EtatParametres
        function onCheminChanged() { conteneur.suivre() }
    }
    Connections {
        target: conteneur.enEvidence ? defilement : null
        function onContentHeightChanged() { conteneur.viser() }
    }
    Timer { id: extinction; interval: Theme.motion?.delays.copied ?? 0; onTriggered: conteneur.enEvidence = null }

    NumberAnimation {
        id: elan
        target: defilement
        property: "contentY"
        duration: Theme.motion?.wheel?.duration ?? 0
        easing.type: conteneur.courbes[Theme.motion?.wheel?.easing] ?? Easing.OutCubic
    }

    // Fondu-glissé de la page entrante : 1 au repos, repris de 0 à chaque changement de page.
    Ressort { id: entree; transition: "reveal"; nature: "fondu"; cible: 1 }
    // La montée de la page a son propre ressort : un ressort de fondu ne porte jamais de déplacement, pour que le
    // mouvement réduit pose la position d'un coup tout en gardant le fondu.
    Ressort { id: montee; transition: "reveal"; cible: 1 }
    Ressort { id: evidence; transition: "state"; nature: "fondu"; cible: conteneur.enEvidence ? 1 : 0 }

    // Étage de la pile : la rangée de retour, puis la sous-page. Son abscisse suit le ressort de son emplacement ;
    // hors du sommet, il reste là où son défilement l'avait laissé.
    Component {
        id: gabarit
        Column {
            id: etage
            required property int rang
            required property Item hote
            required property string retour
            property Item contenu: null
            width: hote.width
            x: (rang - hote.glissement.value) * defilement.width
            y: hote.decalage(rang)
            visible: Math.abs(rang - hote.glissement.value) < 1
            spacing: Theme.space?.scale[1] ?? 0
            Bouton { objectName: "retour"; text: "‹ " + etage.retour; onClicked: conteneur.revenir() }
        }
    }

    Flickable {
        id: defilement
        anchors.fill: parent
        clip: true
        interactive: false
        boundsBehavior: Flickable.StopAtBounds
        contentHeight: (conteneur._montre?.hauteur ?? 0) + 2 * conteneur.marge

        // La molette est prise après les enfants : un contrôle qui la consomme (une liste, un compteur) la garde.
        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: event => conteneur.cran(event.angleDelta.y, event.pixelDelta.y)
        }

        Item {
            id: contenu
            x: conteneur.marge
            y: conteneur.marge + (Theme.mouvementReduit ? 0 : (1 - montee.value) * (Theme.reglages?.pageRise ?? 0))
            width: defilement.width - 2 * x
            opacity: entree.value

            Repeater {
                id: emplacements
                model: conteneur.pages
                onItemAdded: conteneur._poses++
                onItemRemoved: conteneur._poses++

                Item {
                    id: emplacement
                    required property var modelData
                    readonly property bool courant: modelData.id === conteneur.page
                    // Étages des sous-pages ouvertes, du plus ancien au sommet ; sortants, ceux qui glissent hors de la vue.
                    property var pile: []
                    property var sortants: []
                    // Position de défilement retenue pour chaque niveau, page mère en tête.
                    property var positions: [0]
                    readonly property alias mere: mere
                    readonly property alias glissement: glissement
                    readonly property real hauteur: (pile.length ? pile[pile.length - 1].implicitHeight : mere.item?.implicitHeight) ?? 0

                    // charger — construit la page mère à la première visite. Entrées : aucune. Sortie : aucune.
                    // Erreurs : celles du chargement, au journal de Qt. Dépendances : modelData.composant.
                    function charger() { if (mere.status === Loader.Null) mere.setSource(modelData.composant, { conteneur: conteneur }) }

                    // decalage — ordonnée d'un niveau : 0 au sommet ; ailleurs, celle qui le laisse à l'écran là où
                    // son défilement l'avait laissé. Entrée : rang, 0 pour la page mère. Sortie : ordonnée.
                    // Erreurs : aucune. Dépendances : pile, positions, defilement.
                    function decalage(rang) { return rang === pile.length ? 0 : defilement.contentY - (positions[rang] ?? 0) }

                    // nettoyer — détruit les étages sortis de la vue. Entrées : aucune. Sortie : aucune.
                    // Erreurs : aucune. Dépendances : sortants.
                    function nettoyer() {
                        sortants.forEach(s => s.destroy())
                        sortants = []
                    }

                    width: contenu.width
                    visible: courant

                    Ressort {
                        id: glissement
                        transition: "navigate"
                        cible: emplacement.pile.length
                        onMovingChanged: if (!moving) emplacement.nettoyer()
                    }
                    Loader {
                        id: mere
                        width: parent.width
                        x: -glissement.value * defilement.width
                        y: emplacement.decalage(0)
                        visible: glissement.value < 1
                    }
                }
            }

            // Mise en évidence : un voile color.accentDiscret sur le cadre de l'élément atteint, sans contour ni ombre,
            // qui paraît puis s'éteint en fondu jusqu'à l'opacité reglages.evidence au plus : posé au-dessus de la page,
            // il laisse lire le réglage, et ne reprend ni l'aplat ni la teinte de la plaque du curseur. Il reste sur le
            // dernier cadre pendant son extinction.
            Rectangle {
                x: conteneur.cadre.x
                y: conteneur.cadre.y
                width: conteneur.cadre.width
                height: conteneur.cadre.height
                visible: opacity > 0
                opacity: evidence.value * (Theme.reglages?.evidence ?? 0)
                radius: Theme.radius?.control ?? 0
                color: Theme.color?.accentDiscret ?? "transparent"
            }
        }
    }
}
