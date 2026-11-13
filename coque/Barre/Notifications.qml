import QtQuick
import "icones.js" as Icones

// Notifications — cloche de la barre.
// Rôle : affiche la cloche fixe des notifications. Le serveur et la pile (coque/Notifications/) tiennent les
// notifications ; la cloche ne lit plus rien en attendant la feature suivante, qui apportera la pastille de
// compte, l'historique et le « ne pas déranger ».
// Entrées : aucune. Sorties : aucune. Erreurs : aucune.
// Dépendances : ElementBarre, icones.js.
ElementBarre {
    icone: Icones.iconeNotifications(false)
}
