import QtQuick
import Quickshell
import Quickshell.Io
import "nmcli.js" as Nmcli
import "Barre"
import "Reseau"

// Coque d'essai du module Reseau, sans aucune fenêtre.
// Rôle : expose par IPC (cible « reseau ») les fonctions pures de nmcli.js, et le singleton EtatReseau (cible
// « etat »), avec les indicateurs Wifi et Vpn de la barre qui le lisent, pour que tests/test_reseau.py les
// éprouve dans un vrai Quickshell.
// Entrées : commande IPC appeler <fonction> <{"args": [...]} en JSON>. Sortie : le résultat encodé en JSON, ou
// « erreur : <message> » si la fonction lève. Erreurs : nom de fonction inconnu, JSON invalide (même forme de
// retour). Dépendances : quickshell ≥ 0.3 (Quickshell.Io), nmcli.js (lien essai/nmcli.js, car Quickshell ne
// suit pas les imports hors du dossier de la coque ; liens essai/Barre et essai/Reseau pour la même raison).
ShellRoot {
    Component.onCompleted: console.log("reseau : prêt")

    // Les deux lecteurs de EtatReseau : un seul moniteur doit tourner quand ils sont tous deux instanciés.
    Item {
        Wifi { id: wifi }
        Vpn { id: vpn }
    }

    // Réactive EtatReseau peu après son arrêt : le moniteur réel, tué par l'arrêt, ne doit pas se voir relancé
    // par sa sortie tardive sur l'état « actif » déjà rétabli.
    Timer {
        id: reprise
        interval: 300
        onTriggered: EtatReseau.actif = true
    }

    IpcHandler {
        target: "etat"

        // injecter — remplace le moniteur et la lecture de EtatReseau par « sh -c » et les redémarre.
        // Entrées : commande (moniteur), lecture. Sortie : aucune. Erreurs : aucune. Dépendances : EtatReseau.
        function injecter(commande: string, lecture: string): void {
            EtatReseau.actif = false; EtatReseau.relances = 0
            EtatReseau.surveille = ["sh", "-c", commande]; EtatReseau.lecture = ["sh", "-c", lecture]
            reprise.start()
        }

        // valeur — propriété de EtatReseau, en JSON. Entrée : nom. Sortie : JSON. Erreurs : nom inconnu, « null ».
        // Dépendances : EtatReseau.
        function valeur(nom: string): string { return JSON.stringify(EtatReseau[nom] ?? null) }

        // visibles — visibilité de Wifi et de Vpn, « wifi;vpn ». Sortie : texte. Dépendances : wifi, vpn.
        function visibles(): string { return `${wifi.visible};${vpn.visible}` }

        // executer — lance EtatReseau.executer et attend la fin par le journal.
        // Entrées : args, JSON {"args": [...]} ; mode, « sans » (fin réellement
        // undefined), « leve » (fin qui lève) ou autre. Sortie : aucune ; journalise « etat : fin <code> <sortie> ».
        // Erreurs : JSON invalide. Dépendances : EtatReseau.
        function executer(argumentsJson: string, mode: string): void {
            const args = JSON.parse(argumentsJson).args
            if (mode === "sans") EtatReseau.executer(args, undefined)
            else if (mode === "leve") EtatReseau.executer(args, () => { throw new Error("fin factice") })
            else EtatReseau.executer(args, (code, sortie) => console.log("etat : fin " + code + " " + sortie.split("\n")[0]))
        }
    }

    IpcHandler {
        target: "reseau"

        // appeler — appelle une fonction exportée de nmcli.js.
        // Entrées : fonction, son nom ; argumentsJson, un objet JSON {"args": [...]} (un tableau nu serait
        // déformé par la ligne de commande de qs ipc).
        // Sortie : le résultat en JSON, ou « erreur : <message> ». Erreurs : voir ci-dessus.
        // Dépendances : Nmcli.
        function appeler(fonction: string, argumentsJson: string): string {
            try {
                return JSON.stringify(Nmcli[fonction](...JSON.parse(argumentsJson).args))
            } catch (e) {
                return "erreur : " + e.message
            }
        }
    }
}
