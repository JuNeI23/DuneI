import QtQuick
import Quickshell
import Quickshell.Io
import "../Theme"
import "../Composants"

// FenetreParametres — fenêtre de l'application Paramètres, titrée « Paramètres ».
// Rôle : porte la barre latérale et le conteneur de page dans une FloatingWindow construite au clic, quand
// EtatParametres.ouverte passe à vrai (icône de la barre, « qs ipc call parametres ouvrir »), et détruite à sa
// fermeture : aucune fenêtre cachée n'est gardée en mémoire. La création est asynchrone et attend Theme : une
// création synchrone, pendant la notification de Theme.ready, verrait les raccourcis de groupe encore indéfinis. La
// fermeture est immédiate : fermer() cache d'abord la fenêtre, de sorte que l'image cachée parte avant tout, puis ne
// lâche le chargeur qu'au tour suivant de la boucle d'événements ; sans cela, la démolition de l'arborescence
// retiendrait la fenêtre à l'écran (leçon de L2-65). Échap revient d'une sous-page à sa page mère.
// Entrées : aucune ; EtatParametres commande la construction. Une règle Hyprland (config/hypr/modules/regles.lua,
// « fenetre-parametres ») fait flotter la fenêtre, centrée, à sa taille implicite.
// Sorties : fenetre, la FloatingWindow construite, null fermée ; barre, sa BarreLaterale ; conteneur, son
// ConteneurPage ; pastilles, ses PastillesFenetre ; fonction fermer ; IPC « parametres ouvrir <page> » et
// « parametres fermer ».
// Erreurs : aucune ; avant le chargement des tokens, la fenêtre n'est pas construite.
// Dépendances : quickshell ≥ 0.3 (LazyLoader, FloatingWindow, IpcHandler), EtatParametres, BarreLaterale,
// ConteneurPage, Surface, PastillesFenetre, Theme (reglages, space).
// Cotes : reglages.windowWidth × windowHeight par défaut, au moins windowMinWidth × windowMinHeight ; colonne de
// reglages.sidebarWidth ; pastilles à space.scale[2] du coin haut gauche. Fond (D136) : la fenêtre est transparente
// et sa Surface ne peint rien ; la colonne est une Surface surfacePanel en verre (glass.sidebar), que Hyprland
// floute, et le contenu une Surface surfaceWindow opaque.
Scope {
    id: racine

    readonly property var fenetre: chargeur.item
    readonly property var barre: chargeur.item?.barre ?? null
    readonly property var conteneur: chargeur.item?.conteneur ?? null
    readonly property var pastilles: chargeur.item?.pastilles ?? null

    // fermer — cache la fenêtre aussitôt, puis la détruit au tour suivant (appelée par la pastille rouge, le
    // compositeur et l'IPC « parametres fermer »). Entrées : aucune. Sortie : aucune. Erreurs : aucune ; sans fenêtre,
    // ne fait que baisser EtatParametres.ouverte. Dépendances : EtatParametres, Qt.callLater.
    function fermer() {
        if (chargeur.item?.visible) chargeur.item.visible = false
        Qt.callLater(racine.lacher)
    }

    // lacher — lâche le chargeur. Passée nommément à Qt.callLater, qui dédoublonne par identité : deux fermer() de
    // la même passe n'en font qu'un. Entrées : aucune. Sortie : aucune. Erreurs : aucune. Dépendances : EtatParametres.
    function lacher() { EtatParametres.fermer() }

    LazyLoader {
        id: chargeur
        activeAsync: EtatParametres.ouverte && Theme.ready

        FloatingWindow {
            readonly property alias barre: barre
            readonly property alias conteneur: conteneur
            readonly property alias pastilles: pastilles
            title: "Paramètres"
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
                // Échap quitte la sous-page ; au niveau de la page mère, la touche poursuit son chemin.
                Keys.onEscapePressed: event => {
                    event.accepted = conteneur.niveau > 0
                    conteneur.revenir()
                }

                Surface {
                    x: plateau.width
                    width: parent.width - x
                    height: parent.height
                    ConteneurPage { id: conteneur; anchors.fill: parent }
                }
                Surface {
                    id: plateau
                    role: "surfacePanel"
                    verre: true
                    cleVerre: "sidebar"
                    width: Theme.reglages?.sidebarWidth ?? 0
                    height: parent.height
                    BarreLaterale { id: barre; anchors.fill: parent; enTete: pastilles.y + pastilles.height }
                }
                PastillesFenetre {
                    id: pastilles
                    x: Theme.space?.scale[2] ?? 0
                    y: x
                    titre: "Paramètres"
                    onFermer: racine.fermer()
                }
            }
        }
    }

    IpcHandler {
        target: "parametres"

        // ouvrir — ouvre l'application sur une page, ou la laisse ouverte en changeant de page. Entrée : page,
        // identifiant du registre (« wifi », « filaire », « vpn »), ou chaîne vide pour la dernière page vue.
        // Sortie : aucune. Erreurs : aucune ; une page inconnue garde la page courante. Dépendances : EtatParametres.
        function ouvrir(page: string): void { EtatParametres.ouvrir(page, []) }

        // fermer — ferme l'application par le même chemin que sa pastille rouge. Entrées : aucune. Sortie : aucune.
        // Erreurs : aucune. Dépendances : fermer de la racine.
        function fermer(): void { racine.fermer() }
    }
}
