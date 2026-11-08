//@ pragma IconTheme DuneI
import QtQuick
import Quickshell
import Quickshell.Io
import "Theme"
import "Energie"

// Coque d'essai du popover de l'énergie, dans une fenêtre offscreen.
// Rôle : ouvre une FloatingWindow qui porte une ancre de la taille d'un indicateur de la barre et un PopoverEnergie,
// dans un Loader, branché sur un état factice : aucune action ne touche UPower ni le démon de profils.
// tests/test_energie.py (PopoverEnergieTest) le pilote par IPC (cible « popover »).
// Garde de plateforme : la fenêtre n'est construite que sous offscreen, où elle ne paraît jamais à l'écran.
// Entrées : DUNEI_TOKENS_DIR, lu par Theme ; QT_QPA_PLATFORM=offscreen, posé par le test.
// Sortie : « essai : prêt » à l'ouverture de la fenêtre, et la ligne « essai : choisirProfil <profil> » à chaque choix.
// Commandes : voir chaque fonction de l'IpcHandler.
// Erreurs : celles de Theme et des liaisons, dans le journal. Dépendances : quickshell ≥ 0.3 (FloatingWindow,
// LazyLoader, IpcHandler), modules Theme, Composants et Energie, par les liens posés sous cette racine.
ShellRoot {
    id: essai

    // journal — écrit une ligne lisible par le test. Entrées : cle ; valeur, facultative. Sortie : aucune.
    // Erreurs : aucune.
    function journal(cle, valeur = "") { console.info(("essai : " + cle + " " + valeur).trim()) }

    // État factice : les propriétés et la fonction de EtatEnergie qu'emploie le popover. Un choix est confirmé aussitôt,
    // comme le fait le démon de profils, sauf si refuse est vrai.
    QtObject {
        id: faux
        property int pourcent: 76
        property string estimation: "7 h 40 restantes"
        property int seuilFaible: 20
        property int profil: 1
        property bool aPerformance: true
        property bool aProfils: true
        // Vrai, le démon simulé refuse tout choix et le profil reste inchangé.
        property bool refuse: false
        function choisirProfil(p) { essai.journal("choisirProfil", p); if (!refuse) profil = p }
    }

    LazyLoader {
        activeAsync: Theme.ready && Qt.platform.pluginName === "offscreen"

        FloatingWindow {
            implicitWidth: 400
            implicitHeight: 40
            Component.onCompleted: essai.journal("prêt", true)

            Rectangle { id: cible; x: 300; width: 28; height: 28 }

            Loader {
                id: porteur
                sourceComponent: Component { PopoverEnergie { ancre: cible; etat: faux } }
            }

            // Second popover, dont le contenu est construit comme le fait CadrePopovers (D109) : par un Loader
            // asynchrone. L'incubation asynchrone n'est pas celle d'une création directe, et c'est elle qui sert à la barre.
            PopoverEnergie { id: second; etat: faux }
            Loader {
                id: hote
                y: 60
                asynchronous: true
                sourceComponent: second.contenu
            }

            IpcHandler {
                id: ipc
                target: "popover"

                // ouvrir — ouvre ou ferme le popover. Entrée : valeur. Sortie : aucune. Dépendances : porteur.
                function ouvrir(valeur: bool): void { porteur.item.ouvert = valeur }

                // panneau — état du panneau construit, en JSON ; {} s'il n'existe pas.
                // Sortie : {pourcent, estimation, couleurs et taille du pourcentage, section {visible, texte},
                // segments (textes des onglets, dans l'ordre), coche (indice), disque, exclusif, fermeAuDepart,
                // hauteur}. Erreurs : aucune. Dépendances : essai.trouver.
                function panneau(): string {
                    const p = porteur.item?.panneau
                    if (!p) return "{}"
                    const trouve = nom => essai.trouver(p, o => o.objectName === nom)
                    const segments = essai.trouver(p, o => o.objectName === "profils" && o.visible) ?? trouve("profils")
                    return JSON.stringify({
                        pourcent: trouve("pourcent").text, taillePourcent: trouve("pourcent").font.pixelSize,
                        graissePourcent: trouve("pourcent").font.weight, couleurPourcent: String(trouve("pourcent").color),
                        baselinePourcent: trouve("pourcent").mapToItem(p, 0, trouve("pourcent").baselineOffset).y,
                        baselineEstimation: trouve("estimation").mapToItem(p, 0, trouve("estimation").baselineOffset).y,
                        xPourcent: trouve("pourcent").mapToItem(p, 0, 0).x, largeurPourcent: trouve("pourcent").implicitWidth,
                        xEstimation: trouve("estimation").mapToItem(p, 0, 0).x,
                        estimation: trouve("estimation").text, couleurEstimation: String(trouve("estimation").color),
                        section: { visible: trouve("sectionProfil").visible, texte: trouve("sectionProfil").text,
                                   couleur: String(trouve("sectionProfil").color) },
                        segmentsVisibles: segments.visible,
                        segments: Array.from(segments.contentChildren, o => o.text), coche: segments.currentIndex,
                        disque: p.disque, exclusif: porteur.item.exclusif, fermeAuDepart: porteur.item.fermeAuDepart,
                        hauteur: p.implicitHeight,
                    })
                }
                // asynchrone — état du contenu construit par le Loader asynchrone, en JSON ; {} tant qu'il n'est pas prêt.
                // Sortie : {segments (textes dans l'ordre), rect (x, y, largeur, hauteur de la piste dans le Loader),
                // largeurs et xs (largeur et abscisse de chaque segment visible, dans la piste)}. Erreurs : aucune.
                // Dépendances : hote, essai.trouver.
                function asynchrone(): string {
                    if (hote.status !== Loader.Ready) return "{}"
                    const s = essai.trouver(hote.item, o => o.objectName === "profils" && o.visible)
                    const vus = Array.from(s.contentChildren).filter(o => o.visible)
                    const r = s.mapToItem(hote, 0, 0)
                    return JSON.stringify({ segments: Array.from(s.contentChildren, o => o.text),
                        rect: { x: r.x, y: r.y, largeur: s.width, hauteur: s.height },
                        largeurs: vus.map(o => o.width), xs: vus.map(o => o.x) })
                }
                // capturer — enregistre en PNG l'image du contenu asynchrone. Entrée : chemin. Sortie : aucune.
                // Erreurs : aucune ; un échec de capture laisse le fichier absent. Dépendances : hote.
                function capturer(chemin: string): void { hote.grabToImage(r => r.saveToFile(chemin)) }

                // cliquer — choix d'un segment, comme son clic (la barre coche le segment cliqué). Entrée : nom, son texte. Sortie : aucune.
                // Erreurs : TypeError si le segment est introuvable.
                function cliquer(nom: string): void {
                    const s = essai.trouver(porteur.item.panneau, o => o.objectName === "profils" && o.visible)
                    s.setCurrentIndex(Array.from(s.contentChildren).findIndex(o => o.text === nom))
                }
                // fleche — flèche droite sur le segment coché, comme au clavier. Entrées : aucune. Sortie : aucune.
                // Erreurs : TypeError si le panneau n'existe pas.
                function fleche(): void {
                    const s = essai.trouver(porteur.item.panneau, o => o.objectName === "profils" && o.visible)
                    s.incrementCurrentIndex()
                }
                // poser — change une valeur de l'état factice, comme un autre client. Entrées : cle, « pourcent »,
                // « seuilFaible », « estimation », « profil », « aPerformance », « aProfils » ou « refuse » ; valeur, en JSON.
                // Sortie : aucune.
                function poser(cle: string, valeur: string): void { faux[cle] = JSON.parse(valeur) }
            }
        }
    }

    // trouver — premier descendant visuel qui vérifie un prédicat, en profondeur.
    // Entrées : racine, Item ; test, fonction(Item) → bool. Sortie : l'Item, ou null. Erreurs : aucune.
    function trouver(racine, test) {
        for (const enfant of racine.children) {
            if (test(enfant)) return enfant
            const t = trouver(enfant, test)
            if (t) return t
        }
        return null
    }
}
