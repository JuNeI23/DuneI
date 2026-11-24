import QtQuick
import "../Theme"
import "../Composants" as C

// CadreLanceur — cadre du lanceur (L2-16) : verre, champ, accueil ou scission ; contenu de la
// FenetreScene du lanceur (L2-81).
// Rôle : séparé de la fenêtre de calque pour être éprouvé hors écran (coque d'essai essai/clavier, plateforme
// offscreen, où une vraie touche de Qt suit le chemin réel du champ). Il passe de l'accueil (cotes.accueil, coins
// cotes.rayonAccueil) à la scission (cotes.scission, coins radius.window) au ressort window, en largeur, en hauteur
// et en rayon ; il porte le verre e3 du moment (Surface surfaceRaised en verre), son ombre d'élévation, le reflet haut
// material.headerGlow et le liseré material.edgeLight du Materiau, et déclare dnRelief pour que ses médaillons
// prennent le relief « Doux ». Dedans : le champ Recherche agrandi, puis l'Accueil ou la scission (titre
// « Résultats » et Liste, filet, Apercu), qui se croisent en fondu et en glissé. Les touches du champ passent par
// Lanceur.touche ; le reste de la frappe va au champ, qui écrit Lanceur.saisie.
// Entrées : aucune ; la montée depuis le bas de l'écran est celle du Loader de FenetreScene. Les touches ne sont
// traitées que lanceur ouvert : pendant le fondu de sortie, la saisie et la sélection restent figées (L2-74 b).
// Sorties : vignettes, le nombre de vignettes de l'aperçu ; champ, la Recherche, et accueil, l'Accueil (lus par les
// essais) ; reperes().
// Erreurs : aucune ; avant le chargement des tokens, le verre reste transparent.
// Dépendances : Lanceur, Accueil, Liste, Apercu, Ressort, C.Surface, C.OmbreElevation, C.Recherche, C.Texte, Theme
// (material, radius, space, typo, color, icons, police).
// Cotes : champ à cotes.retrait (12) des bords, de cotes.champ de haut (48, maquette 50), corps à l'échelon 4 (18,
// maquette 19), loupe de icons.sizes.default (20, maquette 19), texte à space.scale[4] (24, maquette 20) du bord ;
// vues à partir du bas du champ ; liste de cotes.liste (340) puis un filet material.glassLine (un filet opaque se lirait
// comme un trait blanc sur le verre du jour), retiré de cotes.retrait en haut et en bas.
Item {
    id: cadre

    readonly property bool dnRelief: true
    readonly property var cotes: Lanceur.cotes
    readonly property bool scinde: Lanceur.vue === "scission"
    readonly property int vignettes: apercu.vignettes
    readonly property alias champ: champ
    readonly property alias accueil: accueil

    width: largeur.value
    height: hauteur.value

    // nomTouche — nom d'une touche du lanceur. Entrée : event, KeyEvent. Sortie : « escape », « return »,
    // « ctrl+return », « up », « down », « left », « right », « tab », « shift+tab », « ctrl+j », « ctrl+k », ou « »
    // pour une autre touche. Erreurs : aucune. Dépendances : aucune.
    function nomTouche(event) {
        const ctrl = event.modifiers & Qt.ControlModifier
        const entree = ctrl ? "ctrl+return" : "return"
        return ({ [Qt.Key_Escape]: "escape", [Qt.Key_Return]: entree, [Qt.Key_Enter]: entree, [Qt.Key_Up]: "up",
                  [Qt.Key_Down]: "down", [Qt.Key_Left]: "left", [Qt.Key_Right]: "right", [Qt.Key_Tab]: "tab",
                  [Qt.Key_Backtab]: "shift+tab", [Qt.Key_J]: ctrl ? "ctrl+j" : "", [Qt.Key_K]: ctrl ? "ctrl+k" : "" })[event.key] ?? ""
    }

    // reperes — géométrie de la plaque de la liste et de sa ligne retenue, dans le repère du cadre (lue par les essais).
    // Entrées : aucune. Sortie : voir Liste.reperes ; null hors de la scission. Erreurs : aucune. Dépendances : liste.
    function reperes() { return cadre.scinde ? liste.reperes(cadre) : null }

    Ressort { id: largeur; transition: "window"; cible: cadre.scinde ? cotes.scission.width : cotes.accueil.width }
    Ressort { id: hauteur; transition: "window"; cible: cadre.scinde ? cotes.scission.height : cotes.accueil.height }
    Ressort { id: rayon; transition: "window"; cible: cadre.scinde ? cotes.rayonScission : cotes.rayonAccueil }

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
            effaceSurEchap: false
            text: Lanceur.saisie
            // onTextChanged — la frappe comme le bouton d'effacement écrivent la saisie du lanceur.
            // Entrées : aucune. Sortie : Lanceur.saisie. Erreurs : aucune. Dépendances : Lanceur.
            onTextChanged: if (text !== Lanceur.saisie) Lanceur.saisie = text
            // Keys.onPressed — les touches du lanceur passent par Lanceur.touche avant le traitement propre du
            // champ ; Échap n'est plus traité par la Recherche (effaceSurEchap faux) et suit toujours ce chemin.
            // Lanceur fermé (fondu de sortie), toute touche est prise sans effet, frappe comprise.
            // Entrée : event. Sortie : event.accepted si la touche est prise. Erreurs : aucune.
            // Dépendances : nomTouche, Lanceur.touche, Lanceur.ouvert.
            Keys.onPressed: event => {
                if (!Lanceur.ouvert) return event.accepted = true
                const nom = cadre.nomTouche(event)
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
                id: accueil
                width: cotes.accueil.width
                height: parent.height
                anchors.horizontalCenter: parent.horizontalCenter
                opacity: 1 - bascule.value
                visible: opacity > 0
                transform: [
                    Translate { y: -(Theme.space?.scale[0] ?? 0) * glisse.value },
                    Scale { origin.x: cotes.accueil.width / 2; xScale: 1 - 0.04 * glisse.value; yScale: xScale }
                ]
            }

            Item {
                id: scission
                anchors.fill: parent
                opacity: bascule.value
                visible: opacity > 0
                transform: Translate { y: (1 - glisse.value) * (Theme.space?.scale[1] ?? 0) }

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
                    id: liste
                    x: cotes.retrait
                    y: tete.y + tete.height + (Theme.space?.scale[0] ?? 0)
                    width: cotes.liste - cotes.retrait - (Theme.space?.scale[1] ?? 0)
                    height: parent.height - y - cotes.retrait
                }
                // Filet entre liste et aperçu, retiré de cotes.retrait en haut et en bas, comme le contenu du cadre.
                Rectangle {
                    x: cotes.liste
                    y: cotes.retrait
                    width: 1
                    height: parent.height - 2 * cotes.retrait
                    color: Theme.material?.glassLine ?? "transparent"
                }
                Apercu {
                    id: apercu
                    x: cotes.liste + 1
                    width: parent.width - x
                    height: parent.height
                }
            }

            Ressort { id: bascule; transition: "reveal"; nature: "fondu"; cible: cadre.scinde ? 1 : 0 }
            // Même mouvement que la bascule, réservé au déplacement et à l'échelle : le fondu ne porte que l'opacité.
            Ressort { id: glisse; transition: "reveal"; cible: cadre.scinde ? 1 : 0 }
        }
    }
}
