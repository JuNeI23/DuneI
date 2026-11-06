//@ pragma IconTheme DuneI
//@ pragma Env QSG_DISTANCEFIELD_ANTIALIASING=gray
import Quickshell
import "Barre"
import "Fond"
import "Presquile"
import "Reseau"

// Coque de session de DuneI — racine chargée par « qs -c dunei » (unité dunei-coque.service).
// Rôle : pose sur chaque écran le fond d'écran, une barre système et la presqu'île, dans le même Variants (le fond
// d'abord, pour qu'il soit le plus bas), et, une seule fois hors de Variants, la fenêtre Réseau, construite seulement
// à sa demande, et les notifications de connexion.
// Entrées : aucune ; l'écran de chaque barre vient de Quickshell.screens. Sortie : trois fenêtres de calque par écran ;
// la fenêtre Réseau quand elle est ouverte (IPC « reseau ouvrir » ou « Réglages réseau… »).
// Erreurs : tokens absents ou invalides → fond, barre et presqu'île transparents, erreur de Theme dans le journal de Quickshell.
// Dépendances : quickshell ≥ 0.3, modules Barre (Barre), Fond (Fond), Presquile (Presquile) et Reseau (FenetreReseau, NotificationsReseau).
// Rendu du texte : la directive Env force l'anticrénelage en niveaux de gris, comme dans le banc du verre.
ShellRoot {
    Variants {
        model: Quickshell.screens

        delegate: Scope {
            id: ecran
            required property var modelData

            Fond { modelData: ecran.modelData }
            Barre { modelData: ecran.modelData }
            Presquile { modelData: ecran.modelData }
        }
    }

    FenetreReseau {}
    NotificationsReseau {}
}
