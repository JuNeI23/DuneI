pragma Singleton
import QtQuick
import Quickshell

// Overlays — registre des overlays d'attention et des popovers exclusifs de la coque.
// Rôle : garantit qu'une seule attention est ouverte à la fois (conception, § 7.7) : en ouvrir une seconde ferme
// la première. De même, un seul contextuel exclusif (popover de la barre, D108) est ouvert à la fois. Les deux
// emplacements sont indépendants : une attention ne ferme pas un popover. Les contextuels ordinaires (menus, listes
// déroulantes, y compris celles d'un popover) n'y passent pas ; plusieurs peuvent coexister.
// Entrées : les appels d'Overlay, ouvrir() quand un overlay s'ouvre et fermer() quand il se ferme.
// Sorties : attention, l'overlay d'attention ouvert, ou null ; popover, le contextuel exclusif ouvert, ou null.
// Erreurs : aucune ; un objet qui n'est ni une attention ni un contextuel exclusif est ignoré.
// Dépendances : Quickshell (Singleton) ; tout objet portant famille, ouvert et, pour un popover, exclusif ; Overlay en
// premier lieu.
Singleton {
    property var attention: null
    property var popover: null

    // ouvrir — retient une attention ou un popover exclusif qui vient de s'ouvrir et ferme celui de son emplacement.
    // Rôle : l'objet retenu est remplacé avant que l'ancien soit fermé ; ainsi, l'appel à fermer() que déclenche la
    // fermeture de l'ancien ne touche plus au registre.
    // Entrées : o, l'objet qui s'ouvre (famille, ouvert, exclusif). Sortie : aucune.
    // Erreurs : aucune ; un contextuel non exclusif, une infobulle, ou l'objet déjà retenu, ne change rien.
    // Dépendances : attention, popover.
    function ouvrir(o) {
        const cle = o?.famille === "attention" ? "attention" : o?.famille === "contextuel" && o?.exclusif ? "popover" : ""
        if (!cle || o === this[cle]) return
        const ancien = this[cle]
        this[cle] = o
        if (ancien) ancien.ouvert = false
    }

    // fermer — oublie une attention ou un popover exclusif qui vient de se fermer.
    // Entrées : o, l'objet qui se ferme. Sortie : aucune.
    // Erreurs : aucune ; un objet qui n'est pas retenu ne change rien.
    // Dépendances : attention, popover.
    function fermer(o) {
        if (o === attention) attention = null
        if (o === popover) popover = null
    }
}
