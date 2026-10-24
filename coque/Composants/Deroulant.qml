import QtQuick
import "../Theme"

// Deroulant — menu déroulant de la coque, sur le modèle du bouton contextuel de macOS.
// Rôle : un Bouton qui montre la valeur choisie à gauche et le double chevron haut-bas de macOS, dessiné, à droite
// (conception, § 7.10). Un clic, Espace ou Entrée ouvre un Overlay contextuel ancré sous le bouton, qui porte une
// Liste des choix : sa sélection suit le pointeur (selectionSuitSurvol), comme dans un menu de macOS, et
// l'élément choisi porte en tête la Coche dessinée de la case. Choisir un élément, au clic ou à Entrée, ferme le
// menu, en fait la valeur et émet activated ; Échap ou un clic à l'extérieur ferment sans rien changer. Ouvert au
// clavier, le menu montre le contour de sa rangée courante dès sa construction (Liste.focusClavier part de
// auClavier) ; ouvert à la souris, il ne le montre pas (focusClavier repasse à faux juste après l'arrivée du
// focus, que la Liste prend pour un geste du clavier). Fermé, les flèches haut et bas changent la valeur sans
// ouvrir le menu, comme sur macOS. Il n'est pas bâti sur T.ComboBox, dont le menu, un Popup, ne sort pas de la
// fenêtre : l'Overlay contextuel est une fenêtre surgissante (PopupWindow), construite à l'ouverture et détruite
// à la fermeture (D80).
// Largeur : celle du plus long des choix, pour que changer de valeur ne redimensionne pas le bouton.
// Entrées : model, la liste des choix (chaînes) ; currentIndex, rang de la valeur choisie, 0 par défaut ; le
// reste de l'API de Bouton (enabled, principal…), hors text, que displayText remplit.
// Sorties : displayText, le texte de la valeur choisie (vide hors du modèle) ; signal activated(index), émis quand
// l'utilisateur choisit un élément, au menu ou aux flèches ; menu, l'Overlay ; liste, la Liste du menu ouvert,
// null fermé ; auClavier, vrai si la dernière ouverture vient du clavier ; ces trois dernières, en lecture seule,
// sont lues par les essais.
// Erreurs : aucune ; un modèle vide montre un bouton sans texte, dont le menu est vide ; avant le chargement des
// tokens, les cotes sont nulles et les couleurs transparentes.
// Dépendances : Bouton (fond, états, anneau), Overlay (famille contextuel), Liste, Rangee (accessoire), Coche,
// Chevron, Texte, Theme (density, icons, space).
// Cotes : double chevron de icons.sizes.dense, écarté du texte de space.scale[1] (8) ; colonne de la coche de
// density.checkSize.
Bouton {
    id: deroulant

    property var model: []
    property int currentIndex: 0
    readonly property alias auClavier: interne.auClavier
    readonly property alias liste: interne.liste
    readonly property string displayText: model[currentIndex] ?? ""
    readonly property alias menu: menu
    readonly property real chevron: Theme.icons?.sizes.dense ?? 0
    // Largeur du plus long des choix ; la lecture de la taille de police lie le calcul aux changements de police.
    readonly property real largeurTexte: metriques.font.pixelSize > 0
        ? Math.max(0, ...Array.from(model, t => metriques.advanceWidth(t))) : 0

    signal activated(int index)

    text: displayText
    spacing: Theme.space?.scale[1] ?? 0
    onClicked: ouvrir(false)
    // Ces touches n'agissent que menu fermé : ouvert, le menu a le clavier (HyprlandFocusGrab), et une touche qui
    // parviendrait encore au bouton ne doit ni rouvrir le menu ni changer la valeur sous lui.
    Keys.onSpacePressed: if (!menu.ouvert) ouvrir(true)
    Keys.onReturnPressed: if (!menu.ouvert) ouvrir(true)
    Keys.onEnterPressed: if (!menu.ouvert) ouvrir(true)
    Keys.onUpPressed: if (!menu.ouvert) deplacer(-1)
    Keys.onDownPressed: if (!menu.ouvert) deplacer(1)

    // ouvrir — ouvre le menu des choix sous le bouton.
    // Entrée : clavier, vrai si l'ouverture vient du clavier (le contour de la rangée courante sera montré).
    // Sortie : aucune. Erreurs : aucune. Dépendances : menu (Overlay), interne (auClavier).
    function ouvrir(clavier: bool): void {
        interne.auClavier = clavier
        menu.ouvert = true
    }

    // choisir — fait d'un élément du menu la valeur, ferme le menu et émet activated.
    // Entrée : index, rang de l'élément choisi. Sortie : aucune. Erreurs : aucune. Dépendances : menu, activated.
    function choisir(index: int): void {
        menu.ouvert = false
        currentIndex = index
        activated(index)
    }

    // deplacer — menu fermé, passe à la valeur voisine, bornée au modèle, et émet activated si elle change.
    // Entrée : pas, -1 pour la valeur précédente, 1 pour la suivante. Sortie : aucune. Erreurs : aucune ; aux
    // extrémités, rien ne change. Dépendances : model, currentIndex, activated.
    function deplacer(pas: int): void {
        const i = Math.max(0, Math.min(model.length - 1, currentIndex + pas))
        if (i !== currentIndex) {
            currentIndex = i
            activated(i)
        }
    }

    // État interne, exposé en lecture seule par auClavier et liste : seuls ouvrir() et la Liste du menu l'écrivent.
    QtObject {
        id: interne
        property bool auClavier: false
        property Item liste: null
    }

    FontMetrics {
        id: metriques
        font: libelle.font
    }

    contentItem: Item {
        implicitWidth: deroulant.largeurTexte + deroulant.spacing + deroulant.chevron
        implicitHeight: libelle.implicitHeight

        Texte {
            id: libelle
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - deroulant.spacing - deroulant.chevron
            text: deroulant.displayText
            color: deroulant.etat.texte
            elide: Text.ElideRight
        }

        Chevron {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: deroulant.chevron
            height: width
            sens: "double"
            couleur: deroulant.etat.texte
        }
    }

    Overlay {
        id: menu
        famille: "contextuel"
        ancre: deroulant

        Liste {
            id: choix
            focus: true
            selectionSuitSurvol: true
            currentIndex: deroulant.currentIndex
            focusClavier: deroulant.auClavier
            implicitWidth: deroulant.width
            implicitHeight: count * (Theme.density?.rowHeight ?? 0)
            model: deroulant.model
            Component.onCompleted: interne.liste = choix
            Component.onDestruction: interne.liste = null
            onActiveFocusChanged: {
                // La liste peut être détruite avant l'appel différé, si le menu se ferme aussitôt : interne.liste
                // vaut alors null et rien n'est touché.
                if (activeFocus && !deroulant.auClavier) Qt.callLater(() => {
                    if (interne.liste) interne.liste.focusClavier = false
                })
            }

            delegate: Rangee {
                id: rangee
                required property string modelData
                text: modelData
                // Un menu suit toujours le pointeur, que le bureau active ou non les effets de survol
                // (Qt.styleHints.useHoverEffects, qui règle la valeur par défaut des gabarits).
                hoverEnabled: true
                onActive: deroulant.choisir(index)

                // La colonne des coches : la Coche n'est peinte que sur l'élément choisi, au texte de la rangée.
                accessoire: Component {
                    Item {
                        implicitWidth: Theme.density?.checkSize ?? 0
                        implicitHeight: implicitWidth

                        Coche {
                            anchors.fill: parent
                            visible: rangee.index === deroulant.currentIndex
                            couleur: rangee.etat.texte
                        }
                    }
                }
            }
        }
    }
}
