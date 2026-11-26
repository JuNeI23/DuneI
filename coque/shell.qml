//@ pragma IconTheme DuneI
//@ pragma Env QSG_DISTANCEFIELD_ANTIALIASING=gray
import QtQuick
import Quickshell
import Quickshell.Hyprland
import "Autorisation"
import "Barre"
import "Deconnexion"
import "Fond"
import "Galerie"
import "Lanceur"
import "Notifications"
import "Parametres"
import "Presquile"
import "Reseau"
import "Selecteur"
import "Verrou"

// Coque de session de DuneI — racine chargée par « qs -c dunei » (unité dunei-coque.service).
// Rôle : pose sur chaque écran le fond d'écran, une barre système et la presqu'île, dans le même Variants (le fond
// d'abord, pour qu'il soit le plus bas), et, une seule fois hors de Variants, la fenêtre Réseau et l'application
// Paramètres, construites seulement à leur demande, les notifications de connexion, le serveur de notifications
// (Centre), précédé de la mémoire de son attente (MemoireAttente), la fenêtre de sa pile, sur l'écran actif, le
// panneau des notifications (FenetrePanneau, ouvert par la cloche de chaque barre, à qui il est passé), l'ouvreuse
// de la galerie de fonds et l'annonceur de la jauge du son, à qui chaque presqu'île s'inscrit à sa création et se
// retire à sa destruction (écran débranché). Chaque presqu'île réserve la hauteur du module de la galerie, mesurée
// par l'ouvreuse : sa surface ne change jamais de taille (recette de L2-60).
// Entrées : aucune ; l'écran de chaque barre vient de Quickshell.screens. Sortie : trois fenêtres de calque par
// écran ; la fenêtre de la pile de notifications (une seule, sur l'écran actif) et les cartes de chaque notification
// reçue ; l'application Paramètres quand elle est ouverte (IPC « parametres ouvrir <page> », icône des réglages de
// la barre ou « Réglages réseau… » du popover) ; la galerie dans la presqu'île de l'écran actif à la demande (IPC
// « galerie basculer », SUPER + W) ; la jauge du son à chaque annonce d'EtatAudio (Annonceur) ; l'alerte de batterie
// à chaque palier franchi d'EtatEnergie (AnnonceurAlerte), qui attend la fermeture de la galerie de l'ouvreuse sur
// son écran ; le lanceur (IPC « lanceur basculer », SUPER + R), singleton du module Lanceur réveillé au démarrage ;
// le sélecteur de fenêtres (SUPER + Tab, raccourci global dunei:selecteur déclaré ici), singleton du module
// Selecteur réveillé de même ; le menu de déconnexion (IPC « deconnexion basculer », SUPER + Échap, logo de la
// barre), singleton du module Deconnexion réveillé de même ; le bloc du verrou (IPC « verrou », commandé par
// dunei-verrou), singleton du module Verrou réveillé de même, qui pose son bloc si la coque démarre pendant un verrou,
// et dont la chute ferme ici lanceur, sélecteur et menu de déconnexion ; les fichiers de hyprlock, produits d'avance
// par Production pour qu'ils existent avant le premier verrou (L2-22). Le raccourci global vit dans la coque de session et non
// dans le singleton : le protocole des raccourcis globaux de Hyprland refuse deux clients sur la même paire
// appid:nom, et une coque d'essai qui charge le singleton ferait tomber l'une des deux.
// Erreurs : tokens absents ou invalides → fond, barre et presqu'île transparents, erreur de Theme dans le journal de
// Quickshell.
// Dépendances : quickshell ≥ 0.3 (GlobalShortcut de Quickshell.Hyprland), modules Barre (Barre), Fond (Fond),
// Galerie (Ouvreuse), Lanceur (Lanceur), Notifications (Centre, FenetreNotifications, FenetrePanneau,
// MemoireAttente), Parametres (FenetreParametres), Presquile (Presquile, Annonceur, AnnonceurAlerte), Reseau
// (NotificationsReseau), Selecteur (Selecteur), Deconnexion (Deconnexion), Autorisation (Autorisation) et Verrou
// (Verrou, Production). Le Centre possède
// org.freedesktop.Notifications : aucun autre démon (dunst) ne doit le tenir.
// Rendu du texte : la directive Env force l'anticrénelage en niveaux de gris, comme dans le banc du verre.
ShellRoot {
    Variants {
        model: Quickshell.screens

        delegate: Scope {
            id: ecran
            required property var modelData

            Fond { modelData: ecran.modelData }
            Barre { modelData: ecran.modelData; panneau: panneauNotifications }
            Presquile {
                id: presquile
                modelData: ecran.modelData
                reserve: ouvreuse.hauteurModule
                Component.onCompleted: { ouvreuse.inscrire(presquile); annonceur.inscrire(presquile); alerte.inscrire(presquile) }
                Component.onDestruction: { ouvreuse.retirer(presquile); annonceur.retirer(presquile); alerte.retirer(presquile) }
            }
        }
    }

    Ouvreuse { id: ouvreuse }
    Annonceur { id: annonceur }
    AnnonceurAlerte { id: alerte; galerie: ouvreuse.galerie }
    FenetreParametres {}
    // L'agent d'authentification s'enregistre ici, et seulement ici : les coques d'essai ne le font jamais (L2-24).
    // Les singletons Lanceur, Selecteur et Deconnexion ne naissent qu'au premier accès : ces références publient leurs
    // IPC « lanceur », « selecteur » et « deconnexion » dès le démarrage.
    Component.onCompleted: {
        Lanceur.fermer(); Selecteur.annuler(); Deconnexion.annuler(); Autorisation.demarrer(); Verrou.demarrer()
    }
    Connections {
        target: Verrou
        // onTombe — le bloc part : ce qui pourrait rester ouvert sous lui se ferme. Entrées : aucune. Sortie : aucune.
        // Erreurs : aucune. Dépendances : Lanceur.fermer, Selecteur.annuler, Deconnexion.annuler.
        function onTombe() { Lanceur.fermer(); Selecteur.annuler(); Deconnexion.annuler() }
    }
    Production {}
    // SUPER + Tab : Hyprland appelle ce raccourci global à chaque Tab, sans lancer de processus.
    GlobalShortcut {
        appid: "dunei"
        name: "selecteur"
        description: "Sélecteur de fenêtres : ouvrir ou avancer d'un cran"
        // onPressed — chaque pression du raccourci ouvre le sélecteur ou avance la sélection d'un cran. Entrées :
        // aucune (le raccourci global dunei:selecteur, appelé par Hyprland). Sortie : aucune. Erreurs : aucune ;
        // moins de deux fenêtres, rien. Dépendances : Selecteur.avancer.
        onPressed: Selecteur.avancer(1)
    }
    NotificationsReseau {}
    // Avant le Centre : la mémoire de l'attente est rechargée avant que le serveur ne réémette ses notifications.
    MemoireAttente { attente: centre.attente }
    Centre { id: centre }
    FenetreNotifications { centre: centre }
    FenetrePanneau { id: panneauNotifications; centre: centre }
}
