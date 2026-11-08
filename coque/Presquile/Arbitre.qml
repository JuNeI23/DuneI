import QtQuick

// Arbitre — choisit le module que porte une presqu'île parmi les demandes des modules qui la veulent (L2-12).
// Rôle : retient une demande par clé (composant et priorité) ; le module courant est celui de plus haute priorité, et
// à égalité, celui demandé en premier. Sans demande, c'est le module par défaut, les bureaux. Une demande renouvelée
// par la même clé avec le même composant et la même priorité ne change rien : le module n'est pas remonté. Libérer une
// demande rend la place au suivant, jamais à un module périmé.
// Entrées : défaut, composant rendu sans demande (Bureaux par défaut) ; demander() et liberer().
// Sorties : module, le composant arbitré (lecture seule).
// Erreurs : aucune ; libérer une clé inconnue est sans effet.
// Dépendances : QtQuick, Bureaux.
QtObject {
    id: arbitre

    property Component defaut: Component { Bureaux {} }
    // Demandes en cours, dans l'ordre d'arrivée : { cle, composant, priorite }.
    property var _demandes: []
    // Composant de plus haute priorité ; le premier arrivé l'emporte à égalité (reduce ne remplace que sur un strict).
    readonly property Component module: _demandes.reduce((m, d) => !m || d.priorite > m.priorite ? d : m, null)?.composant ?? defaut

    // demander — inscrit ou met à jour la demande d'une clé.
    // Entrées : cle, identifiant du demandeur ; composant, le module voulu ; priorite, entier (le plus grand l'emporte).
    // Sortie : aucune. Erreurs : aucune ; une demande identique à la précédente ne touche à rien, et une demande
    // modifiée passe après les autres à égalité de priorité.
    // Dépendances : _demandes.
    function demander(cle: string, composant: Component, priorite: int): void {
        const d = _demandes.find(q => q.cle === cle)
        if (d?.composant === composant && d.priorite === priorite) return
        _demandes = [..._demandes.filter(q => q.cle !== cle), { cle, composant, priorite }]
    }

    // liberer — retire la demande d'une clé. Entrée : cle. Sortie : aucune. Erreurs : aucune (clé inconnue sans effet).
    // Dépendances : _demandes.
    function liberer(cle: string): void { _demandes = _demandes.filter(q => q.cle !== cle) }
}
