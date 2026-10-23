pragma Singleton
import QtQuick
import Quickshell

// Overlays — registre des overlays d'attention de la coque.
// Rôle : garantit qu'une seule attention est ouverte à la fois (conception, § 7.7) : en ouvrir une seconde ferme
// la première. Les contextuels n'y passent pas ; plusieurs peuvent coexister.
// Entrées : les appels d'Overlay, ouvrir() quand une attention s'ouvre et fermer() quand elle se ferme.
// Sorties : attention, l'overlay d'attention ouvert, ou null.
// Erreurs : aucune ; un objet qui n'est pas une attention est ignoré.
// Dépendances : Quickshell (Singleton) ; tout objet portant famille et ouvert, Overlay en premier lieu.
Singleton {
    property var attention: null

    // ouvrir — retient une attention qui vient de s'ouvrir et ferme celle qui l'était.
    // Rôle : l'attention retenue est remplacée avant que l'ancienne soit fermée ; ainsi, l'appel à fermer() que
    // déclenche la fermeture de l'ancienne ne touche plus au registre.
    // Entrées : o, l'objet qui s'ouvre (famille, ouvert). Sortie : aucune.
    // Erreurs : aucune ; un contextuel, ou l'attention déjà retenue, ne change rien.
    // Dépendances : attention.
    function ouvrir(o) {
        if (o?.famille !== "attention" || o === attention) return
        const ancienne = attention
        attention = o
        if (ancienne) ancienne.ouvert = false
    }

    // fermer — oublie une attention qui vient de se fermer.
    // Entrées : o, l'objet qui se ferme. Sortie : aucune.
    // Erreurs : aucune ; un objet qui n'est pas l'attention retenue ne change rien.
    // Dépendances : attention.
    function fermer(o) {
        if (o === attention) attention = null
    }
}
