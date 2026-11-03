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
// le réseau réel. Les réseaux factices journalisent leurs appels (connect, disconnect, connectWithPsk avec la seule
// longueur du mot de passe), executer journalise ses arguments, mot de passe masqué. tests/test_reseau.py (PopoverTest) les
// pilote par IPC (cible « popover »).
// Garde de plateforme : la fenêtre n'est construite que sous offscreen, où elle ne paraît jamais à l'écran.
// Entrées : DUNEI_TOKENS_DIR, lu par Theme ; QT_QPA_PLATFORM=offscreen, posé par le test.
// Sortie : « essai : prêt » à l'ouverture de la fenêtre, et les lignes « essai : connect <nom> », « essai :
// disconnect <nom> », « essai : connectWithPsk <nom> <longueur> », « essai : executer <arguments JSON> », « essai :
// allumer <bool> », « essai : ouvrirPortail », « essai : verifier ». Commandes : voir chaque fonction de
// l'IpcHandler (ajouterReseau et retirerReseau imitent le balayage, joindre la réussite d'une connexion).
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
        function disconnect() { essai.journal("disconnect", name) }
        function connectWithPsk(psk) { essai.journal("connectWithPsk", name + " " + psk.length) }
    }

    // Réseaux factices, créés dynamiquement pour que retirerReseau puisse les détruire comme le fait Quickshell
    // quand un réseau quitte le balayage. « Nouveau » n'est montré que par ajouterReseau.
    Component { id: fabriqueReseau; FauxReseau {} }
    property var tous: []
    // reseau — réseau factice par son nom. Entrée : nom. Sortie : l'objet, ou undefined (absent ou détruit).
    function reseau(nom) { return tous.find(r => r?.name === nom) }
    Component.onCompleted: {
        const c = proprietes => fabriqueReseau.createObject(essai, proprietes)
        tous = [c({ name: "Wifi_TRIADES", signalStrength: 0.9, connected: true, known: true }),
                c({ name: "Connu", signalStrength: 0.3, known: true }), c({ name: "Inconnu", signalStrength: 0.7 }),
                c({ name: "Nouveau", signalStrength: 0.95 }),
                c({ name: "Ouvert", signalStrength: 0.5, security: WifiSecurityType.Open })]
        faux.reseaux = ["Connu", "Ouvert", "Wifi_TRIADES", "Inconnu"].map(reseau)
    }

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
        property string profilDemande: ""
        property var profils: []
        property var reseaux: []
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
                id: ipc
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
                // profilDemande — profil demandé à la fenêtre (le popover ne le pose plus : il le vide), en JSON. Sortie : texte.
                function profilDemande(): string { return JSON.stringify(faux.profilDemande) }
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
                function ajouterReseau(): void { faux.reseaux = faux.reseaux.concat([essai.reseau("Nouveau")]) }
                // retirerReseau — le réseau nommé quitte le balayage, puis son objet est détruit, comme sous
                // Quickshell. Entrée : nom. Sortie : aucune.
                function retirerReseau(nom: string): void {
                    const r = essai.reseau(nom)
                    faux.reseaux = faux.reseaux.filter(x => x !== r)
                    r.destroy()
                }
                // joindre — la connexion au réseau nommé réussit : il devient le réseau joint (et connu), l'ancien
                // ne l'est plus, comme le rapporte Quickshell. Entrée : nom. Sortie : aucune.
                function joindre(nom: string): void {
                    essai.tous.forEach(r => { if (r) r.connected = false })
                    const r = essai.reseau(nom)
                    r.known = true
                    r.connected = true
                    faux.nomActif = nom
                }

                // panneau — état du panneau construit, en JSON, sans aucun texte saisi ; {} s'il n'existe pas.
                // Sortie : {titre, etat, bascule {visible, actif, allumee}, reseaux (rangées montrées, dans l'ordre),
                // deplie, erreur, portail, ip (une adresse est-elle affichée), autre (« Autre réseau… »
                // affiché), chevron (« Réglages réseau… » porte un suffixe), balayage, activite (indicateur de la
                // recherche visible), infobulle (texte de l'infobulle de la recherche), connexion (noms des lignes
                // « Connexion… »), glisse (une ligne glisse), lignes (nom → {depliage, deplieEnCours, charge, y,
                // apparition, apparitionEnCours}),
                // margeEcran (du popover), saisie (longueur du mot de passe de la ligne dépliée, -1 sans ligne)}.
                // Erreurs : aucune.
                function panneau(): string {
                    const p = porteur.item?.panneau
                    if (!p) return "{}"
                    const objet = nom => essai.trouver(p, o => o.objectName === nom)
                    const bascule = objet("bascule")
                    const delegues = Object.values(p.delegues)
                    const lignes = {}
                    for (const d of delegues) lignes[d.cle] = {
                        depliage: d.depliage.value, deplieEnCours: d.depliage.moving, charge: d.bloc !== null || d.depliage.value > 0,
                        y: d.y, apparition: d.apparition.value, apparitionEnCours: d.apparition.moving,
                    }
                    return JSON.stringify({
                        titre: p.resume.titre, etat: p.resume.etat,
                        bascule: { visible: bascule.visible, actif: bascule.enabled, allumee: bascule.checked },
                        reseaux: p.listeVisible ? p.ordre.filter((n, i) => p.present(p.reseaux[i])) : [],
                        deplie: p.deplie, erreur: p.erreur,
                        portail: p.etat.connectivite === "portal",
                        ip: essai.trouver(p, o => o.visible && String(o.text ?? "").includes("192.168")) !== null,
                        autre: essai.trouver(p, o => o.text === "Autre réseau…") !== null,
                        chevron: essai.trouver(p, o => o.text === "Réglages réseau…").suffixe !== null,
                        balayage: p.balayage, activite: objet("activiteRecherche").visible,
                        infobulle: Array.from(objet("recherche").data).find(o => o.objectName === "infobulleRecherche")?.texte ?? "",
                        connexion: delegues.filter(d => d.enConnexion).map(d => d.cle),
                        glisse: delegues.some(d => d.decalage.moving), lignes,
                        margeEcran: porteur.item.margeEcran,
                        exclusif: porteur.item.exclusif, fermeAuDepart: porteur.item.fermeAuDepart,
                        retenu: porteur.item.retenu,
                        saisie: p.bloc ? p.bloc.secret.length : -1,
                    })
                }

                // puisLire — appelle une fonction de cette cible puis rend l'état du panneau dans la même passe,
                // avant toute image : un état en plein mouvement se lit sans dépendre de la charge de la machine.
                // Entrées : fonction, son nom ; argument, passé tel quel (ignoré par une fonction sans argument).
                // Sortie : texte JSON, voir panneau. Erreurs : fonction inconnue, TypeError au journal.
                function puisLire(fonction: string, argument: string): string {
                    ipc[fonction](argument)
                    return panneau()
                }
                // profilActif — l'état factice porte un profil Wi-Fi actif lu, d'uuid donné, au nom du réseau joint.
                // Entrée : uuid. Sortie : aucune.
                function profilActif(uuid: string): void {
                    faux.profils = [{ nom: faux.nomActif, uuid, type: "802-11-wireless", actif: true }]
                }

                // choisir — clic sur le réseau nommé. Entrée : nom. Sortie : aucune.
                function choisir(nom: string): void {
                    const p = porteur.item.panneau
                    p.choisir(p.reseaux.find(r => r?.name === nom))
                }
                // echouer — émet connectionFailed (secrets absents) sur le réseau factice nommé. Entrée : nom.
                function echouer(nom: string): void {
                    essai.reseau(nom).connectionFailed(ConnectionFailReason.NoSecrets)
                }
                // saisir — remplit le mot de passe de la ligne dépliée. Entrée : texte.
                function saisir(texte: string): void { porteur.item.panneau.bloc.secret.text = texte }
                // activer — action nommée : rejoindre, reglages, portail, bascule (clic sur la bascule du Wi-Fi),
                // rechercher (bouton de recherche), deconnecter (« Se déconnecter » du pied). Entrée : cle.
                function activer(cle: string): void {
                    const p = porteur.item.panneau
                    const texte = t => essai.trouver(p, o => o.text === t && o.visible)
                    if (cle === "rejoindre") p.rejoindre()
                    else if (cle === "reglages") texte("Réglages réseau…").active()
                    else if (cle === "portail") texte("Ouvrir la page de connexion").clicked()
                    else if (cle === "bascule") {
                        const b = essai.trouver(p, o => o.objectName === "bascule")
                        b.toggle()
                        b.toggled()
                    }
                    else if (cle === "rechercher") essai.trouver(p, o => o.nom === "view-refresh").clique()
                    else if (cle === "deconnecter") texte("Se déconnecter").active()
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
