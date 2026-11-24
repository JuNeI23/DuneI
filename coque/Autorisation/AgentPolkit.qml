import QtQuick
import Quickshell.Services.Polkit

// AgentPolkit — agent d'authentification réel (L2-24), seul fichier de la coque à importer le module Polkit.
// Rôle : s'enregistre auprès de polkit pour la session et expose la demande courante ; construit par Autorisation, et
// par lui seul, quand la mise en marche et la règle PAM le permettent.
// Entrées : aucune. Sorties : enregistre, vrai une fois l'agent enregistré ; flux, l'AuthFlow courant, ou null.
// Erreurs : un enregistrement refusé laisse enregistre à faux (journalisé par Quickshell). Dépendances :
// Quickshell.Services.Polkit.
QtObject {
    readonly property bool enregistre: agent.isRegistered
    readonly property var flux: agent.flow
    readonly property PolkitAgent agent: PolkitAgent { id: agent }
}
