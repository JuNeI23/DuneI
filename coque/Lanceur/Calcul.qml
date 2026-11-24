import QtQuick
import Quickshell
import Quickshell.Io
import "calcul.js" as Logique

// Calcul — calcul et conversions du lanceur par un qalc persistant (L2-16).
// Rôle : garde un seul processus qalc vivant tant que actif est vrai, lui soumet les saisies une par une et publie
// la réponse de la dernière seulement ; une réponse arrivée après une nouvelle frappe est ignorée.
// Entrées : actif (le processus ne vit que pendant qu'il est vrai) ; demander(saisie). Sorties : expression (la
// saisie traduite), valeur ("" sans résultat), disponible (faux si qalc manque ou meurt, jusqu'à la prochaine
// ouverture : jamais de relance en boucle). Erreurs : l'avertissement unique de Quickshell au journal si qalc est introuvable.
// Dépendances : Quickshell.Io (Process, SplitParser), calcul.js, le paquet libqalculate.
Scope {
    id: calcul

    property bool actif: false
    property string expression: ""
    property string valeur: ""
    property bool disponible: true

    // Dernier numéro de requête, requêtes encore sans réponse (n, envoye, ecrit) et requête dont on lit la réponse.
    property int dernier: 0
    property var file: []
    property var courante: null

    // demander — soumet une saisie à qalc.
    // Entrée : saisie, chaîne. Sortie : aucune ; expression et valeur sont remises à vide, puis valeur reçoit la
    // réponse si elle est encore la dernière. Une saisie sans chiffre ou incomprise (L2-82) n'est jamais envoyée.
    // Sans effet si qalc est indisponible. Erreurs : aucune. Dépendances : Logique.aEnvoyer, Logique.traduire, vider.
    function demander(saisie) {
        if (!disponible) return
        dernier++
        valeur = ""
        expression = Logique.aEnvoyer(saisie) ? Logique.traduire(saisie) : ""
        if (!expression) return
        file.push({ n: dernier, envoye: expression, ecrit: false })
        vider()
    }

    // vider — écrit sur l'entrée de qalc les requêtes pas encore écrites, une ligne chacune.
    // Entrées : aucune. Sortie : aucune ; sans processus vivant, elles restent en attente. Erreurs : aucune.
    // Dépendances : processus.
    function vider() {
        if (!processus.running) return
        for (const r of file) if (!r.ecrit) { r.ecrit = true; processus.write(r.envoye.replace(/[\r\n]+/g, " ") + "\n") }
    }

    // lireLigne — range une ligne de la sortie de qalc : « > expression » ouvre une réponse, la première ligne non
    // vide qui suit, messages de qalc sautés (L2-74 h), en est le résultat. L'écho peut arriver précédé d'un saut de
    // ligne (suite du prompt « > » précédent). Entrée : ligne. Sortie : aucune ; valeur reçoit le résultat si la
    // requête est la dernière. Erreurs : aucune. Dépendances : Logique (lire, avertissement).
    function lireLigne(ligne) {
        if (ligne.trim().startsWith("> ")) { courante = file.shift() || null; return }
        if (!courante || !ligne.trim() || Logique.avertissement(ligne)) return
        const r = courante
        courante = null
        if (r.n === dernier) valeur = Logique.lire(ligne, r.envoye)
    }

    // onActifChanged — une nouvelle ouverture redonne sa chance à qalc ; toute bascule efface requêtes et résultat.
    // Entrées : aucune (lit actif). Sortie : file, courante, valeur et expression remises à vide ; disponible vrai à
    // l'ouverture. Erreurs : aucune. Dépendances : aucune.
    onActifChanged: {
        file = []; courante = null; valeur = ""; expression = ""
        if (actif) disponible = true
    }

    Process {
        id: processus
        // « -defaults » : qalc ne lit ni n'écrit les réglages du terminal (qalc.cfg), qui fausseraient
        // ses réponses (D218).
        command: ["qalc", "-t", "-defaults", "-s", "decimal comma on", "-s", "color 0", "-s", "upxrates 1"]
        running: calcul.actif && calcul.disponible
        stdinEnabled: true
        stdout: SplitParser { onRead: ligne => calcul.lireLigne(ligne) }
        // onRunningChanged — démarré, vide les requêtes en attente ; arrêté pendant l'ouverture (qalc absent, qui ne
        // démarre pas, ou mort), rend le calcul indisponible sans relance.
        // Entrées : aucune. Sortie : disponible faux, expression et valeur vides dans le second cas. Erreurs : aucune ; Quickshell journalise
        // déjà lui-même l'échec de démarrage, une seule fois. Dépendances : vider.
        onRunningChanged: {
            if (running) calcul.vider()
            else if (calcul.actif) { calcul.disponible = false; calcul.expression = ""; calcul.valeur = "" }
        }
    }
}
