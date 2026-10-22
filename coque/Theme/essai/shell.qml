import QtQuick
import Quickshell
import Quickshell.Io
import "Theme"

// Coque d'essai du module Theme, sans aucune fenêtre.
// Rôle : instancie le singleton Theme pour que tests/test_coque_theme.py éprouve dans un vrai Quickshell
// le chargement, la surveillance et le repli des fichiers générés, en lisant le journal.
// Entrées : DUNEI_TOKENS_DIR, lu par Theme. Sortie : journal de Theme, plus « essai : prêt <bool>, couleurs
// définies|indéfinies » à chaque changement de Theme.ready (les raccourcis de groupe doivent déjà être à
// jour), et « essai : ressort posé|en vol » deux tours de boucle après chaque nouvel objet de tokens, selon que
// la couleur d'un ColorSpring a déjà rejoint sa cible ou non. Commande IPC « essai etat <interaction> »
// (rest, hover, pressed, disabled) : change l'état du ressort et journalise « essai : état <interaction>,
// ressort posé|en vol » au tour de boucle suivant ; « essai lent » donne au ressort une raideur minime, pour
// qu'il reste en vol plusieurs secondes.
// Erreurs : celles de Theme, dans le journal. Dépendances : quickshell ≥ 0.3 (Quickshell.Io : IpcHandler), module coque/Theme.
// Import : Quickshell ne résout pas un module situé au-dessus de la racine de la coque lancée (import "../"
// laisse Theme indéfini) ; le lien essai/Theme -> .. le place sous cette racine.
ShellRoot {
    id: essai
    property string interaction: "rest"

    // posture — état du ressort pour le journal.
    // Entrées : aucune. Sortie : « posé » si la couleur affichée a rejoint sa cible et ne bouge plus, sinon
    // « en vol ». Erreurs : aucune. Dépendances : spring.
    function posture() {
        return Qt.colorEqual(spring.value, spring.target) && !spring.moving ? "posé" : "en vol"
    }

    ColorSpring {
        id: spring
        target: Theme.stateColors("surfacePanel", "none", essai.interaction)?.fill ?? "transparent"
    }

    IpcHandler {
        target: "essai"

        // etat — change l'interaction simulée du ressort, comme un survol ou une pression.
        // Entrées : interaction (rest, hover, pressed, disabled). Sortie : aucune ; journal un tour plus tard.
        // Erreurs : aucune ; une interaction inconnue donne une cible transparente. Dépendances : posture.
        function etat(interaction: string): void {
            essai.interaction = interaction
            Qt.callLater(() => console.info("essai : état " + interaction + ", ressort " + essai.posture()))
        }

        // lent — remplace le ressort d'état par un ressort très lent, pour éprouver un ressort en vol.
        // Entrées : aucune. Sortie : aucune. Erreurs : aucune. Dépendances : spring.
        function lent(): void {
            spring.params = { mass: 1, stiffness: 1, dampening: 2 }
        }
    }

    Connections {
        target: Theme
        function onReadyChanged() {
            console.info("essai : prêt " + Theme.ready + ", couleurs " + (Theme.color ? "définies" : "indéfinies"))
        }
        function onTokensChanged() {
            // Deux tours de boucle : le ressort prend acte du nouvel objet de tokens au premier.
            Qt.callLater(() => Qt.callLater(() => console.info("essai : ressort " + essai.posture())))
        }
    }
}
