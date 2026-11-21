//@ pragma IconTheme DuneI
//@ pragma Env QSG_DISTANCEFIELD_ANTIALIASING=gray
import QtQuick
import Quickshell
import Quickshell.Io
import "Theme"
import "Composants"
import "Notifications"

// Coque d'essai de la page Notifications de Paramètres, sous la plateforme offscreen.
// Rôle : pose la vraie PageNotifications, dans une fenêtre jamais montrée, sur un conteneur factice, et la pilote par
// IPC : interrupteur, « Remettre », lecture des rangées, carte Son (L2-68, Voix remplacée par un témoin), focus et
// plaques des contrôles isolés. tests/test_notifications.py (PageNotificationsTest) la lance.
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

        // Racine visuelle de la vue, qui porte l'arbitre du curseur comme FenetreParametres en production.
        Item {
            property VueCurseur dnVue: VueCurseur {}
            width: 600
            height: 800

            PageNotifications {
                id: page
                width: 600
                conteneur: conteneur
                voix: temoin
            }
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

        // remettres — JSON des boutons « Remettre » : [{texte, plat, danger, couleur, fond, sous}], texte du bouton,
        // vrai pour un bouton plat ou destructeur, couleur de son texte, fond affiché, et si le curseur est sur lui.
        // Entrées : aucune. Sortie : texte. Erreurs : aucune. Dépendances : page (boutonsRemettre).
        function remettres(): string {
            return JSON.stringify(page.boutonsRemettre().map(b => ({texte: b.text, plat: b.plat, danger: b.danger,
                couleur: String(b.teinte), fond: String(b.background.color), sous: b.etat.sousCurseur,
                neutre: String(b.etat.texteNeutre)})))
        }

        // curseur — pose le curseur de la vue sur le bouton « Remettre » d'une rangée, comme le survol, ou le lâche.
        // Entrée : rang de la rangée, -1 pour lâcher. Sortie : aucune. Erreurs : TypeError au journal sans cette
        // rangée. Dépendances : page (boutonsRemettre).
        function curseur(rang: int): void {
            const vue = page.parent.dnVue
            if (rang < 0) vue.porteur = null; else vue.prendre(page.boutonsRemettre()[rang])
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

        // focaliser — donne le focus du clavier à l'interrupteur de l'en-tête, à celui du son ou au curseur de volume,
        // comme la tabulation. Entrée : nom, « interrupteur », « interrupteurSon » ou « curseurVolume ». Sortie :
        // aucune. Erreurs : TypeError au journal pour un nom inconnu. Dépendances : page.
        function focaliser(nom: string): void { page[nom].forceActiveFocus(Qt.TabFocusReason) }

        // plaques — JSON {interrupteur, interrupteurSon, curseurVolume} : vrai si le parent du contrôle (sa
        // ZoneCurseur) porte la plaque du curseur (dnSurPlaque). Sortie : texte. Erreurs : aucune. Dépendances : page.
        function plaques(): string {
            const sur = c => c.parent?.dnSurPlaque === true
            return JSON.stringify({interrupteur: sur(page.interrupteur), interrupteurSon: sur(page.interrupteurSon),
                curseurVolume: sur(page.curseurVolume)})
        }

        // atteindre — demande de la recherche. Entrée : ancre, la seconde partie du chemin. Sortie : aucune.
        function atteindre(ancre: string): void { page.atteindre(["notifications", ancre]) }
    }
}
