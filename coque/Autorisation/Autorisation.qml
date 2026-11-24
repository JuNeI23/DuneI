pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../Composants" as C
import "../Theme"
import "autorisation.js" as Logique

// Autorisation — contrôleur unique de l'agent d'authentification (L2-24) : demande en cours, saisie, état et IPC.
// Rôle : reçoit un flux (AuthFlow de Quickshell, ou un faux flux d'essai) par surFlux, ouvre une Scene (famille
// « attention » du registre Overlays), tient la garde de frappe, transmet la réponse et annule. Toute fermeture d'une
// demande en cours vaut annulation ; une demande close par polkit ferme sans annuler. flux repasse à null avant l'appel
// d'annulation : celui-ci ne part donc qu'une fois, et jamais après une demande close. Une seconde demande remplace la
// première, qui est laissée : l'annuler fermerait la seconde (essai réel 2a). Le mot de passe ne fait que passer de
// soumettre à flux.submit : il n'est ni retenu, ni journalisé, ni rendu par l'IPC.
// Entrées : surFlux(f) ; lecteur, null par défaut : une fonction qui rend {faillock, conf}, à la place de la commande
//           faillock et de faillock.conf (coques d'essai) ; clavierExclusif et fenetree, vrais par défaut, transmis à la
//           scène ; marche (autorisation.active), regle, fabrique, reprises et avertir, remplacés par les essais.
//           demarrer() charge l'agent réel : la coque de session seule l'appelle. IPC « autorisation » : etat.
// Sorties : flux (null au repos) ; ouvert ; etat (voir Logique.etat ; garde sa dernière valeur pendant la sortie de la
//           fenêtre) ; message, action (textes reçus, à peindre en texte brut) ; ligne ({texte, erreur}) ; saisieOuverte
//           (état saisie et garde écoulée) ; fenetre ; ecran ; prendClavier ; frappe(), soumettre(texte), annuler() ; signal vider(), émis quand
//           le champ doit se vider.
// Erreurs : règle PAM absente ou agent non enregistré après trois reprises : journal, puis une notification ; faillock ou faillock.conf absents ou illisibles laissent le champ ouvert, sans essais restants : PAM décide.
// Dépendances : Quickshell (Singleton), Quickshell.Io (Process, StdioCollector, FileView, IpcHandler), C.Scene, CadreAutorisation, Theme
//           (motion.delays : gardeFrappe, autorise), C.Overlays (ecranCouvert), autorisation.js.
Singleton {
    id: autorisation

    property var flux: null
    property string etat: "attente"
    property string message: ""
    property string action: ""
    property bool enVol: false
    property bool echec: false
    property var echecs: []
    property var restants: null
    property var jusqua: null
    property string supplement: ""
    // Agent réel (AgentPolkit), construit par demarrer, que seule la coque de session appelle.
    property bool marche: Theme.autorisation?.active ?? false
    property bool demarree: false
    property string regle: "/etc/pam.d/polkit-1"
    property Component fabrique: null
    property var reprises: [2000, 10000, 60000]
    property var avertir: () => Quickshell.execDetached(["notify-send", "-a", "DuneI", "-i", "system-lock-screen",
        "Autorisations indisponibles", "La coque n'a pas pu s'enregistrer auprès de polkit."])
    property var agent: null
    property int tentatives: 0
    property var lecteur: null
    property bool clavierExclusif: true
    property bool fenetree: true
    property alias ouvert: scene.ouvert
    readonly property var fenetre: scene.fenetre
    // Écran de la demande, figé à l'ouverture : il borne la hauteur du cadre.
    readonly property var ecran: scene.ecran
    readonly property bool saisieOuverte: etat === "saisie" && Theme.motion !== null && !garde.running
    readonly property var ligne: Logique.ligne(etat, { echec: echec, restants: restants, jusqua: jusqua, supplement: supplement })
    readonly property string utilisateur: Quickshell.env("USER") ?? ""

    // Le clavier est pris pendant une demande, et rendu dès qu'elle est accordée, avant que l'île ne se replie.
    readonly property bool prendClavier: etat !== "succes"

    signal vider()

    C.Scene {
        id: scene
        cadre: Component { CadreAutorisation {} }
        clavierExclusif: autorisation.clavierExclusif && autorisation.prendClavier
        fenetree: autorisation.fenetree
        montee: false
        grandit: false
        positionner: () => 0
        voileFerme: false
        espace: "dunei-attention-autorisation"

        // onOuvertChanged — toute fermeture d'une demande en cours vaut annulation (autre attention ouverte, fenêtre non
        // construite). Entrées : aucune. Sortie : aucune ; sans flux, rien. Erreurs : aucune. Dépendances : annuler.
        onOuvertChanged: if (!ouvert) { sortie.stop(); autorisation.annuler() }
    }

    // demarrer — construit l'agent si la mise en marche le permet et si la règle PAM de DuneI est posée : sans elle,
    // chaque annulation compterait comme un échec. Appelée par la coque de session, jamais par une coque d'essai avec le
    // vrai agent. Entrées : aucune. Sortie : agent. Erreurs : règle absente : avertissement au journal, rien de chargé.
    // Dépendances : marche, lecteurRegle, construire.
    function demarrer() {
        demarree = true
        if (!marche || agent) return
        // Un FileView neuf à chaque lecture : rechargé, il garderait le texte d'un fichier disparu.
        const pam = lecteurRegle.createObject(autorisation)
        const posee = (pam.text().split("\n")[1] ?? "").includes("Posé par DuneI")
        pam.destroy()
        if (!posee) {
            console.warn("Autorisation : " + regle + " n'est pas la règle de DuneI, agent non chargé (make install)")
            return
        }
        tentatives = 0
        construire()
    }

    // construire — (re)construit l'agent, en lit aussitôt la demande (rechargement de la coque) et arme la vérification
    // de son enregistrement. Entrées : aucune. Sortie : agent. Erreurs : composant illisible : avertissement au journal.
    // Dépendances : fabrique, surFlux, verification.
    function construire() {
        agent?.destroy()
        const c = fabrique ?? Qt.createComponent("AgentPolkit.qml")
        agent = c.createObject(autorisation)
        if (!agent) console.warn("Autorisation : agent non construit. " + c.errorString())
        else surFlux(agent.flux)
        verification.interval = reprises[tentatives] ?? reprises[0]
        verification.restart()
    }

    // verifier — reprend l'enregistrement manqué après chaque délai de reprises, puis le signale une fois.
    // Entrées : aucune. Sortie : agent reconstruit, ou avertissement. Erreurs : aucune. Dépendances : construire, avertir.
    function verifier() {
        if (agent?.enregistre) return
        if (tentatives < reprises.length) { tentatives++; construire() }
        else avertir()
    }

    Timer { id: verification; onTriggered: autorisation.verifier() }
    Component { id: lecteurRegle; FileView { path: autorisation.regle; blockLoading: true; printErrors: false } }

    // retirer — débraye l'agent à chaud : la demande en cours est annulée, l'agent détruit. Entrées : aucune. Sortie :
    // agent null. Erreurs : aucune. Dépendances : annuler, verification.
    function retirer() {
        verification.stop()
        annuler()
        agent?.destroy()
        agent = null
    }

    // onMarcheChanged — les jetons peuvent se charger, ou changer, après demarrer. Entrées : aucune. Sortie : agent
    // construit ou retiré. Erreurs : aucune. Dépendances : demarree, demarrer, retirer.
    onMarcheChanged: if (demarree) marche ? demarrer() : retirer()

    Connections {
        target: autorisation.agent
        ignoreUnknownSignals: true
        // onFluxChanged — la demande de l'agent change. Entrées : aucune. Sortie : voir surFlux.
        function onFluxChanged() { autorisation.surFlux(autorisation.agent.flux) }
    }

    // surFlux — reçoit la demande courante de l'agent. Entrée : f, le flux, ou null quand l'agent n'en a plus.
    // Sortie : fenêtre ouverte, ou reprise en place, sur la nouvelle demande, champ vidé et garde relancée ; null ferme
    // sans annuler. Erreurs : aucune ; le flux déjà courant ou un flux déjà clos ne change rien.
    // Dépendances : choisirIdentite, lire, evaluer, garde, finir.
    function surFlux(f) {
        if (f === flux) return
        if (!f) { finir(false); return }
        if (f.isCompleted) return
        sortie.stop()
        flux = f
        message = f.message
        action = f.actionId
        supplement = f.supplementaryMessage
        enVol = false
        echec = false
        echecs = []
        jusqua = null
        garde.restart()
        vider()
        choisirIdentite()
        lire()
        evaluer()
        ouvert = true
    }

    // choisirIdentite — retient l'utilisateur courant s'il figure dans la liste ; sinon le choix de polkit reste. Écrire
    // une identité relance la conversation PAM : rien n'est écrit si elle est déjà retenue.
    // Entrées : aucune. Sortie : flux.selectedIdentity. Erreurs : aucune. Dépendances : flux, utilisateur.
    function choisirIdentite() {
        const moi = Array.from(flux.identities ?? []).find(i => !i.isGroup && i.string === utilisateur)
        if (moi && flux.selectedIdentity?.string !== moi.string) flux.selectedIdentity = moi
    }

    // evaluer — recalcule l'état de la demande en cours. Entrées : aucune. Sortie : etat ; sans flux, il garde sa
    // dernière valeur pendant la sortie de la fenêtre. Erreurs : aucune. Dépendances : Logique.etat.
    function evaluer() {
        if (flux) etat = Logique.etat({ termine: false, verrouille: jusqua !== null, enVol: enVol, requis: flux.isResponseRequired })
    }

    // frappe — une touche pressée tant que la garde court la relance ; ensuite, taper ne la relance plus.
    // Entrées : aucune. Sortie : garde. Erreurs : aucune. Dépendances : garde.
    function frappe() { if (garde.running) garde.restart() }

    // soumettre — envoie la réponse à PAM. Entrée : texte, la réponse. Sortie : aucune ; le champ est vidé.
    // Erreurs : aucune ; texte vide, garde en cours, compte verrouillé ou réponse non attendue : rien ne part.
    // Dépendances : saisieOuverte, flux.submit, evaluer, vider.
    function soumettre(texte: string) {
        if (!texte || !saisieOuverte || !flux?.isResponseRequired) return
        enVol = true
        supplement = ""
        flux.submit(texte)
        vider()
        evaluer()
    }

    // annuler — annule la demande en cours et ferme. Entrées : aucune. Sortie : aucune. Erreurs : aucune ; sans demande
    // en cours, la fenêtre se ferme seulement. Dépendances : flux.cancelAuthenticationRequest, finir.
    function annuler() {
        const f = flux
        finir(false)
        if (f && !f.isCompleted) f.cancelAuthenticationRequest()
    }

    // finir — oublie la demande et ferme la fenêtre, sans annuler ; accordée, « Autorisé » tient d'abord
    // delays.autorise. Entrée : reussi, vrai si polkit l'a accordée.
    // Sortie : flux null, etat « succes » si reussi, champ vidé, garde arrêtée. Erreurs : aucune. Dépendances : scene.
    function finir(reussi: bool) {
        if (!flux) { ouvert = false; return }
        flux = null
        garde.stop()
        vider()
        if (!reussi) { ouvert = false; return }
        etat = "succes"
        sortie.restart()
    }

    // echouer — un mot de passe refusé : la ligne le dit et le compte est relu ; trois échecs en chaîne annulent, car
    // Quickshell rouvre une conversation PAM à chaque échec, sans plafond. Entrées : aucune. Sortie : echec, echecs.
    // Erreurs : aucune. Dépendances : Logique.rafale, annuler, lire, evaluer.
    function echouer() {
        const maintenant = Date.now()
        if (Logique.rafale(echecs, maintenant)) { annuler(); return }
        echecs = echecs.concat([maintenant])
        enVol = false
        echec = true
        lire()
        evaluer()
    }

    // lire — relit les échecs du compte : par lecteur s'il est posé, sinon par faillock et faillock.conf.
    // Entrées : aucune. Sortie : restants et jusqua, aussitôt ou à la fin de la commande. Erreurs : un lecteur qui lève
    // ou une commande absente laisse restants à null. Dépendances : lecteur, compte, reglages, retenir.
    function lire() {
        restants = null
        if (!lecteur) { compte.running = true; return }
        try {
            const r = lecteur()
            retenir(r.faillock, r.conf)
        } catch (e) { restants = null }
    }

    // retenir — retient un relevé. Entrées : faillock, conf, textes. Sortie : restants, jusqua, etat. Erreurs : aucune.
    // Dépendances : Logique (lireConf, verrou), evaluer.
    function retenir(faillock: string, conf: string) {
        const v = Logique.verrou(faillock, Logique.lireConf(conf), Date.now() / 1000)
        restants = v.restants
        jusqua = v.jusqua
        evaluer()
    }

    // Garde de frappe : silence du clavier exigé avant que le champ n'accepte les touches, à partir de chaque flux.
    Timer { id: garde; interval: Theme.motion?.delays.gardeFrappe ?? 0 }

    // Tenue d'« Autorisé » avant la fermeture.
    Timer { id: sortie; interval: Theme.motion?.delays.autorise ?? 0; onTriggered: autorisation.ouvert = false }

    // La presqu'île de l'écran s'efface sous l'île de la demande, et revient à la fermeture.
    Binding { target: C.Overlays; property: "ecranCouvert"; value: scene.ouvert && scene.fenetre ? scene.ecran?.name ?? "" : "" }

    Connections {
        target: autorisation.flux
        ignoreUnknownSignals: true

        // Retours du flux courant : réponse attendue ou non, message de PAM, échec, fin. Un flux remplacé n'est plus
        // écouté. Entrées : aucune. Sortie : etat, ligne, fermeture. Erreurs : aucune. Dépendances : evaluer, echouer,
        // finir.
        function onIsResponseRequiredChanged() {
            if (autorisation.flux.isResponseRequired) autorisation.enVol = false
            autorisation.evaluer()
        }
        function onSupplementaryMessageChanged() { autorisation.supplement = autorisation.flux.supplementaryMessage }
        function onAuthenticationFailed() { autorisation.echouer() }
        function onAuthenticationSucceeded() { autorisation.finir(true) }
        function onIsCompletedChanged() { if (autorisation.flux?.isCompleted) autorisation.finir(autorisation.flux.isSuccessful) }
    }

    Process {
        id: compte
        command: ["faillock", "--user", autorisation.utilisateur]
        stdout: StdioCollector {
            // onStreamFinished — retient le relevé. Entrées : aucune. Sortie : restants, jusqua. Erreurs : un relevé
            // vide laisse restants à null. Dépendances : retenir, reglages.
            onStreamFinished: {
                reglages.reload()
                autorisation.retenir(text, reglages.text())
            }
        }
    }

    // Réglages de faillock, relus à chaque relevé ; absents, les défauts de pam_faillock s'appliquent.
    FileView {
        id: reglages
        path: "/etc/security/faillock.conf"
        blockLoading: true
        printErrors: false
    }

    IpcHandler {
        target: "autorisation"

        // etat — état de l'agent en JSON : ouvert, etat, ligne, saisieOuverte, fenetre (vrai si construite), clavier (vrai
        // si la demande le prend) ; jamais le texte saisi. Entrées : aucune. Sortie : texte. Erreurs : aucune. Dépendances : autorisation.
        function etat(): string {
            return JSON.stringify({ ouvert: autorisation.ouvert, etat: autorisation.etat, ligne: autorisation.ligne,
                                    saisieOuverte: autorisation.saisieOuverte, fenetre: autorisation.fenetre !== null, clavier: autorisation.prendClavier })
        }
    }
}
