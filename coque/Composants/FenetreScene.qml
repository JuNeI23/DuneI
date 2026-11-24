import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../Theme"

// FenetreScene — fenêtre d'une Scene (L2-23) : voile plein écran et cadre centré qui monte du bas ou grandit depuis
// son centre.
// Rôle : PanelWindow plein écran sur l'écran figé à l'ouverture (scene.ecran), couche overlay, namespace
// scene.espace (flouté par le compositeur, le voile restant net sous ignore_alpha), clavier exclusif si
// scene.clavierExclusif, aucun espace réservé ; le composant scene.cadre y est instancié, centré ou placé en
// hauteur par scene.positionner, et reçoit le focus. Le calque ne change jamais de taille : seul le cadre s'anime.
// Reprise de FenetreLanceur, supprimée depuis (L2-81).
// Affichage : la fenêtre est construite dès l'ouverture, mais ne se montre qu'avec scene.montre, ou aussitôt sans
// délai (affiche) ; avant, l'opacité que Hyprland applique à la surface vaut 0 et le masque d'entrée est vide (délai
// du sélecteur, reprise de FenetreSelecteur). Apparition : sans délai, le compositeur la porte, par la règle de
// calque « fade » du namespace (glass.fondu) au ressort overlay de fadeLayersIn ; avec délai, ce fondu joue sur une
// surface d'opacité nulle, et c'est l'opacité de la surface, au même ressort overlay, qui monte à 1 à l'affichage.
// Les deux multiplient le calque entier, flou compris, qui apparaît donc progressivement sans franchir d'un bloc le
// seuil glass.ignore_alpha (D192). Le voile et le cadre restent à l'opacité QML 1. À l'affichage, si scene.montee,
// le cadre part sous le bord bas de l'écran, hors champ, et monte jusqu'à sa place au ressort window, translation
// pure (D193) ; sinon, il grandit depuis son centre, de l'échelle window.echelleApparition à 1, au même ressort
// window et en même temps que le fondu du compositeur. Sous le mouvement réduit, le ressort se pose aussitôt et seul
// le fondu reste.
// Disparition : sur place, en fondu au ressort overlay, par l'opacité que Hyprland applique à la surface
// (HyprlandWindow.opacity, protocole hyprland-surface-v1), qui multiplie elle aussi le flou ; le compositeur
// n'efface pas un calque détruit, qui disparaîtrait d'un coup. À la fermeture, le clavier exclusif est rendu et la
// fenêtre devient transparente au pointeur aussitôt ; le fondu posé, elle signale scene.sortieFinie, qui la
// décharge. Fermée avant l'affichage, elle est déchargée par la scène sans fondu. Une réouverture pendant la sortie
// reprend la même fenêtre, toujours montrée. Un clic sur le voile, hors du cadre, ferme la scène.
// Entrées : scene, la Scene qui la porte (ecran, cadre, ouvert, montre, delai, espace, clavierExclusif, montee,
// positionner), requise.
// Sorties : cadre, l'élément instancié depuis scene.cadre, ou null (lu par les essais) ; affiche, vrai quand la
// scène est ouverte et montrée (ou sans délai) ; eteinte ; cliquerVoile(x, y), appelé aussi par les essais pour
// simuler un clic.
// Erreurs : aucune ; avant le chargement des tokens, le voile reste transparent.
// Dépendances : Quickshell (PanelWindow, ExclusionMode, Region), Quickshell.Wayland (WlrLayershell),
// Quickshell.Hyprland (HyprlandWindow), Scene, Ressort, Theme (material, window.echelleApparition).
PanelWindow {
    id: fenetre

    required property QtObject scene
    readonly property bool clavierExclusif: scene.clavierExclusif && scene.ouvert
    // Sans délai, la fenêtre est affichée dès sa création, sans attendre que la scène pose montre : le LazyLoader la
    // construit avant, et la surface doit naître opaque pour que seul le fondu du compositeur porte l'entrée.
    readonly property bool affiche: scene.ouvert && (scene.montre || scene.delai === 0)
    readonly property var cadre: charge.item

    screen: scene.ecran
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: scene.espace
    WlrLayershell.keyboardFocus: clavierExclusif ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // Avant l'affichage comme après la fermeture, la fenêtre ne prend pas le pointeur : la sortie ne bloque aucun clic.
    mask: Region { width: fenetre.affiche ? fenetre.width : 0; height: fenetre.affiche ? fenetre.height : 0 }

    // Opacité de la surface entière, appliquée par Hyprland, flou compris : 0 avant l'affichage, 1 une fois montrée,
    // 0 à la sortie.
    Ressort { id: effacement; transition: "overlay"; nature: "fondu"; cible: fenetre.affiche ? 1 : 0 }
    HyprlandWindow.opacity: effacement.value

    // eteinte — vraie quand la sortie est posée (scène fermée, fondu à zéro et au repos) : la scène décharge alors la
    // fenêtre. Entrées : aucune. Sortie : scene.sortieFinie(). Erreurs : aucune. Dépendances : effacement, scene.
    readonly property bool eteinte: !scene.ouvert && effacement.value === 0 && !effacement.moving
    onEteinteChanged: if (eteinte) scene.sortieFinie()

    // Montée du cadre, lancée à l'affichage : la cible initiale 0 est posée à la création. Affichée dès la création,
    // la cible 1 part au ressort window au tour de boucle suivant ; posée dans onCompleted même, elle arriverait avant
    // que le Ressort, enfant achevé après la fenêtre, soit prêt, et le cadre se poserait sans monter (recette 2 du
    // lanceur). Avec un délai, le ressort est prêt bien avant l'affichage.
    Ressort { id: montee; transition: "window"; cible: 0 }

    // Component.onCompleted — si la fenêtre est affichée dès sa création, lance la montée du cadre au tour de boucle
    // suivant. Entrées : aucune. Sortie : montee.cible posé à 1. Erreurs : aucune ; non affichée, rien : la montée
    // part à l'affichage. Dépendances : affiche, montee, Qt.callLater.
    Component.onCompleted: if (affiche) Qt.callLater(() => montee.cible = 1)

    // onAfficheChanged — à l'affichage, lance la montée du cadre au tour de boucle suivant : affiche peut devenir vrai
    // pendant la construction de la fenêtre, avant que le Ressort soit prêt. Entrées : aucune (affiche, devenu vrai).
    // Sortie : montee.cible posé à 1. Erreurs : aucune ; à la disparition, rien : le cadre reste posé pendant le
    // fondu. Dépendances : affiche, montee, Qt.callLater.
    onAfficheChanged: if (affiche) Qt.callLater(() => montee.cible = 1)

    // cliquerVoile — un clic sur le voile hors du cadre ferme la scène, si elle l'accepte (voileFerme). Entrées : x, y, position du clic dans la
    // fenêtre (celle du voile, qui la couvre). Sortie : scene.ouvert passé à faux si le point tombe hors du Loader du
    // cadre ; un clic sur le cadre ne fait rien ici. Erreurs : aucune. Dépendances : charge (contains, mapFromItem),
    // voile, scene.ouvert, scene.voileFerme.
    function cliquerVoile(x, y) { if (scene.voileFerme && !charge.contains(charge.mapFromItem(voile, x, y))) scene.ouvert = false }

    // Voile : un clic hors du cadre ferme la scène.
    Rectangle {
        id: voile
        anchors.fill: parent
        color: Theme.material?.shade ?? "transparent"

        MouseArea {
            anchors.fill: parent
            // onClicked — transmet le clic à cliquerVoile. Entrée : m, l'événement de souris (position dans le voile).
            // Sortie : aucune. Erreurs : aucune. Dépendances : cliquerVoile.
            onClicked: m => fenetre.cliquerVoile(m.x, m.y)
        }
    }

    // Cadre : le contenu du client, centré, ou placé en hauteur par scene.positionner quand le client la fournit ; il
    // reçoit le focus. Sans montée, il grandit depuis son centre.
    Loader {
        id: charge
        x: Math.round((fenetre.width - width) / 2)
        y: Math.round(fenetre.scene.positionner ? fenetre.scene.positionner(fenetre.height, height)
                                                : (fenetre.height - height) / 2)
        focus: true
        sourceComponent: fenetre.scene.cadre
        // Départ sous le bord bas de l'écran : le haut du cadre y est posé, hors champ.
        transform: Translate { y: fenetre.scene.montee ? (1 - montee.value) * (fenetre.height - charge.y) : 0 }
        // Sans montée, l'échelle part de window.echelleApparition et rejoint 1 avec le ressort ; l'origine de la
        // transformation est le centre du cadre (Item.Center, par défaut).
        readonly property real depart: Theme.window?.echelleApparition ?? 1
        scale: fenetre.scene.montee || !fenetre.scene.grandit ? 1 : depart + (1 - depart) * montee.value
    }
}
