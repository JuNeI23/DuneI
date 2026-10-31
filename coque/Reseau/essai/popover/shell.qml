//@ pragma IconTheme DuneI
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import "Theme"
import "Reseau"

// Coque d'essai du popover réseau, dans une fenêtre offscreen.
// Rôle : ouvre une FloatingWindow qui porte une ancre de la taille d'un indicateur de la barre, et un
// PopoverReseau, dans un Loader pour pouvoir le détruire, branché sur un état factice : aucune action ne touche
// le réseau réel. Les réseaux factices journalisent leurs appels (connect, connectWithPsk avec la seule longueur
// du mot de passe), executer journalise ses arguments, mot de passe masqué. tests/test_reseau.py (PopoverTest) les
// pilote par IPC (cible « popover »).
// Garde de plateforme : la fenêtre n'est construite que sous offscreen, où elle ne paraît jamais à l'écran.
// Entrées : DUNEI_TOKENS_DIR, lu par Theme ; QT_QPA_PLATFORM=offscreen, posé par le test.
// Sortie : « essai : prêt » à l'ouverture de la fenêtre, et les lignes « essai : connect <nom> », « essai :
// connectWithPsk <nom> <longueur> », « essai : executer <arguments JSON> », « essai : ouvrirPortail », « essai : verifier ».
// Erreurs : celles de Theme et des liaisons, dans le journal. Dépendances : quickshell ≥ 0.3 (FloatingWindow,
// LazyLoader, IpcHandler), Quickshell.Networking (énumérations), modules Theme et Reseau, par les liens
// Theme, Composants, Reseau et Barre posés sous cette racine.
ShellRoot {
    id: essai

    // journal — écrit une ligne lisible par le test. Entrées : cle, valeur. Sortie : aucune. Erreurs : aucune.
    function journal(cle, valeur) { console.info("essai : " + cle + " " + valeur) }

    // Réseau factice : les membres de WifiNetwork que lit le popover.
    component FauxReseau: QtObject {
        property string name
        property real signalStrength
        property bool connected: false
        property bool known: false
        property int security: WifiSecurityType.Wpa2Psk
        signal connectionFailed(int reason)
        function connect() { essai.journal("connect", name) }
        function connectWithPsk(psk) { essai.journal("connectWithPsk", name + " " + psk.length) }
    }

    FauxReseau { id: triades; name: "Wifi_TRIADES"; signalStrength: 0.9; connected: true; known: true }
    FauxReseau { id: connu; name: "Connu"; signalStrength: 0.3; known: true }
    FauxReseau { id: inconnu; name: "Inconnu"; signalStrength: 0.7 }
    FauxReseau { id: nouveau; name: "Nouveau"; signalStrength: 0.95 }
    FauxReseau { id: ouvert; name: "Ouvert"; signalStrength: 0.5; security: WifiSecurityType.Open }

    // État factice : les propriétés et les fonctions de EtatReseau qu'emploie le popover.
    QtObject {
        id: faux
        property bool carte: true
        property bool radio: true
        property bool filaire: false
        property bool connecte: true
        property string connectivite: "full"
        property bool facture: false
        property string nomActif: "Wifi_TRIADES"
        property var ip4: ["192.168.1.42/24"]
        property string icone: "network-wireless-signal-excellent"
        property bool recherche: false
        property bool fenetre: false
        property var reseaux: [connu, ouvert, triades, inconnu]
        function copierIp() { essai.journal("copierIp", true) }
        function allumer(actif) { essai.journal("allumer", actif) }
        function ouvrirPortail() { essai.journal("ouvrirPortail", true) }
        function verifier() { essai.journal("verifier", true) }
        function executer(args, fin) {
            essai.journal("executer", JSON.stringify(args.map((a, i) => args[i - 1] === "password" ? "<masqué>" : a)))
        }
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
                sourceComponent: Component { PopoverReseau { ancre: cible; etat: faux } }
            }

            IpcHandler {
                target: "popover"

                // ouvrir — ouvre ou ferme le popover. Entrée : valeur. Sortie : aucune. Dépendances : porteur.
                function ouvrir(valeur: bool): void { porteur.item.ouvert = valeur }
                // ouvert — état ouvert du popover, en JSON (faux s'il est détruit). Sortie : texte.
                function ouvert(): string { return JSON.stringify(porteur.item?.ouvert ?? false) }
                // detruire — détruit le popover, ouvert ou non. Entrées : aucune. Sortie : aucune.
                function detruire(): void { porteur.active = false }
                // recherche, fenetre — valeurs de l'état factice, en JSON. Sortie : texte.
                function recherche(): string { return JSON.stringify(faux.recherche) }
                function fenetre(): string { return JSON.stringify(faux.fenetre) }
                // connectivite — change la connectivité factice. Entrée : valeur. Sortie : aucune.
                function connectivite(valeur: string): void { faux.connectivite = valeur }
                // sansCarte — machine en filaire seul, sans carte Wi-Fi. Entrées : aucune. Sortie : aucune.
                function sansCarte(): void {
                    faux.carte = false; faux.filaire = true; faux.nomActif = "enp3s0"; faux.reseaux = []
                    faux.icone = "network-wired"
                }

                // forcerRecherche — pose recherche à vrai, comme un popover ouvert sur un autre écran.
                function forcerRecherche(): void { faux.recherche = true }
                // ajouterReseau — fait paraître un réseau, comme le balayage. Entrées : aucune. Sortie : aucune.
                function ajouterReseau(): void { faux.reseaux = faux.reseaux.concat([nouveau]) }

                // panneau — état du panneau construit, en JSON, sans aucun texte saisi ; {} s'il n'existe pas.
                // Sortie : {titre, etat, interrupteur, reseaux, deplie, erreur, portail, autre, saisie (longueur du
                // mot de passe de la ligne dépliée, -1 sans ligne)}. Erreurs : aucune.
                function panneau(): string {
                    const p = porteur.item?.panneau
                    if (!p) return "{}"
                    const visible = nom => essai.trouver(p, o => o.objectName === nom)?.visible ?? false
                    return JSON.stringify({
                        titre: p.resume.titre, etat: p.resume.etat, interrupteur: visible("interrupteur"),
                        reseaux: p.listeVisible ? p.reseaux.map(r => r.name) : [], deplie: p.deplie, erreur: p.erreur,
                        portail: p.etat.connectivite === "portal", autre: p.listeVisible,
                        saisie: p.bloc ? p.bloc.secret.length : -1,
                    })
                }

                // choisir — clic sur le réseau nommé. Entrée : nom. Sortie : aucune.
                function choisir(nom: string): void {
                    const p = porteur.item.panneau
                    p.choisir(p.reseaux.find(r => r.name === nom))
                }
                // echouer — émet connectionFailed (secrets absents) sur le réseau factice nommé. Entrée : nom.
                function echouer(nom: string): void {
                    faux.reseaux.concat([triades, connu, inconnu, ouvert]).find(r => r.name === nom)
                        .connectionFailed(ConnectionFailReason.NoSecrets)
                }
                // saisir, saisirNom — remplissent le mot de passe ou le nom de la ligne dépliée. Entrée : texte.
                function saisir(texte: string): void { porteur.item.panneau.bloc.secret.text = texte }
                function saisirNom(texte: string): void { porteur.item.panneau.bloc.champNom.text = texte }
                // activer — action nommée : rejoindre, autre (« Autre réseau… »), reglages, portail. Entrée : cle.
                function activer(cle: string): void {
                    const p = porteur.item.panneau
                    if (cle === "rejoindre") p.rejoindre()
                    else if (cle === "autre") essai.trouver(p, o => o.text === "Autre réseau…").active()
                    else if (cle === "reglages") essai.trouver(p, o => o.text === "Réglages réseau…").active()
                    else if (cle === "portail") essai.trouver(p, o => o.text === "Ouvrir la page de connexion").clicked()
                }
            }
        }
    }

    // trouver — premier descendant visuel qui vérifie un prédicat, en profondeur.
    // Entrées : racine, Item ; test, fonction(Item) → bool. Sortie : l'Item, ou null. Erreurs : aucune.
    function trouver(racine, test) {
        for (const enfant of racine.children) {
            if (test(enfant)) return enfant
            const r = trouver(enfant, test)
            if (r) return r
        }
        return null
    }
}
