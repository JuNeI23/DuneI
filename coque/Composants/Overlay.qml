import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../Theme"

// Overlay — surface posée au-dessus de tout, construite à l'ouverture et détruite à la fermeture.
// Rôle : primitive des surfaces passagères de la coque (conception, § 7.7), en deux familles.
//   - attention (lanceur, sélecteurs, déconnexion, dialogue) : PanelWindow plein écran sur l'écran du moniteur
//     focalisé d'Hyprland, couche overlay, clavier exclusif, aucun espace réservé ; voile material.shade sur
//     tout l'écran ; une seule à la fois, par le singleton Overlays ; Échap ou un clic sur le voile la ferment.
//   - contextuel (menu, popover, liste déroulante) : PopupWindow ancrée sous l'élément ancre, ou sur le point
//     de clic si point est fourni, retournée puis glissée pour rester dans l'écran ; sans voile ; le clavier
//     est pris par HyprlandFocusGrab, dont la levée (clic à l'extérieur) ferme, comme Échap ; plusieurs
//     peuvent coexister. L'infobulle, qui ne prend jamais le clavier, n'est pas couverte.
// Le contenu est posé au centre d'une Surface surfaceRaised (e3), entourée d'un retrait ; sa taille est celle du
// contenu. Les formes suivent macOS (conception, § 7.10) : une attention a les coins radius.window et le retrait
// space.scale[2] (12), comme une feuille d'alerte ; un contextuel a les coins radius.panel et le retrait
// space.scale[0] (4), comme un menu, dont la pastille de sélection se tient ainsi près du bord. Sobriété (D80) :
// la fenêtre et le contenu ne sont construits par le LazyLoader qu'à l'ouverture, entre deux images, et
// détruits à la fermeture.
// Entrées : famille, "attention" ou "contextuel" ; ouvert, vrai pour ouvrir, faux pour fermer, qui s'affecte et
//           ne se lie pas : le registre Overlays, Échap, le clic sur le voile et la levée du focus l'écrivent
//           impérativement, ce qui romprait une liaison ; l'appelant se resynchronise sur ferme() ; ancre, élément
//           déclencheur d'un contextuel, dans une fenêtre déjà affichée ; point, point de clic dans le repère de
//           l'ancre (Qt.point), null par défaut pour s'ancrer sous l'ancre entière ; contenu, propriété par
//           défaut : l'élément déclaré dans l'Overlay, instancié à chaque ouverture.
// Sorties : ferme(), émis à chaque fermeture, quelle qu'en soit la cause ; chargeur, le LazyLoader de la
//           fenêtre, exposé pour les essais et les relevés de mémoire ; fenetreAttention et fenetreContextuel,
//           les composants de fenêtre que le chargeur instancie, internes à la primitive.
// Erreurs : aucune ; un contextuel sans ancre affichée ne se montre pas (règle de PopupWindow) ; avant le
//           chargement des tokens, voile et fond restent transparents et le retrait vaut 0.
// Dépendances : Quickshell (LazyLoader, PanelWindow, PopupWindow, Edges, PopupAdjustment, ExclusionMode),
//               Quickshell.Wayland (WlrLayershell), Quickshell.Hyprland (Hyprland, HyprlandFocusGrab), Theme
//               (material, radius, space), Surface, Overlays.
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

    // Cadre — Surface surfaceRaised qui porte le contenu, commune aux deux familles.
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

    // Ouverture d'une attention : l'écran focalisé est figé dans ecran, puis Overlays.ouvrir retient cet Overlay
    // et, s'il y en avait une autre, passe son ouvert à faux, ce qui la ferme par ce même gestionnaire. Ouverture
    // d'un contextuel : rien, il ne passe pas par le registre. Fermeture, pour les deux familles : Overlays.fermer
    // oublie cet Overlay s'il était l'attention retenue, puis ferme() est émis, registre déjà à jour. Dans tous
    // les cas, le chargeur suit ouvert par sa liaison. Protocole repris par essai/shell.qml (ouvrirFactice,
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

    readonly property Component fenetreAttention: PanelWindow {
        screen: overlay.ecran
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        // Un clic hors du cadre tombe sur le voile et ferme ; un clic dans le cadre que le contenu n'a pas pris
        // descend aussi jusqu'ici, et il est ignoré.
        Rectangle {
            id: voile
            anchors.fill: parent
            color: Theme.material?.shade ?? "transparent"

            MouseArea {
                anchors.fill: parent
                onClicked: (m) => {
                    if (!cadreAttention.contains(cadreAttention.mapFromItem(voile, m.x, m.y))) overlay.ouvert = false
                }
            }
        }

        Cadre {
            id: cadreAttention
            anchors.centerIn: parent
            contenu: overlay.contenu
            rayon: Theme.radius?.window ?? 0
            retrait: Theme.space?.scale[2] ?? 0
            onEchap: overlay.ouvert = false
        }
    }

    readonly property Component fenetreContextuel: PopupWindow {
        id: popup
        anchor.item: overlay.ancre
        anchor.rect.x: overlay.point?.x ?? 0
        anchor.rect.y: overlay.point?.y ?? 0
        anchor.rect.width: overlay.point ? 1 : overlay.ancre?.width ?? 1
        anchor.rect.height: overlay.point ? 1 : overlay.ancre?.height ?? 1
        // Sous l'ancre, ou à partir du point de clic, en s'étendant vers le bas et la droite.
        anchor.edges: Edges.Left | (overlay.point ? Edges.Top : Edges.Bottom)
        anchor.gravity: Edges.Bottom | Edges.Right
        anchor.adjustment: PopupAdjustment.Flip | PopupAdjustment.Slide
        implicitWidth: cadrePopup.implicitWidth
        implicitHeight: cadrePopup.implicitHeight
        color: "transparent"
        visible: true

        Cadre {
            id: cadrePopup
            anchors.fill: parent
            contenu: overlay.contenu
            rayon: Theme.radius?.panel ?? 0
            retrait: Theme.space?.scale[0] ?? 0
            onEchap: overlay.ouvert = false
        }

        HyprlandFocusGrab {
            windows: [popup]
            active: overlay.ouvert
            onCleared: overlay.ouvert = false
        }
    }
}
