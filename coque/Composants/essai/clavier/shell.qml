import QtQuick
import QtTest
import Quickshell
import Quickshell.Io
import "Theme"
import "Composants"

// Coque d'essai du clavier : parcours de tabulation et curseur de texte, dans une vraie fenêtre.
// Rôle : ouvre une FloatingWindow (un Bouton « avant », une barre Onglets avec les onglets « tokens » et
// « composants », ce dernier coché, un Bouton « apres », un Champ, une Jauge, puis deux Liste côte à côte, un menu qui porte
// selectionSuitSurvol et un témoin qui ne le porte pas) et y synthétise des touches et des mouvements du pointeur
// par le TestEvent de QtTest, pour que tests/test_coque_composants.py éprouve ce que la coque sans fenêtre ne peut
// pas exécuter : le focus actif, la tabulation, le clignotement du curseur, la mise en page de la barre (qui
// attend le polissage d'une fenêtre) et le survol. Lancée sur la plateforme offscreen par le test : la fenêtre ne
// paraît jamais à l'écran, et ni les touches ni le pointeur n'atteignent le bureau. La coque journalise sa
// plateforme dès son chargement, avant d'ouvrir la fenêtre : le test échoue si ce n'est pas offscreen.
// Entrées : DUNEI_TOKENS_DIR, lu par Theme. Sortie : journal de Theme, « essai : plateforme <nom> » au
// chargement, « essai : prêt true » à l'ouverture de la fenêtre, puis une ligne par commande IPC de lecture : « essai : focus <élément> <onglet courant> <sélection
// de tokens> <sélection de composants> <visualFocus> » et « essai : curseur <cursorVisible> <délégué visible>
// <cursorFlashTime> », « essai : onglets <géométrie de la barre et de ses segments> » et « essai : menu <rangée
// courante du menu> <rangée courante du témoin> », « essai : ongletSurvole <interaction> <fond> » et « essai :
// jauge <valeur> <anneau visible> » ; « essai touche <tab|majtab|gauche|droite> » frappe une touche, « essai
// survoler <rang> » pose le pointeur sur une rangée de chaque liste, « essai survolerOnglet » sur l'onglet
// « tokens » et « essai ongletActif <bool> » active ou désactive l'onglet « composants », sans journaliser.
// Erreurs : celles de Theme et des liaisons, dans le journal ; un nom de touche inconnu lève une TypeError.
// Dépendances : quickshell ≥ 0.3 (FloatingWindow, LazyLoader, IpcHandler), QtTest (TestEvent), modules Theme
// et Composants. Import : les liens Theme -> ../Theme et Composants -> ../Composants les posent sous la racine de
// cette coque, comme dans la coque d'essai voisine.
ShellRoot {
    id: essai

    // journal — écrit une ligne lisible par le test.
    // Entrées : cle, nom de la mesure ; valeur, son résultat. Sortie : aucune ; « essai : <cle> <valeur> ».
    // Erreurs : aucune. Dépendances : console.
    function journal(cle, valeur) {
        console.info("essai : " + cle + " " + valeur)
    }

    Component.onCompleted: journal("plateforme", Qt.platform.pluginName)

    LazyLoader {
        activeAsync: Theme.ready

        FloatingWindow {
            implicitWidth: colonne.implicitWidth
            implicitHeight: colonne.implicitHeight
            Component.onCompleted: essai.journal("prêt", true)

            Column {
                id: colonne

                Bouton { objectName: "avant"; text: "Avant" }
                Onglets {
                    id: barre
                    Onglet { id: tokens; objectName: "tokens"; text: "Tokens"; hoverEnabled: true }
                    Onglet { id: composants; objectName: "composants"; text: "Composants" }
                    Component.onCompleted: currentIndex = 1
                }
                Bouton { objectName: "apres"; text: "Après" }
                Champ { id: champ; objectName: "champ" }
                Jauge { id: jaugeEssai; objectName: "jauge"; value: 0.5 }

                Row {
                    Liste { id: listeMenu; selectionSuitSurvol: true; model: 3; delegate: rangee; width: 100; height: 3 * Theme.density.rowHeight }
                    Liste { id: listeTemoin; model: 3; delegate: rangee; width: 100; height: 3 * Theme.density.rowHeight }
                }
            }

            // Rangée des deux listes, qui sont assez hautes pour les montrer toutes. La plateforme offscreen met
            // Qt.styleHints.useHoverEffects à faux, ce qui ôte le survol aux gabarits : il est rendu ici, comme
            // sur un bureau.
            Component {
                id: rangee
                Rangee { text: "Rangée " + index; hoverEnabled: true }
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
                // Erreurs : aucune. Dépendances : colonne, barre, journal.
                function focus(): void {
                    const elus = [...colonne.children, tokens, composants].filter(e => e.activeFocus && e.objectName)
                    const elu = elus[elus.length - 1]
                    essai.journal("focus", [elu?.objectName ?? "aucun", barre.currentIndex, tokens.etat.selection,
                                            composants.etat.selection, elu?.visualFocus ?? false].join(" "))
                }

                // onglets — journalise la géométrie de la barre d'onglets : fond et rayon de la piste, hauteur,
                // retrait des segments, largeur de chaque segment, plus grande largeur implicite, hauteur et rayon
                // du premier segment (« tokens », non coché), puis le fond de ce segment au repos.
                // Entrées : aucune. Sortie : aucune ; « essai : onglets … ». Erreurs : aucune.
                // Dépendances : barre, tokens, composants, journal.
                function onglets(): void {
                    const b = barre.background
                    essai.journal("onglets", [b.color, b.radius, barre.height, barre.leftPadding, tokens.width,
                        composants.width, Math.max(tokens.implicitWidth, composants.implicitWidth), tokens.height,
                        tokens.background.radius, tokens.background.color].join(" "))
                }

                // survolerOnglet — pose le pointeur au centre de l'onglet « tokens », non coché.
                // Entrées : aucune. Sortie : aucune. Erreurs : aucune. Dépendances : tokens, clavier (TestEvent).
                function survolerOnglet(): void {
                    clavier.mouseMove(tokens, tokens.width / 2, tokens.height / 2, -1, Qt.NoButton, Qt.NoModifier)
                }

                // ongletSurvole — journalise l'interaction de l'onglet « tokens » et la couleur de son fond.
                // Entrées : aucune. Sortie : aucune ; « essai : ongletSurvole <interaction> <#aarrggbb> ».
                // Erreurs : aucune. Dépendances : tokens, journal.
                function ongletSurvole(): void {
                    essai.journal("ongletSurvole", tokens.etat.interaction + " " + tokens.background.color)
                }

                // ongletActif — active ou désactive l'onglet coché « composants ».
                // Entrée : valeur, nouvel état enabled. Sortie : aucune. Erreurs : aucune. Dépendances : composants.
                function ongletActif(valeur: bool): void {
                    composants.enabled = valeur
                }

                // jauge — journalise la valeur de la jauge, arrondie au centième, et la visibilité de son anneau
                // de focus. Entrées : aucune. Sortie : aucune ; « essai : jauge <valeur> <bool> ».
                // Erreurs : aucune. Dépendances : jaugeEssai (l'anneau est le dernier enfant de sa barre), journal.
                function jauge(): void {
                    const b = jaugeEssai.barre.children
                    essai.journal("jauge", Math.round(jaugeEssai.value * 100) / 100 + " " + b[b.length - 1].visible)
                }

                // survoler — pose le pointeur au centre de la rangée de rang donné du menu, puis du témoin.
                // Entrée : rang, rang de la rangée. Sortie : aucune. Erreurs : aucune ; un rang absent ne survole
                // rien. Dépendances : listeMenu, listeTemoin, clavier (TestEvent).
                function survoler(rang: int): void {
                    for (const l of [listeMenu, listeTemoin]) {
                        const r = l.itemAtIndex(rang)
                        if (r) clavier.mouseMove(r, r.width / 2, r.height / 2, -1, Qt.NoButton, Qt.NoModifier)
                    }
                }

                // menu — journalise la rangée courante du menu, puis celle du témoin.
                // Entrées : aucune. Sortie : aucune ; « essai : menu <index> <index> ». Erreurs : aucune.
                // Dépendances : listeMenu, listeTemoin, journal.
                function menu(): void {
                    essai.journal("menu", listeMenu.currentIndex + " " + listeTemoin.currentIndex)
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
