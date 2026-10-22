import QtQuick
import Quickshell
import "Theme"

// Coque d'essai du module Theme, sans aucune fenêtre.
// Rôle : instancie le singleton Theme pour que tests/test_coque_theme.py éprouve dans un vrai Quickshell
// le chargement, la surveillance et le repli des fichiers générés, en lisant le journal.
// Entrées : DUNEI_TOKENS_DIR, lu par Theme. Sortie : journal de Theme, plus « essai : prêt <bool>, couleurs
// définies|indéfinies » à chaque changement de Theme.ready (les raccourcis de groupe doivent déjà être à
// jour), et « essai : ressort posé|en vol » un tour de boucle après chaque nouvel objet de tokens, selon que
// la couleur d'un ColorSpring a déjà rejoint sa cible ou non.
// Erreurs : celles de Theme, dans le journal. Dépendances : quickshell ≥ 0.3, module coque/Theme.
// Import : Quickshell ne résout pas un module situé au-dessus de la racine de la coque lancée (import "../"
// laisse Theme indéfini) ; le lien essai/Theme -> .. le place sous cette racine.
ShellRoot {
    ColorSpring {
        id: spring
        target: Theme.stateColors("surfacePanel", "none", "rest")?.fill ?? "transparent"
    }

    Connections {
        target: Theme
        function onReadyChanged() {
            console.info("essai : prêt " + Theme.ready + ", couleurs " + (Theme.color ? "définies" : "indéfinies"))
        }
        function onTokensChanged() {
            Qt.callLater(() => console.info("essai : ressort "
                + (Qt.colorEqual(spring.value, spring.target) && !spring.moving ? "posé" : "en vol")))
        }
    }
}
