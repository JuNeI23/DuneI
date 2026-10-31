.pragma library

// nmcli.js — analyse des sorties « nmcli -t », construction des arguments de modification et fonctions pures
// du popover (tri des réseaux, résumé de l'état).
// Rôle : transforme le texte de NetworkManager en objets simples pour le panneau réseau, sans jamais lancer
// nmcli lui-même (les processus restent dans les singletons QML). Une seule logique d'échappement pour tout le
// module : « nmcli -t » écrit « \: » pour un deux-points et « \\ » pour une barre oblique inverse dans une
// valeur ; un nom de réseau hostile (deux-points, barre oblique, accents, vide) revient donc tel quel.
// Dépendances : aucune (bibliothèque sans état, importable depuis tout QML ou depuis la coque d'essai).

// champs — découpe une ligne « nmcli -t » en champs.
// Entrée : ligne, texte d'une ligne. Sortie : tableau de chaînes ; « \: » devient « : » et « \\ » devient « \ »
// dans les champs, seuls les « : » non échappés séparent ; une ligne vide donne [""]. Erreurs : aucune.
function champs(ligne) {
    const sortie = [""]
    for (let i = 0; i < ligne.length; i++) {
        const c = ligne[i]
        if (c === "\\" && (ligne[i + 1] === ":" || ligne[i + 1] === "\\")) sortie[sortie.length - 1] += ligne[++i]
        else if (c === ":") sortie.push("")
        else sortie[sortie.length - 1] += c
    }
    return sortie
}

// lignes — lignes non vides d'une sortie, chacune découpée en champs.
// Entrée : texte, sortie de nmcli. Sortie : tableau de tableaux de champs. Erreurs : aucune.
// Dépendances : champs.
function lignes(texte) {
    return texte.split("\n").filter(l => l !== "").map(champs)
}

// valeurs — regroupe les lignes « clé:valeur » par clé.
// Entrée : texte, sortie de nmcli avec un champ « clé:valeur » par ligne. Sortie : objet clé → tableau de
// valeurs, l'indice d'une clé indexée étant retiré (« IP4.DNS[2] » range sous « IP4.DNS ») ; la valeur « -- »
// de nmcli compte pour vide. Erreurs : aucune. Dépendances : lignes.
function valeurs(texte) {
    const sortie = {}
    for (const l of lignes(texte)) {
        const cle = l[0].replace(/\[\d+\]$/, "")
        const v = l.slice(1).join(":")
        ;(sortie[cle] = sortie[cle] || []).push(v === "--" ? "" : v)
    }
    return sortie
}

// liste — éclate une valeur multiple de nmcli en éléments non vides.
// Entrée : v, chaîne ou undefined (séparateurs : virgule, espace, barre verticale). Sortie : tableau de chaînes.
// Erreurs : aucune.
function liste(v) {
    return (v || "").split(/[,\s|]+/).filter(x => x !== "")
}

// lireAppareil — état IP d'un appareil.
// Entrée : texte, sortie de « nmcli -t -f IP4.ADDRESS,IP4.GATEWAY,IP4.DNS,GENERAL.METERED device show <iface> ».
// Sortie : {ip4: string[], passerelle: string, dns: string[], facture: bool} ; facture est vrai pour « yes » et
// « yes (guessed) ». Une sortie vide donne des valeurs vides. Erreurs : aucune. Dépendances : valeurs.
function lireAppareil(texte) {
    const v = valeurs(texte)
    return {
        ip4: (v["IP4.ADDRESS"] || []).filter(x => x !== ""),
        passerelle: (v["IP4.GATEWAY"] || [""])[0],
        dns: (v["IP4.DNS"] || []).filter(x => x !== ""),
        facture: /^yes\b/.test((v["GENERAL.METERED"] || [""])[0]),
    }
}

// lireProfils — liste des profils de connexion.
// Entrée : texte, sortie de « nmcli -t -f NAME,UUID,TYPE,DEVICE,ACTIVE connection show ».
// Sortie : tableau de {nom, uuid, type, appareil, actif: bool} ; appareil est vide hors de portée, nom l'est pour
// un réseau caché sans nom. Les lignes de moins de cinq champs sont ignorées. Erreurs : aucune.
// Dépendances : lignes.
function lireProfils(texte) {
    return lignes(texte).filter(l => l.length >= 5).map(l => ({
        nom: l[0], uuid: l[1], type: l[2], appareil: l[3] === "--" ? "" : l[3], actif: l[4] === "yes",
    }))
}

// lireProfil — réglages d'un profil.
// Entrée : texte, sortie de « nmcli -t -f connection.autoconnect,connection.autoconnect-priority,
// connection.metered,ipv4.method,ipv4.addresses,ipv4.gateway,ipv4.dns,802-11-wireless.ssid connection show <uuid> ».
// Sortie : {autoconnect: bool, priorite: int, facture: string, methode: "auto"|"manual", adresse: string (la
// première), passerelle, dns: string[], ssid}. facture garde la valeur de nmcli (« yes », « no », « unknown ») ;
// toute méthode autre que « manual » se lit « auto ». Une clé absente prend sa valeur neutre. Erreurs : aucune.
// Dépendances : valeurs, liste.
function lireProfil(texte) {
    const v = valeurs(texte)
    const un = (cle, defaut) => (v[cle] && v[cle][0] !== "") ? v[cle][0] : defaut
    return {
        autoconnect: un("connection.autoconnect", "no") === "yes",
        priorite: parseInt(un("connection.autoconnect-priority", "0"), 10) || 0,
        facture: un("connection.metered", "unknown"),
        methode: un("ipv4.method", "auto") === "manual" ? "manual" : "auto",
        adresse: liste(un("ipv4.addresses", ""))[0] || "",
        passerelle: un("ipv4.gateway", ""),
        dns: liste(un("ipv4.dns", "")),
        ssid: un("802-11-wireless.ssid", ""),
    }
}

