import QtQuick
import Quickshell.Hyprland
import Quickshell.Wayland
import "../Theme"

// Surface — la surface du verrou de session sur un écran (L2-22, voie B).
// Rôle : fenêtre que le compositeur confie au client verrouilleur, une par écran, créée par le WlSessionLock du
// contrôleur. Elle montre le même Contenu que le bloc, plein écran, à l'aplomb du bloc (même image du bureau, même
// taille décodée, cache partagé) : la première image de la surface est donc celle du bloc, sans trou. Le contenu
// (horloge, date, média, champ du mot de passe) y paraît selon Verrou.vu et y est animé selon Verrou.anime. Elle reçoit
// le clavier du verrou et le transmet à la saisie, partagée par les écrans.
// Entrées : aucune (le compositeur fixe la taille de la surface ; l'écran se lit par screen, posé par le verrou).
// Sorties : la surface du verrou. Erreurs : aucune ; avant les jetons, le fond est un aplat transparent.
// Dépendances : quickshell ≥ 0.3 (WlSessionLockSurface, Hyprland.monitorFor pour l'échelle, la même que celle du bloc), Verrou (vu, anime, saisie, media), Contenu, Theme (couleur).
WlSessionLockSurface {
    id: surface

    color: Theme.color?.surfaceBase ?? "transparent"

    Item {
        anchors.fill: parent
        focus: true

        // Keys.onPressed — transmet chaque touche à la saisie du verrou. Entrée : event (key, text). Sortie : aucune,
        // l'événement est accepté. Erreurs : aucune. Dépendances : Verrou.saisie.
        Keys.onPressed: event => {
            Verrou.saisie.touche(event.key, event.text)
            event.accepted = true
        }

        Contenu {
            anchors.fill: parent
            echelle: Hyprland.monitorFor(surface.screen)?.scale || surface.screen?.devicePixelRatio || 1
            vu: Verrou.vu
            entreeAnimee: Verrou.anime
            saisie: Verrou.saisie
            media: Verrou.media
        }
    }
}
