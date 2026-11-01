//@ pragma IconTheme DuneI
import QtQuick
import Quickshell
import Quickshell.Io
import "Theme"
import "Reseau"

// Coque d'essai de la page VPN de la fenêtre Réseau, dans une fenêtre offscreen.
// Rôle : pose une PageVpn dans une FloatingWindow, branchée sur un état factice (aucune commande ne touche le réseau
// réel) : la liste des profils est celle d'EtatReseau.profils, et executer journalise les arguments de nmcli puis, selon
// le mode, rend un refus (code 1 et message) ou réussit en inversant l'état actif du profil visé, comme le fait la
// relecture de l'état réel. tests/test_reseau.py (PageVpnTest) la pilote par IPC (cible « vpn »).
// Garde de plateforme : la fenêtre n'est construite que sous offscreen, où elle ne paraît jamais à l'écran.
// Entrées : DUNEI_TOKENS_DIR, lu par Theme ; QT_QPA_PLATFORM=offscreen, posé par le test.
// Sortie : « essai : prêt » à l'ouverture, puis « essai : executer <arguments en JSON> » à chaque commande.
// Erreurs : celles de Theme et des liaisons, dans le journal. Dépendances : quickshell ≥ 0.3 (FloatingWindow,
// LazyLoader, IpcHandler), QtTest (TestEvent), modules Theme et Reseau, par les liens posés sous cette racine.
ShellRoot {
    id: essai

    // journal — écrit une ligne lisible par le test. Entrées : cle, valeur. Sortie : aucune. Erreurs : aucune.
    function journal(cle, valeur) { console.info("essai : " + cle + " " + valeur) }

    // État factice : les profils lus par la page (deux VPN, dont un actif, un profil Wi-Fi à ignorer et un nom à
    // deux-points) et un executer qui refuse ou qui réussit.
    QtObject {
        id: faux
        property bool refus: false
        property var profils: [
            {nom: "Bureau", uuid: "bureau-1", type: "wireguard", appareil: "wg0", actif: true},
            {nom: "Maison: OpenVPN", uuid: "maison-1", type: "vpn", appareil: "", actif: false},
            {nom: "Wifi_TRIADES", uuid: "wifi-1", type: "802-11-wireless", appareil: "wlan0", actif: true}
        ]
        // executer — journalise les arguments, puis refuse (code 1) ou inverse l'état du profil visé. Entrées : args,
        // fin. Sortie : aucune.
        function executer(args, fin) {
            essai.journal("executer", JSON.stringify(args))
            if (refus) { if (fin) fin(1, "Error: Secrets were required, but not provided.\n"); return }
            const monter = args.includes("up"), u = args[args.length - 1]
            profils = profils.map(p => p.uuid === u ? Object.assign({}, p, {actif: monter}) : p)
            if (fin) fin(0, "")
        }
    }

    // trouver — premier descendant visuel qui vérifie un prédicat, en profondeur. Entrées : racine, test. Sortie : l'Item, ou null.
    function trouver(racine, test) {
        for (const enfant of racine?.children ?? []) {
            if (test(enfant)) return enfant
            const r = trouver(enfant, test)
            if (r) return r
        }
        return null
    }
    // tous_ — tous les descendants visuels qui vérifient un prédicat, en profondeur. Entrées : racine, test. Sortie : tableau.
    function tous_(racine, test) {
        const sortie = []
        for (const enfant of racine?.children ?? []) {
            if (test(enfant)) sortie.push(enfant)
            sortie.push(...tous_(enfant, test))
        }
        return sortie
    }
    // touche — frappe une touche dans la fenêtre de la page, comme le clavier. Entrées : cible, un Item de la fenêtre ;
    // cle, un Qt.Key_* ; modif, un Qt.KeyboardModifier. Sortie : aucune. Dépendances : QtTest.
    function touche(cible, cle, modif) {
        const e = Qt.createQmlObject("import QtTest; TestEvent {}", cible)
        e.keyClick(cle, modif, -1)
        e.destroy()
    }
    // nomDe — nom du focus : « interrupteur:<nom de la rangée> » pour un interrupteur, sinon le libellé ou l'objectName
    // le plus proche. Entrée : item. Sortie : texte, vide sans focus.
    function nomDe(item) {
        for (let o = item; o; o = o.parent) {
            if (o.objectName === "interrupteur") return "interrupteur:" + (trouverLigne(o)?.libelle ?? "")
            if (o.libelle) return o.libelle
            if (o.objectName) return o.objectName
        }
        return ""
    }
    // trouverLigne — la Ligne qui porte un contrôle. Entrée : item. Sortie : l'ancêtre à libellé, ou null.
    function trouverLigne(item) {
        for (let o = item; o; o = o.parent) if (o.libelle !== undefined) return o
        return null
    }

    LazyLoader {
        activeAsync: Theme.ready && Qt.platform.pluginName === "offscreen"

        FloatingWindow {
            id: fenetre
            implicitWidth: 760
            implicitHeight: 900
            color: Theme.color?.surfaceWindow ?? "transparent"
            Component.onCompleted: essai.journal("prêt", true)

            PageVpn { id: page; width: fenetre.width; panneau: null; etat: faux }

            IpcHandler {
                target: "vpn"

                // page — état de la page, en JSON : {titres (étiquettes de section visibles), vpns (liste de {nom, aide,
                // actif (médaillon à l'accent), coche (interrupteur), erreur}), aucun, aide (message d'ajout visible)}.
                // Erreurs : aucune.
                function page(): string {
                    const rangees = essai.tous_(page, o => o.objectName === "vpn" && o.visible)
                    return JSON.stringify({
                        titres: essai.tous_(page, o => o.text !== undefined && o.moyen === true && o.echelon === 0 && o.visible).map(o => o.text),
                        vpns: rangees.map(r => ({nom: r.libelle, aide: r.aide, actif: r.iconeActive, erreur: r.erreur,
                            coche: essai.trouver(r, o => o.objectName === "interrupteur").checked})),
                        aucun: essai.trouver(page, o => o.text === "Aucune connexion VPN." && o.visible) !== null,
                        aide: essai.trouver(page, o => o.text === "L'ajout d'une connexion VPN viendra plus tard." && o.visible) !== null,
                    })
                }
                // refuser — fait refuser (ou accepter) les commandes suivantes. Entrée : oui, « oui » ou « non ». Sortie : aucune.
                function refuser(oui: string): void { faux.refus = oui === "oui" }
                // sans — retire tous les profils. Entrées : aucune. Sortie : aucune.
                function sans(): void { faux.profils = [] }
                // basculer — clique l'interrupteur de la rangée nommée. Entrée : nom. Sortie : aucune.
                function basculer(nom: string): void {
                    const c = essai.trouver(essai.tous_(page, o => o.objectName === "vpn" && o.libelle === nom)[0], o => o.objectName === "interrupteur")
                    c.toggle()
                    c.toggled()
                }
                // tab, espace — frappent Tab et Espace. Entrées : aucune. Sortie : aucune.
                function tab(): void { essai.touche(page, Qt.Key_Tab, Qt.NoModifier) }
                function espace(): void { essai.touche(page, Qt.Key_Space, Qt.NoModifier) }
                // focus — nom du focus actif de la fenêtre (voir nomDe). Sortie : texte.
                function focus(): string { return essai.nomDe(page.Window.window?.activeFocusItem) }
            }
        }
    }
}
