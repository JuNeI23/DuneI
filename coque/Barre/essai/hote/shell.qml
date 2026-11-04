//@ pragma IconTheme DuneI
import QtQuick
import QtTest
import Quickshell
import Quickshell.Io
import "Theme"
import "Composants"
import "Barre"

// Coque d'essai du cadre des popovers et du chemin hébergé d'Overlay, dans une fenêtre offscreen.
// Rôle : porte quatre Overlay hébergés au contenu factice (e a la forme exacte de a), un Overlay ordinaire et un
// CadrePopovers, la partie de HotePopovers qui se charge sous offscreen ; tests/test_barre.py (HoteTest) les pilote par IPC (cible « hote ») et y
// synthétise de vrais clics et de vraies touches, qui n'atteignent jamais le bureau.
// Garde de plateforme : la fenêtre n'est construite que sous offscreen, où elle ne paraît jamais à l'écran.
// Entrées : DUNEI_TOKENS_DIR, lu par Theme ; QT_QPA_PLATFORM=offscreen, posé par le test.
// Sortie : « essai : prêt true » à l'ouverture de la fenêtre, « essai : ferme <nom> » à chaque fermeture, et le
// résultat de chaque appel IPC. Erreurs : celles de Theme et des liaisons, dans le journal.
// Dépendances : quickshell ≥ 0.3 (FloatingWindow, LazyLoader, IpcHandler), QtTest (TestEvent), modules Theme,
// Composants et Barre, par les liens posés sous cette racine.
ShellRoot {
    id: essai

    // Panneaux factices construits, par nom, et forme du cadre au premier fondu de chacun.
    property var panneaux: ({})
    property var premierFondu: ({})
    // Cadre principal construit, null s'il est détruit.
    property Item hote: null
    // Plus petite hauteur du cadre depuis le dernier appel à marquer().
    property real hauteurMin: 0

    // journal — écrit une ligne lisible par le test. Entrées : cle, valeur. Sortie : aucune. Erreurs : aucune.
    function journal(cle, valeur) { console.info("essai : " + cle + " " + valeur) }

    // Contenu — contenu factice d'un popover hébergé : le même contrat que le panneau des vrais popovers.
    // Entrées : nom, le nom du panneau dans essai.panneaux ; largeur et hauteur, sa taille implicite.
    // Sorties : remises, nombre d'appels à reinitialiser ; clics, nombre de clics reçus. Erreurs : aucune.
    // Dépendances : essai (panneaux, premierFondu, formeCadre).
    component Contenu: FocusScope {
        id: contenu
        property string nom
        property real largeur
        property real hauteur
        property real fonduContenu: 1
        property real fonduDisque: 1
        property int remises: 0
        property int clics: 0
        readonly property alias aide: aide
        focus: true
        implicitWidth: largeur
        implicitHeight: hauteur
        Component.onCompleted: essai.panneaux[nom] = contenu
        Component.onDestruction: delete essai.panneaux[nom]
        // reinitialiser — compte les remises à neuf. Entrées : aucune. Sortie : aucune. Erreurs : aucune.
        function reinitialiser(): void { remises++ }
        onFonduContenuChanged: if (fonduContenu > 0 && fonduContenu < 1 && !essai.premierFondu[nom])
            essai.premierFondu[nom] = essai.formeCadre()
        MouseArea { anchors.fill: parent; onClicked: contenu.clics++ }
        Infobulle { id: aide; cible: contenu; texte: "aide" }
    }

    // formeCadre — forme affichée du cadre principal. Entrées : aucune. Sortie : {gauche, droite, hauteur}, ou null
    // sans cadre. Erreurs : aucune. Dépendances : hote.
    function formeCadre() {
        const c = essai.hote?.cadre
        return c ? { gauche: c.x, droite: c.x + c.width, hauteur: c.height } : null
    }

    LazyLoader {
        activeAsync: Theme.ready && Qt.platform.pluginName === "offscreen"

        FloatingWindow {
            id: racine
            implicitWidth: 1000
            implicitHeight: 800
            Component.onCompleted: essai.journal("prêt", true)

            TestEvent { id: evenement }

            Rectangle { id: ancreA; x: 600; y: 2; width: 28; height: 24 }
            Rectangle { id: ancreB; x: 900; y: 2; width: 28; height: 24 }
            Rectangle { id: ancreC; x: 100; y: 2; width: 28; height: 24 }
            Rectangle { id: ancreO; x: 300; y: 2; width: 28; height: 24 }

            Overlay {
                id: a
                famille: "contextuel"; exclusif: true; heberge: true; ancre: ancreA
                onFerme: essai.journal("ferme", "a")
                Contenu { nom: "a"; largeur: 200; hauteur: 300 }
            }
            Overlay {
                id: b
                famille: "contextuel"; exclusif: true; heberge: true; ancre: ancreB
                onFerme: essai.journal("ferme", "b")
                Contenu { nom: "b"; largeur: 280; hauteur: 150 }
            }
            Overlay {
                id: c
                famille: "contextuel"; exclusif: true; heberge: true; ancre: ancreC
                onFerme: essai.journal("ferme", "c")
                Contenu { nom: "c"; largeur: 120; hauteur: 400 }
            }
            Overlay {
                id: e
                famille: "contextuel"; exclusif: true; heberge: true; ancre: ancreA
                onFerme: essai.journal("ferme", "e")
                Contenu { nom: "e"; largeur: 200; hauteur: 300 }
            }
            // Contextuel ordinaire : il garde sa fenêtre et son comportement d'avant l'hébergement.
            Overlay {
                id: ordinaire
                famille: "contextuel"; ancre: ancreO
                onFerme: essai.journal("ferme", "ordinaire")
                Item { implicitWidth: 50; implicitHeight: 50 }
            }

            // Le cadre, un Loader à part pour le construire après une ouverture et le détruire seul.
            Loader {
                id: hotes
                anchors.fill: parent
                // Un Loader est une portée de focus : sans cela, le cadre n'aurait jamais le focus actif de la fenêtre.
                focus: true
                onItemChanged: essai.hote = item
                sourceComponent: Component {
                    CadrePopovers {
                        popovers: [a, b, c, e]
                        largeurEcran: racine.implicitWidth
                        hauteurBarre: 28
                    }
                }
            }
            Connections {
                target: hotes.item?.cadre ?? null
                function onHeightChanged() { essai.hauteurMin = Math.min(essai.hauteurMin, hotes.item.cadre.height) }
            }

            // Une barre entière, avec son popover et son cadre, pour la détruire d'un bloc comme à l'écran débranché.
            Loader {
                id: barreFactice
                active: false
                sourceComponent: Component {
                    Item {
                        id: arbre
                        property alias popover: d
                        // Reproduit l'accroche de Barre.qml : la fermeture rend la main à l'élément de la barre.
                        property bool elementOuvert: true
                        Rectangle { id: ancreD; x: 400; width: 28; height: 24 }
                        Overlay {
                            id: d
                            famille: "contextuel"; exclusif: true; heberge: true; ancre: ancreD
                            onFerme: { arbre.elementOuvert = false; essai.journal("ferme", "d") }
                            Contenu { nom: "d"; largeur: 100; hauteur: 100 }
                        }
                        CadrePopovers { popovers: [d]; largeurEcran: racine.implicitWidth; hauteurBarre: 28 }
                    }
                }
            }

            IpcHandler {
                target: "hote"

                // etat — relevé complet, en JSON : registre, cadre, Overlay et panneaux. Entrées : aucune.
                // Sortie : texte JSON. Erreurs : aucune. Dépendances : a, b, c, e, ordinaire, hotes, essai.
                function etat(): string {
                    const h = hotes.item
                    const nomme = o => o === null || o === undefined ? null
                        : ["a", "b", "c", "e", "ordinaire"].find(n => ({ a, b, c, e, ordinaire })[n] === o) ?? "d"
                    const ov = o => ({ ouvert: o.ouvert, survol: o.survolCadre, fenetre: o.chargeur.item !== null })
                    const panneaux = {}
                    for (const [n, p] of Object.entries(essai.panneaux)) {
                        const v = p.parent
                        panneaux[n] = { contenu: p.fonduContenu, disque: p.fonduDisque, remises: p.remises, clics: p.clics,
                                        xEcran: h ? p.mapToItem(null, 0, 0).x : 0, visible: v.montree, z: v.z,
                                        focus: v.focus, statut: v.status, bulle: p.aide.bulle.ouvert }
                    }
                    return JSON.stringify({
                        registre: nomme(Overlays.popover), courant: nomme(h?.courant), affiche: nomme(h?.affiche),
                        deploye: h?.deploye ?? null, passage: h?.passage ?? null, sens: h?.sens ?? null,
                        cadre: essai.formeCadre(), cadreVisible: h?.cadre.visible ?? null, cadreY: h?.cadre.y ?? null,
                        cadreOpacite: h?.cadre.opacity ?? null,
                        a: ov(a), b: ov(b), c: ov(c), e: ov(e), ordinaire: ov(ordinaire), panneaux,
                        premierFondu: essai.premierFondu, hauteurMin: essai.hauteurMin,
                        d: barreFactice.item ? ov(barreFactice.item.popover) : null,
                        elementOuvert: barreFactice.item?.elementOuvert ?? null,
                    })
                }

                // marquer — remet à zéro les relevés de passage. Entrées : aucune. Sortie : aucune. Erreurs : aucune.
                function marquer(): void { essai.premierFondu = ({}); essai.hauteurMin = hotes.item?.cadre.height ?? 0 }

                // ouvrir — ouvre ou ferme un Overlay, puis rend l'état dans la même passe, avant toute image.
                // Entrées : nom (a, b, c, e, ordinaire), valeur. Sortie : texte JSON. Erreurs : TypeError pour un nom
                // inconnu. Dépendances : a, b, c, e, ordinaire, etat.
                function ouvrir(nom: string, valeur: bool): string {
                    ({ a, b, c, e, ordinaire })[nom].ouvert = valeur
                    return etat()
                }

                // construire, detruireHote — construit ou détruit le cadre seul, Overlay intacts.
                // Entrées : aucune. Sortie : aucune. Erreurs : aucune. Dépendances : hotes.
                function construire(): void { hotes.active = true }
                function detruireHote(): void { hotes.active = false }

                // construireBarre, ouvrirBarre, detruireBarre — barre factice entière : la construit, ouvre son
                // popover, la détruit d'un bloc. Entrées : aucune. Sortie : aucune. Erreurs : aucune.
                function construireBarre(): void { barreFactice.active = true }
                function ouvrirBarre(): void { barreFactice.item.popover.ouvert = true }
                function detruireBarre(): void { barreFactice.active = false }

                // cacherAncre — rend invisible l'ancre du popover a. Entrées : aucune. Sortie : aucune.
                function cacherAncre(): void { ancreA.visible = false }

                // survoler — amène le pointeur au milieu du cadre, ou hors de lui. Entrée : dedans.
                // Sortie : aucune. Erreurs : aucune. Dépendances : evenement (TestEvent), hotes.
                function survoler(dedans: bool): void {
                    const c = hotes.item.cadre
                    if (dedans) evenement.mouseMove(c, c.width / 2, c.height / 2, -1, Qt.NoButton, Qt.NoModifier)
                    else evenement.mouseMove(ancreO, 1, 1, -1, Qt.NoButton, Qt.NoModifier)
                }

                // cliquer — clic réel au milieu d'un panneau factice, tel qu'il est posé dans la fenêtre.
                // Entrée : nom du panneau. Sortie : aucune. Erreurs : TypeError pour un nom inconnu.
                // Dépendances : evenement (TestEvent), essai.panneaux.
                function cliquer(nom: string): void {
                    const p = essai.panneaux[nom]
                    const q = p.mapToItem(racine.contentItem, p.width / 2, p.height / 2)
                    evenement.mouseClick(racine.contentItem, q.x, q.y, Qt.LeftButton, Qt.NoModifier, -1)
                }

                // echap — frappe Échap dans la fenêtre. Entrées : aucune. Sortie : aucune. Dépendances : evenement.
                function echap(): void { evenement.keyClick(Qt.Key_Escape, Qt.NoModifier, -1) }
            }
        }
    }
}
