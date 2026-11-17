import QtQuick
import "../Theme"
import "icones.js" as Icones

// PastilleCloche — pastille posée sur la cloche de la barre (L2-67).
// Rôle : dit, sur le glyphe même, combien de notifications restent à traiter : une pilule de la couleur du texte de
// la barre, qui porte le nombre (deux chiffres au plus, puis « 99+ ») dans le texte opposé ; ou, dès qu'une
// notification critique attend, une boule à la couleur d'erreur à la place du nombre. Rien sans notification.
// Mouvement : pilule et boule paraissent et disparaissent en fondu et en échelle au ressort « state » (le mouvement
// réduit ne garde que le fondu) ; le passage de l'une à l'autre est un fondu croisé ; un nombre qui change passe
// lui aussi par un fondu croisé des chiffres, au ressort « state », pendant que la largeur de la pilule suit. La
// pilule garde son dernier texte pendant qu'elle s'efface.
// Les chiffres sont centrés sur leur dessin (boîte encrée mesurée par TextMetrics), sans arrondi au pixel
// logique : à l'échelle 1,25 de l'écran, l'arrondi les décalait vers le bas.
// Entrées : nombre, critique ; couleur, celle du texte de l'élément de barre (son ressort de couleur).
// Sorties : texte, celui de la pilule (icones.js, textePastille) ; forme, « », « nombre » ou « boule » ; pilule et
// boule, et ancien, l'ancien texte d'un fondu croisé des chiffres ; decalage, l'écart du dessin des chiffres au
// centre de la pilule ; lus par les essais. L'élément n'a pas de taille : il se pose dans le cadre du glyphe, dont
// il déborde.
// Erreurs : aucune ; avant le chargement des jetons, les cotes sont nulles et rien n'est peint.
// Dépendances : Theme (cloche, texteBureauOppose, color.error, typo), Ressort, icones.js.
// Cotes (jetons [cloche]) : pilule haute de hauteur (13), large d'au moins autant, marge horizontale interieur (3),
// chiffres de corps (9,5) gras et tabulaires, posée en pastilleX, pastilleY (9, −5) depuis le coin haut gauche du
// glyphe ; boule de boule (8), posée en bouleX, bouleY (10, −2).
Item {
    id: pastille

    property int nombre: 0
    property bool critique: false
    property color couleur: Theme.texteBureau
    readonly property string texte: Icones.textePastille(nombre)
    readonly property string forme: critique ? "boule" : nombre > 0 ? "nombre" : ""
    readonly property alias pilule: pilule
    readonly property alias boule: boule
    readonly property alias ancien: ancien
    // Écart [dx, dy] entre le centre du dessin des chiffres (leur boîte encrée) et celui de la pilule (essais).
    readonly property var decalage: [chiffres.x + mesure.tightBoundingRect.x + mesure.tightBoundingRect.width / 2
                                         - pilule.width / 2,
                                     chiffres.y + chiffres.baselineOffset + mesure.tightBoundingRect.y
                                         + mesure.tightBoundingRect.height / 2 - pilule.height / 2]
    // Dernier texte non vide : celui que la pilule garde pendant son fondu de sortie ; _ancien, celui qu'il remplace.
    property string _montre: texte
    property string _ancien: ""

    onTexteChanged: {
        if (texte === "") return
        if (_montre !== "" && _montre !== texte && fonduPilule.value > 0) {
            _ancien = _montre
            croise.reprendre(0, 0)
        }
        _montre = texte
    }

    Ressort { id: croise; transition: "state"; nature: "fondu"; cible: 1 }

    Ressort { id: fonduPilule; transition: "state"; nature: "fondu"; cible: pastille.forme === "nombre" ? 1 : 0 }
    Ressort { id: echellePilule; transition: "state"; cible: fonduPilule.cible }
    Ressort { id: fonduBoule; transition: "state"; nature: "fondu"; cible: pastille.forme === "boule" ? 1 : 0 }
    Ressort { id: echelleBoule; transition: "state"; cible: fonduBoule.cible }
    Ressort {
        id: largeur
        transition: "state"
        cible: Math.max(pilule.height, chiffres.implicitWidth + 2 * (Theme.cloche?.interieur ?? 0))
    }

    Rectangle {
        id: pilule
        x: Theme.cloche?.pastilleX ?? 0
        y: Theme.cloche?.pastilleY ?? 0
        width: largeur.value
        height: Theme.cloche?.hauteur ?? 0
        radius: height / 2
        color: pastille.couleur
        visible: opacity > 0
        opacity: fonduPilule.value
        scale: 0.5 + 0.5 * echellePilule.value
        transformOrigin: Item.Left

        // Boîte encrée des chiffres montrés, relative à leur ligne de base.
        TextMetrics { id: mesure; font: chiffres.font; text: pastille._montre }
        TextMetrics { id: mesureAncien; font: chiffres.font; text: pastille._ancien }

        Text {
            id: chiffres
            // Centré sur le dessin des chiffres, non sur leur boîte de ligne : celle-ci compte l'espace des
            // descendantes et les approches, ce qui poussait les chiffres vers le bas et la droite.
            x: (pilule.width - mesure.tightBoundingRect.width) / 2 - mesure.tightBoundingRect.x
            y: (pilule.height - mesure.tightBoundingRect.height) / 2 - mesure.tightBoundingRect.y - baselineOffset
            opacity: Math.max(0, Math.min(1, croise.value))
            text: pastille._montre
            color: Theme.texteBureauOppose
            font: Qt.font({ family: Theme.typo?.interface ?? Qt.application.font.family,
                            pixelSize: Theme.cloche?.corps ?? Qt.application.font.pixelSize, weight: Font.Bold,
                            features: Theme.typo?.tabularNumerals ? { "tnum": 1 } : ({}) })
        }
        Text {
            id: ancien
            x: (pilule.width - mesureAncien.tightBoundingRect.width) / 2 - mesureAncien.tightBoundingRect.x
            y: (pilule.height - mesureAncien.tightBoundingRect.height) / 2 - mesureAncien.tightBoundingRect.y
               - baselineOffset
            visible: opacity > 0
            opacity: 1 - chiffres.opacity
            text: pastille._ancien
            color: chiffres.color
            font: chiffres.font
        }
    }

    Rectangle {
        id: boule
        x: Theme.cloche?.bouleX ?? 0
        y: Theme.cloche?.bouleY ?? 0
        width: Theme.cloche?.boule ?? 0
        height: width
        radius: width / 2
        color: Theme.color?.error ?? "transparent"
        visible: opacity > 0
        opacity: fonduBoule.value
        scale: 0.5 + 0.5 * echelleBoule.value
    }
}
