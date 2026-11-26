import QtQuick
import Quickshell
import Quickshell.Io
import "Theme"
import "Verrou"

// Coque d'essai de la production des fichiers de hyprlock (L2-22).
// Rôle : charge Production.qml sur une liste d'écrans fictifs, vide au départ (rien n'est produit), que l'IPC pose ;
// tests/test_verrou.py (ProductionTest) lit ensuite les fichiers écrits dans DUNEI_ETAT_DIR/verrou.
// Entrées : DUNEI_TOKENS_DIR et DUNEI_ETAT_DIR ; IPC « essai » : produire <{"ecrans": [...]} en JSON>.
// Sorties : « essai : prêt » quand les jetons sont chargés ; « essai : produit <noms des écrans> » à la fin de chaque
// production. Erreurs : celles de Theme et de Production, dans le journal.
// Dépendances : quickshell ≥ 0.3 (IpcHandler) ; liens essai/production/Theme et Verrou, car Quickshell ne suit pas
// les imports hors du dossier de la coque.
ShellRoot {
    id: essai

    property var ecrans: []

    // signaler — annonce la coque prête une fois les jetons chargés. Entrées : aucune. Sortie : « essai : prêt ».
    // Erreurs : aucune. Dépendances : Theme.ready, console.
    function signaler() { if (Theme.ready) console.log("essai : prêt") }

    Component.onCompleted: signaler()
    Connections { target: Theme; function onReadyChanged() { essai.signaler() } }

    Production {
        ecrans: essai.ecrans
        onProduit: console.log("essai : produit " + essai.ecrans.map(e => e.nom).join(" "))
    }

    IpcHandler {
        target: "essai"

        // produire — pose les écrans fictifs, ce qui relance la production.
        // Entrée : json, un objet {"ecrans": [{nom, largeur, hauteur, echelle}]}. Sortie : aucune.
        // Erreurs : JSON invalide → exception au journal. Dépendances : Production.
        function produire(json: string): void { essai.ecrans = JSON.parse(json).ecrans }
    }
}
