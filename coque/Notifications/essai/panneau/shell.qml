//@ pragma IconTheme DuneI
//@ pragma Env QSG_DISTANCEFIELD_ANTIALIASING=gray
import QtQuick
import Quickshell
import Quickshell.Io
import "Theme"
import "Notifications"
import "Notifications/essai"

// Coque d'essai du contenu du panneau des notifications, sous la plateforme offscreen.
// Rôle : pose un Panneau, dans une fenêtre jamais montrée, sur une Attente de notifications factices créées par IPC ;
// déclenche les gestes du panneau par ses fonctions (les boutons et les touches appellent les mêmes) et rend son état.
// tests/test_notifications.py (PanneauTest) la pilote.
// Entrées : DUNEI_TOKENS_DIR, lu par Theme ; DUNEI_ETAT_DIR, où EtatNotifications lit et écrit son fichier.
// Sortie : « essai : prêt » au démarrage ; voir l'IpcHandler. Erreurs : celles de Theme, dans le journal.
// Dépendances : quickshell ≥ 0.3 (IpcHandler, FloatingWindow), Panneau, Attente, EtatNotifications,
// FausseNotification, FauxVerrou, liens Theme, Composants et Notifications ; thème d'icônes DuneI.
ShellRoot {
    id: essai

    // Le panneau monté, ou un objet vide tant qu'il est démonté.
    readonly property var panneau: chargeur.item ?? ({})

    property int suivant: 1
    property var notifications: ({})
    property var journal: []

    Component.onCompleted: console.info("essai : prêt")

    Attente {
        id: attenteEssai
        verrou: Component { FauxVerrou {} }
    }

    Component {
        id: fabrique
        FausseNotification {}
    }

    FloatingWindow {
        implicitWidth: 400
        implicitHeight: 1000
        color: "transparent"

        // Le panneau est monté par un Loader, comme dans FormePanneau : l'essai le démonte et le remonte.
        Loader {
            id: chargeur
            sourceComponent: Panneau {
                width: Theme.panneau?.largeur ?? 0
                height: implicitHeight
                attente: attenteEssai
            }
        }
    }

    // attendue — entrée de l'attente qui tient une notification. Entrée : id. Sortie : Attendue ou undefined.
    // Erreurs : aucune. Dépendances : attenteEssai.
    function attendue(id) { return attenteEssai.entrees.find(a => a.notification && a.notification.id === id) }

    IpcHandler {
        target: "essai"

        // pret — vrai une fois les jetons chargés. Entrées : aucune. Sortie : « true » ou « false ».
        // Erreurs : aucune. Dépendances : Theme.
        function pret(): string { return String(Theme.panneau !== undefined) }

        // creer — crée une notification factice suivie et l'ajoute à l'attenteEssai.
        // Entrées : app (appName, « » pour une anonyme), resume, urgence (0, 1 ou 2). Sortie : son identifiant.
        // Erreurs : aucune. Dépendances : fabrique, attenteEssai.
        function creer(app: string, resume: string, urgence: int): string {
            const id = essai.suivant++
            const n = fabrique.createObject(essai, {id: id, appName: app, summary: resume, body: "Corps",
                                                    urgency: urgence, tracked: true})
            n.appel.connect(t => essai.journal = essai.journal.concat([t]))
            essai.notifications[id] = n
            attenteEssai.ajouter(n, "", new Date(Date.now() + id))
            return String(id)
        }

        // appels — journal des appels reçus par les notifications, séparés par des virgules. Sortie : texte.
        function appels(): string { return essai.journal.join(",") }

        // etat — JSON de l'état du panneau (monté) : hauteur (implicite), vide (état vide montré), toutEffacer (action
        // offerte), groupes [{nom, nombre, deplie, autres (libellé « N autres » ou « »), retirable, lignes}],
        // texteEtat (état de « ne pas déranger »), nePasDeranger, retirees, nombre (celui de l'attente), courante
        // (identifiant de la notification de l'entrée courante au clavier, 0 sans elle), defilable, montree, entrees
        // (nombre d'entrées de l'attente, sortantes comprises), vue (position de la ligne courante dans la vue).
        // Entrées : aucune. Sortie : texte. Erreurs : aucune. Dépendances : panneau, attente, EtatNotifications.
        function etat(): string {
            return JSON.stringify({hauteur: panneau.implicitHeight, vide: panneau.vide,
                toutEffacer: panneau.effacable, groupes: panneau.releve?.() ?? [], texteEtat: panneau.texteEtat,
                nePasDeranger: EtatNotifications.nePasDeranger, retirees: EtatNotifications.retirees,
                nombre: attenteEssai.nombre, courante: panneau.courante?.notification?.id ?? 0,
                defilable: panneau.defilable, montree: attenteEssai.montree, entrees: attenteEssai.entrees.length,
                vue: panneau.vueCourante?.() ?? null,
                bascule: {allumee: panneau.bascule?.checked ?? null, glyphe: panneau.bascule?.icone ?? null}})
        }

        // monter — monte ou démonte le panneau, comme l'ouverture et la fermeture de sa forme. Entrée : v.
        function monter(v: bool): void { chargeur.active = v }

        // fermerParApp — fermeture d'une notification par son application. Entrée : id.
        function fermerParApp(id: int): void { essai.notifications[id].fermer(3) }

        // hauteurMax — borne la hauteur du panneau, comme le fait sa fenêtre. Entrée : h. Sortie : aucune.
        function hauteurMax(h: real): void { chargeur.item.hauteurMax = h }

        // deplier — clic sur « N autres » d'un groupe. Entrée : identifiant de l'application. Sortie : aucune.
        function deplier(identifiant: string): void { panneau.deplier(identifiant) }

        // ouvrir, ecarter — clic sur une entrée, clic sur son bouton d'écart. Entrée : id de la notification.
        // Sortie : aucune. Erreurs : TypeError au journal si aucune entrée ne la tient.
        function ouvrir(id: int): void { attenteEssai.ouvrir(essai.attendue(id)) }
        function ecarter(id: int): void { attenteEssai.ecarter(essai.attendue(id)) }

        // effacerGroupe, nePlusGarder, toutEffacer, basculer — les actions en texte du panneau et sa bascule.
        // Entrée : identifiant de l'application. Sortie : aucune. Erreurs : aucune. Dépendances : panneau.
        function effacerGroupe(identifiant: string): void { panneau.effacerGroupe(identifiant) }
        function nePlusGarder(identifiant: string): void { panneau.nePlusGarder(identifiant) }
        function toutEffacer(): void { panneau.toutEffacer() }
        function basculer(): void { panneau.bascule.toggle(); panneau.bascule.toggled() }

        // touche — touche reçue par la liste : « bas », « haut », « entree » ou « suppr ». Entrée : nom.
        // Sortie : aucune. Erreurs : aucune. Dépendances : panneau.touche.
        function touche(nom: string): void {
            panneau.touche({bas: Qt.Key_Down, haut: Qt.Key_Up, entree: Qt.Key_Return, suppr: Qt.Key_Delete}[nom])
        }
    }
}
