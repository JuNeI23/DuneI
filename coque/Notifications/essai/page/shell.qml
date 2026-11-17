//@ pragma IconTheme DuneI
//@ pragma Env QSG_DISTANCEFIELD_ANTIALIASING=gray
import QtQuick
import Quickshell
import Quickshell.Io
import "Theme"
import "Notifications"

// Coque d'essai de la page Notifications de Paramètres, sous la plateforme offscreen.
// Rôle : pose la vraie PageNotifications, dans une fenêtre jamais montrée, sur un conteneur factice, et la pilote par
// IPC : interrupteur, « Remettre », lecture des rangées. tests/test_notifications.py (PageNotificationsTest) la lance.
// Entrées : DUNEI_TOKENS_DIR, lu par Theme ; DUNEI_ETAT_DIR, où EtatNotifications lit et écrit son fichier.
// Sortie : « essai : prêt » au démarrage ; voir l'IpcHandler. Erreurs : celles de Theme, dans le journal.
// Dépendances : quickshell ≥ 0.3 (IpcHandler, FloatingWindow), PageNotifications, EtatNotifications, liens Theme,
// Composants, Parametres, Reseau et Notifications ; thème d'icônes DuneI.
ShellRoot {
    Component.onCompleted: console.info("essai : prêt")

    // Conteneur factice : la page lui demande de montrer un élément ; le dernier montré est retenu.
    QtObject {
        id: conteneur
        property var montre: null
        function montrer(item) { montre = item }
    }

    FloatingWindow {
        implicitWidth: 700
        implicitHeight: 800
        color: "transparent"

        PageNotifications {
            id: page
            width: 600
            conteneur: conteneur
        }
    }

    IpcHandler {
        target: "essai"

        // pret — vrai une fois les jetons chargés. Sortie : « true » ou « false ».
        function pret(): string { return String(Theme.reglages !== undefined) }

        // etat — JSON {interrupteur, nePasDeranger, retirees, rangees (libellés), vide (ligne « Aucune application
        // retirée » montrée), phrase, montre (objectName du dernier élément montré)}. Sortie : texte.
        function etat(): string {
            return JSON.stringify({interrupteur: page.interrupteur.checked, nePasDeranger: EtatNotifications.nePasDeranger,
                retirees: EtatNotifications.retirees, rangees: page.rangees(), vide: page.vide, phrase: page.phrase,
                montre: conteneur.montre?.objectName ?? ""})
        }

        // basculer — clic sur l'interrupteur de « ne pas déranger ». Sortie : aucune.
        function basculer(): void { page.interrupteur.toggle(); page.interrupteur.toggled() }

        // poser, retirer — changent l'état depuis ailleurs (cloche, panneau). Entrées : v ; identifiant.
        function poser(v: bool): void { EtatNotifications.poser(v) }
        function retirer(identifiant: string): void { EtatNotifications.retirer(identifiant) }

        // remettre — clic sur « Remettre » d'une application retirée. Entrée : identifiant. Sortie : aucune.
        function remettre(identifiant: string): void { page.remettre(identifiant) }

        // atteindre — demande de la recherche. Entrée : ancre, la seconde partie du chemin. Sortie : aucune.
        function atteindre(ancre: string): void { page.atteindre(["notifications", ancre]) }
    }
}
