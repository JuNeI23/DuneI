import QtQuick
import Quickshell
import Quickshell.Hyprland
import "../Theme"
import "ancrage.js" as Ancrage

// Overlay — surface posée au-dessus de tout, construite à l'ouverture et détruite à la fermeture.
// Rôle : primitive des surfaces passagères de la coque (conception, § 7.7), en trois familles.
//   - attention (lanceur, sélecteurs, déconnexion, dialogue) : FenetreAttention, PanelWindow plein écran sur
//     l'écran du moniteur focalisé d'Hyprland, couche overlay, clavier exclusif, aucun espace réservé ; voile
//     material.shade sur tout l'écran ; une seule à la fois, par le singleton Overlays ; Échap ou un clic sur le
//     voile la ferment. Elle n'est compilée qu'à l'ouverture d'une attention, si bien que l'Overlay se charge
//     aussi sous la plateforme offscreen, qui n'a pas de PanelWindow.
//   - contextuel (menu, popover, liste déroulante) : PopupWindow ancrée sous l'élément ancre, à un écart de
//     space.scale[0] de son bord bas, ou sur le point de clic (sans écart) si point est fourni ;
//     horizontalement, la coque serre le cadre dans l'écran quand l'ancre est dans
//     un calque (ancrage.js), le compositeur retourne et glisse la fenêtre sinon ; verticalement, elle est
//     retournée puis glissée (sous une ancre, elle ne se retourne pas et glisse : la marge d'ombre de la fenêtre
//     n'a qu'une correction exacte par sens, voir fenetreContextuel) ; sans voile ; le clavier
//     est pris par HyprlandFocusGrab, dont la levée (clic à l'extérieur) ferme, comme Échap ; plusieurs
//     peuvent coexister.
//   - infobulle : la même PopupWindow, centrée sous l'ancre et serrée dans l'écran comme un contextuel, au même
//     écart de son bord, sans retournement vertical (elle glisse faute de place) ; sans voile ni
//     HyprlandFocusGrab : elle ne prend jamais le clavier et seule son ouvreuse, l'Infobulle, la ferme.
// Le contenu est posé au centre d'une Surface surfaceRaised (e3), entourée d'un retrait ; sa taille est celle du
// contenu. Les formes suivent macOS (conception, § 7.10) : une attention a les coins radius.window et le retrait
// space.scale[2] (12), comme une feuille d'alerte ; un contextuel a les coins radius.panel et le retrait
// space.scale[0] (4), comme un menu, dont la pastille de sélection se tient ainsi près du bord ; une infobulle a
// les coins radius.small et le même retrait (conception, § 7.10). Sobriété (D80) : la fenêtre et le contenu ne
// sont construits qu'à l'ouverture et sont détruits à la fermeture ; ceux d'un contextuel ou d'une infobulle sont
// incubés par le LazyLoader entre deux images, alors que la fenêtre d'attention, créée par le porteur que le
// LazyLoader incube, se construit d'un bloc. Si elle ne peut l'être (fichier en erreur, plateforme sans dorsale
// de couches), l'échec est journalisé et l'Overlay se referme, pour que le registre Overlays ne retienne pas une
// attention sans fenêtre.
// Entrées : famille, "attention", "contextuel" ou "infobulle" ; ouvert, vrai pour ouvrir, faux pour fermer, qui
//           s'affecte et ne se lie pas : le registre Overlays, Échap, le clic sur le voile et la levée du focus
//           l'écrivent impérativement, ce qui romprait une liaison ; l'appelant se resynchronise sur ferme() ; ancre,
//           élément déclencheur d'un contextuel ou d'une infobulle, dans une fenêtre déjà affichée ; point, point de
//           clic dans le repère de l'ancre (Qt.point), null par défaut pour s'ancrer sous l'ancre entière ; contenu,
//           propriété par défaut : l'élément déclaré dans l'Overlay, instancié à chaque ouverture.
// Sorties : ferme(), émis à chaque fermeture, quelle qu'en soit la cause ; chargeur, le LazyLoader de la
//           fenêtre, exposé pour les essais et les relevés de mémoire ; fenetreAttention (un porteur de
//           FenetreAttention) et fenetreContextuel, les composants que le chargeur instancie, internes à la
//           primitive ; bulle, vrai pour la famille infobulle. La fenêtre d'une infobulle est fenetreContextuel.
// Erreurs : aucune ; un contextuel sans ancre affichée ne se montre pas (règle de PopupWindow) ; avant le
//           chargement des tokens, voile et fond restent transparents et le retrait vaut 0.
// Dépendances : Quickshell (LazyLoader, PopupWindow, QsWindow, Edges, PopupAdjustment), ancrage.js (origine,
//               gaucheCadre), Quickshell.Hyprland (Hyprland,
//               HyprlandFocusGrab), Theme (radius, space), Surface, Overlays, FenetreAttention (chargée par son
//               adresse, qui emploie le Cadre déclaré ici).
// Liste ouverte à la souris : Liste passe focusClavier à vrai dès qu'elle reçoit le focus. Un menu
// (selectionSuitSurvol) ne montre jamais le contour de sa rangée courante ; une autre Liste le montrerait, et
// l'ouvreur d'un Overlay ouvert à la souris pose alors focusClavier = false sur elle une fois le focus donné ;
// l'Overlay ne le détecte pas.
QtObject {
    id: overlay

    property string famille: "attention"
    property bool ouvert: false
    property Item ancre: null
    property var point: null
    default property Component contenu
    signal ferme()
    readonly property bool bulle: famille === "infobulle"

    // Cadre — Surface surfaceRaised qui porte le contenu, commune aux trois familles ; seule surface de la fenêtre
    // de l'overlay, elle porte le verre et l'ombre d'élévation e3.
    // Rôle : instancie le contenu dans un Loader, l'entoure du retrait et capte Échap, qu'il signale par echap() ;
    // c'est une FocusScope qui demande le focus, pour que les touches non consommées par le contenu y remontent.
    // Ce composant en ligne n'accède à rien hors de lui : son API est explicite, car un composant en ligne ne
    // partage pas la portée du document qui le déclare.
    // Entrées : contenu, composant à instancier ; rayon, rayon des coins de la Surface ; retrait, marge entre la
    // Surface et le contenu. Sorties : echap(), émis sur Échap non consommé par le contenu ; implicitWidth,
    // implicitHeight, taille du contenu et du retrait. Erreurs : aucune.
    // Dépendances : Surface.
    component Cadre: FocusScope {
        id: cadre

        property Component contenu
        property real rayon
        property real retrait
        signal echap()
        readonly property real marge: ombre.marge

        focus: true
        implicitWidth: charge.implicitWidth + 2 * retrait
        implicitHeight: charge.implicitHeight + 2 * retrait
        Keys.onEscapePressed: echap()

        OmbreElevation {
            id: ombre
            cible: corps
            niveau: "e3"
        }

        Surface {
            id: corps
            anchors.fill: parent
            role: "surfaceRaised"
            radius: cadre.rayon
            verre: true

            Loader {
                id: charge
                anchors.centerIn: parent
                focus: true
                sourceComponent: cadre.contenu
            }
        }
    }

    // Écran du moniteur focalisé d'Hyprland, le premier écran en repli, suivi en continu. Il est évalué dès la
    // création : Hyprland.focusedMonitor vaut undefined au tout premier accès et ne se remplit qu'ensuite (constaté
    // sous Quickshell 0.3.2), et une première lecture faite seulement à l'ouverture enverrait toujours la première
    // attention sur le premier écran.
    readonly property var ecranFocalise: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name)
        ?? Quickshell.screens[0]
    // Écran de l'attention, figé à l'ouverture pour que la fenêtre ne suive pas le pointeur d'un écran à l'autre.
    property var ecran: null

    // Ouverture d'une attention : l'écran focalisé est figé dans ecran, puis Overlays.ouvrir retient cet Overlay et,
    // s'il y en avait une autre, passe son ouvert à faux, ce qui la ferme par ce même gestionnaire. Ouverture d'un
    // contextuel ou d'une infobulle : rien, ils ne passent pas par le registre. Fermeture, pour les trois familles :
    // Overlays.fermer oublie cet Overlay s'il était l'attention retenue, puis ferme() est émis, registre déjà à jour.
    // Dans tous les cas, le chargeur suit ouvert par sa liaison. Protocole repris par essai/shell.qml (ouvrirFactice,
    // fermerFactice).
    onOuvertChanged: {
        if (ouvert && famille === "attention") {
            ecran = ecranFocalise
            Overlays.ouvrir(overlay)
        } else if (!ouvert) {
            Overlays.fermer(overlay)
            ferme()
        }
    }

    readonly property LazyLoader chargeur: LazyLoader {
        activeAsync: overlay.ouvert
        component: overlay.famille === "attention" ? overlay.fenetreAttention : overlay.fenetreContextuel
    }

    // La fenêtre d'attention vit dans FenetreAttention.qml, que ce porteur ne compile qu'à l'ouverture d'une
    // attention (Qt.createComponent, mis en cache par le moteur) : nommer PanelWindow ici empêcherait de charger
    // l'Overlay sous une plateforme sans dorsale de couches, comme la plateforme offscreen des coques d'essai. Le
    // porteur est l'objet du chargeur ; la fenêtre, son enfant, est détruite avec lui à la fermeture. Si le
    // composant n'est pas prêt, ou si la création échoue, l'échec est journalisé et ouvert repasse à faux, après la
    // fin de l'incubation du porteur (Qt.callLater), ce qui ferme l'Overlay et le retire du registre.
    readonly property Component fenetreAttention: QtObject {
        id: porteur
        readonly property Component composant: Qt.createComponent("FenetreAttention.qml")
        readonly property var fenetre: composant.status === Component.Ready
            ? composant.createObject(porteur, { overlay }) : null

        Component.onCompleted: {
            if (fenetre) return
            console.warn("Overlay : fenêtre d'attention non construite. " + composant.errorString())
            Qt.callLater(() => overlay.ouvert = false)
        }
    }

    readonly property Component fenetreContextuel: PopupWindow {
        id: popup
        anchor.item: overlay.ancre
        // Tout overlay ancré à un élément (contextuel et infobulle) se tient à un écart sous lui, comme sur macOS ;
        // un contextuel ouvert au point de clic n'en a pas.
        readonly property real ecart: overlay.point ? 0 : Theme.space?.scale[0] ?? 0
        // Le cadre est en retrait de la marge de l'ombre dans la fenêtre : le rectangle d'ancrage est corrigé pour que
        // le cadre visible tombe là où il tomberait sans marge. Sous une ancre, la fenêtre se pose sous le bord bas
        // du rectangle, alignée sur son bord gauche (contextuel) ou centrée sur lui (infobulle) : le rectangle est
        // donc réduit à une ligne de 1 px, la hauteur minimale de PopupAnchor, dont le bord bas est remonté de la
        // marge au-dessus du bord bas de l'ancre (agrandie de l'écart, sauf à un point de clic), et il est élargi de la
        // marge de chaque côté. Pour un point de clic, le rectangle est élargi de la marge de chaque côté, dans les
        // deux sens, ce qui reste exact aussi une fois retourné. Sous une ancre, la fenêtre ne se retourne pas
        // verticalement mais glisse : retournée, elle aurait demandé un rectangle différent, et PopupAnchor ne
        // connaît aucun décalage qui permette de satisfaire les deux sens ; la coque est une barre en haut de
        // l'écran, dont les menus s'ouvrent vers le bas.
        readonly property real marge: cadrePopup.marge
        readonly property bool surAncre: !overlay.point
        // Serrage horizontal : le compositeur garde dans l'écran la fenêtre entière, marge comprise ; près d'un bord,
        // il la déplacerait dès que la seule marge transparente déborde, et le cadre avec elle. Quand la fenêtre de
        // l'ancre est un calque (PanelWindow), dont la position sur l'écran se déduit (ancrage.js, origine), la
        // coque place elle-même le bord gauche du cadre (gaucheCadre) et ne demande aucun ajustement horizontal : le
        // rectangle d'ancrage est une colonne de 1 px à la marge à gauche de ce bord, et la marge peut sortir de
        // l'écran. La position de l'ancre dans sa fenêtre est lue à la construction de la fenêtre de l'overlay, qui
        // a lieu à chaque ouverture. Sinon (fenêtre flottante), le rectangle reste élargi de la marge et l'ajustement
        // horizontal revient au compositeur.
        readonly property var fenetreAncre: overlay.ancre?.QsWindow.window ?? null
        readonly property real origine: Ancrage.origine(fenetreAncre)
        readonly property bool serre: !isNaN(origine)
        readonly property real ancreX: serre && overlay.ancre ? origine + overlay.ancre.mapToItem(null, 0, 0).x : 0
        readonly property real gaucheCadre: serre
            ? Ancrage.gaucheCadre(overlay.bulle, ancreX, overlay.ancre?.width ?? 0, overlay.point?.x ?? null,
                                  cadrePopup.implicitWidth, fenetreAncre.screen.width) - ancreX
            : 0
        anchor.rect.x: serre ? gaucheCadre - marge : (overlay.point?.x ?? 0) - marge
        anchor.rect.y: overlay.point ? overlay.point.y - marge : (overlay.ancre?.height ?? 1) + ecart - marge - 1
        anchor.rect.width: serre ? 1 : (overlay.point ? 1 : overlay.ancre?.width ?? 1) + 2 * marge
        anchor.rect.height: overlay.point ? 1 + 2 * marge : 1
        // Serré : la fenêtre part du bord gauche du rectangle vers la droite, sous lui (ancre) ou à partir du point
        // de clic, vers le bas ; seul le sens vertical s'ajuste (glissement sous une ancre, retournement puis
        // glissement à un point de clic). Sinon : contextuel sous l'ancre ou à partir du point de clic, vers le bas et
        // la droite ; infobulle centrée sous l'ancre ; sous une ancre, retournement horizontal et glissement.
        anchor.edges: serre || !overlay.bulle ? Edges.Left | (overlay.point ? Edges.Top : Edges.Bottom) : Edges.Bottom
        anchor.gravity: serre || !overlay.bulle ? Edges.Bottom | Edges.Right : Edges.Bottom
        anchor.adjustment: serre ? (surAncre ? PopupAdjustment.SlideY : PopupAdjustment.FlipY | PopupAdjustment.SlideY)
            : surAncre ? PopupAdjustment.FlipX | PopupAdjustment.Slide : PopupAdjustment.Flip | PopupAdjustment.Slide
        // La fenêtre dépasse le cadre de la marge de l'ombre de chaque côté ; seul le cadre reçoit les clics, la
        // marge les laisse passer à la fenêtre dessous.
        readonly property Item cadre: cadrePopup
        implicitWidth: cadrePopup.implicitWidth + 2 * cadrePopup.marge
        implicitHeight: cadrePopup.implicitHeight + 2 * cadrePopup.marge
        color: "transparent"
        visible: true
        mask: Region { item: cadrePopup }

        Cadre {
            id: cadrePopup
            anchors.fill: parent
            anchors.margins: marge
            contenu: overlay.contenu
            rayon: (overlay.bulle ? Theme.radius?.small : Theme.radius?.panel) ?? 0
            retrait: Theme.space?.scale[0] ?? 0
            onEchap: overlay.ouvert = false
        }

        HyprlandFocusGrab {
            windows: [popup]
            active: overlay.ouvert && !overlay.bulle
            onCleared: overlay.ouvert = false
        }
    }
}
