import QtQuick
import Quickshell
import Quickshell.Io
import "Theme"
import "Composants"
import "Verrou"

// Coque d'essai du contrôleur du verrou (L2-22), sans calque, sans clavier, sans jamais lire le vrai compositeur.
// Rôle : charge le singleton Verrou, fenêtres, verrou de session et clavier désactivés comme pour l'autorisation, et
// remplace sa lecture de l'état du compositeur par une commande echo (session tenue par défaut), sa recherche d'un
// lanceur par false (aucun lanceur) et le dossier de ses piles PAM par DUNEI_ESSAI_PAM (pile « echec » par défaut ;
// jamais /etc/pam.d). tests/test_verrou.py (ControleurTest) la pilote par l'IPC « verrou » du singleton, comme le
// lanceur, et par l'IPC « essai ». Elle trace la position et l'opacité du bloc à chaque changement, et l'instant
// (Date.now, en ms) de la pose, de la demande du verrou, du retrait du contenu et du verrou rendu.
// Entrées : DUNEI_TOKENS_DIR, DUNEI_ETAT_DIR et DUNEI_ESSAI_PAM ; IPC « essai » : pret, lecture, lanceur, recherche,
// position, reduit, demarrer, ouvrir, ouverts, mesure, montres, trace, pile, taper, entree, dessiner, dessinAuto,
// attendre, refuser, reagir, ecrans.
// Sorties : « essai : prêt » au démarrage. Erreurs : celles de Theme et de Verrou, dans le journal.
// Dépendances : quickshell ≥ 0.3 (IpcHandler), Verrou, Overlays, Theme ; liens essai/fenetre/ vers les modules de la
// coque, car Quickshell ne suit pas les imports hors du dossier de la coque.
ShellRoot {
    id: essai

    property var positions: []
    property int opacitesIntermediaires: 0
    // Suite des valeurs prises par Verrou.montre, chacune avec l'état actif au même instant.
    property var montres: []
    // Instants de la pose, de la demande du verrou, du retrait du contenu et du verrou rendu ; dessin simulé à la pose.
    property double tPose: 0
    property double tVoulu: 0
    property double tVuFaux: 0
    property double tVouluFaux: 0
    property bool dessinAuto: false
    // Réaction enchaînée dans la coque, sans latence d'IPC : « remonterALaPose », « tomberALaRemontee »,
    // « reprendreAuSucces », ou vide.
    property string reaction: ""

    // Component.onCompleted — retire calques, verrou de session et clavier, pose une lecture « session tenue » et les
    // piles factices (un dossier inexistant si DUNEI_ESSAI_PAM manque), signale la coque prête.
    // Entrées : aucune. Sortie : la ligne « essai : prêt ». Erreurs : aucune. Dépendances : Verrou.
    Component.onCompleted: {
        Verrou.fenetree = false
        Verrou.saisie.dossierPile = Quickshell.env("DUNEI_ESSAI_PAM") || "/nonexistent/dunei-essai-pam"
        Verrou.saisie.pile = "echec"
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
        // Instants du déroulé ; à la pose, le dessin simulé de chaque écran si dessinAuto. Entrées : aucune.
        function onPoseChanged() {
            if (!Verrou.pose) return
            essai.tPose = Date.now()
            if (essai.dessinAuto) for (const e of Quickshell.screens) Verrou.dessine(e.name)
            if (essai.reaction === "remonterALaPose") Qt.callLater(() => Verrou.remonter(Verrou.ordre))
        }
        // Réaction au départ de la remontée : la session est retenue et un nouveau verrou tombe pendant le retrait,
        // au tour de boucle suivant, comme une IPC (jamais au milieu de relever).
        function onRemonteChanged() {
            if (!Verrou.remonte || essai.reaction !== "tomberALaRemontee") return
            Qt.callLater(() => {
                Verrou.lecture = ["echo", "{\"locked\": true}"]
                Verrou.tomber(Verrou.ordre + 1)
            })
        }
        function onVouluChanged() { if (Verrou.voulu) essai.tVoulu = Date.now(); else essai.tVouluFaux = Date.now() }
        function onVuChanged() { if (!Verrou.vu) essai.tVuFaux = Date.now() }
    }

    // Faux popover exclusif et fausse attention, pour l'essai de fermeture.
    QtObject {
        id: popover
        property string famille: "contextuel"
        property bool exclusif: true
        property bool ouvert: false
    }
    QtObject { id: attention; property string famille: "attention"; property bool ouvert: false }

    Connections {
        target: Verrou.saisie
        // Réaction au succès de PAM : verrou perdu, remontée, puis nouveau verrou sec, le tout avant verrouRetrait.
        // Entrées : aucune. Sortie : aucune. Dépendances : Verrou.
        function onReussi() {
            if (essai.reaction !== "reprendreAuSucces") return
            Qt.callLater(() => {
                Verrou.refuserEssai = true
                Verrou.remonter(Verrou.ordre)
                Verrou.refuserEssai = false
                Verrou.poserSec(Verrou.ordre + 1)
            })
        }
    }

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
                                    voulu: Verrou.voulu, tient: Verrou.tient, anime: Verrou.anime,
                                    points: Verrou.saisie.points, message: Verrou.saisie.message,
                                    verifie: Verrou.saisie.verifie,
                                    tPose: essai.tPose, tVoulu: essai.tVoulu, tVuFaux: essai.tVuFaux,
                                    tVouluFaux: essai.tVouluFaux })
        }

        // pile — choisit la pile PAM factice de la saisie. Entrée : nom.
        function pile(nom: string): void { Verrou.saisie.pile = nom }

        // taper — frappe chaque caractère du texte dans la saisie du verrou. Entrée : texte.
        function taper(texte: string): void { for (const c of Array.from(texte)) Verrou.saisie.touche(0, c) }

        // entree — frappe Entrée dans la saisie du verrou. Entrées : aucune.
        function entree(): void { Verrou.saisie.touche(Qt.Key_Return, "\r") }

        // dessiner — simule une image posée par le bloc d'un écran. Entrée : nom de l'écran.
        function dessiner(nom: string): void { Verrou.dessine(nom) }

        // dessinAuto — chaque écran dessine dès la pose. Entrée : oui.
        function dessinAuto(oui: bool): void { essai.dessinAuto = oui }

        // attendre — mode d'essai attendreImages du relais. Entrée : oui.
        function attendre(oui: bool): void { Verrou.attendreImages = oui }

        // refuser — mode d'essai refuserEssai : le verrou demandé n'est jamais tenu. Entrée : oui.
        function refuser(oui: bool): void { Verrou.refuserEssai = oui }

        // reagir — choisit la réaction enchaînée dans la coque (voir reaction). Entrée : nom, ou vide.
        function reagir(nom: string): void { essai.reaction = nom }

        // ecrans — nombre d'écrans de Quickshell.screens. Sortie : texte.
        function ecrans(): string { return String(Quickshell.screens.length) }

        // montres — suite des [montre, actif] vus à chaque changement de montre, en JSON.
        function montres(): string { return JSON.stringify(essai.montres) }

        // trace — positions distinctes et nombre d'opacités intermédiaires vues depuis le dernier reduit(), en JSON.
        function trace(): string {
            return JSON.stringify({ positions: essai.positions, opacitesIntermediaires: essai.opacitesIntermediaires })
        }
    }
}
