import QtQuick
import Quickshell
import Quickshell.Io
import "Theme"
import "Galerie/galerie.js" as Galerie
import "Theme/fichiers.js" as Fichiers

// Coque d'essai du module Galerie.
// Rôle : expose par IPC (cible « galerie-essai ») les fonctions pures de galerie.js et de fichiers.js, pour que
// tests/test_galerie.py les éprouve dans un vrai Quickshell, sans fenêtre.
// Entrées : DUNEI_TOKENS_DIR, lu par Theme ; QT_QPA_PLATFORM, posé à offscreen par le test. Commandes IPC : filtres,
// borner, deplacer, initial, cran, identique, url, developper, jeton (les listes et objets sont rendus en JSON,
// le reste en texte).
// Sortie : le résultat de chaque appel IPC, sur la sortie de « qs ipc call ». Erreurs : celles de Theme, dans
// le journal. Dépendances : quickshell ≥ 0.3 (Quickshell.Io), modules Theme et Galerie.
// Import : liens essai/Theme, essai/Composants et essai/Galerie, comme dans les autres coques d'essai.
ShellRoot {
    // Theme est un singleton paresseux : cette lecture le charge, ce qu'attend le setUp de l'essai.
    Component.onCompleted: Theme.tokens

    IpcHandler {
        target: "galerie-essai"

        // filtres — motifs de formats. Sortie : JSON, liste de textes. Erreurs : aucune. Dépendances : Galerie.
        function filtres(): string { return JSON.stringify(Galerie.FILTRES) }
        // borner — voir galerie.js. Sortie : l'index borné. Erreurs : aucune. Dépendances : Galerie.
        function borner(index: int, nombre: int): int { return Galerie.borner(index, nombre) }
        // deplacer — voir galerie.js. Sortie : le nouvel index. Erreurs : aucune. Dépendances : Galerie.
        function deplacer(index: int, pas: int, nombre: int): int { return Galerie.deplacer(index, pas, nombre) }
        // initial — voir galerie.js. Entrées : chemins, séparés par des sauts de ligne (« qs ipc » découpe un
        // argument JSON) ; actuel. Sortie : l'index. Erreurs : aucune. Dépendances : Galerie.
        function initial(chemins: string, actuel: string): int {
            return Galerie.initial(chemins === "" ? [] : chemins.split("\n"), actuel)
        }
        // cran — voir galerie.js. Sortie : JSON {pas, reste}. Erreurs : aucune. Dépendances : Galerie.
        function cran(reste: real, delta: real, tranche: real): string {
            return JSON.stringify(Galerie.cran(reste, delta, tranche))
        }
        // identique — voir galerie.js. Sortie : true ou false. Erreurs : aucune. Dépendances : Galerie.
        function identique(choisi: string, actuel: string): bool { return Galerie.identique(choisi, actuel) }
        // url — voir fichiers.js. Sortie : l'URL. Erreurs : aucune. Dépendances : Fichiers.
        function url(chemin: string): string { return Fichiers.url(chemin) }
        // developper — voir fichiers.js. Sortie : le chemin développé. Erreurs : aucune. Dépendances : Fichiers.
        function developper(chemin: string, home: string): string { return Fichiers.developper(chemin, home) }
        // jeton — lit un jeton de Theme.galerie. Entrée : nom. Sortie : sa valeur en JSON. Erreurs : aucune.
        // Dépendances : Theme.
        function jeton(nom: string): string { return JSON.stringify(Theme.galerie?.[nom]) }
    }
}
