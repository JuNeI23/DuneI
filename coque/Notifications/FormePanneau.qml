import QtQuick
import "../Theme"
import "../Presquile"

// FormePanneau — forme animée du panneau des notifications et son contenu (L2-67).
// Rôle : la partie de FenetrePanneau qui se charge sans fenêtre de calque. Elle remplit la surface, de taille
// constante, et y fait vivre la presqu'île latérale : une Encoche collée au bord droit (verre glass.presquile), dont
// l'évasement du haut part du haut de la surface. La forme bouge, la surface ne bouge pas (D132, D134).
// Séquence, sur les ressorts et les seuils de la presqu'île (D124) : à l'ouverture (phase « forme »), le corps sort du
// bord droit jusqu'à panneau.largeur et s'étire, depuis panneau.hauteurMin, à la hauteur de son contenu ; quand il
// ne lui reste plus que la part presquile.entree de sa largeur à parcourir, le contenu paraît en fondu (phase
// « entree »). À la fermeture (phase « sortie »), le contenu s'efface ; dès que son opacité passe sous
// presquile.sortie, la forme se rétracte dans le bord, puis le contenu est démonté. En mouvement réduit, la forme se
// pose d'un coup et seuls les fondus durent. Ouvert, le corps suit au même ressort la hauteur du contenu, qui change
// quand une entrée part ou qu'un groupe se déplie.
// Le contenu (Panneau) n'est monté que tant que la forme est sortie ; il garde la largeur du panneau pendant que la
// forme s'étire, découpé au corps. Il prend le focus à l'ouverture ; Échap émet fermer().
// Entrées : attente, l'Attente montrée ; ouvert, l'état voulu.
// Sorties : phase (« repos », « forme », « entree » ou « sortie ») ; charge, vrai tant que la forme est sortie, même
// en partie (le contenu est monté et le masque de saisie couvre le corps) ; corps, le rectangle du corps, masque de
// saisie de la fenêtre ; largeurForme et hauteurForme, taille courante du corps ; opaciteContenu ; marge, débord de
// l'ombre de la forme, à réserver à gauche par la fenêtre ; signal fermer().
// Erreurs : aucune ; sans jetons chargés, la forme est de taille nulle.
// Dépendances : Encoche (côté droit), Panneau, Ressort, Theme (panneau, tokens.presquile).
Item {
    id: forme

    property QtObject attente: null
    property bool ouvert: false

    readonly property real largeurPanneau: Theme.panneau?.largeur ?? 0
    readonly property real hauteurMin: Theme.panneau?.hauteurMin ?? 0
    readonly property real evasement: Theme.tokens?.presquile?.evasement ?? 0
    // Hauteur offerte au corps : celle de la surface, moins les deux évasements et le débord de l'ombre en bas.
    readonly property real hauteurMax: Math.max(hauteurMin, height - 2 * evasement - encoche.marge)
    // La forme reste sortie tant que le panneau est ouvert, puis tant que son contenu n'est pas assez effacé.
    readonly property bool deployee: ouvert || opacite.value > (Theme.tokens?.presquile?.sortie ?? 0)
    // Le contenu paraît quand la largeur n'a plus que la part « entree » à parcourir.
    readonly property bool montre: ouvert && largeurPanneau > 0
        && (largeurPanneau - largeur.value) / largeurPanneau <= (Theme.tokens?.presquile?.entree ?? 0)
    readonly property bool charge: ouvert || largeur.value > 0 || largeur.moving
    readonly property string phase: ouvert ? (!montre ? "forme" : opacite.moving ? "entree" : "repos")
                                           : charge ? "sortie" : "repos"
    readonly property Item corps: encoche.corps
    readonly property real largeurForme: largeur.value
    readonly property real hauteurForme: hauteur.value
    readonly property real opaciteContenu: opacite.value
    readonly property real marge: encoche.marge

    signal fermer()

    Ressort { id: largeur; transition: "window"; cible: forme.deployee ? forme.largeurPanneau : 0 }
    Ressort {
        id: hauteur
        transition: "window"
        cible: forme.deployee && contenu.item ? contenu.item.implicitHeight : forme.hauteurMin
    }
    Ressort { id: opacite; transition: "reveal"; nature: "fondu"; cible: forme.montre ? 1 : 0 }

    Encoche {
        id: encoche
        cote: "droite"
        x: forme.width - width
        largeurCorps: Math.max(0, largeur.value)
        hauteur: Math.max(0, hauteur.value)
        visible: forme.charge
    }

    // Le contenu, à la largeur du panneau et calé à droite, découpé au corps de la forme qui s'étire.
    Item {
        x: encoche.x
        y: forme.evasement
        width: encoche.width
        height: encoche.hauteur
        clip: true
        opacity: Math.max(0, Math.min(1, opacite.value))

        Loader {
            id: contenu
            x: parent.width - width
            width: forme.largeurPanneau
            height: parent.height
            active: forme.charge
            focus: true
            Keys.onEscapePressed: forme.fermer()
            onLoaded: item.forceActiveFocus()
            sourceComponent: Panneau {
                attente: forme.attente
                hauteurMax: forme.hauteurMax
            }
        }
    }
}
