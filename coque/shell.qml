//@ pragma IconTheme DuneI
//@ pragma Env QSG_DISTANCEFIELD_ANTIALIASING=gray
import Quickshell
import "Barre"
import "Presquile"

// Coque de session de DuneI — racine chargée par « qs -c dunei » (unité dunei-coque.service).
// Rôle : pose sur chaque écran une barre système et la presqu'île, dans le même Variants.
// Entrées : aucune ; l'écran de chaque barre vient de Quickshell.screens. Sortie : deux fenêtres de calque par écran.
// Erreurs : tokens absents ou invalides → barre et presqu'île transparentes, erreur de Theme dans le journal de Quickshell.
// Dépendances : quickshell ≥ 0.3, modules Barre (Barre) et Presquile (Presquile).
// Rendu du texte : la directive Env force l'anticrénelage en niveaux de gris, comme dans le banc du verre.
ShellRoot {
    Variants {
        model: Quickshell.screens

        delegate: Scope {
            id: ecran
            required property var modelData

            Barre { modelData: ecran.modelData }
            Presquile { modelData: ecran.modelData }
        }
    }
}
