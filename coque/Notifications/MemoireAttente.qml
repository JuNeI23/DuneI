import QtQuick
import Quickshell

// MemoireAttente — mémoire de l'attente d'une génération de la coque à la suivante (L2-67).
// Rôle : à chaque rechargement de la coque (make install, toute modification de coque/), le serveur réémet les
// notifications encore suivies ; celles qui attendaient dans le panneau doivent y retourner sans repasser en carte.
// La mémoire tient donc les identifiants des notifications en attente dans un PersistentProperties, que Quickshell
// transmet à la génération suivante, et en donne la copie à la nouvelle attente (connus) dès le rechargement.
// Place dans l'arbre (épreuves du 17 novembre 2026, bus privé) : Quickshell ne recharge que les objets atteints par
// la filiation de la racine ; un objet tenu par une propriété (la pile du Centre, son attente) ne l'est pas, et sa
// mémoire renaîtrait vide. La mémoire est donc un enfant direct de la racine de la coque, déclaré AVANT le Centre :
// elle est rechargée avant que le serveur ne réémette ses notifications. La liste est typée (list<int>), car une
// valeur JavaScript libre ne passe pas d'un moteur à l'autre (« JSValue can't be reassigned to another engine »).
// Entrées : attente, l'Attente à servir (obligatoire). Sorties : aucune ; attente.connus au rechargement.
// Erreurs : aucune ; sans mémoire, ou au premier lancement, connus reste vide et les notifications réémises repassent
// une fois en carte. Dépendances : Quickshell (PersistentProperties), Attente (vivantes, connus).
Scope {
    id: memoire

    required property QtObject attente

    PersistentProperties {
        id: tenus
        reloadableId: "dunei-attente"
        property list<int> ids: []
        onReloaded: memoire.attente.connus = [...ids]
    }

    Connections {
        target: memoire.attente
        function onVivantesChanged() { tenus.ids = memoire.attente.vivantes.map(a => a.notification.id) }
    }
}
