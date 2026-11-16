import QtQuick
import Quickshell
import Quickshell.Io

// MemoireFactures — mémoire persistante des réseaux Wi-Fi vus facturés à l'usage (partages de connexion).
// Rôle : NetworkManager ne dit qu'un réseau est facturé qu'une fois celui-ci joint (« yes (guessed) » sur le lien
// actif ; connection.metered du profil reste « unknown », relevé du 14 novembre 2026). Dès que le lien Wi-Fi actif
// est vu facturé, son nom est donc retenu ici, dans l'état persistant de la coque, pour que les listes lui donnent
// ensuite le glyphe de partage de connexion même quand il n'est pas joint. Rien n'est jamais écrit dans les profils
// de NetworkManager : la mémoire est un fichier JSON de la coque, {"factures": [noms]}.
// Entrées : etat, la source de l'état du réseau (facture, filaire, nomActif : EtatReseau ou un état factice), null
// par défaut (rien n'est alors retenu de soi-même) ; chemin, le fichier de la mémoire, reseau.json dans le dossier
// d'état de la coque (Quickshell.stateDir) par défaut, ou dans celui que nomme la variable DUNEI_ETAT_DIR (posée par
// les essais, pour qu'une coque d'essai n'écrive jamais dans l'état de la session).
// Sorties : noms, les noms des réseaux vus facturés ; vu, le nom du réseau Wi-Fi joint s'il est facturé, vide sinon.
// Fonction : retenir.
// Erreurs : aucune ; un fichier absent ou illisible donne une mémoire vide, et il est créé à la première écriture.
// Dépendances : Quickshell (Scope, env, stateDir), Quickshell.Io (FileView, JsonAdapter).
Scope {
    id: memoire

    property var etat: null
    property string chemin: (Quickshell.env("DUNEI_ETAT_DIR") || Quickshell.stateDir) + "/reseau.json"
    readonly property var noms: adaptateur.factures
    // Le lien facturé est celui de l'appareil lu : le Wi-Fi, sauf quand un câble est branché.
    readonly property string vu: etat?.facture && !etat.filaire ? etat.nomActif ?? "" : ""

    // retenir — ajoute un nom à la mémoire, qui est écrite aussitôt. Entrée : nom, le nom du réseau. Sortie : aucune.
    // Erreurs : aucune ; un nom vide ou déjà retenu ne change rien. Dépendances : adaptateur.
    function retenir(nom) { if (nom !== "" && !noms.includes(nom)) adaptateur.factures = noms.concat(nom) }

    onVuChanged: retenir(vu)
    Component.onCompleted: retenir(vu)

    FileView {
        path: memoire.chemin
        printErrors: false
        // La lecture est attendue : un réseau vu facturé dès le démarrage s'ajoute à la mémoire lue, sans l'écraser.
        blockLoading: true
        onAdapterUpdated: writeAdapter()
        JsonAdapter {
            id: adaptateur
            property list<string> factures: []
        }
    }
}
