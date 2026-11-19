import QtQuick
import Quickshell
import Quickshell.Io
import "lanceur.js" as Logique

// MemoireLanceur — relevé d'usage du lanceur (L2-16).
// Rôle : retient combien de fois et quand chaque résultat a été lancé, dans lanceur.json, pour classer l'accueil
// (applications fréquentes) et les résultats. Le fichier est lu par Logique.assainir : absent, vide ou corrompu, il
// donne un relevé vide, et le premier noter le réécrit sain.
// Entrées : chemin, le fichier du relevé (lanceur.json dans DUNEI_ETAT_DIR, sinon Quickshell.stateDir) ; noter(cle).
// Sorties : usage, objet {clé: {n, dernier}}. Erreurs : aucune ; une lecture impossible laisse usage vide.
// Dépendances : Quickshell (env, stateDir), Quickshell.Io (FileView), lanceur.js (noter, assainir).
Scope {
    id: memoire

    property string chemin: (Quickshell.env("DUNEI_ETAT_DIR") || Quickshell.stateDir) + "/lanceur.json"
    property var usage: ({})

    // noter — enregistre un lancement et réécrit le fichier.
    // Entrée : cle, la clé du résultat lancé. Sortie : aucune ; usage est remplacé et le fichier écrit.
    // Erreurs : aucune. Dépendances : Logique.noter, fichier.
    function noter(cle) {
        usage = Logique.noter(usage, cle, Date.now())
        fichier.setText(JSON.stringify(usage))
    }

    FileView {
        id: fichier
        path: memoire.chemin
        printErrors: false
        blockLoading: true

        // onLoaded — lit le relevé du disque. Entrées : aucune. Sortie : usage assaini ({} si le JSON est invalide).
        // Erreurs : aucune (l'exception d'analyse est rattrapée). Dépendances : Logique.assainir.
        onLoaded: {
            try { memoire.usage = Logique.assainir(JSON.parse(text())) } catch (e) { memoire.usage = ({}) }
        }
    }
}
