import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Notifications

// Centre — serveur de notifications unique de la coque (L2-19) : la coque possède org.freedesktop.Notifications.
// Rôle : reçoit chaque notification et la remet à sa Pile, qui la suit (tracked), la met en file, la remplace ou
// l'affiche. Le service est séparé de l'affichage : la fenêtre de la pile (FenetreNotifications) lit pile, comme le
// feront la cloche et l'historique de la feature suivante. keepOnReload est faux : un rechargement de la coque ne
// réémet pas les notifications de la génération précédente.
// Entrées : retenue, vrai tant que l'espace de travail actif de l'écran actif a une fenêtre en plein écran (même
// liaison que dans AnnonceurAlerte) ; une coque d'essai la remplace.
// Sorties : pile, la Pile des notifications reçues.
// Erreurs : si un autre démon tient déjà le nom org.freedesktop.Notifications, Quickshell le journalise et aucune
// notification n'arrive.
// Dépendances : quickshell ≥ 0.3 (Quickshell.Services.Notifications, Quickshell.Hyprland), Pile.
NotificationServer {
    id: centre

    property bool retenue: Hyprland.focusedMonitor?.activeWorkspace?.hasFullscreen ?? false
    readonly property Pile pile: Pile { retenue: centre.retenue }

    keepOnReload: false
    actionsSupported: true
    imageSupported: true
    bodyMarkupSupported: true
    persistenceSupported: true

    onNotification: n => pile.recevoir(n)
}
