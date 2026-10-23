import QtQuick
import Quickshell
import Quickshell.Io
import "Theme"
import "Composants"
import "Composants/etats.js" as Etats

// Coque d'essai du module Composants, sans aucune fenêtre.
// Rôle : instancie un arbre fixe (une Surface fenêtre contenant une Surface panneau contenant la sonde
// capteur, plus une Surface inactive à l'écart) pour que tests/test_coque_composants.py éprouve dans un vrai
// Quickshell les règles d'etats.js, l'héritage par remontée et l'import du Theme, en lisant le journal.
// Entrées : DUNEI_TOKENS_DIR, lu par Theme. Sortie : journal de Theme, plus « essai : prêt <bool> » à chaque
// changement de Theme.ready, et une ligne « essai : <clé> <valeur> » par commande IPC de lecture (cran,
// interaction, selection, sonde, naissances) ; « essai inactif <bool> » et « essai reparenter » agissent sans
// journaliser.
// Erreurs : celles de Theme et des liaisons, dans le journal. Dépendances : quickshell ≥ 0.3 (Quickshell.Io :
// IpcHandler), modules coque/Theme et coque/Composants.
// Import : Quickshell ne résout pas un module situé au-dessus de la racine de la coque lancée ; les liens
// essai/Theme -> ../../Theme et essai/Composants -> .. les posent côte à côte sous cette racine, comme dans la
// coque réelle, et le "../Theme" de Surface y désigne essai/Theme, donc le même singleton.
ShellRoot {
    id: essai

    // journal — écrit une ligne lisible par le test.
    // Entrées : cle, nom de la mesure ; valeur, son résultat. Sortie : aucune ; « essai : <cle> <valeur> ».
    // Erreurs : aucune. Dépendances : console.
    function journal(cle, valeur) {
        console.info("essai : " + cle + " " + valeur)
    }

    Surface {
        id: fenetre
        role: "surfaceWindow"
        elevation: "e0"

        Surface {
            id: panneau
            role: "surfacePanel"
            elevation: "e1"

            Item {
                id: capteur
                property int naissances: 0
                readonly property string role: Etats.herite(capteur, "dnRole", "surfaceWindow")
                readonly property bool inactif: Etats.herite(capteur, "dnInactive", false)
                Component.onCompleted: naissances++
            }
        }
    }

    Surface {
        id: inactive
        role: "surfaceRaised"
        elevation: "e3"
        dnInactive: true
    }

    IpcHandler {
        target: "essai"

        // cran — journalise le cran des quatre rôles, dans l'ordre surfaceWindow, surfacePanel, surfaceRaised,
        // controlRaised. Entrées : aucune. Sortie : aucune. Erreurs : aucune. Dépendances : Etats.cran.
        function cran(): void {
            essai.journal("cran", ["surfaceWindow", "surfacePanel", "surfaceRaised", "controlRaised"]
                .map(Etats.cran).join(", "))
        }

        // interaction — journalise l'état de quatre contrôles simulés : désactivé et pressé et survolé, pressé
        // et survolé, survolé, au repos. Entrées : aucune. Sortie : aucune. Erreurs : aucune.
        // Dépendances : Etats.interaction.
        function interaction(): void {
            essai.journal("interaction", [{ enabled: false, down: true, hovered: true },
                { enabled: true, down: true, hovered: true }, { enabled: true, hovered: true }, { enabled: true }]
                .map(Etats.interaction).join(", "))
        }

        // selection — journalise les quatre cas de sélection : non sélectionné, sélectionné inactif avec focus,
        // sélectionné avec focus, sélectionné sans focus. Entrées : aucune. Sortie : aucune. Erreurs : aucune.
        // Dépendances : Etats.selection.
        function selection(): void {
            essai.journal("selection", [[false, true, true], [true, true, true], [true, true, false],
                [true, false, false]].map(a => Etats.selection(...a)).join(", "))
        }

        // sonde — journalise le rôle et le modificateur inactive que la sonde lit par ses liaisons.
        // Entrées : aucune. Sortie : aucune ; « essai : sonde <rôle> <bool> ». Erreurs : aucune.
        // Dépendances : capteur.
        function sonde(): void {
            essai.journal("sonde", capteur.role + " " + capteur.inactif)
        }

        // naissances — journalise le nombre de créations de la sonde, qui doit rester 1 après un reparentage.
        // Entrées : aucune. Sortie : aucune. Erreurs : aucune. Dépendances : capteur.
        function naissances(): void {
            essai.journal("naissances", capteur.naissances)
        }

        // inactif — pose le modificateur inactive sur la Surface fenêtre, en tête de l'arbre de la sonde.
        // Entrées : valeur, nouveau modificateur. Sortie : aucune. Erreurs : aucune. Dépendances : fenetre.
        function inactif(valeur: bool): void {
            fenetre.dnInactive = valeur
        }

        // reparenter — déplace la sonde sous la Surface inactive, sans la recréer.
        // Entrées : aucune. Sortie : aucune. Erreurs : aucune. Dépendances : capteur, inactive.
        function reparenter(): void {
            capteur.parent = inactive
        }
    }

    Connections {
        target: Theme
        function onReadyChanged() {
            essai.journal("prêt", Theme.ready)
        }
    }
}
