//@ pragma IconTheme DuneI
//@ pragma Env QSG_DISTANCEFIELD_ANTIALIASING=gray
import QtQuick
import QtTest
import Quickshell
import Quickshell.Io
import "Theme"
import "Lanceur"

// Coque d'essai du clavier du lanceur (L2-16), sous la plateforme offscreen, sans écran ni compositeur.
// Rôle : pose un CadreLanceur dans une fenêtre jamais montrée à Nicolas (Lanceur.fenetree faux : aucune fenêtre de
// calque) et y presse de vraies touches de Qt par un TestCase de QtTest (keyClick) : l'évènement suit le chemin réel,
// du champ (Keys.onPressed) à la Recherche, jusqu'à Lanceur.touche. Aucun clavier de la session n'est jamais pris.
// tests/test_lanceur.py (ClavierTest) la pilote.
// Entrées : DUNEI_TOKENS_DIR et DUNEI_ETAT_DIR ; IPC « essai » : injecter, cle, focus. Sorties : « essai : prêt » au
// démarrage ; « essai : exécuté <genre> <cible> » à chaque action. Erreurs : celles de Theme, dans le journal.
// Dépendances : quickshell ≥ 0.3 (IpcHandler, FloatingWindow), QtTest (TestCase), Lanceur, CadreLanceur, Theme ; liens
// essai/clavier/Theme, Composants, Applications, Parametres, Barre et Lanceur.
ShellRoot {
    // Component.onCompleted — retire la fenêtre de calque, détourne l'exécution et signale que la coque est prête.
    // Entrées : aucune. Sortie : la ligne « essai : prêt ». Erreurs : aucune. Dépendances : Lanceur, console.
    Component.onCompleted: {
        Lanceur.fenetree = false
        Lanceur.executeur = a => console.log("essai : exécuté " + a.genre + " " + a.cible)
        console.log("essai : prêt")
    }

    FloatingWindow {
        id: fenetre
        implicitWidth: 1000
        implicitHeight: 560
        color: "transparent"

        Loader {
            id: charge
            active: Lanceur.ouvert
            sourceComponent: CadreLanceur {}
        }
        TestCase { id: testeur; when: false }
    }

    IpcHandler {
        target: "essai"

        // injecter — remplace des entrées des sources du lanceur. Entrée : json (clés de Sources). Sortie : aucune.
        function injecter(json: string): void {
            const d = JSON.parse(json)
            for (const cle in d) Lanceur.sources[cle] = d[cle]
        }

        // focus — vrai si le champ du cadre a le focus actif. Sortie : « true » ou « false ».
        function focus(): string { return String(charge.item?.champ.activeFocus ?? false) }

        // cle — presse une vraie touche dans la fenêtre. Entrée : nom, « escape », « tab », « return », « down », « up ».
        // Sortie : aucune. Erreurs : aucune. Dépendances : testeur (keyClick).
        function cle(nom: string): void {
            charge.item?.champ.forceActiveFocus()
            testeur.keyClick({ escape: Qt.Key_Escape, tab: Qt.Key_Tab, "return": Qt.Key_Return, down: Qt.Key_Down,
                               up: Qt.Key_Up }[nom])
        }
    }

    IpcHandler {
        target: "notifications"

        // nePasDeranger — faux état de « ne pas déranger ». Sortie : « true ».
        function nePasDeranger(): string { return "true" }
    }
}
