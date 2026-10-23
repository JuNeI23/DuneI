import QtQuick
import QtTest
import Quickshell
import Quickshell.Io
import "Theme"
import "Composants"

// Coque d'essai du clavier : parcours de tabulation et curseur de texte, dans une vraie fenêtre.
// Rôle : ouvre une FloatingWindow (un Bouton « avant », la BarreOnglets de la planche avec les onglets « tokens »
// et « composants », ce dernier coché, un Bouton « apres » et un Champ) et y synthétise des touches par le
// TestEvent de QtTest, pour que tests/test_coque_composants.py éprouve ce que la coque sans fenêtre ne peut pas
// exécuter : le focus actif, la tabulation et le clignotement du curseur. Lancée sur la plateforme offscreen par
// le test : la fenêtre ne paraît jamais à l'écran et aucune touche n'atteint le bureau.
// Entrées : DUNEI_TOKENS_DIR, lu par Theme. Sortie : journal de Theme, « essai : prêt true » à l'ouverture de la
// fenêtre, puis une ligne par commande IPC de lecture : « essai : focus <élément> <onglet courant> <sélection
// de tokens> <sélection de composants> <visualFocus> » et « essai : curseur <cursorVisible> <délégué visible>
// <cursorFlashTime> » ; « essai touche <tab|majtab|gauche|droite> » frappe une touche sans journaliser.
// Erreurs : celles de Theme et des liaisons, dans le journal ; un nom de touche inconnu lève une TypeError.
// Dépendances : quickshell ≥ 0.3 (FloatingWindow, LazyLoader, IpcHandler), QtTest (TestEvent), modules Theme
// et Composants, BarreOnglets de la planche. Import : les liens Theme -> ../Theme, Composants -> ../Composants et
// BarreOnglets.qml les posent sous la racine de cette coque, comme dans la coque d'essai voisine.
ShellRoot {
    id: essai

    // journal — écrit une ligne lisible par le test.
    // Entrées : cle, nom de la mesure ; valeur, son résultat. Sortie : aucune ; « essai : <cle> <valeur> ».
    // Erreurs : aucune. Dépendances : console.
    function journal(cle, valeur) {
        console.info("essai : " + cle + " " + valeur)
    }

    LazyLoader {
        activeAsync: Theme.ready

        FloatingWindow {
            implicitWidth: colonne.implicitWidth
            implicitHeight: colonne.implicitHeight
            Component.onCompleted: essai.journal("prêt", true)

            Column {
                id: colonne

                Bouton { objectName: "avant"; text: "Avant" }
                BarreOnglets {
                    id: onglets
                    Onglet { id: tokens; objectName: "tokens"; text: "Tokens" }
                    Onglet { id: composants; objectName: "composants"; text: "Composants" }
                    Component.onCompleted: currentIndex = 1
                }
                Bouton { objectName: "apres"; text: "Après" }
                Champ { id: champ; objectName: "champ" }
            }

            TestEvent { id: clavier }

            IpcHandler {
                target: "essai"

                // touche — frappe une touche dans la fenêtre, comme le clavier.
                // Entrée : nom, "tab", "majtab" (Maj+Tab, reçu comme Backtab), "gauche" ou "droite".
                // Sortie : aucune. Erreurs : TypeError pour un nom inconnu. Dépendances : clavier (TestEvent).
                function touche(nom: string): void {
                    const [cle, mod] = ({ tab: [Qt.Key_Tab, Qt.NoModifier], majtab: [Qt.Key_Backtab, Qt.ShiftModifier],
                                          gauche: [Qt.Key_Left, Qt.NoModifier], droite: [Qt.Key_Right, Qt.NoModifier] })[nom]
                    clavier.keyClick(cle, mod, -1)
                }

                // focus — journalise l'élément qui a le focus actif, l'onglet courant et la sélection des onglets.
                // Entrées : aucune. Sortie : aucune ; « essai : focus … », « aucun » si rien n'a le focus.
                // Erreurs : aucune. Dépendances : colonne, onglets, journal.
                function focus(): void {
                    const elus = [...colonne.children, tokens, composants].filter(e => e.activeFocus && e.objectName)
                    const elu = elus[elus.length - 1]
                    essai.journal("focus", [elu?.objectName ?? "aucun", onglets.currentIndex, tokens.etat.selection,
                                            composants.etat.selection, elu?.visualFocus ?? false].join(" "))
                }

                // curseur — journalise l'état du curseur de texte du champ.
                // Entrées : aucune. Sortie : aucune ; « essai : curseur … ». Erreurs : aucune ; avant la première
                // prise de focus, le délégué n'existe pas et compte invisible. Dépendances : champ, journal.
                function curseur(): void {
                    const delegue = champ.children.find(e => e.objectName === "curseur")
                    essai.journal("curseur", [champ.cursorVisible, delegue?.visible ?? false,
                                              Qt.styleHints.cursorFlashTime].join(" "))
                }
            }
        }
    }
}
