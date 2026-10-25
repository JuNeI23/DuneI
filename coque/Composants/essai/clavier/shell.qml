import QtQuick
import QtTest
import Quickshell
import Quickshell.Io
import "Theme"
import "Composants"

// Coque d'essai du clavier : parcours de tabulation et curseur de texte, dans une vraie fenêtre.
// Rôle : ouvre une FloatingWindow (un Bouton « avant », une barre Onglets avec les onglets « tokens » et « composants
// », ce dernier coché, un Bouton « apres », un Champ, une Jauge, un Compteur, un Deroulant, des Pastilles, une
// Recherche, une Depliable, une Bascule, une Activite, un Bouton « bulle » qui porte une Infobulle sans texte (jamais
// de fenêtre), puis deux Liste côte à côte, un menu qui porte selectionSuitSurvol et un témoin qui ne le porte pas) et
// y synthétise des touches et des mouvements du pointeur par le TestEvent de QtTest, pour que
// tests/test_coque_composants.py éprouve ce que la coque sans fenêtre ne peut pas exécuter : le focus actif, la
// tabulation, le clignotement du curseur, la mise en page de la barre (qui attend le polissage d'une fenêtre) et le
// survol.
// Garde de plateforme : la coque journalise Qt.platform.pluginName dès son chargement, et son LazyLoader ne
// construit la fenêtre que sous la plateforme offscreen, où elle ne paraît jamais à l'écran et où ni les touches
// ni le pointeur n'atteignent le bureau. Lancée sous une autre plateforme (wayland compris), elle n'ouvre donc
// aucune fenêtre et ne se déclare jamais prête ; le test lit la ligne de plateforme avant d'attendre « prêt » et
// échoue en la nommant.
// Entrées : DUNEI_TOKENS_DIR, lu par Theme ; QT_QPA_PLATFORM, posé à offscreen par le test.
// Sortie : journal de Theme, « essai : plateforme <nom> » au chargement, « essai : prêt true » à l'ouverture de la
// fenêtre, puis une ligne par commande IPC de lecture : « essai : focus <élément> <onglet courant> <sélection de
// tokens> <sélection de composants> <visualFocus> », « essai : curseur <cursorVisible> <délégué visible>
// <cursorFlashTime> », « essai : onglets <géométrie de la barre et de ses segments> », « essai : menu <rangée courante
// du menu> <rangée courante du témoin> », « essai : ongletSurvole <interaction> <fond> » et « essai : jauge <valeur>
// <anneau visible> », ainsi que attention, anneauOnglets, compteur, deroulant, pastilles, pastillesCouleurs, bascule,
// activite, materiauDpr, contextuel et ancrage (voir chaque fonction) ; « essai touche <tab|majtab|gauche|droite|haut|bas|espace|entree|echap> » frappe une
// touche, « essai activiteMarche <bool> » lance ou arrête l'indicateur d'activité, « essai molette <1|-1> » tourne la
// molette sur le compteur, « essai cliquerDeroulant » clique le déroulant, « essai ouvrirAttention » ouvre l'Overlay
// d'attention, « essai ouvrirContextuel » celui du contextuel, « essai pointerRangee <rang> <bool> » pose le pointeur sur une rangée du menu ouvert et l'y clique si
// demandé, « essai pointerPastille <rang> <bool> » pose le pointeur sur une pastille et l'y clique si demandé, « essai
// appuyerPastille <rang> <bool> » enfonce ou relâche le bouton sur une pastille, « essai pastillesReduire <bool> »
// active ou désactive la pastille de réduction, « essai rechercheTexte <texte> » remplit la recherche, « essai
// cliquerEffacer » clique son bouton d'effacement, « essai cliquerDepliable » clique l'en-tête de la section, « essai
// survolerBulle », « essai quitterBulle » et « essai appuyerBulle » posent le pointeur sur le bouton « bulle », l'en
// retirent ou l'y cliquent ; « essai cibleNouvelle », « essai cibleDetruire » et « essai survolerMobile » créent,
// détruisent ou survolent la cible de l'infobulle mobile ; recherche, depliable, bulle, survolerBulle et mobile
// journalisent (voir chaque fonction), « essai survoler <rang> » pose le pointeur sur une rangée de chaque liste, «
// essai survolerOnglet » sur l'onglet « tokens » et « essai ongletActif <bool> » active ou désactive l'onglet «
// composants », sans journaliser. Erreurs : celles de Theme et des liaisons, dans le journal ; un nom de touche inconnu
// lève une TypeError.
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
        activeAsync: Theme.ready && Qt.platform.pluginName === "offscreen"

        FloatingWindow {
            id: fenetre
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
                Compteur { id: compteurEssai; objectName: "compteur"; from: 0; to: 3; value: 1 }

                Deroulant {
                    id: deroulantEssai
                    property int activations: 0
                    objectName: "deroulant"
                    model: ["Un", "Deux", "Trois"]
                    onActivated: activations++
                }

                // Pastilles dont chaque signal compte ses émissions ; elles ne sont pas un arrêt de tabulation.
                Pastilles {
                    id: pastillesEssai
                    property var emis: ({ fermer: 0, reduire: 0, agrandir: 0 })
                    onFermer: emis = Object.assign({}, emis, { fermer: emis.fermer + 1 })
                    onReduire: emis = Object.assign({}, emis, { reduire: emis.reduire + 1 })
                    onAgrandir: emis = Object.assign({}, emis, { agrandir: emis.agrandir + 1 })
                }

                Recherche { id: rechercheEssai; objectName: "recherche" }

                Depliable {
                    id: depliableEssai
                    text: "Section"
                    Texte { text: "Contenu" }
                }

                Bascule { id: basculeEssai; objectName: "bascule"; icone: "network-wireless"; text: "Wi-Fi" }

                // L'indicateur d'activité, arrêté : « essai activiteMarche » le lance.
                Activite { id: activiteEssai; running: false }

                // Bouton qui porte l'infobulle et compte ses clics. L'infobulle n'a pas de texte : son délai et sa
                // fermeture s'éprouvent sans qu'aucune fenêtre ne s'ouvre.
                Bouton {
                    id: boutonBulle
                    property int clics: 0
                    objectName: "bulle"
                    text: "Bulle"
                    onClicked: clics++
                }

                Infobulle { id: infobulleEssai; cible: boutonBulle }

                // Infobulle sans texte dont la cible, un Bouton « mobile » créé et détruit à la demande, change en
                // cours de vie.
                Infobulle { id: infobulleMobile }

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

            // Overlay d'attention : sous offscreen, sa fenêtre (PanelWindow) ne peut pas se construire, ce qui éprouve
            // le repli de l'Overlay (échec journalisé, ouvert rendu à faux, registre vidé).
            Overlay {
                id: attentionEssai
                famille: "attention"
                Texte { text: "attention" }
            }

            // Overlay contextuel, ancré sur le bouton « bulle » : « essai ouvrirContextuel » l'ouvre, pour mesurer sa
            // fenêtre et la marge de son ombre.
            Overlay {
                id: contextuelEssai
                famille: "contextuel"
                ancre: boutonBulle
                Texte { text: "contextuel" }
            }

            // Ancre haute (80 px, plus de deux marges), sur laquelle se posent un contextuel et une infobulle d'essai
            // pour éprouver l'ancrage sans que la correction soit bornée.
            Item { id: ancreHaute; width: 100; height: 80 }
            Overlay { id: contextuelAncre; famille: "contextuel"; ancre: ancreHaute; Texte { text: "contextuel" } }
            Overlay { id: bulleAncree; famille: "infobulle"; ancre: ancreHaute; Texte { text: "bulle" } }

            // Infobulle créée et détruite à la demande sur le bouton « bulle », qui lui survit ; ses gestionnaires sont
            // gardés dans des propriétés typées, que le moteur remet à null quand ils sont détruits.
            property Infobulle jetable: null
            property HoverHandler gardeSurvol: null
            property TapHandler gardeAppui: null

            Component {
                id: modeleInfobulle
                Infobulle { cible: boutonBulle }
            }

            // Cible créée à la demande dans le contenu de la fenêtre, pour l'infobulle mobile.
            Component {
                id: modeleCible
                Bouton { objectName: "mobile"; text: "Mobile" }
            }

            TestEvent { id: clavier }

            IpcHandler {
                target: "essai"

                // touche — frappe une touche dans la fenêtre, comme le clavier.
                // Entrée : nom, "tab", "majtab" (Maj+Tab, reçu comme Backtab), "gauche", "droite", "haut", "bas",
                // "espace", "entree" ou "echap".
                // Sortie : aucune. Erreurs : TypeError pour un nom inconnu. Dépendances : clavier (TestEvent).
                function touche(nom: string): void {
                    const cle = ({ tab: Qt.Key_Tab, majtab: Qt.Key_Backtab, gauche: Qt.Key_Left, droite: Qt.Key_Right,
                                   haut: Qt.Key_Up, bas: Qt.Key_Down, espace: Qt.Key_Space, entree: Qt.Key_Return,
                                   echap: Qt.Key_Escape })[nom]
                    clavier.keyClick(cle, nom === "majtab" ? Qt.ShiftModifier : Qt.NoModifier, -1)
                }

                // ouvrirAttention — ouvre l'Overlay d'attention d'essai. Entrées : aucune. Sortie : aucune.
                // Erreurs : aucune ; l'échec de construction de la fenêtre est journalisé par l'Overlay.
                // Dépendances : attentionEssai.
                function ouvrirAttention(): void {
                    attentionEssai.ouvert = true
                }

                // attention — journalise l'état ouvert de l'Overlay d'attention d'essai et l'attention retenue par le
                // registre (null si aucune). Entrées : aucune. Sortie : aucune ; « essai : attention <bool>
                // <null|retenue> ». Erreurs : aucune. Dépendances : attentionEssai, Overlays, journal.
                function attention(): void {
                    essai.journal("attention", attentionEssai.ouvert + " "
                        + (Overlays.attention === null ? "null" : "retenue"))
                }

                // ouvrirContextuel — ouvre l'Overlay contextuel d'essai. Entrées : aucune. Sortie : aucune.
                // Erreurs : aucune. Dépendances : contextuelEssai.
                function ouvrirContextuel(): void {
                    contextuelEssai.ouvert = true
                    contextuelAncre.ouvert = true
                    bulleAncree.ouvert = true
                }

                // contextuel — journalise la largeur et la hauteur de la fenêtre du contextuel, celles de son cadre,
                // puis la marge de son ombre. Entrées : aucune. Sortie : aucune ; « essai : contextuel <l> <h> <l> <h>
                // <marge> » ; « absent » tant que la fenêtre n'est pas construite. Erreurs : aucune.
                // Dépendances : contextuelEssai (chargeur, fenêtre, cadre), journal.
                function contextuel(): void {
                    const f = contextuelEssai.chargeur.item
                    essai.journal("contextuel", f ? [f.width, f.height, f.cadre.width, f.cadre.height, f.cadre.marge].join(" ") : "absent")
                }

                // ancrage — journalise où l'ancrage de la fenêtre d'un Overlay d'essai (« contextuel » ou « bulle »)
                // posera le cadre visible, d'après le modèle d'xdg_popup : la fenêtre se pose sous le bord bas du
                // rectangle d'ancrage, alignée sur son bord gauche (contextuel) ou centrée sur lui (bulle), et le
                // cadre est en retrait de la marge. Entrée : nom. Sortie : aucune ; « essai : ancrage <nom> <dx> <dy>
                // <marge> », décalage du coin haut gauche du cadre (contextuel) ou de son centre horizontal (bulle) au
                // coin bas gauche de l'ancre d'essai, puis, pour la bulle, l'écart attendu en plus ; « absent » tant que
                // la fenêtre n'est pas construite. Erreurs : aucune. Dépendances : contextuelAncre, journal.
                function ancrage(nom: string): void {
                    const o = nom === "bulle" ? bulleAncree : contextuelAncre
                    const f = o.chargeur.item
                    if (!f) return essai.journal("ancrage", nom + " absent")
                    const r = f.anchor.rect, m = f.cadre.marge, h = ancreHaute.height
                    const dx = nom === "bulle" ? r.x + r.width / 2 - ancreHaute.width / 2 : r.x + m
                    essai.journal("ancrage", [nom, dx, r.y + r.height + m - h, m].join(" "))
                }

                // anneauOnglets — journalise la visibilité de l'anneau de la barre d'onglets, puis celle de l'anneau
                // propre au segment « composants ». Entrées : aucune. Sortie : aucune ; « essai : anneauOnglets
                // <bool> <bool> ». Erreurs : aucune. Dépendances : barre (anneau), composants (anneau), journal.
                function anneauOnglets(): void {
                    essai.journal("anneauOnglets", barre.anneau.visible + " " + composants.anneau.visible)
                }

                // materiauDpr — journalise le rapport de pixels que reçoit le Materiau du fond du champ, celui de la
                // fenêtre (QT_SCALE_FACTOR compris). Entrées : aucune. Sortie : aucune ; « essai : materiauDpr <dpr> ».
                // Erreurs : aucune. Dépendances : champ (background, un Materiau), journal.
                function materiauDpr(): void {
                    essai.journal("materiauDpr", champ.background.dpr)
                }

                // compteur — journalise la valeur du compteur, la visibilité de son anneau, puis l'activation des
                // demi-boutons haut et bas. Entrées : aucune. Sortie : aucune ; « essai : compteur <valeur> <bool>
                // <bool> <bool> ». Erreurs : aucune. Dépendances : compteurEssai, journal.
                function compteur(): void {
                    const c = compteurEssai
                    essai.journal("compteur", [c.value, c.anneau.visible, c.up.indicator.enabled,
                                               c.down.indicator.enabled].join(" "))
                }

                // molette — fait tourner la molette d'un cran au-dessus du compteur.
                // Entrée : sens, 1 vers le haut, -1 vers le bas. Sortie : aucune. Erreurs : aucune.
                // Dépendances : compteurEssai, clavier (TestEvent).
                function molette(sens: int): void {
                    const c = compteurEssai
                    clavier.mouseWheel(c, c.width / 4, c.height / 2, Qt.NoButton, Qt.NoModifier, 0, 120 * sens, -1)
                }

                // deroulant — journalise le rang et le texte du déroulant, le nombre d'activations, l'état ouvert de
                // son menu, puis, menu ouvert, la rangée courante de la liste, son drapeau focusClavier et la
                // visibilité de la coche de chaque rangée. Entrées : aucune. Sortie : aucune ; « essai : deroulant
                // <rang> <texte> <n> <bool> [<rang> <bool> <bool>…] ». Erreurs : aucune.
                // Dépendances : deroulantEssai (menu, liste), journal.
                function deroulant(): void {
                    const d = deroulantEssai, l = d.liste
                    // La coche d'une rangée se trouve par son objectName (« glyphe », celui de Coche), à toute
                    // profondeur.
                    const glyphe = e => e?.objectName === "glyphe" ? e
                        : Array.from(e?.children ?? []).map(glyphe).find(g => g) ?? null
                    const coches = l ? [0, 1, 2].map(i => glyphe(l.itemAtIndex(i))?.visible) : []
                    essai.journal("deroulant", [d.currentIndex, d.displayText, d.activations, d.menu.ouvert]
                        .concat(l ? [l.currentIndex, l.focusClavier] : [], coches).join(" "))
                }

                // cliquerDeroulant — clique au centre du déroulant, comme la souris.
                // Entrées : aucune. Sortie : aucune. Erreurs : aucune. Dépendances : deroulantEssai, clavier.
                function cliquerDeroulant(): void {
                    const d = deroulantEssai
                    clavier.mouseClick(d, d.width / 2, d.height / 2, Qt.LeftButton, Qt.NoModifier, -1)
                }

                // pointerRangee — pose le pointeur sur une rangée du menu ouvert du déroulant, et l'y clique si
                // demandé. Les événements de la souris vont à la fenêtre de la rangée, le menu, même sans focus
                // clavier. Entrées : rang, rang de la rangée ; clic, vrai pour cliquer. Sortie : aucune. Erreurs :
                // TypeError si le menu est fermé. Dépendances : deroulantEssai (liste), clavier.
                function pointerRangee(rang: int, clic: bool): void {
                    const r = deroulantEssai.liste.itemAtIndex(rang)
                    clavier.mouseMove(r, r.width / 2, r.height / 2, -1, Qt.NoButton, Qt.NoModifier)
                    if (clic) clavier.mouseClick(r, r.width / 2, r.height / 2, Qt.LeftButton, Qt.NoModifier, -1)
                }

                // pastilles — journalise le survol du groupe, la visibilité des trois glyphes et le nombre
                // d'émissions de fermer, reduire et agrandir. Entrées : aucune. Sortie : aucune ; « essai :
                // pastilles <bool> <bool> <bool> <bool> <n> <n> <n> ». Erreurs : aucune.
                // Dépendances : pastillesEssai (survol, disques, emis), journal.
                function pastilles(): void {
                    const p = pastillesEssai, e = p.emis
                    essai.journal("pastilles", [p.survol, ...[0, 1, 2].map(i => p.disques.itemAt(i).trace.visible),
                                                e.fermer, e.reduire, e.agrandir].join(" "))
                }

                // pastillesCouleurs — journalise la couleur peinte de chacune des trois pastilles.
                // Entrées : aucune. Sortie : aucune ; « essai : pastillesCouleurs <#> <#> <#> ». Erreurs : aucune.
                // Dépendances : pastillesEssai (disques), journal.
                function pastillesCouleurs(): void {
                    essai.journal("pastillesCouleurs", [0, 1, 2].map(i => pastillesEssai.disques.itemAt(i).couleur)
                        .join(" "))
                }

                // appuyerPastille — pose le pointeur au centre d'une pastille, comme la souris qui s'y déplace, puis
                // y enfonce le bouton gauche, ou l'y relâche.
                // Entrées : rang, 0, 1 ou 2 ; appui, vrai pour enfoncer, faux pour relâcher. Sortie : aucune.
                // Erreurs : TypeError pour un rang absent. Dépendances : pastillesEssai, clavier (TestEvent).
                function appuyerPastille(rang: int, appui: bool): void {
                    const d = pastillesEssai.disques.itemAt(rang)
                    clavier.mouseMove(d, d.width / 2, d.height / 2, -1, Qt.NoButton, Qt.NoModifier)
                    if (appui) clavier.mousePress(d, d.width / 2, d.height / 2, Qt.LeftButton, Qt.NoModifier, -1)
                    else clavier.mouseRelease(d, d.width / 2, d.height / 2, Qt.LeftButton, Qt.NoModifier, -1)
                }

                // bascule — journalise la bascule d'essai : allumée, sélection de son Etat, focus clavier, anneau
                // visible et rond (son rayon suit celui du disque). Entrées : aucune. Sortie : aucune ; « essai :
                // bascule <bool> <sélection> <bool> <bool> ». Erreurs : aucune. Dépendances : basculeEssai, journal.
                function bascule(): void {
                    const b = basculeEssai, a = b.anneau
                    essai.journal("bascule", [b.checked, b.etat.selection, b.visualFocus,
                                              a.visible && a.radius === b.disque.radius + a.decalage].join(" "))
                }

                // pointerPastille — pose le pointeur au centre d'une pastille, et l'y clique si demandé.
                // Entrées : rang, 0 (fermer), 1 (réduire) ou 2 (agrandir) ; clic, vrai pour cliquer.
                // Sortie : aucune. Erreurs : TypeError pour un rang absent. Dépendances : pastillesEssai, clavier.
                function pointerPastille(rang: int, clic: bool): void {
                    const d = pastillesEssai.disques.itemAt(rang)
                    clavier.mouseMove(d, d.width / 2, d.height / 2, -1, Qt.NoButton, Qt.NoModifier)
                    if (clic) clavier.mouseClick(d, d.width / 2, d.height / 2, Qt.LeftButton, Qt.NoModifier, -1)
                }

                // pastillesReduire — active ou désactive la pastille de réduction.
                // Entrée : valeur, nouveau reduireActif. Sortie : aucune. Erreurs : aucune.
                // Dépendances : pastillesEssai.
                function pastillesReduire(valeur: bool): void {
                    pastillesEssai.reduireActif = valeur
                }

                // activite — journalise l'état en marche de l'animation de chacun des trois grains de l'indicateur.
                // Entrées : aucune. Sortie : aucune ; « essai : activite <bool> <bool> <bool> ». Erreurs : aucune.
                // Dépendances : activiteEssai (repeteur), journal.
                function activite(): void {
                    essai.journal("activite", [0, 1, 2].map(i => activiteEssai.repeteur.itemAt(i).animation.running)
                                                     .join(" "))
                }

                // activiteMarche — lance ou arrête l'indicateur.
                // Entrée : valeur, nouvelle marche. Sortie : aucune. Erreurs : aucune. Dépendances : activiteEssai.
                function activiteMarche(valeur: bool): void {
                    activiteEssai.running = valeur
                }

                // recherche — journalise le texte de la recherche, entre chevrons, et la visibilité de son bouton
                // d'effacement. Entrées : aucune. Sortie : aucune ; « essai : recherche «<texte>» <bool> ».
                // Erreurs : aucune. Dépendances : rechercheEssai (effacer), journal.
                function recherche(): void {
                    essai.journal("recherche", "«" + rechercheEssai.text + "» " + rechercheEssai.effacer.visible)
                }

                // rechercheTexte — remplace le texte de la recherche.
                // Entrée : texte, nouveau contenu. Sortie : aucune. Erreurs : aucune. Dépendances : rechercheEssai.
                function rechercheTexte(texte: string): void {
                    rechercheEssai.text = texte
                }

                // cliquerEffacer — clique au centre du bouton d'effacement de la recherche, comme la souris.
                // Entrées : aucune. Sortie : aucune. Erreurs : aucune. Dépendances : rechercheEssai, clavier.
                function cliquerEffacer(): void {
                    const e = rechercheEssai.effacer
                    clavier.mouseClick(e, e.width / 2, e.height / 2, Qt.LeftButton, Qt.NoModifier, -1)
                }

                // depliable — journalise l'état de la section : ouverte, bloc de contenu visible, anneau visible.
                // Entrées : aucune. Sortie : aucune ; « essai : depliable <bool> <bool> <bool> ». Erreurs : aucune.
                // Dépendances : depliableEssai (bloc, anneau), journal.
                function depliable(): void {
                    const d = depliableEssai
                    essai.journal("depliable", [d.ouvert, d.bloc.visible, d.anneau.visible].join(" "))
                }

                // cliquerDepliable — clique au centre de l'en-tête de la section, comme la souris.
                // Entrées : aucune. Sortie : aucune. Erreurs : aucune. Dépendances : depliableEssai, clavier.
                function cliquerDepliable(): void {
                    const e = depliableEssai.entete
                    clavier.mouseClick(e, e.width / 2, e.height / 2, Qt.LeftButton, Qt.NoModifier, -1)
                }

                // bulle — journalise l'état de l'infobulle (délai armé, délai écoulé, overlay ouvert) et le nombre
                // de clics reçus par le bouton qui la porte. Entrées : aucune. Sortie : aucune ; « essai : bulle
                // <bool> <bool> <bool> <n> ». Erreurs : aucune. Dépendances : infobulleEssai, boutonBulle, journal.
                function bulle(): void {
                    const i = infobulleEssai
                    essai.journal("bulle", [i.armee, i.due, i.bulle.ouvert, boutonBulle.clics].join(" "))
                }

                // survolerBulle — pose le pointeur au centre du bouton « bulle », puis journalise aussitôt, dans le
                // même appel, l'état de l'infobulle, pour que la lecture ne coure pas après le délai.
                // Entrées : aucune. Sortie : aucune ; « essai : survolerBulle <bool> <bool> <bool> <n> », comme bulle.
                // Erreurs : aucune. Dépendances : boutonBulle, infobulleEssai, clavier, journal.
                function survolerBulle(): void {
                    clavier.mouseMove(boutonBulle, boutonBulle.width / 2, boutonBulle.height / 2, -1, Qt.NoButton,
                                      Qt.NoModifier)
                    const i = infobulleEssai
                    essai.journal("survolerBulle", [i.armee, i.due, i.bulle.ouvert, boutonBulle.clics].join(" "))
                }

                // cibleNouvelle — crée un Bouton « mobile » dans le contenu de la fenêtre, en haut à gauche, par-dessus
                // la colonne (posé au bas de la colonne, il tomberait hors de la fenêtre, qui ne s'agrandit pas
                // aussitôt), et en fait la cible de l'infobulle mobile. Entrées : aucune. Sortie : aucune.
                // Erreurs : aucune. Dépendances : modeleCible, colonne, infobulleMobile.
                function cibleNouvelle(): void {
                    infobulleMobile.cible = modeleCible.createObject(colonne.parent)
                }

                // cibleDetruire — détruit la cible courante de l'infobulle mobile, sans la retirer de l'infobulle.
                // Entrées : aucune. Sortie : aucune. Erreurs : aucune ; sans cible, rien.
                // Dépendances : infobulleMobile.
                function cibleDetruire(): void {
                    infobulleMobile.cible?.destroy()
                }

                // survolerMobile — pose le pointeur au centre de la cible de l'infobulle mobile.
                // Entrées : aucune. Sortie : aucune. Erreurs : TypeError sans cible. Dépendances : infobulleMobile.
                function survolerMobile(): void {
                    const c = infobulleMobile.cible
                    clavier.mouseMove(c, c.width / 2, c.height / 2, -1, Qt.NoButton, Qt.NoModifier)
                }

                // infobulleJetable — crée une Infobulle sur le bouton « bulle » et garde ses deux gestionnaires.
                // Entrées : aucune. Sortie : aucune. Erreurs : aucune. Dépendances : modeleInfobulle, fenêtre d'essai.
                function infobulleJetable(): void {
                    fenetre.jetable = modeleInfobulle.createObject(fenetre)
                    fenetre.gardeSurvol = fenetre.jetable.survol
                    fenetre.gardeAppui = fenetre.jetable.appui
                }

                // detruireInfobulle — détruit l'Infobulle jetable, sans toucher au bouton « bulle ».
                // Entrées : aucune. Sortie : aucune. Erreurs : aucune ; sans Infobulle, rien. Dépendances : fenêtre.
                function detruireInfobulle(): void {
                    fenetre.jetable?.destroy()
                }

                // jetable — journalise la présence de l'Infobulle jetable, puis celle de ses deux gestionnaires.
                // Entrées : aucune. Sortie : aucune ; « essai : jetable <bool> <bool> <bool> ». Erreurs : aucune.
                // Dépendances : fenêtre, journal.
                function jetable(): void {
                    essai.journal("jetable", [fenetre.jetable !== null, fenetre.gardeSurvol !== null,
                                              fenetre.gardeAppui !== null].join(" "))
                }

                // mobile — journalise l'état de l'infobulle mobile : cible présente, gestionnaires posés sur elle,
                // délai armé, délai écoulé, survol. Entrées : aucune. Sortie : aucune ; « essai : mobile <bool> × 5 ».
                // Erreurs : aucune. Dépendances : infobulleMobile, journal.
                function mobile(): void {
                    const i = infobulleMobile, c = i.cible
                    const poses = c !== null && i.survol?.parent === c && i.appui?.parent === c
                    essai.journal("mobile", [c !== null, poses, i.armee, i.due, i.survolee].join(" "))
                }

                // quitterBulle — retire le pointeur du bouton « bulle » en le posant sur la recherche.
                // Entrées : aucune. Sortie : aucune. Erreurs : aucune. Dépendances : rechercheEssai, clavier.
                function quitterBulle(): void {
                    clavier.mouseMove(rechercheEssai, rechercheEssai.width / 2, rechercheEssai.height / 2, -1,
                                      Qt.NoButton, Qt.NoModifier)
                }

                // appuyerBulle — clique au centre du bouton « bulle », comme la souris.
                // Entrées : aucune. Sortie : aucune. Erreurs : aucune. Dépendances : boutonBulle, clavier.
                function appuyerBulle(): void {
                    clavier.mouseClick(boutonBulle, boutonBulle.width / 2, boutonBulle.height / 2, Qt.LeftButton,
                                       Qt.NoModifier, -1)
                }

                // focus — journalise l'élément qui a le focus actif, l'onglet courant et la sélection des onglets.
                // Entrées : aucune. Sortie : aucune ; « essai : focus … », « aucun » si rien n'a le focus.
                // Erreurs : aucune. Dépendances : colonne, barre, journal.
                function focus(): void {
                    const elus = [...colonne.children, tokens, composants, depliableEssai.entete]
                        .filter(e => e.activeFocus && e.objectName)
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
                // Erreurs : aucune. Dépendances : jaugeEssai (sortie anneau), journal.
                function jauge(): void {
                    essai.journal("jauge", Math.round(jaugeEssai.value * 100) / 100 + " " + jaugeEssai.anneau.visible)
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
