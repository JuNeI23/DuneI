//@ pragma IconTheme DuneI
//@ pragma Env QSG_DISTANCEFIELD_ANTIALIASING=gray
import QtQuick
import Quickshell
import Quickshell.Io
import "Theme"
import "Notifications"

// Coque d'essai de la page Notifications de Paramètres, sous la plateforme offscreen.
// Rôle : pose la vraie PageNotifications, dans une fenêtre jamais montrée, sur un conteneur factice, et la pilote par
// IPC : interrupteur, « Remettre », lecture des rangées, carte Son (L2-68, Voix remplacée par un témoin). tests/test_notifications.py (PageNotificationsTest) la lance.
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

    // Témoin de la voix : compte les aperçus, sans rien jouer.
    QtObject {
        id: temoin
        property int apercus: 0
        function jouer(nom) { apercus++ }
    }

    FloatingWindow {
        implicitWidth: 700
        implicitHeight: 800
        color: "transparent"

        PageNotifications {
            id: page
            width: 600
            conteneur: conteneur
            voix: temoin
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

        // basculer — clic sur l'interrupteur des notifications, dans l'en-tête. Sortie : aucune.
        function basculer(): void { page.interrupteur.toggle(); page.interrupteur.toggled() }

        // fondu — JSON {sortante, ancienne} : opacité de la phrase sortante de l'en-tête et texte qu'elle peint.
        // Sortie : texte. Erreurs : aucune. Dépendances : page (enTete).
        function fondu(): string {
            return JSON.stringify({sortante: page.enTete.sortante.opacity, ancienne: page.enTete.ancienne})
        }

        // poser, retirer — changent l'état depuis ailleurs (cloche, panneau). Entrées : v ; identifiant.
        function poser(v: bool): void { EtatNotifications.poser(v) }
        function retirer(identifiant: string): void { EtatNotifications.retirer(identifiant) }

        // remettre — clic sur « Remettre » d'une application retirée. Entrée : identifiant. Sortie : aucune.
        function remettre(identifiant: string): void { page.remettre(identifiant) }

        // etatSon — JSON {interrupteur, son, curseur (valeur du curseur), volumeSon, valeur (texte montré), hauteur (de
        // la rangée de volume), carte (hauteur de la carte Son, telle que sa mise en page la pose), apercus (aperçus
        // joués), decalage (position de la ligne Volume dans sa rangée : négative quand elle remonte sous la rangée
        // précédente)}. Sortie : texte. Erreurs : aucune.
        function etatSon(): string {
            return JSON.stringify({interrupteur: page.interrupteurSon.checked, son: EtatNotifications.son,
                curseur: page.curseurVolume.value, volumeSon: EtatNotifications.volumeSon,
                valeur: EtatNotifications.volumeSon + " %", hauteur: page.rangeeVolume.height, carte: page.carteSon.height,
                decalage: page.rangeeVolume.children.find(c => c.libelle === "Volume").y,
                apercus: temoin.apercus})
        }

        // basculerSon — clic sur l'interrupteur « Activé » de la carte Son. Sortie : aucune.
        function basculerSon(): void { page.interrupteurSon.toggle(); page.interrupteurSon.toggled() }

        // deplacer, relacher — un pas du curseur de volume (glissement ou clavier), puis la fin d'un glissement : le
        // gabarit T.Slider ne laisse pas poser pressed, la page reçoit donc ce que ses gestionnaires lui transmettent.
        // Entrées : v, en pour cent ; enGlissement. Sortie : aucune.
        function deplacer(v: int, enGlissement: bool): void { page.curseurVolume.value = v; page.deplacer(v, enGlissement) }
        function relacher(): void { page.relacher() }

        // atteindre — demande de la recherche. Entrée : ancre, la seconde partie du chemin. Sortie : aucune.
        function atteindre(ancre: string): void { page.atteindre(["notifications", ancre]) }
    }
}
