import QtQuick
import Quickshell
import Quickshell.Io
import "Notifications"

// Coque d'essai de l'état persistant des notifications, sans aucune fenêtre.
// Rôle : expose par IPC (cible « essai ») le singleton EtatNotifications, pour que tests/test_notifications.py
// (EtatNotificationsTest) éprouve sa lecture, son écriture et ses fonctions ; la cible « notifications », portée par
// le singleton lui-même, est appelée telle quelle par l'essai.
// Entrées : DUNEI_ETAT_DIR, le dossier où notifications.json est lu et écrit. Sortie : « essai : prêt » au
// démarrage ; voir l'IpcHandler. Erreurs : aucune. Dépendances : quickshell ≥ 0.3 (IpcHandler), EtatNotifications
// (lien Notifications).
ShellRoot {
    Component.onCompleted: { EtatNotifications.nePasDeranger; console.info("essai : prêt") }

    IpcHandler {
        target: "essai"

        // etat — état lu dans le singleton. Entrées : aucune. Sortie : {"nePasDeranger": bool, "retirees": [...]} en
        // JSON. Erreurs : aucune. Dépendances : EtatNotifications.
        function etat(): string {
            return JSON.stringify({nePasDeranger: EtatNotifications.nePasDeranger, retirees: EtatNotifications.retirees})
        }

        // basculer, poser, retirer, remettre, poserSon, poserVolume — relais des fonctions du singleton. Entrées : v ; identifiant.
        // Sortie : aucune. Erreurs : aucune. Dépendances : EtatNotifications.
        function basculer(): void { EtatNotifications.basculer() }
        function poser(v: bool): void { EtatNotifications.poser(v) }
        function retirer(identifiant: string): void { EtatNotifications.retirer(identifiant) }
        function remettre(identifiant: string): void { EtatNotifications.remettre(identifiant) }
        function poserSon(v: bool): void { EtatNotifications.poserSon(v) }
        function poserVolume(v: int): void { EtatNotifications.poserVolume(v) }

        // icone — glyphe de l'état, tel que le lisent la cloche et la bascule. Entrées : aucune. Sortie : son nom.
        // Erreurs : aucune. Dépendances : EtatNotifications.
        function icone(): string { return EtatNotifications.icone }
    }
}
