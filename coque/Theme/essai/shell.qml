import QtQuick
import Quickshell
import "Theme"

// Coque d'essai du module Theme, sans aucune fenêtre.
// Rôle : instancie le singleton Theme pour que tests/test_coque_theme.py éprouve dans un vrai Quickshell
// le chargement, la surveillance et le repli des fichiers générés, en lisant le journal.
// Entrées : DUNEI_TOKENS_DIR, lu par Theme. Sortie : journal de Theme, plus « essai : prêt <bool> » à chaque
// changement de Theme.ready.
// Erreurs : celles de Theme, dans le journal. Dépendances : quickshell ≥ 0.3, module coque/Theme.
// Import : Quickshell ne résout pas un module situé au-dessus de la racine de la coque lancée (import "../"
// laisse Theme indéfini) ; le lien essai/Theme -> .. le place sous cette racine.
ShellRoot {
    Connections {
        target: Theme
        function onReadyChanged() { console.info("essai : prêt " + Theme.ready) }
    }
}
