import QtQuick
import Quickshell
import Quickshell.Wayland
import "../Theme"
import "../Composants" as C

// FenetreLanceur — fenêtre d'attention du lanceur (L2-16) : voile plein écran et cadre animé, accueil ou scission.
// Rôle : PanelWindow plein écran sur l'écran figé à l'ouverture (Lanceur.ecran), couche overlay, namespace
// « dunei-attention » (flouté par le compositeur, le voile restant net sous ignore_alpha), clavier exclusif si
// clavierExclusif, aucun espace réservé. Le calque ne change jamais de taille : seul le cadre intérieur s'anime. Le
// cadre est un cadre propre au lanceur plutôt que celui de FenetreAttention, qui centre un contenu à sa taille : il se
// tient au tiers haut (le centre de la scission sur le tiers de l'écran, bord haut fixe) et passe de l'accueil
// (cotes.accueil, coins cotes.rayonAccueil) à la scission (cotes.scission, coins radius.window) au ressort window, en
// largeur, en hauteur et en rayon. Il porte le verre e3 du moment (Surface surfaceRaised en verre), son ombre
// d'élévation, le reflet haut material.headerGlow et le liseré material.edgeLight du Materiau, et déclare dnRelief
// pour que ses médaillons prennent le relief « Doux ». Dedans : le champ Recherche agrandi, puis l'Accueil ou la
// scission (titre « Résultats » et Liste, filet, Apercu), qui se croisent en fondu et en glissé. À l'ouverture, voile et cadre entrent au
// ressort overlay (fondu, cadre de 94 % à 100 %, glissé vers le haut). Un clic sur le voile ferme ; les touches
// du champ passent par Lanceur.touche, le reste de la frappe va au champ, qui écrit Lanceur.saisie.
// Entrées : clavierExclusif (Lanceur.clavierExclusif). Sorties : cadre, l'élément du cadre (taille relevée par les
// essais) ; vignettes, le nombre de vignettes de l'aperçu.
// Erreurs : aucune ; avant le chargement des tokens, voile et verre restent transparents.
// Dépendances : Quickshell (PanelWindow, ExclusionMode), Quickshell.Wayland (WlrLayershell), Lanceur, Accueil, Liste,
// Apercu, Ressort, C.Surface, C.OmbreElevation, C.Recherche, Theme (material, radius, space, typo, color, police).
// Cotes : champ à cotes.retrait (12) des bords, de cotes.champ de haut (48, maquette 50), corps à l'échelon 4 (18,
// maquette 19), loupe de icons.sizes.default (20, maquette 19), texte à space.scale[4] (24, maquette 20) du bord ;
// vues à partir du bas du champ ; liste de cotes.liste (340) puis un filet material.glassLine (un filet opaque se lirait comme
// un trait blanc sur le verre du jour).
PanelWindow {
    id: fenetre

    property bool clavierExclusif: Lanceur.clavierExclusif
    readonly property alias cadre: cadre
    readonly property int vignettes: apercu.vignettes

    screen: Lanceur.ecran
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "dunei-attention"
    WlrLayershell.keyboardFocus: clavierExclusif ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    readonly property var cotes: Lanceur.cotes
    readonly property bool scinde: Lanceur.vue === "scission"

    // Entrée de la fenêtre : la cible initiale 0 est posée à la création, puis la cible 1 part au ressort.
    Ressort { id: entree; transition: "overlay"; nature: "fondu"; cible: 0 }
    Component.onCompleted: entree.cible = 1

    // nomTouche — nom d'une touche du lanceur. Entrée : event, KeyEvent. Sortie : « escape », « return », « up »,
    // « down », « left », « right », « tab », « shift+tab », « ctrl+j », « ctrl+k », ou « » pour une autre touche.
    // Erreurs : aucune. Dépendances : aucune.
    function nomTouche(event) {
        const ctrl = event.modifiers & Qt.ControlModifier
        return ({ [Qt.Key_Escape]: "escape", [Qt.Key_Return]: "return", [Qt.Key_Enter]: "return", [Qt.Key_Up]: "up",
                  [Qt.Key_Down]: "down", [Qt.Key_Left]: "left", [Qt.Key_Right]: "right", [Qt.Key_Tab]: "tab",
                  [Qt.Key_Backtab]: "shift+tab", [Qt.Key_J]: ctrl ? "ctrl+j" : "", [Qt.Key_K]: ctrl ? "ctrl+k" : "" })[event.key] ?? ""
    }

    // Voile : un clic hors du cadre ferme le lanceur.
    Rectangle {
        id: voile
        anchors.fill: parent
        color: Theme.material?.shade ?? "transparent"
        opacity: entree.value

        MouseArea {
            anchors.fill: parent
            onClicked: m => { if (!cadre.contains(cadre.mapFromItem(voile, m.x, m.y))) Lanceur.fermer() }
        }
    }

    Item {
        id: cadre
        readonly property bool dnRelief: true

        x: Math.round((fenetre.width - width) / 2)
        y: Math.max(cotes.retrait, Math.round(fenetre.height / 3 - cotes.scission.height / 2))
        width: largeur.value
        height: hauteur.value
        opacity: entree.value
        transform: [
            Translate { y: (1 - entree.value) * (Theme.space?.scale[2] ?? 0) },
            Scale { origin.x: cadre.width / 2; origin.y: 0; xScale: 0.94 + 0.06 * entree.value; yScale: xScale }
        ]

        Ressort { id: largeur; transition: "window"; cible: fenetre.scinde ? cotes.scission.width : cotes.accueil.width }
        Ressort { id: hauteur; transition: "window"; cible: fenetre.scinde ? cotes.scission.height : cotes.accueil.height }
        Ressort { id: rayon; transition: "window"; cible: fenetre.scinde ? cotes.rayonScission : cotes.rayonAccueil }

        C.OmbreElevation { cible: corps; niveau: "e3"; evidee: true }

        C.Surface {
            id: corps
            anchors.fill: parent
            role: "surfaceRaised"
            radius: rayon.value
            verre: true

            // Reflet haut du relief « Doux » : le blanc des reflets, éteint à la part headerGlowReach de la hauteur.
            Rectangle {
                anchors.fill: parent
                radius: rayon.value
                opacity: Theme.material?.headerGlow ?? 0
                gradient: Gradient {
                    GradientStop { position: 0; color: Theme.material?.highlight ?? "transparent" }
                    GradientStop { position: Theme.material?.headerGlowReach ?? 0; color: "transparent" }
                }
            }

            C.Recherche {
                id: champ
                x: cotes.retrait
                y: cotes.retrait
                width: parent.width - 2 * cotes.retrait
                height: cotes.champ
                focus: true
                font: Theme.police(4, false)
                placeholderText: "Rechercher une application, une fenêtre, une commande"
                loupe.taille: Theme.icons?.sizes.default ?? 0
                loupe.x: Theme.space?.scale[3] ?? 0
                leftPadding: (Theme.space?.scale[3] ?? 0) + loupe.taille + (Theme.space?.scale[2] ?? 0)
                text: Lanceur.saisie
                // onTextEdited — la frappe écrit la saisie du lanceur. Entrées : aucune. Sortie : Lanceur.saisie.
                // Erreurs : aucune. Dépendances : Lanceur.
                onTextEdited: Lanceur.saisie = text
                // Keys.onPressed — les touches du lanceur passent par Lanceur.touche avant le champ (Échap compris).
                // Entrée : event. Sortie : event.accepted si la touche est prise. Erreurs : aucune.
                // Dépendances : nomTouche, Lanceur.touche.
                Keys.onPressed: event => {
                    const nom = fenetre.nomTouche(event)
                    if (nom && Lanceur.touche(nom)) event.accepted = true
                }
            }

            // Vues sous le champ ; le contenu qui déborde pendant le ressort du cadre est rogné.
            Item {
                id: vues
                anchors.fill: parent
                anchors.topMargin: champ.y + champ.height
                clip: true

                Accueil {
                    width: cotes.accueil.width
                    height: parent.height
                    anchors.horizontalCenter: parent.horizontalCenter
                    opacity: 1 - bascule.value
                    visible: opacity > 0
                    transform: [
                        Translate { y: -(Theme.space?.scale[0] ?? 0) * bascule.value },
                        Scale { origin.x: cotes.accueil.width / 2; xScale: 1 - 0.04 * bascule.value; yScale: xScale }
                    ]
                }

                Item {
                    id: scission
                    anchors.fill: parent
                    opacity: bascule.value
                    visible: opacity > 0
                    transform: Translate { y: (1 - bascule.value) * (Theme.space?.scale[1] ?? 0) }

                    C.Texte {
                        id: tete
                        x: cotes.retrait + (Theme.space?.scale[2] ?? 0)
                        y: cotes.retrait + (Theme.space?.scale[0] ?? 0)
                        text: "Résultats".toUpperCase()
                        echelon: 0
                        moyen: true
                        color: Theme.color?.textTertiary ?? "transparent"
                    }
                    Liste {
                        x: cotes.retrait
                        y: tete.y + tete.height + (Theme.space?.scale[0] ?? 0)
                        width: cotes.liste - cotes.retrait - (Theme.space?.scale[1] ?? 0)
                        height: parent.height - y - cotes.retrait
                    }
                    Rectangle {
                        x: cotes.liste
                        width: 1
                        height: parent.height
                        color: Theme.material?.glassLine ?? "transparent"
                    }
                    Apercu {
                        id: apercu
                        x: cotes.liste + 1
                        width: parent.width - x
                        height: parent.height
                    }
                }

                Ressort { id: bascule; transition: "reveal"; nature: "fondu"; cible: fenetre.scinde ? 1 : 0 }
            }
        }
    }
}
