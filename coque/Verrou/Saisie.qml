import QtQuick
import Quickshell.Services.Pam
import "../Theme"
import "verrou.js" as Logique

// Saisie — le champ de mot de passe de l'écran verrouillé et son dialogue avec PAM (L2-22, voie B).
// Rôle : reçoit les touches du clavier du verrou, tient l'état du champ (verrou.js, frappe et issue) et, sur Entrée,
// ouvre une conversation PAM : la première question reçoit le mot saisi, la fin donne le succès, l'échec ou
// l'impossibilité. Trois minuteries : le repos du champ (il se referme seul), la durée d'un message d'échec et la garde
// de la vérification (une pile PAM muette est abandonnée). Aucune touche n'est lue pendant la vérification.
// Entrées : pret (le verrou de session est acquis : Entrée avant lui attend), pile (nom de la pile PAM, « hyprlock »),
// dossierPile (son dossier, « /etc/pam.d »), repos, dureeMessage et garde (délais en ms, les jetons par défaut) ;
// touche(key, texte) et vider().
// Sorties : points (nombre de caractères saisis), ouvert, verifie, message ; signaux secoue() (échec, pour la
// secousse) et reussi() (le verrou peut se lever). Erreurs : tout échec de PAM est affiché « Vérification impossible »,
// le champ restant utilisable. Dépendances : quickshell ≥ 0.3 (Quickshell.Services.Pam), Theme.motion.delays, verrou.js.
Item {
    id: saisie

    property bool pret: false
    property string pile: "hyprlock"
    property string dossierPile: "/etc/pam.d"
    property int repos: Theme.motion?.delays.verrouChampRepos ?? 8000
    property int dureeMessage: Theme.motion?.delays.verrouMessage ?? 3000
    property int garde: Theme.motion?.delays.verrouPam ?? 10000

    // État du champ tel que le tiennent frappe et issue.
    property var etat: ({ texte: "", ouvert: false, verifie: false, message: "" })
    readonly property int points: Array.from(etat.texte).length
    readonly property bool ouvert: etat.ouvert
    readonly property bool verifie: etat.verifie
    readonly property string message: etat.message

    signal secoue()
    signal reussi()

    // Vrai quand Entrée attend l'acquisition du verrou ; vrai aussi une fois la question de la conversation répondue.
    property bool enAttente: false
    property bool repondu: false
    property string messagePam: ""

    // appliquer — pose le nouvel état du champ et exécute l'action demandée par la logique.
    // Entrée : res, {etat, action}. Sortie : aucune. Erreurs : aucune.
    // Dépendances : repos, message (minuteries), lancer, secoue, reussi.
    function appliquer(res) {
        etat = res.etat
        if (!etat.ouvert || etat.verifie) repos.stop()
        if (etat.message !== "") effacement.restart()
        if (res.action === "rearmer") repos.restart()
        else if (res.action === "verifier") lancer()
        else if (res.action === "secouer") secoue()
        else if (res.action === "deverrouiller") reussi()
    }

    // touche — classe une frappe du clavier et la transmet à la logique du champ.
    // Entrées : key, le code Qt.Key_* ; texte, le texte de la frappe. Sortie : aucune. Erreurs : aucune ; une touche
    // sans rôle (flèche, texte de contrôle) est ignorée. Dépendances : appliquer, verrou.js (frappe).
    function touche(key, texte) {
        let nature = null
        if (key === Qt.Key_Return || key === Qt.Key_Enter) nature = "entree"
        else if (key === Qt.Key_Backspace) nature = "retour"
        else if (key === Qt.Key_Escape) nature = "echap"
        else if (texte !== "" && !/[\u0000-\u001f\u007f]/.test(texte)) nature = "imprimable"
        if (nature) appliquer(Logique.frappe(etat, { nature, texte }))
    }

    // vider — referme et vide le champ sans passer par une touche (le contrôleur le demande, par exemple au retrait).
    // Entrées, sortie : aucune. Erreurs : aucune. Dépendances : appliquer.
    function vider() { appliquer(Logique.frappe(etat, { nature: "repos", texte: "" })) }

    // lancer — ouvre la conversation PAM, dès que le verrou est acquis, et arme la garde.
    // Entrées, sortie : aucune. Erreurs : start() faux (pile introuvable) donne « impossible ».
    // Dépendances : pret, pam, garde, terminer.
    function lancer() {
        if (!pret) { enAttente = true; return }
        enAttente = false
        repondu = false
        messagePam = ""
        delaiGarde.restart()
        if (!pam.start()) terminer("impossible")
    }

    // terminer — clôt la vérification une seule fois et vide le texte, qui ne doit plus rester en mémoire.
    // Entrée : quoi, « succes », « echec » ou « impossible ». Sortie : aucune. Erreurs : sans effet si aucune
    // vérification n'est en cours (issue tardive après abandon). Dépendances : appliquer, verrou.js (issue).
    function terminer(quoi) {
        if (!etat.verifie) return
        delaiGarde.stop()
        appliquer(Logique.issue(etat, quoi, messagePam))
    }

    onPretChanged: if (pret && enAttente) lancer()

    PamContext {
        id: pam
        configDirectory: saisie.dossierPile
        config: saisie.pile

        // Une question reçoit le mot saisi ; une seconde question n'est pas prévue : la conversation est abandonnée.
        onResponseRequiredChanged: {
            if (!responseRequired) return
            if (!saisie.repondu) { saisie.repondu = true; respond(saisie.etat.texte) }
            else { abort(); saisie.terminer("impossible") }
        }
        // Le message d'erreur de PAM remplace le texte « Mot de passe incorrect » en cas d'échec.
        onPamMessage: if (messageIsError) saisie.messagePam = message
        onCompleted: result => saisie.terminer(result === PamResult.Success ? "succes"
                                               : result === PamResult.Failed ? "echec" : "impossible")
        onError: saisie.terminer("impossible")
    }

    Timer { id: repos; interval: saisie.repos; onTriggered: saisie.appliquer(Logique.frappe(saisie.etat, { nature: "repos", texte: "" })) }
    Timer { id: effacement; interval: saisie.dureeMessage; onTriggered: if (!saisie.etat.verifie) saisie.etat = Object.assign({}, saisie.etat, { message: "" }) }
    Timer { id: delaiGarde; interval: saisie.garde; onTriggered: { if (pam.active) pam.abort(); saisie.terminer("impossible") } }
}
