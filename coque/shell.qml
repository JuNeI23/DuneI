//@ pragma IconTheme Adwaita
//@ pragma Env QSG_DISTANCEFIELD_ANTIALIASING=gray
import Quickshell
import "Barre"

// Coque de session de DuneI — racine chargée par « qs -c dunei » (unité dunei-coque.service).
// Rôle : pose une barre système sur chaque écran. La presqu'île (lot 2, après la barre) viendra dans le même
// Variants, à côté de Barre.
// Entrées : aucune ; l'écran de chaque barre vient de Quickshell.screens. Sortie : une fenêtre de calque par écran.
// Erreurs : tokens absents ou invalides → barre transparente, erreur de Theme dans le journal de Quickshell.
// Dépendances : quickshell ≥ 0.3, module Barre (Barre).
// Rendu du texte : la directive Env force l'anticrénelage en niveaux de gris, comme dans le banc du verre.
ShellRoot {
    Variants {
        model: Quickshell.screens

        // Emplacement futur de Presquile : un second délégué dans ce Variants, ou un second Variants frère.
        delegate: Barre {}
    }
}
