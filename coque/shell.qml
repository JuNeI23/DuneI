//@ pragma IconTheme DuneI
//@ pragma Env QSG_DISTANCEFIELD_ANTIALIASING=gray
import QtQuick
import Quickshell
import "Barre"
import "Fond"
import "Galerie"
import "Presquile"
import "Reseau"

// Coque de session de DuneI — racine chargée par « qs -c dunei » (unité dunei-coque.service).
// Rôle : pose sur chaque écran le fond d'écran, une barre système et la presqu'île, dans le même Variants (le fond
// d'abord, pour qu'il soit le plus bas), et, une seule fois hors de Variants, la fenêtre Réseau, construite seulement
// à sa demande, les notifications de connexion, l'ouvreuse de la galerie de fonds et l'annonceur de la jauge du son,
// à qui chaque presqu'île s'inscrit à sa création et se retire à sa destruction (écran débranché). Chaque presqu'île
// réserve la hauteur du module de la galerie, mesurée par l'ouvreuse : sa surface ne change jamais de taille (recette
// de L2-60).
// Entrées : aucune ; l'écran de chaque barre vient de Quickshell.screens. Sortie : trois fenêtres de calque par écran ;
// la fenêtre Réseau quand elle est ouverte (IPC « reseau ouvrir » ou « Réglages réseau… ») ; la galerie dans la
// presqu'île de l'écran actif à la demande (IPC « galerie basculer », SUPER + W) ; la jauge du son à chaque
// annonce d'EtatAudio (Annonceur).
// Erreurs : tokens absents ou invalides → fond, barre et presqu'île transparents, erreur de Theme dans le journal de Quickshell.
// Dépendances : quickshell ≥ 0.3, modules Barre (Barre), Fond (Fond), Galerie (Ouvreuse), Presquile (Presquile,
// Annonceur) et Reseau (FenetreReseau, NotificationsReseau).
// Rendu du texte : la directive Env force l'anticrénelage en niveaux de gris, comme dans le banc du verre.
ShellRoot {
    Variants {
        model: Quickshell.screens

        delegate: Scope {
            id: ecran
            required property var modelData

            Fond { modelData: ecran.modelData }
            Barre { modelData: ecran.modelData }
            Presquile {
                id: presquile
                modelData: ecran.modelData
                reserve: ouvreuse.hauteurModule
                Component.onCompleted: { ouvreuse.inscrire(presquile); annonceur.inscrire(presquile) }
                Component.onDestruction: { ouvreuse.retirer(presquile); annonceur.retirer(presquile) }
            }
        }
    }

    Ouvreuse { id: ouvreuse }
    Annonceur { id: annonceur }
    FenetreReseau {}
    NotificationsReseau {}
}
