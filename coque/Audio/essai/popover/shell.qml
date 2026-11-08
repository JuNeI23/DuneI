//@ pragma IconTheme DuneI
import QtQuick
import Quickshell
import Quickshell.Io
import "Theme"
import "Audio"

// Coque d'essai du popover audio, dans une fenêtre offscreen.
// Rôle : ouvre une FloatingWindow qui porte une ancre de la taille d'un indicateur de la barre et un PopoverAudio,
// dans un Loader, branché sur un état factice : aucune action ne touche PipeWire. tests/test_audio.py
// (PopoverAudioTest) le pilote par IPC (cible « popover »).
// Garde de plateforme : la fenêtre n'est construite que sous offscreen, où elle ne paraît jamais à l'écran.
// Entrées : DUNEI_TOKENS_DIR, lu par Theme ; QT_QPA_PLATFORM=offscreen, posé par le test.
// Sortie : « essai : prêt » à l'ouverture de la fenêtre, et les lignes « essai : reglerVolume <pourcent> », « essai :
// reglerMicro <pourcent> », « essai : basculerSon », « essai : basculerMicro », « essai : choisirSortie <nom> »,
// « essai : choisirEntree <nom> ». Commandes : voir chaque fonction de l'IpcHandler.
// Erreurs : celles de Theme et des liaisons, dans le journal. Dépendances : quickshell ≥ 0.3 (FloatingWindow,
// LazyLoader, IpcHandler), modules Theme, Composants et Audio, et Barre/icones.js, par les liens posés sous cette racine.
ShellRoot {
    id: essai

    // journal — écrit une ligne lisible par le test. Entrées : cle ; valeur, facultative. Sortie : aucune.
    // Erreurs : aucune.
    function journal(cle, valeur = "") { console.info(("essai : " + cle + " " + valeur).trim()) }

    // Nœud factice : les membres de PwNode que lisent audio.js et le popover.
    component FauxNoeud: QtObject {
        property string name
        property string description
        property string nickname
        property var properties: ({})
    }

    Component { id: fabriqueNoeud; FauxNoeud {} }
    FauxNoeud { id: hautParleurs; name: "alsa_output.pci-0000_04_00.6.analog-stereo"; description: "Haut-parleurs" }
    FauxNoeud { id: bose; name: "bluez_output.4C_87_5D_A2_58_8A.1"; description: "Bose NC 700" }
    FauxNoeud { id: microIntegre; name: "alsa_input.pci-0000_04_00.6.digital"; description: "Micro intégré" }
    FauxNoeud { id: prise; name: "alsa_input.pci-0000_04_00.6.analog-stereo"; description: "Prise casque" }

    // État factice : les propriétés et les fonctions de EtatAudio qu'emploie le popover.
    QtObject {
        id: faux
        property var sorties: [hautParleurs, bose]
        property var entrees: [microIntegre, prise]
        property var sortie: hautParleurs
        property var entree: microIntegre
        readonly property bool presente: sorties.length > 0
        property int volume: 50
        property int niveauMicro: 100
        property bool muet: false
        property bool micMuet: false
        property bool popoverOuvert: false
        function reglerVolume(p) { essai.journal("reglerVolume", p); volume = p }
        function reglerMicro(p) { essai.journal("reglerMicro", p); niveauMicro = p }
        function basculerSon() { essai.journal("basculerSon"); muet = !muet }
        function basculerMicro() { essai.journal("basculerMicro"); micMuet = !micMuet }
        function choisirSortie(n) { essai.journal("choisirSortie", n.description) }
        function choisirEntree(n) { essai.journal("choisirEntree", n.description) }
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
                sourceComponent: Component { PopoverAudio { ancre: cible; etat: faux } }
            }

            IpcHandler {
                id: ipc
                target: "popover"

                // ouvrir — ouvre ou ferme le popover. Entrée : valeur. Sortie : aucune. Dépendances : porteur.
                function ouvrir(valeur: bool): void { porteur.item.ouvert = valeur }

                // panneau — état du panneau construit, en JSON ; {} s'il n'existe pas.
                // Sortie : {titre, sousTitre, sectionSortie, sectionMicro et leurs couleurs, sorties et entrees (lignes
                // {nom, icone, pleine, gras, teinteIcone, teinteTexte}, dans l'ordre), jaugeSon et jaugeMicro ({valeur,
                // coupe, icone, pas}), reglages {texte, actif}, exclusif, fermeAuDepart, hauteur, hauteurLigne}.
                // Erreurs : aucune. Dépendances : essai.trouver, essai.lignes.
                function panneau(): string {
                    const p = porteur.item?.panneau
                    if (!p) return "{}"
                    const texte = nom => essai.trouver(p, o => o.objectName === nom)
                    const jauge = nom => {
                        const j = texte(nom)
                        return { valeur: j.value, coupe: j.coupe, icone: j.icone, pas: j.stepSize }
                    }
                    const reglages = texte("reglages")
                    return JSON.stringify({
                        titre: texte("titre").text, sousTitre: texte("sousTitre").text,
                        sectionSortie: texte("sectionSortie").text, sectionMicro: texte("sectionMicro").text,
                        couleurSectionSortie: String(texte("sectionSortie").color),
                        couleurSectionMicro: String(texte("sectionMicro").color),
                        sorties: essai.lignes(texte("sorties")), entrees: essai.lignes(texte("entrees")),
                        jaugeSon: jauge("jaugeSon"), jaugeMicro: jauge("jaugeMicro"),
                        reglages: { texte: reglages.text, actif: reglages.enabled },
                        exclusif: porteur.item.exclusif, fermeAuDepart: porteur.item.fermeAuDepart,
                        hauteur: p.implicitHeight, hauteurLigne: p.hauteurLigne,
                    })
                }
                // puisLire — appelle une fonction de cette cible puis rend l'état du panneau dans la même passe.
                // Entrées : fonction, son nom ; argument, passé tel quel. Sortie : texte JSON, voir panneau.
                function puisLire(fonction: string, argument: string): string {
                    ipc[fonction](argument)
                    return panneau()
                }

                // choisir — clic sur la ligne d'un appareil. Entrées : liste, « sorties » ou « entrees » ; nom, le
                // libellé de la ligne. Sortie : aucune. Erreurs : TypeError si la ligne est introuvable.
                function choisir(liste: string, nom: string): void {
                    const l = essai.trouver(porteur.item.panneau, o => o.objectName === liste)
                    essai.trouver(l, o => o.text === nom && o.active !== undefined).clicked()
                }
                // cliquerIcone — clic sur l'icône d'une jauge. Entrée : nom, « jaugeSon » ou « jaugeMicro ».
                // Sortie : aucune. Erreurs : TypeError si la jauge est introuvable.
                function cliquerIcone(nom: string): void {
                    essai.trouver(porteur.item.panneau, o => o.objectName === nom).zoneIcone.clicked(null)
                }
                // glisser — la poignée d'une jauge, tenue, est amenée à une valeur, comme au glisser de la souris,
                // puis l'état est lu avant le relâchement. Entrées : nom, la jauge ; valeur (entier, en chaîne).
                // Sortie : texte JSON, voir panneau. Erreurs : TypeError si la jauge est introuvable.
                function glisser(nom: string, valeur: string): string {
                    const j = essai.trouver(porteur.item.panneau, o => o.objectName === nom)
                    j.pressed = true
                    j.value = Number(valeur)
                    j.moved()
                    const lu = panneau()
                    j.pressed = false
                    return lu
                }
                // poser — change une valeur de l'état factice, comme une touche ou une autre application.
                // Entrées : cle, « volume », « niveauMicro », « muet » ou « micMuet » ; valeur, en chaîne.
                // Sortie : aucune. Erreurs : aucune.
                function poser(cle: string, valeur: string): void { faux[cle] = JSON.parse(valeur) }
                // ajouterSortie — une sortie nouvelle paraît (casque qui se connecte). Entrée : nom, sa description.
                // Sortie : aucune. Erreurs : aucune.
                function ajouterSortie(nom: string): void {
                    faux.sorties = faux.sorties.concat([fabriqueNoeud.createObject(essai, { name: "bluez_output.x", description: nom })])
                }
            }
        }
    }

    // lignes — description des rangées d'une liste d'appareils, dans l'ordre. Entrée : liste, l'Item de la liste.
    // Sortie : tableau de {nom, icone, pleine, gras, teinteIcone, teinteTexte}. Erreurs : aucune.
    function lignes(liste) {
        return Array.from(liste.children).filter(r => r.active !== undefined).sort((a, b) => a.y - b.y).map(r => ({
            nom: r.text, icone: r.icone, pleine: r.pleine, gras: r.gras,
            teinteIcone: String(r.teinteIcone), teinteTexte: String(r.teinteTexte),
        }))
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
