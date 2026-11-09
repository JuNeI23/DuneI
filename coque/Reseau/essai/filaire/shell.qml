//@ pragma IconTheme DuneI
import QtQuick
import Quickshell
import Quickshell.Io
import "Theme"
import "Reseau"

// Coque d'essai de la page Filaire de la fenêtre Réseau, dans une fenêtre offscreen (L2-65 : dépliant de la connexion
// filaire active).
// Rôle : pose une PageFilaire dans une FloatingWindow, branchée sur un état et un panneau factices (aucune commande ne
// touche le réseau réel ni les appareils de la machine) : l'état simule un câble branché, débranché ou une machine
// sans carte filaire, le panneau journalise ouvrirProfil. tests/test_reseau.py (PageFilaireTest) la pilote par IPC
// (cible « filaire »).
// Garde de plateforme : la fenêtre n'est construite que sous offscreen, où elle ne paraît jamais à l'écran.
// Entrées : DUNEI_TOKENS_DIR, lu par Theme ; QT_QPA_PLATFORM=offscreen, posé par le test.
// Sortie : « essai : prêt » à l'ouverture, puis « essai : ouvrirProfil <uuid> ».
// Erreurs : celles de Theme et des liaisons, dans le journal. Dépendances : quickshell ≥ 0.3 (FloatingWindow,
// LazyLoader, IpcHandler), modules Theme et Reseau, par les liens Theme, Composants, Reseau et Barre posés sous cette
// racine.
ShellRoot {
    id: essai

    // journal — écrit une ligne lisible par le test. Entrées : cle, valeur. Sortie : aucune. Erreurs : aucune.
    function journal(cle, valeur) { console.info("essai : " + cle + " " + valeur) }

    // État factice : les propriétés d'EtatReseau que lit la page Filaire. Au départ, un câble branché.
    QtObject {
        id: faux
        property bool filaire: true
        property bool carteFilaire: true
        property var appareilFilaire: ({name: "enp3s0", address: "8C:16:45:2E:71:B0", linkSpeed: 1000})
        property string appareil: "enp3s0"
        property var ip4: ["10.0.0.2/24"]
        property var ip6: ["fe80::2/64"]
        property string passerelle: "10.0.0.1"
        property var dns: ["10.0.0.1"]
        property string mac: "8C:16:45:2E:71:B0"
        property string connectivite: "full"
        // executer — journalise les arguments et rend le profil factice à la lecture « nmcli -t … show ». Entrées :
        // args, fin. Sortie : aucune.
        function executer(args, fin) {
            essai.journal("executer", JSON.stringify(args))
            if (fin && args[0] === "-t" && args.includes("show"))
                fin(0, "connection.autoconnect:yes\nconnection.autoconnect-priority:5\nconnection.metered:unknown\nipv4.method:auto\nipv4.addresses:\nipv4.gateway:\nipv4.dns:\n")
        }
    }

    // Panneau factice : les profils filaires (un actif, un débranché) et l'ouverture d'une sous-page.
    QtObject {
        id: panneauFaux
        property var rangees: [
            {groupe: "Filaire", nom: "Bureau", uuid: "bureau-1", appareil: "enp3s0", wifi: false, actif: true, etat: "Connecté", icone: "network-wired"},
            {groupe: "Filaire", nom: "Atelier", uuid: "atelier-1", appareil: "", wifi: false, actif: false, etat: "Débranché", icone: "network-wired"},
            {groupe: "Wi-Fi", nom: "Wifi_TRIADES", uuid: "wifi-1", appareil: "wlan0", wifi: true, actif: true, etat: "Connecté", icone: "network-wireless-signal-excellent"}
        ]
        property string sousPage: ""
        property string onglet: "filaire"
        function ouvrirProfil(uuid) { essai.journal("ouvrirProfil", uuid) }
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

    LazyLoader {
        activeAsync: Theme.ready && Qt.platform.pluginName === "offscreen"

        FloatingWindow {
            id: fenetre
            implicitWidth: 760
            implicitHeight: 900
            color: Theme.color?.surfaceWindow ?? "transparent"
            Component.onCompleted: essai.journal("prêt", true)

            PageFilaire { id: page; width: fenetre.width; panneau: panneauFaux; etat: faux }

            IpcHandler {
                target: "filaire"

                // page — état de la page, en JSON : {titres (étiquettes de section visibles), appareil (libellé de la
                // rangée de tête), aide (son état), actif (son médaillon est à l'accent), materiel (adresse matérielle
                // montrée, vide sans rangée), profils (noms des profils filaires, dans l'ordre), aucun (« Aucun profil
                // filaire. » est montré), depliant ({existe (le dépliant de la connexion active est montré), charge (son
                // contenu est chargé, montré ou non), ouvert, lu
                // (profil lu), tuiles (libellé → texte), reglages (libellés des réglages montrés), pied (libellés des
                // boutons du pied), debits (la courbe est montrée), carteAdresses (une CarteAdresses existe : toujours
                // faux)}}. Erreurs : aucune.
                function page(): string {
                    const objet = nom => essai.trouver(page, o => o.objectName === nom)
                    const tete = objet("appareil")
                    const materiel = objet("materiel")
                    const f = essai.trouver(page, o => String(o.objectName).startsWith("depliant:") && o.visible)
                    const c = f?.corps
                    const tuilesDe = g => Array.from(g?.children ?? []).filter(t => t.largeur !== undefined && t.visible)
                    const depliant = {
                        existe: f !== null, charge: page.depliant.corps !== null, ouvert: f?.ouvert ?? false, lu: c?.profil.lu ?? false,
                        tuiles: c ? c.tuiles.liste.reduce((m, t) => (m[t.libelle] = t.texte, m), {}) : {},
                        reglages: c ? tuilesDe(c.reglages.grille).map(t => t.libelle) : [],
                        pied: c ? essai.tous_(c.reglages, o => (o.objectName === "avances" || o.objectName === "oublier") && o.visible).map(o => o.text) : [],
                        debits: c?.debits.visible ?? false,
                        carteAdresses: essai.trouver(page, o => o.methode !== undefined && o.rangee !== undefined) !== null,
                    }
                    return JSON.stringify({
                        titres: essai.tous_(page, o => o.text !== undefined && o.moyen === true && o.echelon === 0 && o.visible).map(o => o.text),
                        appareil: tete.libelle, aide: tete.aide, actif: tete.iconeActive,
                        materiel: materiel && materiel.visible ? essai.trouver(materiel, o => o.copiable !== undefined)?.text ?? "" : "",
                        profils: essai.tous_(page, o => o.modelData?.uuid !== undefined && o.clique !== undefined).map(o => o.libelle),
                        aucun: essai.trouver(page, o => o.text === "Aucun profil filaire." && o.visible) !== null,
                        depliant,
                    })
                }

                // mode — simule l'état du câble. Entrée : nom, « connecte » (câble branché), « debranche » (carte sans
                // câble) ou « aucune » (pas de carte filaire). Sortie : aucune.
                function mode(nom: string): void {
                    faux.filaire = nom === "connecte"
                    faux.carteFilaire = nom !== "aucune"
                    faux.appareilFilaire = nom === "aucune" ? null : {name: "enp3s0", address: "8C:16:45:2E:71:B0"}
                    faux.appareil = nom === "connecte" ? "enp3s0" : "wlan0"
                }
                // sansProfils — retire les profils filaires du panneau. Entrées : aucune. Sortie : aucune.
                function sansProfils(): void { panneauFaux.rangees = panneauFaux.rangees.filter(r => r.wifi) }
                // sansAutres — ne garde que le profil filaire actif. Entrées : aucune. Sortie : aucune.
                function sansAutres(): void { panneauFaux.rangees = panneauFaux.rangees.filter(r => r.wifi || r.actif) }
                // appareil — change l'appareil que lit l'état (le Wi-Fi quand le filaire est inactif). Entrée : nom.
                function appareil(nom: string): void { faux.appareil = nom }
                // montrer — demande le dépliant d'un profil comme le fait le panneau pour un profil demandé. Entrée :
                // uuid. Sortie : vrai si la page l'a déplié, faux s'il faut la sous-page.
                function montrer(uuid: string): bool { return page.montrer(uuid) }
                // basculer — clic sur la tête du dépliant. Entrées : aucune. Sortie : aucune.
                function basculer(): void { essai.trouver(page, o => o.objectName === "tete").clique() }
                // choisir — clic sur le profil d'un uuid. Entrée : uuid. Sortie : aucune.
                function choisir(uuid: string): void { essai.trouver(page, o => o.modelData?.uuid === uuid && o.clique !== undefined).clique() }
            }
        }
    }
}