// Correspondance entre les clés de modification de l'interface et les propriétés de nmcli.
const PROPRIETES = {
    autoconnect: "connection.autoconnect", priorite: "connection.autoconnect-priority",
    facture: "connection.metered", methode: "ipv4.method", adresse: "ipv4.addresses",
    passerelle: "ipv4.gateway", dns: "ipv4.dns", psk: "802-11-wireless-security.psk",
}

// argsModifier — arguments de « nmcli connection modify ».
// Entrées : uuid, le profil visé ; changes, objet dont les clés sont autoconnect (bool), priorite (entier),
// facture (« yes », « no » ou « unknown »), methode (« auto » ou « manual »), adresse, passerelle, dns (tableau
// ou chaîne) et psk. Sortie : tableau d'arguments (sans « nmcli »), dans l'ordre des clés de changes ; passer
// methode à « auto » vide aussi l'adresse et la passerelle et ignore celles que changes redonne.
// Erreurs : Error si une clé est inconnue (le message la nomme). Dépendances : PROPRIETES.
function argsModifier(uuid, changes) {
    const args = ["connection", "modify", uuid]
    const auto = changes.methode === "auto"
    for (const cle of Object.keys(changes)) {
        if (!(cle in PROPRIETES)) throw new Error("clé de modification inconnue : " + cle)
        if (auto && (cle === "adresse" || cle === "passerelle")) continue
        const v = changes[cle]
        args.push(PROPRIETES[cle], typeof v === "boolean" ? (v ? "yes" : "no") : Array.isArray(v) ? v.join(",") : String(v))
        if (cle === "methode" && auto) args.push(PROPRIETES.adresse, "", PROPRIETES.passerelle, "")
    }
    return args
}

// etatAppareils — dérive l'état de connexion de la liste des appareils de Quickshell.Networking.
// Entrées : appareils, tableau d'appareils (type, connected, name, networks.values) ; typeWifi et typeFilaire,
// valeurs de DeviceType.Wifi et DeviceType.Wired. Sortie : {carte: bool (une carte Wi-Fi existe), filaire: bool
// (un appareil filaire est connecté), reseauActif (le premier réseau Wi-Fi joint, ou null), connecte: bool (Wi-Fi
// joint ou filaire connecté), nomActif: string (nom de l'appareil filaire connecté, sinon du réseau Wi-Fi joint,
// sinon "")}. Une liste vide donne carte, filaire et connecte faux. Erreurs : aucune.
// Dépendances : aucune.
function etatAppareils(appareils, typeWifi, typeFilaire) {
    const cartes = appareils.filter(d => d.type === typeWifi)
    const cables = appareils.filter(d => d.type === typeFilaire && d.connected)
    const reseauActif = cartes.reduce((tous, c) => tous.concat(Array.from(c.networks.values)), [])
                              .find(n => n.connected) ?? null
    return {
        carte: cartes.length > 0, filaire: cables.length > 0, reseauActif,
        connecte: reseauActif !== null || cables.length > 0,
        nomActif: cables.length > 0 ? cables[0].name : (reseauActif?.name ?? ""),
    }
}

// trierReseaux — ordre de la liste des réseaux du popover.
// Entrée : reseaux, tableau d'objets {name, connected, known, signalStrength} (des WifiNetwork de
// Quickshell.Networking ou des factices). Sortie : nouveau tableau, le réseau joint en tête, puis les réseaux
// connus, puis la force décroissante ; un nom vide (réseau caché, qu'on rejoint par « Autre réseau… ») est écarté.
// Erreurs : aucune. Dépendances : aucune.
function trierReseaux(reseaux) {
    const rang = r => (r.connected ? 0 : 2) + (r.known ? 0 : 1)
    return reseaux.filter(r => r.name !== "").sort((a, b) => rang(a) - rang(b) || b.signalStrength - a.signalStrength)
}

// resume — titre et état affichés en tête du popover réseau.
// Entrée : e, objet {carte, radio, filaire, connecte, connectivite, facture, nomActif}, valeurs de EtatReseau.
// Sortie : {titre, etat, alerte} ; titre, le nom du réseau joint, « Réseau filaire », « Wi-Fi » ou « Réseau » ;
// etat, « Connecté », « Connecté sans internet » (connectivité « limited » ou « none »), « Portail de connexion »,
// « Partage du téléphone » (Wi-Fi facturé à l'usage), « Non connecté », « Wi-Fi désactivé » ou « Aucune carte
// réseau » ; alerte, vrai sans internet ou derrière un portail. Le filaire l'emporte sur le Wi-Fi, comme pour
// l'icône de la barre. Erreurs : aucune. Dépendances : aucune.
function resume(e) {
    if (!e.carte && !e.filaire) return {titre: "Réseau", etat: "Aucune carte réseau", alerte: false}
    if (!e.filaire && !e.radio) return {titre: "Wi-Fi", etat: "Wi-Fi désactivé", alerte: false}
    if (!e.connecte) return {titre: "Wi-Fi", etat: "Non connecté", alerte: false}
    const titre = e.filaire ? "Réseau filaire" : e.nomActif
    if (e.connectivite === "portal") return {titre, etat: "Portail de connexion", alerte: true}
    if (e.connectivite === "limited" || e.connectivite === "none") return {titre, etat: "Connecté sans internet", alerte: true}
    return {titre, etat: !e.filaire && e.facture ? "Partage du téléphone" : "Connecté", alerte: false}
}
