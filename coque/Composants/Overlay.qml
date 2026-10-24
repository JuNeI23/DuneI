import QtQuick
import Quickshell
import Quickshell.Hyprland
import "../Theme"

// Overlay — surface posée au-dessus de tout, construite à l'ouverture et détruite à la fermeture.
// Rôle : primitive des surfaces passagères de la coque (conception, § 7.7), en trois familles.
//   - attention (lanceur, sélecteurs, déconnexion, dialogue) : FenetreAttention, PanelWindow plein écran sur
//     l'écran du moniteur focalisé d'Hyprland, couche overlay, clavier exclusif, aucun espace réservé ; voile
//     material.shade sur tout l'écran ; une seule à la fois, par le singleton Overlays ; Échap ou un clic sur le
//     voile la ferment. Elle n'est compilée qu'à l'ouverture d'une attention, si bien que l'Overlay se charge
//     aussi sous la plateforme offscreen, qui n'a pas de PanelWindow.
//   - contextuel (menu, popover, liste déroulante) : PopupWindow ancrée sous l'élément ancre, ou sur le point
//     de clic si point est fourni, retournée puis glissée pour rester dans l'écran ; sans voile ; le clavier
//     est pris par HyprlandFocusGrab, dont la levée (clic à l'extérieur) ferme, comme Échap ; plusieurs
//     peuvent coexister.
//   - infobulle : la même PopupWindow, centrée sous l'ancre, ou au-dessus s'il n'y a pas la place, à un échelon
//     de space (space.scale[0]) de son bord ; sans voile ni HyprlandFocusGrab : elle ne prend jamais le clavier
//     et seule son ouvreuse, l'Infobulle, la ferme.
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
// Dépendances : Quickshell (LazyLoader, PopupWindow, Edges, PopupAdjustment), Quickshell.Hyprland (Hyprland,
//               HyprlandFocusGrab), Theme (radius, space), Surface, Overlays, FenetreAttention (chargée par son
//               adresse, qui emploie le Cadre déclaré ici).
// Liste ouverte à la souris : Liste passe focusClavier à vrai dès qu'elle reçoit le focus, ce qui montre le
// contour de la rangée courante. Si le contenu porte une Liste et que l'Overlay a été ouvert à la souris,
// l'ouvreur pose focusClavier = false sur cette Liste une fois le focus donné ; l'Overlay ne le détecte pas.
QtObject {
    id: overlay

    property string famille: "attention"
    property bool ouvert: false
    property Item ancre: null
    property var point: null
    default property Component contenu
    signal ferme()
    readonly property bool bulle: famille === "infobulle"

    // Cadre — Surface surfaceRaised qui porte le contenu, commune aux trois familles.
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

        focus: true
        implicitWidth: charge.implicitWidth + 2 * retrait
        implicitHeight: charge.implicitHeight + 2 * retrait
        Keys.onEscapePressed: echap()

        Surface {
            anchors.fill: parent
            role: "surfaceRaised"
            radius: cadre.rayon

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
        anchor.rect.x: overlay.point?.x ?? 0
        // L'infobulle s'ancre sur l'ancre agrandie de l'écart en haut et en bas, pour s'en tenir à distance des
        // deux côtés, qu'elle soit posée dessous ou retournée au-dessus.
        readonly property real ecart: overlay.bulle ? Theme.space?.scale[0] ?? 0 : 0
        anchor.rect.y: overlay.point?.y ?? -ecart
        anchor.rect.width: overlay.point ? 1 : overlay.ancre?.width ?? 1
        anchor.rect.height: overlay.point ? 1 : (overlay.ancre?.height ?? 1) + 2 * ecart
        // Contextuel : sous l'ancre, ou à partir du point de clic, en s'étendant vers le bas et la droite.
        // Infobulle : centrée sous l'ancre, retournée au-dessus s'il n'y a pas la place.
        anchor.edges: overlay.bulle ? Edges.Bottom : Edges.Left | (overlay.point ? Edges.Top : Edges.Bottom)
        anchor.gravity: overlay.bulle ? Edges.Bottom : Edges.Bottom | Edges.Right
        anchor.adjustment: PopupAdjustment.Flip | PopupAdjustment.Slide
        implicitWidth: cadrePopup.implicitWidth
        implicitHeight: cadrePopup.implicitHeight
        color: "transparent"
        visible: true

        Cadre {
            id: cadrePopup
            anchors.fill: parent
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
