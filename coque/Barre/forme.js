.pragma library
.import "../Composants/ancrage.js" as Ancrage

// forme.js — forme et règles de passage du cadre des popovers.
// Rôle : calcule la forme visée du cadre (bords et hauteur), la distance d'un trajet entre deux formes, le moment
// où le contenu peut apparaître pendant un passage, l'opacité du disque de l'ancien popover et le rayon des coins.
// Toutes les fonctions sont pures et sans QML : le cadre des popovers (CadrePopovers) les consomme, et la coque d'essai
// de la barre les expose par IPC. Aucune valeur de mouvement n'y est écrite : les seuils viennent des appelants.
// Dépendances : Composants/ancrage.js (gaucheCadre).

// cibles — forme visée du cadre.
// Rôle : fermé, le cadre se réduit à l'ancre (hauteur nulle) ; ouvert, il prend sa largeur et sa hauteur, son
// bord gauche étant placé sous l'ancre puis serré dans l'écran à la marge demandée.
// Entrées : ouvert, vrai si le popover est ouvert ; ancreX, bord gauche de l'ancre sur l'écran ; ancreL, sa
// largeur ; largeur et hauteur du cadre ouvert ; ecran, largeur de l'écran ; marge, écart gardé avec chaque bord
// de l'écran ; toutes en pixels logiques.
// Sortie : {gauche, droite, hauteur}. Erreurs : aucune ; une ancre de largeur nulle donne une forme finie.
// Dépendances : Ancrage.gaucheCadre.
function cibles(ouvert, ancreX, ancreL, largeur, hauteur, ecran, marge) {
    if (!ouvert) return {gauche: ancreX, droite: ancreX + ancreL, hauteur: 0}
    const gauche = Ancrage.gaucheCadre(false, ancreX, ancreL, null, largeur, ecran, marge)
    return {gauche, droite: gauche + largeur, hauteur}
}

// trajet — distance à parcourir d'une forme à une autre.
// Entrées : depuis et vers, formes {gauche, droite, hauteur}. Sortie : le plus grand des trois écarts absolus,
// en pixels logiques. Erreurs : aucune. Dépendances : aucune.
function trajet(depuis, vers) {
    return Math.max(Math.abs(vers.gauche - depuis.gauche), Math.abs(vers.droite - depuis.droite),
                    Math.abs(vers.hauteur - depuis.hauteur))
}

// contenuPermis — autorise l'apparition du contenu pendant un passage d'un popover à un autre.
// Rôle : hors passage, le contenu est toujours permis ; pendant un passage, il attend que la forme ait parcouru
// la part `seuil` du trajet.
// Entrées : enPassage, vrai pendant un passage ; reste, distance encore à parcourir ; trajetTotal, distance du
// trajet entier ; seuil, part du trajet à franchir, entre 0 et 1.
// Sortie : vrai si le contenu peut apparaître. Erreurs : aucune ; un trajet nul permet le contenu.
// Dépendances : aucune.
function contenuPermis(enPassage, reste, trajetTotal, seuil) {
    return !enPassage || trajetTotal <= 0 || reste / trajetTotal <= 1 - seuil
}

// opaciteDisque — opacité du disque de fond d'un popover.
// Rôle : le disque de l'ancien popover reste plein tant que le nouveau ne l'a pas entièrement recouvert ;
// sinon le disque suit le fondu du contenu.
// Entrées : estAffiche, vrai pour le popover affiché (faux pour l'ancien) ; passageEnCours, vrai pendant un
// passage ; opaciteNouveau, opacité du nouveau popover, de 0 à 1 ; fondu, opacité suivant le fondu du contenu.
// Sortie : l'opacité, de 0 à 1. Erreurs : aucune. Dépendances : aucune.
function opaciteDisque(estAffiche, passageEnCours, opaciteNouveau, fondu) {
    return !estAffiche && passageEnCours && opaciteNouveau < 1 ? 1 : fondu
}

// rayon — rayon des coins du cadre.
// Rôle : le rayon du panneau, plafonné à la moitié du plus petit côté pour qu'une forme étroite ou basse
// garde des coins cohérents.
// Entrées : rayonPanneau, rayon voulu ; largeur et hauteur du cadre, en pixels logiques.
// Sortie : le rayon, jamais négatif. Erreurs : aucune. Dépendances : aucune.
function rayon(rayonPanneau, largeur, hauteur) {
    return Math.max(0, Math.min(rayonPanneau, largeur / 2, hauteur / 2))
}
