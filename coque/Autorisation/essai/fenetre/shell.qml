//@ pragma IconTheme DuneI
//@ pragma Env QSG_DISTANCEFIELD_ANTIALIASING=gray
import QtQuick
import Quickshell
import Quickshell.Io
import "Theme"
import "Composants"
import "Autorisation"

// Coque d'essai de l'agent d'authentification (L2-24), sans jamais toucher polkit, PAM ni faillock, ni prendre le
// clavier.
// Rôle : charge le singleton Autorisation, lui donne de faux flux (objets QtObject aux propriétés, signaux et fonctions
// d'AuthFlow) et un faux lecteur de faillock ; les flux retiennent en mémoire leurs appels à submit et à
// cancelAuthenticationRequest, jamais le texte au journal. tests/test_autorisation.py (ControleurTest, CadreTest) la
// pilote ; elle sert aussi aux captures. Elle sert la cible « notifications », dont l'état « ne pas déranger » vaut
// toujours « true ».
// Entrées : DUNEI_TOKENS_DIR et DUNEI_ETAT_DIR ; IPC « essai » : pret, fenetree, lire, demander, poser, emettre, appels,
// soumettre, annuler, frapper, voiler, attention.
// Sorties : « essai : prêt » au démarrage. Erreurs : celles de Theme et d'Autorisation, dans le journal.
// Dépendances : quickshell ≥ 0.3 (IpcHandler), Autorisation, Overlays, Theme ; liens essai/fenetre/ vers les modules de
// la coque, car Quickshell ne suit pas les imports hors du dossier de la coque.
ShellRoot {
    id: essai

    property var flux: []
    property int vides: 0

    // Component.onCompleted — retire le clavier et la fenêtre, pose un relevé vide, signale que la coque est prête.
    // Entrées : aucune. Sortie : la ligne « essai : prêt ». Erreurs : aucune. Dépendances : Autorisation.
    Component.onCompleted: {
        Autorisation.clavierExclusif = false
        Autorisation.fenetree = false
        Autorisation.lecteur = () => ({ faillock: "", conf: "" })
        console.log("essai : prêt")
    }

    // Faux AuthFlow : mêmes noms ; appels retient [fonction, texte éventuel].
    Component {
        id: faux
        QtObject {
            property string message
            property string actionId
            property var identities: []
            property var selectedIdentity: null
            property bool isResponseRequired: false
            property bool responseVisible: false
            property string inputPrompt: "Password: "
            property string supplementaryMessage: ""
            property bool supplementaryIsError: false
            property bool isCompleted: false
            property bool isSuccessful: false
            property bool isCancelled: false
            property bool failed: false
            property var appels: []
            signal authenticationSucceeded()
            signal authenticationFailed()
            signal authenticationRequestCancelled()
            // submit, cancelAuthenticationRequest — retiennent l'appel. Entrée : texte, la réponse. Sortie : appels.
            function submit(texte) { appels = appels.concat([["submit", texte]]); isResponseRequired = false }
            function cancelAuthenticationRequest() { appels = appels.concat([["annuler"]]); isCancelled = true; isCompleted = true }
        }
    }

    // Autre attention, pour l'essai du registre.
    QtObject {
        id: autre
        property string famille: "attention"
        property bool ouvert: false
    }

    Connections {
        target: Autorisation
        // onVider — compte les vidages du champ. Entrées : aucune. Sortie : vides.
        function onVider() { essai.vides++ }
    }

    // Frappe continue, un appui toutes les 100 ms.
    Timer { id: frappes; interval: 100; repeat: true; triggeredOnStart: true; onTriggered: Autorisation.frappe() }

    IpcHandler {
        target: "essai"

        // pret — vrai une fois les jetons et le mouvement chargés. Sortie : « true » ou « false ».
        function pret(): string { return String(Theme.ready && Theme.motion !== null) }

        // fenetree — construit ou non la fenêtre. Entrée : oui. Sortie : aucune.
        function fenetree(oui: bool): void { Autorisation.fenetree = oui }

        // lire — pose le faux lecteur. Entrée : json, {faillock, conf} ; « leve » fait lever le lecteur. Sortie : aucune.
        function lire(json: string): void {
            const r = json === "leve" ? null : JSON.parse(json)
            Autorisation.lecteur = () => { if (!r) throw new Error("illisible"); return r }
        }

        // demander — crée un faux flux, réponse attendue, et le remet au contrôleur. Entrée : json, propriétés.
        // Sortie : son rang.
        function demander(json: string): string {
            const f = faux.createObject(essai, Object.assign({ message: "Message", actionId: "org.dunei.essai",
                                                               isResponseRequired: true }, JSON.parse(json)))
            essai.flux = essai.flux.concat([f])
            Autorisation.surFlux(f)
            return String(essai.flux.length - 1)
        }

        // clore — fait passer le flux courant à null, comme l'agent. Entrées : aucune. Sortie : aucune.
        function clore(): void { Autorisation.surFlux(null) }

        // poser — écrit des propriétés d'un flux. Entrées : i, son rang ; json, propriétés. Sortie : aucune.
        function poser(i: int, json: string): void {
            const p = JSON.parse(json)
            for (const k in p) essai.flux[i][k] = p[k]
        }

        // emettre — émet un signal d'un flux. Entrées : i, son rang ; nom, le signal. Sortie : aucune.
        function emettre(i: int, nom: string): void { essai.flux[i][nom]() }

        // appels — appels reçus par un flux et vidages du champ. Entrée : i, son rang. Sortie : JSON {appels, vides}.
        function appels(i: int): string { return JSON.stringify({ appels: essai.flux[i].appels, vides: essai.vides }) }

        // identite — identité retenue par un flux. Entrée : i, son rang. Sortie : JSON.
        function identite(i: int): string { return JSON.stringify(essai.flux[i].selectedIdentity) }

        // soumettre, annuler, frapper — appellent le contrôleur ; frapper répète une touche toutes les 100 ms.
        // Entrées : texte factice ; oui. Sortie : aucune.
        function soumettre(texte: string): void { Autorisation.soumettre(texte) }
        function annuler(): void { Autorisation.annuler() }
        function frapper(oui: bool): void { frappes.running = oui }

        // cadre — ce que montre le cadre. Entrées : aucune. Sortie : JSON, ou « null » sans cadre : titre, message et son
        // format, action, ligne peinte, longueur du champ (jamais son texte), champ actif, autoriser et annuler
        // (visibles et actifs), fermer (visible), activite (visible), hauteur, écran, bas des boutons, y du cadre.
        function cadre(): string {
            const c = Autorisation.fenetre?.cadre
            if (!c) return "null"
            return JSON.stringify({ titre: c.titre.text, message: c.message.text, brut: c.message.textFormat === Text.PlainText,
                action: c.action.text, ligne: c.ligne.text, longueur: c.champ.length, champ: c.champ.enabled,
                autoriser: [c.autoriser.visible, c.autoriser.enabled], annuler: [c.annuler.visible, c.annuler.enabled],
                fermer: c.fermer.visible, activite: c.activite.visible, hauteur: c.height, largeur: c.width,
                ecran: Autorisation.fenetre.height, y: c.parent.y,
                bas: c.autoriser.mapToItem(c, 0, c.autoriser.height).y })
        }

        // taper, entree, touche — écrit le texte factice dans le champ, valide le champ, presse une touche du cadre.
        // Entrées : texte ; nom, « escape » ou une autre. Sortie : aucune.
        function taper(texte: string): void { Autorisation.fenetre.cadre.champ.text = texte }
        function entree(): void { Autorisation.fenetre.cadre.champ.accepted() }
        function touche(nom: string): void { Autorisation.fenetre.cadre.touche(nom) }

        // cliquer — clique un bouton. Entrée : nom, « autoriser », « annuler » ou « fermer ». Sortie : aucune.
        function cliquer(nom: string): void { const b = Autorisation.fenetre.cadre[nom]; if (b.enabled) b.clicked() }

        // voile — clic simulé au coin de la fenêtre. Entrées : aucune. Sortie : aucune.
        function voile(): void { Autorisation.fenetre.cliquerVoile(1, 1) }

        // attention — ouvre une autre attention, qui ferme celle de l'agent. Sortie : aucune.
        function attention(): void { autre.ouvert = true; Overlays.ouvrir(autre) }
    }

    IpcHandler {
        target: "notifications"

        // nePasDeranger — faux état de « ne pas déranger ». Sortie : « true ».
        function nePasDeranger(): string { return "true" }
    }
}
