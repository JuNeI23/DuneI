import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import "Reseau"

// Coque d'essai de la Jonction, sans fenêtre.
// Rôle : pose une Jonction seule sur un état et des réseaux factices, pour que tests/test_reseau.py (JonctionTest)
// éprouve sa logique sans passer par une vue : aucune action ne touche le réseau réel. Les réseaux factices
// journalisent leurs appels (connect, disconnect, connectWithPsk avec la seule longueur du mot de passe).
// Entrées : aucune (la Jonction ne lit aucun jeton). Sortie : « essai : prêt » au chargement, puis les lignes
// « essai : connect <nom> », « essai : disconnect <nom> » et « essai : connectWithPsk <nom> <longueur> ».
// Commandes : voir chaque fonction de l'IpcHandler (cible « jonction »).
// Erreurs : celles des liaisons, dans le journal. Dépendances : quickshell ≥ 0.3 (IpcHandler),
// Quickshell.Networking (énumérations), module Reseau (Jonction), par les liens Theme, Composants, Reseau et Barre
// posés sous cette racine.
ShellRoot {
    id: essai

    // journal — écrit une ligne lisible par le test. Entrées : cle, valeur. Sortie : aucune. Erreurs : aucune.
    function journal(cle, valeur) { console.info("essai : " + cle + " " + valeur) }

    // Réseau factice : les membres de WifiNetwork que lit la Jonction.
    component FauxReseau: QtObject {
        property string name
        property bool connected: false
        property bool known: false
        property int security: WifiSecurityType.Wpa2Psk
        signal connectionFailed(int reason)
        function connect() { essai.journal("connect", name) }
        function disconnect() { essai.journal("disconnect", name) }
        function connectWithPsk(psk) { essai.journal("connectWithPsk", name + " " + psk.length) }
    }

    // État factice : la seule propriété de EtatReseau que lit la Jonction.
    QtObject {
        id: faux
        property list<QtObject> reseaux: [
            FauxReseau { name: "Joint"; connected: true; known: true },
            FauxReseau { name: "Connu"; known: true },
            FauxReseau { name: "Voisin"; known: true },
            FauxReseau { name: "Inconnu" },
            FauxReseau { name: "Ouvert"; security: WifiSecurityType.Open }
        ]
    }

    // Noms reçus par le signal joint, et nombre de signaux refuse, dans l'ordre de leur émission.
    property var joints: []
    property int refus: 0

    Jonction { id: jonction; etat: faux }
    Connections {
        target: jonction
        function onJoint(r) { essai.joints = essai.joints.concat([r.name]) }
        function onRefuse() { essai.refus++ }
    }

    Component.onCompleted: journal("prêt", true)

    IpcHandler {
        target: "jonction"

        // reseau — réseau factice par son nom. Entrée : nom. Sortie : l'objet, ou undefined. Erreurs : aucune.
        function reseau(nom) { return Array.from(faux.reseaux).find(r => r.name === nom) }

        // etat — état de la Jonction, en JSON : {deplie, erreur, enCours (nom du réseau suivi, vide sans lui), fige,
        // joints (noms reçus par joint), refus (nombre de refuse)}. Entrées : aucune. Sortie : texte JSON.
        // Erreurs : aucune. Dépendances : jonction.
        function etat(): string {
            return JSON.stringify({ deplie: jonction.deplie, erreur: jonction.erreur, enCours: jonction.enCours?.name ?? "",
                                    fige: jonction.fige, joints: essai.joints, refus: essai.refus })
        }
        // choisir — clic sur le réseau nommé, puis état de la Jonction. Entrée : nom. Sortie : voir etat.
        function choisir(nom: string): string { jonction.choisir(reseau(nom)); return etat() }
        // rejoindre — valide le mot de passe de la rangée dépliée, puis état de la Jonction. Entrée : secret.
        // Sortie : voir etat.
        function rejoindre(secret: string): string { jonction.rejoindre(secret); return etat() }
        // echouer — émet connectionFailed sur le réseau nommé, puis état de la Jonction. Entrées : nom ; raison, le
        // nom d'une valeur de ConnectionFailReason. Sortie : voir etat.
        function echouer(nom: string, raison: string): string {
            reseau(nom).connectionFailed(ConnectionFailReason[raison])
            return etat()
        }
        // joindre — la connexion au réseau nommé réussit : il devient le réseau joint (et connu), l'ancien ne l'est
        // plus, comme le rapporte Quickshell. Entrée : nom. Sortie : voir etat.
        function joindre(nom: string): string {
            Array.from(faux.reseaux).forEach(r => r.connected = false)
            const r = reseau(nom)
            r.known = true
            r.connected = true
            return etat()
        }
    }
}
