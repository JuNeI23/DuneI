import QtQuick
import Quickshell
import Quickshell.Io
import "Theme"
import "Composants"
import "Verrou"

// Coque d'essai du contrôleur du verrou (L2-22), sans calque, sans clavier, sans jamais lire le vrai compositeur.
// Rôle : charge le singleton Verrou, fenêtres et clavier désactivés comme pour l'autorisation, et remplace sa lecture
// de l'état du compositeur par une commande echo (session tenue par défaut) et sa recherche d'un lanceur par false
// (aucun lanceur). tests/test_verrou.py (ControleurTest) la pilote par l'IPC « verrou » du singleton, comme le
// lanceur, et par l'IPC « essai ». Elle trace la position et l'opacité du bloc à chaque changement.
// Entrées : DUNEI_TOKENS_DIR et DUNEI_ETAT_DIR ; IPC « essai » : pret, lecture, lanceur, recherche, position,
// reduit, demarrer, ouvrir, ouverts, mesure, montres, trace.
// Sorties : « essai : prêt » au démarrage. Erreurs : celles de Theme et de Verrou, dans le journal.
// Dépendances : quickshell ≥ 0.3 (IpcHandler), Verrou, Overlays, Theme ; liens essai/fenetre/ vers les modules de la
// coque, car Quickshell ne suit pas les imports hors du dossier de la coque.
ShellRoot {
    id: essai

    property var positions: []
    property int opacitesIntermediaires: 0
    // Suite des valeurs prises par Verrou.montre, chacune avec l'état actif au même instant.
    property var montres: []

    // Component.onCompleted — retire calques et clavier, pose une lecture « session tenue », signale la coque prête.
    // Entrées : aucune. Sortie : la ligne « essai : prêt ». Erreurs : aucune. Dépendances : Verrou.
    Component.onCompleted: {
        Verrou.fenetree = false
        Verrou.clavierExclusif = false
        Verrou.lecture = ["echo", "{\"locked\": true}"]
        Verrou.presence = ["false"]
        console.log("essai : prêt")
    }

    Connections {
        target: Verrou
        // Trace du mouvement : positions distinctes, opacités strictement entre 0 et 1. Entrées : aucune.
        function onPositionChanged() {
            if (!essai.positions.includes(Verrou.position)) essai.positions = essai.positions.concat([Verrou.position])
        }
        function onOpaciteChanged() { if (Verrou.opacite > 0 && Verrou.opacite < 1) essai.opacitesIntermediaires++ }
        // Trace du mappage du bloc : chaque changement de montre, avec actif. Entrées : aucune.
        function onMontreChanged() { essai.montres = essai.montres.concat([[Verrou.montre, Verrou.actif]]) }
    }

    // Faux popover exclusif et fausse attention, pour l'essai de fermeture.
    QtObject {
        id: popover
        property string famille: "contextuel"
        property bool exclusif: true
        property bool ouvert: false
    }
    QtObject { id: attention; property string famille: "attention"; property bool ouvert: false }

    IpcHandler {
        target: "essai"

        // pret — vrai une fois les jetons et le mouvement chargés. Sortie : « true » ou « false ».
        function pret(): string { return String(Theme.ready && Theme.motion !== null) }

        // lecture — état que rendra la fausse lecture du compositeur. Entrée : locked, « true » ou « false ».
        function lecture(locked: string): void { Verrou.lecture = ["echo", "{\"locked\": " + locked + "}"] }

        // lanceur — fait passer un lanceur pour vivant ou non. Entrée : oui.
        function lanceur(oui: bool): void { Verrou.presence = [oui ? "true" : "false"] }

        // recherche — la recherche d'un lanceur sort avec le code donné (124 : délai dépassé). Entrée : code.
        function recherche(code: int): void { Verrou.presence = ["sh", "-c", "exit " + code] }

        // position — position courante du bloc (1 posé, 0 caché). Sortie : texte.
        function position(): string { return String(Verrou.position) }

        // reduit — préférence de mouvement réduit ; vide la trace. Entrée : oui.
        function reduit(oui: bool): void {
            Theme.mouvementReduit = oui
            essai.positions = []
            essai.opacitesIntermediaires = 0
        }

        // demarrer — démarrage de la coque de session. Entrées : aucune.
        function demarrer(): void { Verrou.demarrer() }

        // ouvrir — ouvre le faux popover et la fausse attention dans le registre. Entrées : aucune.
        function ouvrir(): void {
            popover.ouvert = true
            attention.ouvert = true
            Overlays.ouvrir(popover)
            Overlays.ouvrir(attention)
        }

        // ouverts — [popover ouvert, attention ouverte], en JSON.
        function ouverts(): string { return JSON.stringify([popover.ouvert, attention.ouvert]) }

        // mesure — état interne du contrôleur, en JSON.
        function mesure(): string {
            return JSON.stringify({ position: Verrou.position, opacite: Verrou.opacite, verrou: Overlays.verrou,
                                    montre: Verrou.montre, clavier: Verrou.clavier, vu: Verrou.vu,
                                    contenuBloc: Verrou.contenuBloc })
        }

        // montres — suite des [montre, actif] vus à chaque changement de montre, en JSON.
        function montres(): string { return JSON.stringify(essai.montres) }

        // trace — positions distinctes et nombre d'opacités intermédiaires vues depuis le dernier reduit(), en JSON.
        function trace(): string {
            return JSON.stringify({ positions: essai.positions, opacitesIntermediaires: essai.opacitesIntermediaires })
        }
    }
}
