import QtQuick
import Quickshell
import Quickshell.Io
import "Lanceur"
import "Lanceur/lanceur.js" as Logique

// Coque d'essai des sources du lanceur, sans aucune fenêtre ni prise du clavier.
// Rôle : charge Sources, y injecte par IPC (cible « essai ») de fausses entrées de bureau, de fausses fenêtres, un
// usage, un faux calcul et un préfixe d'appel IPC vers elle-même, puis rend ses résultats pour tests/test_lanceur.py
// (SourcesTest). Elle sert aussi la cible « notifications », dont l'état « ne pas déranger » vaut toujours « true ».
// Entrées : commandes IPC injecter, calculer, classes, accueil, rafraichir. Sortie : JSON ; la ligne « essai : état
// <état> » à chaque état reçu. Erreurs : aucune. Dépendances : quickshell ≥ 0.3 (Quickshell.Io), Sources, lanceur.js
// (liens essai/sources/Lanceur, Applications et Parametres, car Quickshell ne suit pas les imports hors du dossier
// de la coque).
ShellRoot {
    // Component.onCompleted — signale que la coque d'essai est prête.
    // Entrées : aucune. Sortie : la ligne « essai : prêt » dans le journal. Erreurs : aucune. Dépendances : console.
    Component.onCompleted: console.log("essai : prêt")

    // Faux calcul : la même interface publiée que Calcul (expression, valeur).
    QtObject {
        id: fauxCalcul
        property string expression: ""
        property string valeur: ""
    }

    Sources {
        id: sources
        calcul: fauxCalcul
        // onEtatsChanged — signale chaque état reçu. Entrées : aucune. Sortie : la ligne « essai : état <état de
        // ne pas déranger> ». Erreurs : aucune. Dépendances : console.
        onEtatsChanged: console.log("essai : état " + (etats["ne-pas-deranger"] || ""))
    }

    IpcHandler {
        target: "essai"

        // injecter — remplace des entrées de Sources. Entrée : json, objet dont chaque clé (entrees, fenetres,
        // poids, cheminRoles, ipc) nomme une propriété de Sources. Sortie : aucune. Erreurs : aucune.
        // Dépendances : Sources.
        function injecter(json: string): void {
            const d = JSON.parse(json)
            for (const cle in d) sources[cle] = d[cle]
        }

        // calculer — publie un faux résultat de calcul. Entrées : expression, valeur. Sortie : aucune.
        // Erreurs : aucune. Dépendances : fauxCalcul.
        function calculer(expression: string, valeur: string): void {
            fauxCalcul.expression = expression
            fauxCalcul.valeur = valeur
        }

        // classes — résultats d'une saisie, classés sans poids. Entrée : saisie. Sortie : tableau JSON.
        // Erreurs : aucune. Dépendances : Sources.chercher, Logique.classer.
        function classes(saisie: string): string { return JSON.stringify(Logique.classer(sources.chercher(saisie), {})) }

        // accueil — accueil des sources. Entrées : aucune. Sortie : {medaillons, puces} en JSON. Erreurs : aucune.
        // Dépendances : Sources.accueil.
        function accueil(): string { return JSON.stringify(sources.accueil()) }

        // rafraichir — relit les états des commandes. Entrées : aucune. Sortie : aucune. Erreurs : aucune.
        // Dépendances : Sources.rafraichir.
        function rafraichir(): void { sources.rafraichir() }
    }

    IpcHandler {
        target: "notifications"

        // nePasDeranger — faux état de « ne pas déranger ». Entrées : aucune. Sortie : « true ». Erreurs : aucune.
        // Dépendances : aucune.
        function nePasDeranger(): string { return "true" }
    }
}
