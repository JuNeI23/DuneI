import QtQuick
import "../Theme"
import "../Composants"
import "forme.js" as Forme

// CadrePopovers — cadre de verre unique des popovers de la barre et contenu de chacun (L2-06, L2-56).
// Rôle : partie visuelle et logique de HotePopovers, séparée de la fenêtre de calque pour se charger aussi sous la
// plateforme offscreen des coques d'essai. Trois ressorts au même réglage (bord gauche, bord droit, hauteur) décrivent
// le
// cadre : il naît de l'icône, y retourne, et passe d'un popover à l'autre sans se refermer. Le verre n'est jamais
// estompé, hors mouvement réduit.
// Le contenu de chaque Overlay est construit une fois pour toutes, de façon asynchrone, et reste fixe sur l'écran : le
// cadre le découvre sans le déplacer. Mouvement réduit (Theme.mouvementReduit) : le cadre paraît à sa forme finale (ses
// ressorts, de déplacement, se posent aussitôt) et s'efface ou apparaît par un fondu court de tout le cadre, au ressort
// `reduced` ; il garde sa forme pendant le fondu de sortie, puis se replie sur l'icône. Le verre n'est alors estompé
// que
// pendant ce fondu : sous le seuil ignore_alpha du calque, le flou s'éteint (seule exception à la règle du verre, bible
// ch. 6), et le cadre à pleine opacité retrouve son flou. Au passage, le cadre se pose à la nouvelle forme et les
// contenus se croisent en fondu court. En mouvement normal, l'ancien contenu s'efface aussitôt, le nouveau attend la
// part motion.popover.passage_content_at du trajet et s'affiche au-dessus, et le disque de l'ancienne bascule reste
// plein jusqu'à être recouvert, sauf si le nouveau contenu n'a pas de bascule ronde pour le recouvrir (disque faux) :
// il s'efface alors avec son contenu. Un contenu fermé ne reçoit plus aucun clic, même pendant son fondu : son bouclier
// les arrête,
// car le désactiver (enabled) changerait la couleur de sa bascule sous les yeux. Une fois qu'il ne se voit plus, il est
// remis à neuf par reinitialiser(). Une ouverture faite avant la fin de la construction attend le contenu.
// Entrées : popovers, les Overlay hébergés (heberge: true) de cette barre, dont le contenu offre sur sa racine
// fonduContenu,
// fonduDisque et reinitialiser(), et peut déclarer disque, faux s'il n'a pas de bascule ronde (vrai par défaut) ;
// largeurEcran, largeur de l'écran ; hauteurBarre, hauteur de la barre, sous laquelle se
// tient le cadre.
// Sorties : courant, l'Overlay ouvert parmi popovers, ou null ; affiche, l'Overlay dont le cadre a la forme, ou null ;
// deploye, vrai tant qu'un popover est ouvert ou que le cadre n'a pas fini de se refermer ; passage, vrai tant qu'un
// nouveau contenu attend le trajet du cadre ; sens, réglage des ressorts du cadre ; cadre, l'élément du cadre, dont la
// fenêtre tire son masque de saisie.
// Erreurs : aucune ; avant le chargement des jetons, les ressorts se posent sans animation et les cotes sont nulles. À
// la
// destruction de ce composant, l'Overlay encore ouvert passe à faux, pour ne rester ni au registre ni sans fenêtre.
// Dépendances : Theme (motion, radius, space), Overlays, Ressort, Surface, OmbreElevation, forme.js.
Item {
    id: racine

    property var popovers: []
    property real largeurEcran: 0
    property real hauteurBarre: 0
    readonly property alias cadre: cadre

    readonly property var courant: popovers.indexOf(Overlays.popover) >= 0 ? Overlays.popover : null
    property var affiche: null
    property var vueAffichee: null
    // Vue dont le disque reste plein pendant un passage, null hors passage : l'ancienne, ou celle qu'on rouvre en plein
    // passage. Le disque retenu s'efface avec presence si le popover se ferme avant d'être recouvert.
    property var vueRetenue: null
    readonly property real opaciteAffichee: vueAffichee?.opaciteContenu ?? 1
    // Cadre assez haut pour se dessiner ; la stricte positivité vaut pour le repos d'avant le chargement des jetons.
    readonly property bool dessine: hauteur.value > 0 && hauteur.value >= seuil
    readonly property bool deploye: courant !== null || dessine || hauteur.moving
    readonly property string sens: affiche ? "in" : "out"
    readonly property real seuil: Theme.motion?.popover.rest_threshold_px ?? 0
    readonly property real retrait: Theme.space?.scale[0] ?? 0
    readonly property real marge: Theme.space?.scale[1] ?? 0

    // Ancre et largeur retenues à l'affichage : le cadre garde une place valide si l'ancre bouge ensuite.
    property real ancreX: 0
    property real ancreL: 0
    property real largeurOuverte: 0
    readonly property real hauteurOuverte: vueAffichee?.item ? vueAffichee.item.implicitHeight + 2 * retrait : 0
    // Mouvement réduit : le cadre reste à sa forme ouverte tant que son fondu de sortie n'est pas terminé.
    readonly property bool tenu: affiche !== null || (Theme.mouvementReduit && presence.value > 0)
    readonly property var visee: Forme.cibles(tenu, ancreX, ancreL, largeurOuverte, hauteurOuverte,
                                              largeurEcran, marge)

    // Passage : la distance restante ne dépend pas de passage, que sa notification écrit ; elle ne varie que pendant un
    // mouvement, donc rien ne se calcule au repos.
    property bool passage: false
    property real trajetTotal: 0
    readonly property real reste: Forme.trajet(formeActuelle(), visee)
    readonly property real partPassage: Theme.motion?.popover.passage_content_at ?? 0

    onResteChanged: if (passage && Forme.contenuPermis(passage, reste, trajetTotal, partPassage)) passage = false
    onOpaciteAfficheeChanged: if (opaciteAffichee >= 1) vueRetenue = null
    onDeployeChanged: if (!deploye) vueRetenue = null
    onCourantChanged: {
        if (courant) {
            // Le pointeur a pu rester sur le cadre : le survol passe au nouveau popover, que sa minuterie ne le ferme
            // pas.
            courant.survolCadre = survol.hovered
            // Le contenu choisi peut se faire attendre (pretAMontrer) : le disque de l'ancien tient dès le clic.
            if (affiche && affiche !== courant && !vueRetenue) vueRetenue = vueAffichee
        } else {
            affiche = null
            passage = false
        }
    }
    Component.onDestruction: if (courant) courant.ouvert = false

    // formeActuelle — forme affichée du cadre.
    // Entrées : aucune. Sortie : {gauche, droite, hauteur}. Erreurs : aucune. Dépendances : les trois ressorts.
    function formeActuelle() { return { gauche: gauche.value, droite: droite.value, hauteur: hauteur.value } }

    // montrer — fait prendre au cadre la forme d'un popover dont le contenu est construit.
    // Rôle : retient l'ancre, fige la place du contenu sur l'écran, pose le cadre sur l'icône s'il était fermé, et
    // ouvre
    // un passage si le cadre a un vrai trajet à faire depuis une autre forme.
    // Entrées : ov, l'Overlay ; vue, son Loader, prêt. Sortie : aucune. Erreurs : aucune ; sans ancre, le cadre part du
    // bord gauche de l'écran.
    // Dépendances : Forme (cibles, trajet), Ressort.poser, mapToItem (repère de la fenêtre de la barre, qui couvre la
    // largeur de l'écran).
    function montrer(ov, vue) {
        const ferme = !dessine && !hauteur.moving
        const precedente = affiche ? vueAffichee : null
        ancreX = ov.ancre?.mapToItem(null, 0, 0).x ?? 0
        ancreL = ov.ancre?.width ?? 0
        largeurOuverte = vue.item.implicitWidth + 2 * retrait
        vue.xFixe = Forme.cibles(true, ancreX, ancreL, largeurOuverte, 0, largeurEcran, marge).gauche
        if (ferme) { gauche.poser(); droite.poser() }
        // Le disque déjà retenu reste le seul plein, même si son popover est rouvert, jusqu'à ce que le dernier contenu
        // choisi soit plein. Un contenu sans bascule ronde ne recouvrira jamais l'ancien disque : rien n'est retenu, et
        // l'ancien disque s'efface avec son contenu.
        if (!precedente || !(vue.item.disque ?? true)) vueRetenue = null
        else if (!vueRetenue && precedente !== vue) vueRetenue = precedente
        vueAffichee = vue
        affiche = ov
        trajetTotal = Forme.trajet(formeActuelle(), visee)
        passage = !ferme && trajetTotal > seuil
    }

    Ressort { id: gauche; transition: "overlay"; sens: racine.sens; seuil: racine.seuil; cible: racine.visee.gauche }
    Ressort { id: droite; transition: "overlay"; sens: racine.sens; seuil: racine.seuil; cible: racine.visee.droite }
    Ressort { id: hauteur; transition: "overlay"; sens: racine.sens; seuil: racine.seuil; cible: racine.visee.hauteur }
    Ressort { id: presence; transition: "reveal"; nature: "fondu"; cible: racine.affiche ? 1 : 0 }

    FocusScope {
        id: cadre
        x: gauche.value
        y: racine.hauteurBarre + racine.retrait
        width: droite.value - gauche.value
        height: hauteur.value
        visible: racine.dessine
        // Verre jamais estompé, sauf en mouvement réduit où tout le cadre s'efface en fondu court (objectif 6).
        opacity: Theme.mouvementReduit ? presence.value : 1
        focus: true
        Keys.onEscapePressed: if (racine.courant) racine.courant.ouvert = false

        OmbreElevation { cible: corps; niveau: "e3"; evidee: true }

        Surface {
            id: corps
            anchors.fill: parent
            role: "surfaceRaised"
            radius: Forme.rayon(Theme.radius?.panel ?? 0, cadre.width, cadre.height)
            verre: true
        }

        Item {
            anchors.fill: parent
            clip: true

            Repeater {
                model: racine.popovers

                Loader {
                    id: vue
                    required property var modelData
                    // Un contenu qui connaît sa vraie hauteur un instant après l'ouverture le dit par pretAMontrer : le
                    // cadre
                    // attend pour viser directement sa forme, au lieu de passer par une forme vide (D118).
                    readonly property bool pret: modelData.ouvert && status === Loader.Ready && (item?.pretAMontrer ?? true)
                    readonly property bool estAffichee: racine.vueAffichee === vue
                    readonly property real opaciteContenu: fondu.value
                    readonly property bool retenue: racine.vueRetenue === vue
                    readonly property real opaciteDisque: Forme.opaciteDisque(estAffichee && !retenue, retenue,
                                                                              racine.opaciteAffichee, fondu.value)
                                                          * (retenue ? presence.value : 1)
                    readonly property bool montree: opaciteContenu > 0 || opaciteDisque > 0
                    // Plus rien ne se voit : son fondu est terminé (fin de passage), ou le cadre est refermé, ce qui
                    // arrive
                    // avant la fin de la traîne invisible du fondu.
                    readonly property bool effacee: !montree || !racine.deploye
                    // Place du contenu sur l'écran, figée quand il est montré : le cadre le découvre sans le déplacer.
                    property real xFixe: 0

                    x: xFixe + racine.retrait - cadre.x
                    y: racine.retrait
                    z: estAffichee ? 1 : 0
                    visible: montree
                    focus: modelData.ouvert
                    asynchronous: true
                    sourceComponent: modelData.contenu
                    onLoaded: {
                        item.fonduContenu = Qt.binding(() => vue.opaciteContenu)
                        item.fonduDisque = Qt.binding(() => vue.opaciteDisque)
                    }
                    onPretChanged: if (pret) racine.montrer(modelData, vue)
                    onEffaceeChanged: if (effacee && !modelData.ouvert) item?.reinitialiser()

                    Ressort {
                        id: fondu
                        transition: "reveal"
                        nature: "fondu"
                        cible: vue.pret && !(racine.passage && vue.estAffichee) ? 1 : 0
                    }

                    // Bouclier d'un contenu fermé encore visible, au-dessus de lui : il arrête clics et molette.
                    MouseArea {
                        anchors.fill: parent
                        z: 1
                        enabled: !vue.pret
                        acceptedButtons: Qt.AllButtons
                        onWheel: wheel => wheel.accepted = true
                    }
                }
            }
        }

        HoverHandler {
            id: survol
            onHoveredChanged: if (racine.courant) racine.courant.survolCadre = hovered
        }
    }
}
