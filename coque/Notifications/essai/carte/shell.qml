//@ pragma IconTheme DuneI
import QtQuick
import Quickshell
import Quickshell.Io
import "Theme"
import "Notifications"
import "Notifications/essai"

// Coque d'essai de la carte de notification, sous la plateforme offscreen.
// Rôle : ouvre une fenêtre jamais montrée à l'écran qui porte une seule Carte ; sa notification factice
// (FausseNotification, sans délai d'expiration) est remise à une Pile au démarrage, puis réglée sur place par IPC.
// tests/test_notifications.py (CarteTest) la pilote et relève l'état de la carte.
// Entrées : DUNEI_TOKENS_DIR, lu par Theme ; QT_QPA_PLATFORM, posé à offscreen par le test.
// Sortie : « essai : prêt » au démarrage ; voir l'IpcHandler. Erreurs : celles de Theme, dans le journal.
// Les notifications factices ne sont pas Retainable : la pile reçoit FauxVerrou à la place de RetainableLock.
// Dépendances : quickshell ≥ 0.3 (IpcHandler, FloatingWindow), Pile, Carte, FausseNotification, FauxVerrou,
// liens Theme, Composants et Notifications ; thème d'icônes DuneI (cloche de l'icône générique).
ShellRoot {
    id: essai

    Pile {
        id: pile
        verrou: Component { FauxVerrou {} }
    }

    // La propriété id de la notification factice ne peut s'écrire qu'à la création.
    readonly property QtObject notification: fabrique.createObject(essai, {id: 1, appName: "App", summary: "Titre",
                                                                           expireTimeout: 0})

    Component { id: fabrique; FausseNotification {} }

    Component.onCompleted: {
        pile.recevoir(notification)
        console.info("essai : prêt")
    }

    FloatingWindow {
        implicitWidth: 400
        implicitHeight: 300
        color: "transparent"

        // Écartée de l'origine, où se tient le pointeur virtuel de la plateforme offscreen : il la survolerait.
        Carte { id: carte; x: 40; y: 40; entree: pile.affichees[0] ?? null; pile: pile }
    }

    IpcHandler {
        target: "essai"

        // pret — vrai une fois les jetons chargés et la notification affichée. Sortie : « true » ou « false ».
        function pret(): string { return String(Theme.notifications !== undefined && carte.entree !== null) }

        // regler — règle la notification sur place.
        // Entrées : app, resume, corps ; urgence (0, 1 ou 2) ; image, chemin de l'image jointe ; icone, appIcon ;
        // actions, « identifiant:texte » séparés par des virgules, « » pour aucune. Sortie : aucune.
        function regler(app: string, resume: string, corps: string, urgence: int, image: string, icone: string,
                        actions: string): void {
            Object.assign(essai.notification, {appName: app, summary: resume, body: corps, urgency: urgence, image: image,
                                         appIcon: icone})
            essai.notification.poserActions(actions === "" ? [] : actions.split(",").map(a => a.split(":")))
        }

        // survoler — pose le survol de l'entrée, comme le ferait le pointeur. Entrée : v. Sortie : aucune.
        function survoler(v: bool): void { carte.entree.survolee = v }

        // etat — « source=…;titre=<couleur>;actions=<n>;libelles=a|b;visibles=…;mouvement=…;largeur=…;hauteur=…;
        // lignesCorps=…;app=…;heure=HH:mm ». Sortie : texte. Dépendances : carte.
        function etat(): string {
            return ["source=" + carte.sourceIcone, "titre=" + carte.couleurTitre, "actions=" + carte.actions.length,
                    "libelles=" + carte.libelles.join("|"), "visibles=" + carte.actionsVisibles,
                    "mouvement=" + carte.enMouvement, "largeur=" + carte.width, "hauteur=" + carte.implicitHeight,
                    "lignesCorps=" + carte.lignesCorps, "app=" + carte.texteApplication,
                    "heure=" + carte.texteHeure].join(";")
        }
    }
}
