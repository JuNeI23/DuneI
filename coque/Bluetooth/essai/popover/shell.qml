//@ pragma IconTheme DuneI
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import "Theme"
import "Bluetooth"

// Coque d'essai du popover Bluetooth, dans une fenêtre offscreen.
// Rôle : ouvre une FloatingWindow qui porte une ancre de la taille d'un indicateur de la barre, et un
// PopoverBluetooth, dans un Loader pour pouvoir le détruire, branché sur un état factice : aucune action ne touche la
// radio réelle. tests/test_bluetooth.py (PopoverBluetoothTest) le pilote par IPC (cible « popover »).
// Garde de plateforme : la fenêtre n'est construite que sous offscreen, où elle ne paraît jamais à l'écran.
// Entrées : DUNEI_TOKENS_DIR, lu par Theme ; QT_QPA_PLATFORM=offscreen, posé par le test.
// Sortie : « essai : prêt » à l'ouverture de la fenêtre, et les lignes « essai : allumer <bool> », « essai :
// basculer <adresse> », « essai : appairer <adresse> », « essai : oublier <adresse> ». Commandes : voir chaque
// fonction de l'IpcHandler.
// Erreurs : celles de Theme et des liaisons, dans le journal. Dépendances : quickshell ≥ 0.3 (FloatingWindow,
// LazyLoader, IpcHandler), Quickshell.Bluetooth (BluetoothDeviceState), modules Theme, Composants et Bluetooth, par
// les liens posés sous cette racine.
ShellRoot {
    id: essai

    // journal — écrit une ligne lisible par le test. Entrées : cle, valeur. Sortie : aucune. Erreurs : aucune.
    function journal(cle, valeur) { console.info("essai : " + cle + " " + valeur) }

    // Appareil factice : les membres de BluetoothDevice que lit le popover.
    component FauxAppareil: QtObject {
        property string name
        property string address
        property string icon
        property bool paired: false
        property bool connected: false
        property bool pairing: false
        property int state: connected ? BluetoothDeviceState.Connected : BluetoothDeviceState.Disconnected
        property bool batteryAvailable: false
        property real battery: 0
    }

    FauxAppareil { id: bose; name: "Bose NC 700 Headphones"; address: "4C:87:5D:A2:58:8A"; icon: "audio-headset"; paired: true; connected: true; batteryAvailable: true; battery: 0.62 }
    FauxAppareil { id: souris; name: "Souris"; address: "11:22:33:44:55:66"; icon: "input-mouse"; paired: true }
    FauxAppareil { id: enceinte; name: "Enceinte"; address: "77:88:99:AA:BB:CC"; icon: "audio-card" }
    FauxAppareil { id: anonyme; name: "AA-BB-CC-DD-EE-FF"; address: "AA:BB:CC:DD:EE:FF" }

    // État factice : les propriétés et les fonctions de EtatBluetooth qu'emploie le popover.
    QtObject {
        id: faux
        property bool disponible: true
        property bool allume: true
        property bool recherche: false
        readonly property bool enRecherche: recherche && allume
        property var appareils: [bose, souris, enceinte, anonyme]
        readonly property var connecte: appareils.find(a => a.connected) ?? null
        readonly property string resumeTexte: !allume ? "Désactivé" : connecte
            ? connecte.name + (connecte.batteryAvailable ? " · " + Math.round(connecte.battery * 100) + " %" : "")
            : "Aucun appareil connecté"
        signal echec(string adresse, string message)
        function allumer(actif) { essai.journal("allumer", actif) }
        function basculer(a) { essai.journal("basculer", a.address) }
        function appairer(a) { essai.journal("appairer", a.address); a.pairing = true }
        function oublier(a) { essai.journal("oublier", a.address) }
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
                sourceComponent: Component { PopoverBluetooth { ancre: cible; etat: faux } }
            }

            IpcHandler {
                id: ipc
                target: "popover"

                // ouvrir — ouvre ou ferme le popover. Entrée : valeur. Sortie : aucune. Dépendances : porteur.
                function ouvrir(valeur: bool): void { porteur.item.ouvert = valeur }
                // detruire — détruit le popover, ouvert ou non. Entrées : aucune. Sortie : aucune.
                function detruire(): void { porteur.active = false }
                // recherche — demande de recherche de l'état factice, en JSON. Sortie : texte.
                function recherche(): string { return JSON.stringify(faux.recherche) }

                // panneau — état du panneau construit, en JSON ; {} s'il n'existe pas.
                // Sortie : {titre, etat, bascule {actif, allumee}, mes et proches (adresses des lignes montrées, dans
                // l'ordre), deplie, lignes (adresse → {nom, icone, statut, apparition}), exclusif, fermeAuDepart,
                // retenu}. Erreurs : aucune.
                function panneau(): string {
                    const p = porteur.item?.panneau
                    if (!p) return "{}"
                    const bascule = essai.trouver(p, o => o.objectName === "bascule")
                    const lignes = {}
                    for (const d of Object.values(p.delegues)) lignes[d.cle] = {
                        nom: d.appareil?.name ?? "", icone: d.icone, statut: d.statut, apparition: d.apparition.value,
                    }
                    return JSON.stringify({
                        titre: "Bluetooth", etat: p.etat.resumeTexte,
                        bascule: { actif: bascule.enabled, allumee: bascule.checked },
                        mes: p.listeVisible ? p.mes.ordre.filter(c => p.appareil(c) !== null) : [],
                        proches: p.listeVisible ? p.proches.ordre.filter(c => p.appareil(c) !== null) : [],
                        deplie: p.deplie, lignes,
                        exclusif: porteur.item.exclusif, fermeAuDepart: porteur.item.fermeAuDepart,
                        retenu: porteur.item.retenu,
                    })
                }
                // puisLire — appelle une fonction de cette cible puis rend l'état du panneau dans la même passe.
                // Entrées : fonction, son nom ; argument, passé tel quel. Sortie : texte JSON, voir panneau.
                function puisLire(fonction: string, argument: string): string {
                    ipc[fonction](argument)
                    return panneau()
                }

                // choisir — clic sur la ligne de l'appareil d'adresse donnée. Entrée : adresse.
                function choisir(adresse: string): void { porteur.item.panneau.delegues[adresse].rangee.active() }
                // deplier — clic sur le chevron de la ligne d'adresse donnée. Entrée : adresse.
                function deplier(adresse: string): void { porteur.item.panneau.delegues[adresse].deplier() }
                // oublier — clic sur « Oublier cet appareil » de la ligne dépliée. Entrées : aucune.
                function oublier(): void {
                    const p = porteur.item.panneau
                    essai.trouver(p, o => o.text === "Oublier cet appareil" && o.visible).active()
                }
                // echouer — l'appairage de l'appareil d'adresse donnée échoue. Entrée : adresse.
                function echouer(adresse: string): void {
                    faux.appareils.find(a => a.address === adresse).pairing = false
                    faux.echec(adresse, "Appairage impossible")
                }
                // appaire — l'appairage de l'appareil d'adresse donnée réussit. Entrée : adresse.
                function appaire(adresse: string): void {
                    const a = faux.appareils.find(x => x.address === adresse)
                    a.pairing = false
                    a.paired = true
                }
                // couper — la radio est coupée. Entrées : aucune.
                function couper(): void { faux.allume = false }
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
