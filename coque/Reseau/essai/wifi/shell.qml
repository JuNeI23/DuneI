//@ pragma IconTheme DuneI
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import "Theme"
import "Reseau"

// Coque d'essai de la page Wi-Fi de la fenêtre Réseau, dans une fenêtre offscreen.
// Rôle : pose une PageWifi dans une FloatingWindow, branchée sur un état et un panneau factices (aucune action ne
// touche le réseau réel) : réseaux factices qui journalisent leurs appels (connect, connectWithPsk avec la seule
// longueur du mot de passe), executer qui journalise ses arguments et rend des profils fixes, panneau qui journalise
// ouvrirProfil et ouvrirNouveau. tests/test_reseau.py (PageWifiTest) la pilote par IPC (cible « wifi »).
// Garde de plateforme : la fenêtre n'est construite que sous offscreen, où elle ne paraît jamais à l'écran.
// Entrées : DUNEI_TOKENS_DIR, lu par Theme ; QT_QPA_PLATFORM=offscreen, posé par le test.
// Sortie : « essai : prêt » à l'ouverture, puis les lignes « essai : connect <nom> », « essai : connectWithPsk <nom>
// <longueur> », « essai : executer <arguments JSON> », « essai : allumer <bool> », « essai : ouvrirProfil <uuid> »,
// « essai : ouvrirNouveau ». Le texte d'un mot de passe n'est jamais journalisé ni rendu.
// Erreurs : celles de Theme et des liaisons, dans le journal. Dépendances : quickshell ≥ 0.3 (FloatingWindow,
// LazyLoader, IpcHandler), Quickshell.Networking (énumérations), modules Theme et Reseau, par les liens
// Theme, Composants, Reseau et Barre posés sous cette racine.
ShellRoot {
    id: essai

    // Mot de passe enregistré que rend le faux « nmcli -s » ; il ne doit jamais paraître au journal.
    readonly property string secretFiche: "psk-enregistre-jamais-journalise"

    // journal — écrit une ligne lisible par le test. Entrées : cle, valeur. Sortie : aucune. Erreurs : aucune.
    function journal(cle, valeur) { console.info("essai : " + cle + " " + valeur) }

    // Réseau factice : les membres de WifiNetwork que lit la page.
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
    Component { id: fabriqueReseau; FauxReseau {} }
    property var tous: []
    // reseau — réseau factice par son nom. Entrée : nom. Sortie : l'objet, ou undefined.
    function reseau(nom) { return tous.find(r => r?.name === nom) }
    Component.onCompleted: {
        const c = proprietes => fabriqueReseau.createObject(essai, proprietes)
        tous = [c({ name: "Wifi_TRIADES", signalStrength: 0.9, connected: true, known: true }),
                c({ name: "Connu", signalStrength: 0.3, known: true }), c({ name: "Inconnu", signalStrength: 0.7 }),
                c({ name: "Ouvert", signalStrength: 0.5, security: WifiSecurityType.Open })]
        faux.reseaux = ["Connu", "Ouvert", "Wifi_TRIADES", "Inconnu"].map(reseau)
    }

    // État factice : les propriétés et fonctions d'EtatReseau qu'emploient la page et le dépliant du réseau joint.
    QtObject {
        id: faux
        property bool radio: true
        property string connectivite: "full"
        property string nomActif: "Wifi_TRIADES"
        property real force: 0.9
        property string appareil: "wlan0"
        property var ip4: ["192.168.1.42/24"]
        property var ip6: ["fe80::1/64"]
        property string passerelle: "192.168.1.1"
        property var dns: ["192.168.1.1"]
        property string mac: "A4:C3:F0:5B:1E:72"
        property bool carteFilaire: true
        property bool recherche: false
        property bool rechercheFenetre: false
        readonly property bool balayage: recherche || rechercheFenetre
        property var reseaux: []
        // Priorité que rend la lecture du profil ; changée par l'IPC « prioriteLue » pour simuler la sous-page.
        property int prioriteLue: 5
        function allumer(actif) { essai.journal("allumer", actif); radio = actif }
        function executer(args, fin) {
            essai.journal("executer", JSON.stringify(args))
            if (args[0] === "-s") return fin(0, essai.secretFiche + "\n")
            if (args[0] === "-t" && args.includes("show")) fin(0, "connection.autoconnect:yes\nconnection.autoconnect-priority:" + prioriteLue + "\nconnection.metered:unknown\nipv4.method:auto\nipv4.addresses:\nipv4.gateway:\nipv4.dns:\n802-11-wireless.ssid:Wifi_TRIADES\n802-11-wireless-security.key-mgmt:wpa-psk\n")
        }
    }

    // Panneau factice : les rangées de profils et les deux ouvertures de sous-page.
    QtObject {
        id: panneauFaux
        property var factures: ({})
        // Onglet et sous-page courants, que lit la page pour relire le profil du réseau joint au retour d'une sous-page.
        property string onglet: "wifi"
        property string sousPage: ""
        property var rangees: [
            {groupe: "Wi-Fi", nom: "Wifi_TRIADES", uuid: "wifi-1", appareil: "wlan0", wifi: true, actif: true, etat: "Connecté", icone: "network-wireless-signal-excellent"},
            {groupe: "Wi-Fi", nom: "Connu", uuid: "connu-1", appareil: "", wifi: true, actif: false, etat: "À portée", icone: "network-wireless-signal-good"},
            {groupe: "Wi-Fi", nom: "Telephone_Essai", uuid: "hotspot-1", appareil: "", wifi: true, actif: false, etat: "Hors de portée", icone: "network-wireless-hotspot"},
            {groupe: "Wi-Fi", nom: "Cafe", uuid: "cafe-1", appareil: "", wifi: true, actif: false, etat: "Hors de portée", icone: "network-wireless-signal-excellent"},
            {groupe: "Filaire", nom: "Bureau", uuid: "filaire-1", appareil: "", wifi: false, actif: false, etat: "Débranché", icone: "network-wired"}
        ]
        function ouvrirProfil(uuid) { essai.journal("ouvrirProfil", uuid) }
        function ouvrirNouveau() { essai.journal("ouvrirNouveau", true) }
    }

    // touche — frappe une touche dans la fenêtre de la page, comme le clavier. Entrées : cible, un Item de la fenêtre ;
    // cle, un Qt.Key_* ; modif, un Qt.KeyboardModifier. Sortie : aucune. Erreurs : page détruite, TypeError au
    // journal. Dépendances : QtTest.
    function touche(cible, cle, modif) {
        const e = Qt.createQmlObject("import QtTest; TestEvent {}", cible)
        e.keyClick(cle, modif, -1)
        e.destroy()
    }

    // nomDe — nom lisible d'un élément du focus : le libellé de la Ligne ou l'objectName du contrôle, cherchés en
    // remontant les parents (le focus d'un champ est dans son TextInput). Entrée : item. Sortie : texte, vide sinon.
    function nomDe(item) {
        for (let o = item; o; o = o.parent) {
            if (o.libelle) return o.libelle
            if (o.objectName) return o.objectName
        }
        return ""
    }

    LazyLoader {
        activeAsync: Theme.ready && Qt.platform.pluginName === "offscreen"

        FloatingWindow {
            id: fenetre
            implicitWidth: 760
            implicitHeight: 900
            color: Theme.color?.surfaceWindow ?? "transparent"
            Component.onCompleted: essai.journal("prêt", true)

            // La page défile comme dans le panneau de la fenêtre, pour éprouver une longue liste de réseaux connus.
            Flickable {
                id: defilement
                anchors.fill: parent
                contentHeight: porteur.height
                Loader {
                    id: porteur
                    width: fenetre.width
                    sourceComponent: Component { PageWifi { width: fenetre.width; panneau: panneauFaux; etat: faux } }
                }
            }

            // Sous-page d'un profil (FicheProfil complète) sur l'état factice, ouverte à la demande de l'IPC.
            Loader {
                id: sousPage
                property string uuid
                y: 0
                width: fenetre.width
                active: uuid !== ""
                sourceComponent: Component {
                    FicheProfil { width: fenetre.width; uuid: sousPage.uuid; rangee: panneauFaux.rangees.find(r => r.uuid === sousPage.uuid) ?? null; etat: faux }
                }
            }

            IpcHandler {
                id: ipc
                target: "wifi"

                // ouvrirFiche — ouvre la FicheProfil complète d'un profil du panneau factice. Entrée : uuid. Sortie : aucune.
                function ouvrirFiche(uuid: string): void { sousPage.uuid = uuid }
                // prioriteLue, sousPage — simulent une modification faite dans la sous-page « Détails… » (nouvelle priorité
                // enregistrée) puis l'ouverture ou la fermeture de la sous-page. Entrées : valeur. Sortie : aucune.
                function prioriteLue(valeur: int): void { faux.prioriteLue = valeur }
                function sousPage(valeur: string): void { panneauFaux.sousPage = valeur }
                // carteFilaire — pose la présence d'une carte filaire dans l'état factice. Entrée : valeur. Sortie : aucune.
                function carteFilaire(valeur: bool): void { faux.carteFilaire = valeur }
                // connexion — clique « Se connecter » ou « Se déconnecter » de la carte de tête de la sous-page. Entrées :
                // aucune. Sortie : le texte du bouton avant le clic, vide s'il est masqué. Erreurs : sous-page fermée.
                function connexion(): string {
                    const b = essai.trouver(sousPage.item, o => o.objectName === "connexion")
                    if (!b.visible) return ""
                    const t = b.text
                    b.clicked()
                    return t
                }

                // page — état de la page, en JSON, sans aucun texte saisi. Sortie : {existe, joint (le dépliant du réseau
                // joint existe), tete (libellé de sa rangée de tête), aideTete, rangeesJoint (libellés des rangées du
                // dépliant), reseaux (noms montrés des autres réseaux, dans l'ordre), serrures (noms à cadenas), autre
                // (« Autre réseau… » visible dans le groupe des autres réseaux), blocs (objectName des blocs visibles de
                // la page, de haut en bas), filtre, connus
                // (libellés des réseaux connus visibles, dans l'ordre), connusVisible (la section des réseaux connus
                // est visible), connusOuverts (son groupe est montré), connuOuvert (uuid du connu déplié), compte (le
                // nombre affiché), ouverts (uuids des connus dépliés), rejoindre (uuid → « Rejoindre » visible, pour
                // les connus chargés), secretsConnus (uuid → [longueur du mot de passe, révélé], pour les connus chargés), icones ({autres, connus} : tailles des icônes de signal visibles), deplie,
                // erreur, saisie (longueur du mot de passe saisi, -1 sans bloc), connexion (noms « Connexion… »),
                // balayage, activite, rechercher (le bouton est visible), radio, balayageEtat (faux.balayage),
                // recherche, rechercheFenetre, priorite (valeur du Compteur), titres (étiquettes de section
                // visibles)}. Erreurs : aucune.
                function page(): string {
                    const p = porteur.item
                    if (!p) return JSON.stringify({existe: false, rechercheFenetre: faux.rechercheFenetre, balayageEtat: faux.balayage})
                    const objet = nom => essai.trouver(p, o => o.objectName === nom)
                    const lignes = nom => essai.tous_(p, o => o.objectName === nom && o.visible)
                    const reseaux = essai.tous_(p, o => String(o.objectName).startsWith("reseau:") && o.visible)
                    const f = p.depliant
                    const carteJoint = f ? essai.tous_(f, o => o.libelle !== undefined && o.libelle !== "" && o.visible).map(o => o.libelle) : []
                    const tete = f ? essai.trouver(f, o => o.objectName === "tete") : null
                    const bloc = essai.trouver(p, o => o.objectName === "bloc" && o.visible)?.item
                    const connus = essai.tous_(objet("connus"), o => String(o.objectName).startsWith("depliant:") && o.visible)
                    const blocs = ["titre", "desactive", "recherche", "joint", "autres", "connus"].map(objet)
                        .filter(o => o?.visible).sort((a, b) => a.mapToItem(p, 0, 0).y - b.mapToItem(p, 0, 0).y)
                    const tailles = o => essai.tous_(o, i => i.securise !== undefined && i.force !== undefined && i.visible).map(i => i.taille)
                    return JSON.stringify({
                        existe: true, joint: f !== null, tete: tete ? tete.libelle : "", aideTete: tete ? tete.aide : "",
                        rangeesJoint: carteJoint,
                        reseaux: reseaux.map(o => o.objectName.slice(7)),
                        serrures: reseaux.filter(o => essai.trouver(o, i => i.nom === "network-wireless-encrypted" && i.visible)).map(o => o.objectName.slice(7)),
                        autre: objet("disponibles").visible && essai.trouver(objet("disponibles"), o => o.objectName === "autre" && o.visible) !== null,
                        depliantOuvert: f?.ouvert ?? false, blocs: blocs.map(o => o.objectName),
                        filtre: p.filtre, connus: connus.map(o => o.rangee.nom), connusVisible: objet("connus")?.visible ?? false,
                        connusOuverts: objet("groupeConnus")?.visible ?? false, connuOuvert: p.connuOuvert,
                        compte: objet("compte")?.text ?? "", ouverts: connus.filter(o => o.ouvert).map(o => o.rangee.uuid),
                        rejoindre: connus.reduce((m, o) => o.corps ? (m[o.rangee.uuid] = essai.trouver(o, i => i.objectName === "rejoindre").visible, m) : m, {}),
                        secretsConnus: essai.tous_(objet("connus"), o => String(o.objectName).startsWith("depliant:")).reduce((m, o) => o.corps
                            ? (m[o.rangee.uuid] = [o.corps.reglages.champ.length, o.corps.reglages.champ.revele], m) : m, {}),
                        icones: {autres: tailles(objet("disponibles")), connus: tailles(objet("connus"))},
                        revele: bloc ? bloc.secret.revele : null, deplie: p.deplie, erreur: p.erreur, saisie: bloc ? bloc.secret.length : -1,
                        connexion: reseaux.filter(o => essai.trouver(o, i => i.objectName === "ligne")?.aide === "Connexion…").map(o => o.objectName.slice(7)),
                        balayage: p.balayage, activite: objet("activiteRecherche")?.visible ?? false,
                        rechercher: objet("rechercher")?.visible ?? false, radio: faux.radio, balayageEtat: faux.balayage,
                        recherche: faux.recherche, rechercheFenetre: faux.rechercheFenetre,
                        ficheSecret: f?.corps ? [f.corps.reglages.champ.length, f.corps.reglages.champ.revele] : null,
                        priorite: f ? essai.trouver(f, o => o.objectName === "priorite")?.value ?? null : null,
                        disponiblesVisible: objet("disponibles").visible,
                        titres: essai.tous_(p, o => o.text !== undefined && o.moyen === true && o.echelon === 0 && o.visible).map(o => o.text),
                    })
                }

                // tab, retourArriere, entree — frappent Tab, Maj+Tab et Entrée. Entrées : aucune. Sortie : aucune.
                function tab(): void { essai.touche(porteur.item, Qt.Key_Tab, Qt.NoModifier) }
                function retourArriere(): void { essai.touche(porteur.item, Qt.Key_Backtab, Qt.ShiftModifier) }
                function entree(): void { essai.touche(porteur.item, Qt.Key_Return, Qt.NoModifier) }
                // focus — nom de l'élément qui a le focus actif de la fenêtre (voir nomDe), vide sans focus. Sortie : texte.
                function focus(): string { return essai.nomDe(porteur.item.Window.window?.activeFocusItem) }
                // appareil — change l'appareil que lit l'état (le filaire actif l'emporte sur le Wi-Fi). Entrée : nom.
                function appareil(nom: string): void { faux.appareil = nom }
                // deconnecter — le Wi-Fi n'a plus de réseau actif : le profil joint et son réseau se déconnectent. Entrées et
                // sortie : aucune.
                function deconnecter(): void {
                    essai.reseau("Wifi_TRIADES").connected = false
                    faux.nomActif = ""
                    panneauFaux.rangees = panneauFaux.rangees.map(r => r.uuid === "wifi-1" ? Object.assign({}, r, {actif: false, etat: "À portée"}) : r)
                }
                // radio — allume ou coupe le Wi-Fi de l'état factice, sans journaliser l'appel comme un geste de
                // l'utilisateur. Entrée : valeur. Sortie : aucune.
                function radio(valeur: bool): void { faux.radio = valeur }
                // capturer — enregistre l'image de la page telle qu'elle paraît dans la fenêtre, pour les captures de
                // recette (L2-65). Entrée : chemin du PNG. Sortie : aucune. Erreurs : écriture refusée, avertissement au
                // journal. Dépendances : Item.grabToImage.
                function capturer(chemin: string): void {
                    defilement.grabToImage(r => { if (!r.saveToFile(chemin)) console.warn("essai : capture non écrite") })
                }
                // sansConnus — ne laisse au panneau factice que le profil Wi-Fi actif et le filaire. Entrées et sortie : aucune.
                function sansConnus(): void { panneauFaux.rangees = panneauFaux.rangees.filter(r => r.actif || !r.wifi) }
                // nombreux — remplace les réseaux connus par 40 profils factices hors de portée, « Profil_01 » à
                // « Profil_40 » (uuid « profil-01 » à « profil-40 »). Entrées et sortie : aucune.
                function nombreux(): void {
                    const n = i => String(i + 1).padStart(2, "0")
                    panneauFaux.rangees = panneauFaux.rangees.filter(r => r.actif || !r.wifi).concat(Array.from({length: 40}, (_, i) => (
                        {groupe: "Wi-Fi", nom: "Profil_" + n(i), uuid: "profil-" + n(i), appareil: "", wifi: true, actif: false,
                         etat: "Hors de portée", icone: "network-wireless-signal-excellent"})))
                }
                // filtrer — saisit un filtre dans le champ de recherche (vide : l'efface). Entrée : texte. Sortie : aucune.
                function filtrer(texte: string): void { essai.trouver(porteur.item, o => o.objectName === "recherche").text = texte }
                // section — clic sur l'en-tête de la section « Réseaux connus ». Entrées et sortie : aucune.
                function section(): void { essai.trouver(porteur.item, o => o.objectName === "connus").entete.clicked() }
                // connu — clic sur la tête du réseau connu d'un uuid. Entrée : uuid. Sortie : aucune.
                function connu(uuid: string): void { essai.trouver(essai.trouver(porteur.item, o => o.objectName === "depliant:" + uuid), o => o.objectName === "tete").clique() }
                // revelerConnu — clic sur l'œil du réseau connu déplié d'un uuid : lit le secret factice et le montre.
                // Entrée : uuid. Sortie : aucune.
                function revelerConnu(uuid: string): void { essai.trouver(porteur.item, o => o.objectName === "depliant:" + uuid).corps.profil.reveler() }
                // fenetreVisible — montre ou cache la fenêtre de l'essai, la page restant visible. Entrée : valeur.
                function fenetreVisible(valeur: bool): void { fenetre.visible = valeur }
                // rejoindreConnu — clic sur « Rejoindre » du réseau connu déplié d'un uuid. Entrée : uuid. Sortie : aucune.
                function rejoindreConnu(uuid: string): void { essai.trouver(essai.trouver(porteur.item, o => o.objectName === "depliant:" + uuid), o => o.objectName === "rejoindre").clicked() }
                // defiler — défile la page jusqu'en bas. Sortie : JSON {defile (la page dépasse la fenêtre), dernier
                // (libellé du dernier réseau connu), vu (sa tête est entièrement dans la fenêtre)}. Erreurs : aucune.
                function defiler(): string {
                    defilement.contentY = Math.max(0, defilement.contentHeight - defilement.height)
                    const tetes = essai.tous_(essai.trouver(porteur.item, o => o.objectName === "connus"), o => o.objectName === "tete" && o.visible)
                    const t = tetes[tetes.length - 1], y = t.mapToItem(defilement, 0, 0).y
                    return JSON.stringify({defile: defilement.contentHeight > defilement.height, dernier: t.libelle,
                                           vu: y >= 0 && y + t.height <= defilement.height})
                }

                // choisir — clic sur le réseau disponible nommé. Entrée : nom. Sortie : aucune.
                function choisir(nom: string): void { essai.trouver(porteur.item, o => o.objectName === "reseau:" + nom && o.visible).children[0].clique() }
                // saisir — remplit le mot de passe de la rangée dépliée. Entrée : texte (jamais journalisé).
                function saisir(texte: string): void { essai.trouver(porteur.item, o => o.objectName === "bloc" && o.visible).item.secret.text = texte }
                // rejoindre — « Rejoindre » du bloc déplié. Entrées : aucune. Sortie : aucune.
                function rejoindre(): void { essai.trouver(porteur.item, o => o.objectName === "bloc" && o.visible).item.rejoindre() }
                // echouer — émet connectionFailed (secrets absents) sur le réseau nommé. Entrée : nom.
                function echouer(nom: string): void { essai.reseau(nom).connectionFailed(ConnectionFailReason.NoSecrets) }
                // echouerAutrement — émet connectionFailed (échec générique). Entrée : nom.
                function echouerAutrement(nom: string): void { essai.reseau(nom).connectionFailed(ConnectionFailReason.Unknown) }
                // autre — clic sur « Autre réseau… ». Entrées : aucune.
                function autre(): void { essai.trouver(porteur.item, o => o.objectName === "autre").clique() }
                // details — clic sur « Réglages avancés… » du dépliant du réseau joint. Entrées : aucune.
                function details(): void { essai.trouver(porteur.item.depliant, o => o.objectName === "avances").clicked() }
                // avancesConnu — clic sur « Réglages avancés… » du réseau connu déplié d'un uuid. Entrée : uuid.
                function avancesConnu(uuid: string): void { essai.trouver(essai.trouver(porteur.item, o => o.objectName === "depliant:" + uuid), o => o.objectName === "avances").clicked() }
                // rechercher — clic sur « Rechercher ». Entrées : aucune.
                function rechercher(): void { essai.trouver(porteur.item, o => o.objectName === "rechercher").clique() }
                // balayer — le balayage rend sa liste : la liste est réaffectée, comme le fait EtatReseau. Entrées : aucune.
                function balayer(): void { faux.reseaux = faux.reseaux.slice() }
                // basculer — clic sur l'interrupteur de la radio. Entrées : aucune.
                function basculer(): void {
                    const b = essai.trouver(porteur.item, o => o.objectName === "radio")
                    b.toggle()
                    b.toggled()
                }
                // popover — le popover (autre demandeur) pose ou lâche sa demande de balayage. Entrée : valeur.
                function popover(valeur: bool): void { faux.recherche = valeur }
                // masquer, detruire — la page devient invisible (autre sous-page) ou est détruite. Entrées : aucune.
                // reveler — clic sur l'œil du dépliant du réseau joint : lit le secret factice et le montre. Entrées et sortie : aucune.
                function reveler(): void { porteur.item.depliant.corps.profil.reveler() }
                function masquer(valeur: bool): void { porteur.visible = !valeur }
                function detruire(): void { porteur.active = false }
                // priorite — pas du Compteur de priorité. Entrée : pas (+1 ou -1).
                function priorite(pas: int): void {
                    const c = essai.trouver(porteur.item.depliant, o => o.objectName === "priorite")
                    pas > 0 ? c.increase() : c.decrease()
                    c.valueModified()
                }
            }
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
}
