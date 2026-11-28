import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Notifications
import "../Composants"
import "../Theme"

// Centre — serveur de notifications unique de la coque (L2-19) : la coque possède org.freedesktop.Notifications.
// Rôle : reçoit chaque notification et la remet à sa Pile, qui la suit (tracked), la met en file, la remplace ou
// l'affiche, puis confie à son attente celles qui doivent être traitées (L2-67). Le service est séparé de
// l'affichage : la fenêtre de la pile (FenetreNotifications) lit pile ; la cloche et le panneau lisent attente. La
// pile est liée à EtatNotifications (« ne pas déranger », applications retirées, voix activée) et au plein écran ; la
// voix qu'elle choisit (signal sonner, L2-68) est jouée par Voix. La capacité « sound » n'est pas annoncée (D187),
// mais l'indice suppress-sound est respecté. keepOnReload est vrai : à chaque rechargement de la coque
// (make install, toute modification de coque/), les notifications encore suivies de la génération précédente sont
// réémises par onNotification (lastGeneration vrai) et reprennent place dans la nouvelle pile, minuterie à neuf ; sans
// cela, cartes et file disparaîtraient sans avoir été vues.
// Entrées : pleinEcran, vrai tant que l'écran actif montre une fenêtre en vrai plein écran (PleinEcran, comme dans
// AnnonceurAlerte) ; retenue, vraie pendant le plein écran et encore notifications.reprise ms après
// sa fin, pour que la première carte n'entre pas pendant l'animation de sortie du plein écran (recette de L2-19), et
// tant que le bloc du verrou est là (Overlays.verrou, L2-22) : la notification attend dans la file sans s'annoncer, et
// EtatNotifications n'est pas touché ; une coque d'essai la remplace.
// Sorties : pile, la Pile des notifications reçues ; attente, l'Attente de la pile (notifications gardées).
// Erreurs : si un autre démon tient déjà le nom org.freedesktop.Notifications, Quickshell le journalise et aucune
// notification n'arrive.
// Dépendances : quickshell ≥ 0.3 (Quickshell.Services.Notifications, Quickshell.Hyprland), Pile, Attente,
// EtatNotifications, PleinEcran, Voix.
NotificationServer {
    id: centre

    readonly property bool pleinEcran: PleinEcran.sur(Hyprland.focusedMonitor?.name ?? "")
    property bool retenue: pleinEcran || Overlays.verrou || reprise.running
    readonly property Timer reprise: Timer { interval: Theme.notifications?.reprise ?? 0 }

    onPleinEcranChanged: if (!pleinEcran) reprise.restart()
    readonly property Pile pile: Pile {
        retenue: centre.retenue
        nePasDeranger: EtatNotifications.nePasDeranger
        retirees: EtatNotifications.retirees
        // Sous le verrou comme en plein écran, seule une notification critique sonne (son.js).
        pleinEcran: centre.pleinEcran || Overlays.verrou
        sonActif: EtatNotifications.son
        onSonner: voix => Voix.jouer(voix)
    }
    readonly property Attente attente: pile.attente

    keepOnReload: true
    actionsSupported: true
    imageSupported: true
    bodyMarkupSupported: true
    persistenceSupported: true

    onNotification: n => pile.recevoir(n)
}
