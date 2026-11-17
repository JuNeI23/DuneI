pragma Singleton
import QtQuick
import Quickshell

// EtatParametres — état de l'application Paramètres, partagé par la coque entière.
// Rôle : dit si l'application est demandée, quelle page elle montre et quel réglage elle doit atteindre. La fenêtre
// (FenetreParametres) se construit quand ouverte passe à vrai et se détruit quand elle repasse à faux ; la page est
// gardée d'une ouverture à l'autre, si bien que rouvrir sans page rend la dernière vue de la session.
// Entrées : presents, les conditions vraies à l'instant (par exemple « joint »), que les pages tiennent à jour et que
// la recherche lit pour écarter un réglage dont la cible n'existe pas ; vide par défaut.
// Sorties : ouverte, vrai tant que l'application est demandée ; page, identifiant de la page montrée (« wifi » par
// défaut) ; chemin, l'ancre demandée (liste de chaînes au format de recherche.js : page, puis sous-page ou dépliant
// éventuel, puis réglage), vide sans demande : le conteneur de page la consomme dès que la page l'a suivie.
// Fonctions : ouvrir, fermer.
// Erreurs : aucune ; une page inconnue du registre laisse la page courante.
// Dépendances : Quickshell (Singleton), Registre (pages).
Singleton {
    id: racine

    property bool ouverte: false
    property string page: "wifi"
    property var chemin: []
    property var presents: []

    // ouvrir — demande l'application sur une page, et au besoin sur un de ses réglages.
    // Entrées : page, identifiant du registre, ou chaîne vide pour la dernière page vue ; chemin, ancre à atteindre
    // (liste de chaînes), vide ou absente pour la page seule.
    // Sortie : aucune ; écrit page, chemin et ouverte. Erreurs : aucune ; une page inconnue est ignorée, la page
    // courante reste. Dépendances : Registre.pages.
    function ouvrir(page, chemin) {
        if (Registre.pages.some(p => p.id === page)) racine.page = page
        racine.chemin = chemin ?? []
        ouverte = true
    }

    // fermer — retire la demande : la fenêtre se détruit. Entrées : aucune. Sortie : aucune ; écrit ouverte et vide
    // chemin. Erreurs : aucune. Dépendances : aucune. Pour fermer sans retenir la fenêtre à l'écran le temps de sa
    // démolition, passer par FenetreParametres.fermer, qui la cache d'abord.
    function fermer() {
        chemin = []
        ouverte = false
    }
}
