import QtQuick
import Quickshell.Widgets
import "../Theme"
import "../Composants" as C
import "lanceur.js" as Logique

// Liste — colonne des résultats de la scission (L2-16, maquette v3).
// Rôle : une seule liste classée, sans sections, de lignes de cotes.ligne (44) : l'icône (en couleur pour une
// application, une fenêtre ou une action ; symbolique pour une commande ou le calcul), le titre, dont les lettres
// trouvées prennent color.accentStandalone hors de la plaque (soulignées sur elle), et le type en gris à droite. Une
// fenêtre rangée sous son application est en retrait, à plus petite icône. Le calcul se lit « expression = valeur ».
// La plaque d'accent glisse sous la ligne retenue (sel.rang), qui reste visible (la vue défile au besoin) ; les lignes
// entrent en cascade à chaque nouvelle liste ; un clic choisit la ligne et l'exécute. Quand le curseur du clavier est
// dans l'aperçu (actif faux), l'accent n'appartient plus à la ligne : la plaque passe au fond neutre du survol
// (états surfaceRaised, sans sélection, survol), qui dit seulement quelle ligne est prévisualisée, et le texte revient
// à ses couleurs normales, au ressort des états ; l'accent revient quand le curseur revient dans la liste.
// Entrées : resultats (Lanceur.resultats) ; rang, la ligne retenue (Lanceur.sel.rang) ; saisie (Lanceur.saisie).
// Sorties : aucune ; le pointeur appelle Lanceur.choisir. Erreurs : aucune ; une liste vide ne montre rien.
// Dépendances : Lanceur (cotes, icone, choisir, sel), lanceur.js (surligner, expressionLisible), C.Plaque, Cascade, C.Icone, C.Texte,
// ColorSpring, Quickshell.Widgets (IconImage), Theme (space, typo, color, radius, icons, stateColors).
// Cotes : retrait des lignes space.scale[2] (12), fenêtre rangée à space.scale[5] (32, maquette 28) ; icône de
// icons.sizes.comfortable (24, maquette 26), de icons.sizes.default (20) en retrait ; titre à l'échelon 2 (13) en
// graisse moyenne ; type à l'échelon 1 (12) ; plaque aux coins radius.panel (10).
ListView {
    id: liste

    property var resultats: Lanceur.resultats
    property int rang: Lanceur.sel.rang
    property string saisie: Lanceur.saisie
    // Vrai tant que le curseur du clavier est dans la liste (la plaque porte alors l'accent plein).
    property bool actif: Lanceur.sel.zone === "liste"
    readonly property real ligne: Lanceur.cotes.ligne

    // Modèle entier : les lignes suivent le contenu sans être recréées ; elles rejouent leur entrée en cascade à
    // chaque frappe (comme la maquette), pas quand une fenêtre change de titre ou que le calcul répond.
    model: resultats.length
    signal rejouer()
    onSaisieChanged: rejouer()
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    currentIndex: rang
    highlightFollowsCurrentItem: false
    // onRangChanged — garde la ligne retenue visible. Entrées : aucune. Sortie : aucune. Erreurs : aucune.
    // Dépendances : positionViewAtIndex.
    onRangChanged: positionViewAtIndex(rang, ListView.Contain)

    // La plaque vit dans le contenu défilé (contentItem), comme les lignes : elle défile avec elles, et sa cible
    // (rang × hauteur de ligne, plus originY) est dans le même repère que leur y. Déclarée simplement dans la ListView,
    // elle restait dans le repère fixe de la vue, et tout défilement la décalait de contentY (bogue E de la recette 1).
    C.Plaque {
        id: plaque
        parent: liste.contentItem
        z: -1
        cible: liste.count > 0 ? Qt.rect(0, liste.originY + liste.rang * liste.ligne, liste.width, liste.ligne) : Qt.rect(0, 0, 0, 0)
        rayon: Theme.radius?.panel ?? 0
        teinte: (liste.actif ? Theme.color?.accent : Theme.stateColors("surfaceRaised", "none", "hover")?.fill) ?? "transparent"
    }

    // reperes — géométrie de la plaque et de la ligne retenue dans un repère commun, pour les essais.
    // Entrée : repere, Item où mapper. Sortie : {rang, plaque, ligne, hauteur, haut, bas, pleine, surAccent} : plaque et
    // ligne, ordonnées des bords hauts (ligne vaut null si la ligne n'est pas construite) ; hauteur, celle de la plaque
    // peinte ; haut et bas, les bords de la zone visible de la liste ; pleine, vrai si la teinte visée de la plaque est
    // color.accent ; surAccent, vrai si le texte de la ligne retenue vise color.onAccent. Erreurs : aucune.
    // Dépendances : itemAtIndex, mapToItem, Qt.colorEqual.
    function reperes(repere) {
        const l = itemAtIndex(rang), p = plaque.mapToItem(repere, 0, 0), q = plaque.mapToItem(repere, 0, plaque.height)
        return { rang, plaque: p.y, hauteur: q.y - p.y, ligne: l ? l.mapToItem(repere, 0, 0).y : null,
                 haut: mapToItem(repere, 0, 0).y, bas: mapToItem(repere, 0, height).y,
                 pleine: Qt.colorEqual(plaque.teinte, Theme.color?.accent ?? "transparent"), surAccent: l ? l.surAccent : null }
    }

    // texteMarque — titre en texte riche, lettres trouvées teintées (hors plaque) ou soulignées (sur la plaque).
    // Entrées : titre ; choisie, vrai sous la plaque. Sortie : chaîne StyledText, le texte échappé. Erreurs : aucune.
    // Dépendances : Logique.surligner, Theme.color.accentStandalone.
    function texteMarque(titre, choisie) {
        const echappe = s => s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
        const accent = String(Theme.color?.accentStandalone ?? "")
        return Logique.surligner(titre, saisie).map(s => !s.trouve ? echappe(s.texte)
            : choisie ? "<u>" + echappe(s.texte) + "</u>" : "<font color=\"" + accent + "\">" + echappe(s.texte) + "</font>").join("")
    }

    // Ligne — un résultat de la liste.
    delegate: Item {
        id: l
        required property int index
        readonly property var modelData: liste.resultats[index] ?? ({})
        readonly property bool choisie: index === liste.rang
        // Texte sur l'accent plein : ligne retenue, curseur dans la liste.
        readonly property bool surAccent: choisie && liste.actif
        readonly property bool symbolique: modelData.genre === "commande" || modelData.genre === "calcul"
        readonly property real retraitIcone: (modelData.retrait ? Theme.space?.scale[5] : Theme.space?.scale[2]) ?? 0

        width: liste.width
        height: liste.ligne
        opacity: entree.value
        transform: Translate { y: (1 - entree.value) * (Theme.space?.scale[1] ?? 0) }

        Cascade { id: entree; rang: l.index }
        Connections { target: liste; function onRejouer() { entree.rejouer() } }
        ColorSpring { id: encre; target: (l.surAccent ? Theme.color?.onAccent : Theme.color?.textPrimary) ?? "transparent" }
        ColorSpring { id: gris; target: (l.surAccent ? Theme.color?.onAccent : Theme.color?.textTertiary) ?? "transparent" }

        IconImage {
            id: image
            x: l.retraitIcone
            anchors.verticalCenter: parent.verticalCenter
            visible: !l.symbolique
            source: visible ? Lanceur.icone(l.modelData.icone) : ""
            implicitSize: (l.modelData.retrait ? Theme.icons?.sizes.default : Theme.icons?.sizes.comfortable) ?? 0
            asynchronous: true
        }
        C.Icone {
            x: l.retraitIcone
            anchors.verticalCenter: parent.verticalCenter
            visible: l.symbolique
            nom: !l.symbolique ? "" : l.modelData.genre === "calcul" ? "edit-copy" : l.modelData.icone
            taille: Theme.icons?.sizes.default ?? 0
            couleur: encre.value
        }
        C.Texte {
            anchors.left: parent.left
            anchors.leftMargin: l.retraitIcone + image.implicitSize + (Theme.space?.scale[2] ?? 0)
            anchors.right: type.left
            anchors.rightMargin: Theme.space?.scale[2] ?? 0
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            textFormat: l.modelData.genre === "calcul" ? Text.PlainText : Text.StyledText
            text: l.modelData.genre === "calcul" ? Logique.expressionLisible(liste.saisie) + " = " + l.modelData.titre
                : liste.texteMarque(l.modelData.titre, l.surAccent)
            moyen: true
            color: encre.value
        }
        C.Texte {
            id: type
            anchors.right: parent.right
            anchors.rightMargin: Theme.space?.scale[2] ?? 0
            anchors.verticalCenter: parent.verticalCenter
            text: l.modelData.type
            echelon: 1
            color: gris.value
        }

        // Le survol ne choisit pas la ligne : les lignes recréées à chaque frappe sous un pointeur immobile
        // voleraient la sélection au clavier.
        HoverHandler { cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: Lanceur.choisir("liste", l.index) }
    }
}
