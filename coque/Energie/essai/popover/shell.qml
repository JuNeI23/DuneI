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
    // comme le fait le démon de profils.
    QtObject {
        id: faux
        property int pourcent: 76
        property string estimation: "7 h 40 restantes"
        property int profil: 1
        property bool aPerformance: true
        property bool aProfils: true
        function choisirProfil(p) { essai.journal("choisirProfil", p); profil = p }
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
                    const segments = trouve("profils")
                    return JSON.stringify({
                        pourcent: trouve("pourcent").text, taillePourcent: trouve("pourcent").font.pixelSize,
                        graissePourcent: trouve("pourcent").font.weight, couleurPourcent: String(trouve("pourcent").color),
                        estimation: trouve("estimation").text, couleurEstimation: String(trouve("estimation").color),
                        section: { visible: trouve("sectionProfil").visible, texte: trouve("sectionProfil").text,
                                   couleur: String(trouve("sectionProfil").color) },
                        segmentsVisibles: segments.visible,
                        segments: Array.from(segments.contentChildren, o => o.text), coche: segments.currentIndex,
                        disque: p.disque, exclusif: porteur.item.exclusif, fermeAuDepart: porteur.item.fermeAuDepart,
                        hauteur: p.implicitHeight,
                    })
                }
                // cliquer — choix d'un segment, comme son clic (la barre coche le segment cliqué). Entrée : nom, son texte. Sortie : aucune.
                // Erreurs : TypeError si le segment est introuvable.
                function cliquer(nom: string): void {
                    const s = essai.trouver(porteur.item.panneau, o => o.objectName === "profils")
                    s.setCurrentIndex(Array.from(s.contentChildren).findIndex(o => o.text === nom))
                }
                // fleche — flèche droite sur le segment coché, comme au clavier. Entrées : aucune. Sortie : aucune.
                // Erreurs : TypeError si le panneau n'existe pas.
                function fleche(): void {
                    const s = essai.trouver(porteur.item.panneau, o => o.objectName === "profils")
                    s.incrementCurrentIndex()
                }
                // poser — change une valeur de l'état factice, comme un autre client. Entrées : cle, « pourcent »,
                // « estimation », « profil », « aPerformance » ou « aProfils » ; valeur, en JSON. Sortie : aucune.
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
