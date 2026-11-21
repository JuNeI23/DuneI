import QtQuick
import "../Theme"
import "etats.js" as Etats

// ZoneCurseur — plaque du curseur posée derrière un contrôle isolé, qui n'a ni rangée ni plaque naturelle.
// Rôle : depuis que l'anneau de focus a disparu (L2-73), un contrôle seul (la bascule Wi-Fi d'un popover, un
// interrupteur d'en-tête, une jauge, un bouton texte comme « Actualiser ») montrerait son focus clavier par rien.
// La zone enveloppe ce contrôle et suit le curseur de sa vue (Etat.suitCurseur) : survolée, ou quand le contrôle a
// le focus clavier (visualFocus, ou activeFocus pour un simple Item atteint à la tabulation), et tant que le contrôle
// est actif (enabled : un contrôle désactivé ne prend jamais le curseur), elle prend le curseur
// et peint derrière lui l'aplat de la plaque des listes (Etat.curseurAplat : color.accent, ou l'accent sans chroma
// sous inactive), sans ombre, au rayon radius.control, débordant de marge autour du contrôle sans changer sa mise en
// page. La plaque paraît et s'efface au ressort des états ; hors du curseur, elle est transparente. Sous le curseur,
// la zone déclare dnSurPlaque : un contrôle allumé s'y inverse (Etat.inverseSurPlaque) ; un contenu qui peint son
// propre texte prend etat.texte, neutre au repos et au sur-accent sur la plaque.
// Entrées : le contrôle, déclaré comme unique enfant (cible) : la zone l'adopte et il la remplit ; marge, débord de
// la plaque autour du contrôle, space.scale[0] par défaut ; marque, vrai par défaut : faux, la zone n'est plus
// qu'une enveloppe neutre, qui ne prend jamais le curseur et ne peint rien, et le contrôle garde son propre survol
// (les popovers, où Nicolas a refusé la plaque autour des glyphes et des jauges, recette de L2-73).
// Sorties : etat, l'Etat de la plaque (couleurs, sousCurseur) ; hovered, visualFocus, down (down du contrôle, ou
// pressed pour un gabarit qui n'a pas down, comme T.Slider), lus par l'Etat ;
// dnSurPlaque, vrai sous le curseur ; plaque, le rectangle peint, lu par les essais.
// Taille : la taille implicite du contrôle ; posée par l'appelant (largeur d'une mise en page), elle s'impose au
// contrôle.
// Erreurs : aucune ; sans contrôle, la zone est nulle et ne prend jamais le focus.
// Dépendances : Etat, VueCurseur (par Etat), Theme (space, radius), etats.js (cran, herite).
Item {
    id: zone

    default property Item cible
    property real marge: Theme.space?.scale[0] ?? 0
    property bool marque: true
    readonly property alias etat: etat
    readonly property alias plaque: plaque
    readonly property bool actif: marque && (cible?.enabled ?? false)
    readonly property bool hovered: survol.hovered && actif
    readonly property bool visualFocus: actif && (cible.visualFocus ?? cible.activeFocus)
    readonly property bool down: (cible?.down ?? cible?.pressed) === true
    readonly property bool dnSurPlaque: etat.sousCurseur

    implicitWidth: cible?.implicitWidth ?? 0
    implicitHeight: cible?.implicitHeight ?? 0

    // adopter — fait du contrôle déclaré un enfant visuel de la zone, au-dessus de la plaque, qu'il remplit.
    // Entrées : aucune (cible). Sortie : aucune. Erreurs : aucune ; sans cible, rien. Dépendances : cible.
    onCibleChanged: if (cible) { cible.parent = zone; cible.anchors.fill = zone }

    HoverHandler { id: survol }
    Etat {
        id: etat
        controle: zone
        role: Etats.cran(Etats.herite(zone, "dnRole", "surfaceWindow"))
        suitCurseur: true
        curseurAplat: true
        fondReposTransparent: true
        fondSurvolTransparent: true
    }
    Rectangle {
        id: plaque
        anchors.fill: parent
        anchors.margins: -zone.marge
        radius: Theme.radius?.control ?? 0
        color: etat.fond
    }
}
