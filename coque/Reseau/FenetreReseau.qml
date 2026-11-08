import QtQuick
import Quickshell
import Quickshell.Io
import "../Theme"
import "../Composants"

// FenetreReseau — fenêtre Réseau autonome, titrée « Réseau » (L2-11).
// Rôle : porte le PanneauReseau dans une FloatingWindow, construite quand EtatReseau.fenetre passe à vrai (« Réglages
// réseau… » du popover, ou « qs ipc call reseau ouvrir ») et détruite à sa fermeture (D80) : le secret révélé disparaît
// avec elle. La fenêtre est créée de façon asynchrone une fois Theme prêt, comme la planche de contrôle : une création
// synchrone, pendant la notification de Theme.ready, verrait les raccourcis de groupe encore indéfinis.
// Entrées : aucune ; EtatReseau.fenetre commande la construction. La fenêtre porte en tête, au sommet du plateau de la
// barre latérale (bible, « Pastilles de fenêtre »), ses pastilles (PastillesFenetre) : fermer la détruit, réduire
// l'envoie au bureau spécial, agrandir bascule le plein écran. Une règle Hyprland (config/hypr/modules/regles.lua,
// « fenetre-reseau ») la fait flotter, centrée, à sa taille implicite.
// Sorties : panneau, le PanneauReseau de la fenêtre construite, null fermée ; pastilles, ses PastillesFenetre ;
// fonction fermer ; IPC « reseau ouvrir ».
// Erreurs : aucune ; avant le chargement des tokens, la fenêtre n'est pas construite.
// Dépendances : quickshell ≥ 0.3 (LazyLoader, FloatingWindow, IpcHandler), Theme, Surface, PastillesFenetre,
// PanneauReseau, EtatReseau, Theme (reglages, space).
// Cotes : 840 × 640 px par défaut (direction D4) et au moins 720 × 480 px, par les jetons reglages.windowWidth,
// windowHeight, windowMinWidth et windowMinHeight ; la sous-page d'un profil défile au-delà ; pastilles au sommet de
// la colonne latérale, à space.scale[2] (12) du coin haut gauche de la fenêtre, dont l'angle reste radius.window (la
// règle Hyprland ne change pas). Fond : la fenêtre est transparente et sa Surface ne peint rien ; le panneau peint la
// colonne en verre et le contenu opaque, que Hyprland floute derrière la colonne (D136).
Scope {
    id: racine

    readonly property var panneau: chargeur.item?.panneau ?? null
    readonly property var pastilles: chargeur.item?.pastilles ?? null

    // fermer — détruit la fenêtre (appelée quand le compositeur la ferme). Entrées : aucune. Sortie : aucune.
    // Erreurs : aucune. Dépendances : EtatReseau.
    function fermer() { EtatReseau.fenetre = false }

    LazyLoader {
        id: chargeur
        activeAsync: EtatReseau.fenetre && Theme.ready

        FloatingWindow {
            readonly property alias panneau: panneau
            readonly property alias pastilles: pastilles
            title: "Réseau"
            color: "transparent"
            implicitWidth: Theme.reglages?.windowWidth ?? 0
            implicitHeight: Theme.reglages?.windowHeight ?? 0
            minimumSize: Qt.size(Theme.reglages?.windowMinWidth ?? 0, Theme.reglages?.windowMinHeight ?? 0)
            onClosed: racine.fermer()
            onVisibleChanged: if (!visible) racine.fermer()

            Surface {
                anchors.fill: parent
                role: "surfaceWindow"
                peinte: false
                PanneauReseau {
                    id: panneau
                    anchors.fill: parent
                    enTete: pastilles.y + pastilles.height
                }
                PastillesFenetre {
                    id: pastilles
                    x: Theme.space?.scale[2] ?? 0
                    y: x
                    titre: "Réseau"
                    onFermer: racine.fermer()
                }
            }
        }
    }

    IpcHandler {
        target: "reseau"

        // ouvrir — ouvre la fenêtre Réseau, ou la laisse ouverte. Entrées : aucune. Sortie : aucune.
        // Erreurs : aucune. Dépendances : EtatReseau.
        function ouvrir(): void { EtatReseau.fenetre = true }
    }
}
