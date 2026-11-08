import QtQuick
import Quickshell
import Quickshell.Io
import "Energie"
import "Energie/energie.js" as Logique

// Coque d'essai de la logique de l'énergie, sans aucune fenêtre.
// Rôle : expose par IPC (cible « energie ») les fonctions pures de energie.js, et (cible « suivi ») un SuiviEnergie
// branché sur un appareil et des profils simulés, plus (cible « reel ») un SuiviEnergie branché sur UPower et le démon
// de profils réels, pour que tests/test_energie.py les éprouve dans un vrai Quickshell.
// Entrées : commande IPC energie appeler <fonction> <{"args": [...]} en JSON> ; suivi fixer <ready> <portable> <pourcent>
// <state> <secondes> ; suivi lire ; suivi choisir <profil> ; reel choisir <profil> ; reel lire.
// Sorties : le résultat encodé en JSON, ou « erreur : <message> » si la fonction lève ; le suivi journalise
// « annonce <palier> » et « effacer » ; lire rend un objet JSON. Erreurs : nom de fonction inconnu, JSON invalide (même
// forme de retour). Dépendances : quickshell ≥ 0.3 (Quickshell.Io), energie.js et SuiviEnergie.qml (liens dans essai/Energie/, et Theme dans essai/,
// car Quickshell ne suit pas les imports hors du dossier de la coque).
ShellRoot {
    Component.onCompleted: console.log("energie : prêt")

    // Appareil et profils simulés : mêmes propriétés que UPowerDevice et PowerProfiles.
    QtObject {
        id: faux
        // État initial réglable par ESSAI_READY (« 1 »), ESSAI_FRACTION (réel de 0 à 1) et ESSAI_STATE (UPowerDeviceState),
        // pour éprouver le démarrage d'une coque dont l'appareil est déjà prêt.
        property bool ready: Quickshell.env("ESSAI_READY") === "1"
        property bool isLaptopBattery: true
        property real percentage: Number(Quickshell.env("ESSAI_FRACTION") ?? 0)
        property int state: Number(Quickshell.env("ESSAI_STATE") ?? 2)
        property real timeToEmpty: 0
        property real timeToFull: 0
    }
    QtObject {
        id: fauxProfils
        property int profile: 1
        property bool hasPerformanceProfile: false
    }

    SuiviEnergie {
        id: suivi
        appareil: faux
        profils: fauxProfils
        onAnnoncer: palier => console.log("energie : annonce " + palier)
        onEffacer: console.log("energie : effacer")
    }

    SuiviEnergie { id: reel }

    IpcHandler {
        target: "energie"

        // appeler — appelle une fonction exportée de energie.js.
        // Entrées : fonction, son nom ; argumentsJson, un objet JSON {"args": [...]}.
        // Sortie : le résultat en JSON, ou « erreur : <message> ». Erreurs : voir ci-dessus. Dépendances : Logique (energie.js).
        function appeler(fonction: string, argumentsJson: string): string {
            try {
                return JSON.stringify(Logique[fonction](...JSON.parse(argumentsJson).args))
            } catch (e) {
                return "erreur : " + e.message
            }
        }
    }

    IpcHandler {
        target: "suivi"

        // fixer — remplace d'un coup l'état de l'appareil simulé.
        // Entrées : ready, portable (« true » ou « false »), fraction (réel de 0 à 1, comme UPower), state (UPowerDeviceState), secondes (estimation,
        // pour la décharge comme pour la charge). Sortie : aucune. Erreurs : aucune. Dépendances : faux.
        function fixer(ready: bool, portable: bool, fraction: real, state: int, secondes: real): void {
            faux.isLaptopBattery = portable
            faux.percentage = fraction
            faux.state = state
            faux.timeToEmpty = secondes
            faux.timeToFull = secondes
            faux.ready = ready
        }

        // dossier — dossier où le suivi simulé cherche energie.json. Entrées : aucune. Sortie : son chemin. Erreurs : aucune.
        function dossier(): string { return suivi.dir }

        // permettre — autorise ou non le profil Performance du démon simulé. Entrée : oui. Sortie : aucune.
        function permettre(oui: bool): void { fauxProfils.hasPerformanceProfile = oui }

        // choisir — appelle choisirProfil du suivi simulé. Entrée : profil. Sortie : aucune. Erreurs : aucune.
        function choisir(profil: int): void { suivi.choisirProfil(profil) }

        // lire — état courant du suivi simulé. Entrées : aucune. Sortie : objet JSON des propriétés lues par les
        // consommateurs, profil du démon simulé compris. Erreurs : aucune.
        function lire(): string {
            return JSON.stringify({ presente: suivi.presente, pourcent: suivi.pourcent, etat: suivi.etat,
                estimation: suivi.estimation, palier: suivi.palierCourant, profil: suivi.profil,
                faible: suivi.seuilFaible, critique: suivi.seuilCritique })
        }
    }

    IpcHandler {
        target: "reel"

        // choisir — appelle choisirProfil du suivi réel. Entrée : profil. Sortie : aucune. Erreurs : aucune.
        function choisir(profil: int): void { reel.choisirProfil(profil) }

        // lire — profil réel tel que le suivi le lit. Entrées : aucune. Sortie : objet JSON { profil, aProfils,
        // aPerformance, presente, pourcent, etat, estimation, palier }. Erreurs : aucune.
        function lire(): string {
            return JSON.stringify({ profil: reel.profil, aProfils: reel.aProfils, aPerformance: reel.aPerformance,
                presente: reel.presente, pourcent: reel.pourcent, etat: reel.etat, estimation: reel.estimation,
                palier: reel.palierCourant })
        }
    }
}
