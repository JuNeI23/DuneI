pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import "pleinecran.js" as Logique

// PleinEcran — lecture unique du vrai plein écran et du bureau spécial ouvert, écran par écran.
// Rôle : dit si l'espace que montre un écran porte une fenêtre en vrai plein écran ; le bureau spécial ouvert fait foi à
// la place de l'espace actif, comme dans Hyprland, et une fenêtre agrandie ne compte pas. Tient pour cela le nom du
// bureau spécial ouvert sur chaque moniteur : lu une fois à l'apparition du moniteur (specialWorkspace de
// lastIpcObject), puis suivi par l'événement activespecial, sans sondage.
// Entrées : l'état de Hyprland, que publie Quickshell.
// Sorties : special(nom) et sur(nom), que toute liaison peut appeler : elle se réévalue avec l'état lu.
// Erreurs : aucune ; un moniteur inconnu n'a ni bureau spécial ni plein écran.
// Dépendances : Quickshell.Hyprland (monitors, workspaces, toplevels, rawEvent), pleinecran.js.
Singleton {
    id: racine

    // Nom du bureau spécial ouvert, par nom de moniteur ; remplacé d'un bloc, pour que les liaisons le voient changer.
    property var speciaux: ({})

    // special — bureau spécial ouvert sur un moniteur. Entrée : nom du moniteur.
    // Sortie : son nom (« special:… »), ou "". Erreurs : aucune. Dépendances : speciaux.
    function special(nom: string): string { return speciaux[nom] ?? "" }

    // sur — dit si un écran montre un vrai plein écran. Entrée : nom du moniteur. Sortie : booléen.
    // Erreurs : aucune ; faux pour un moniteur inconnu. Dépendances : special, pleinecran.js, Hyprland.
    function sur(nom: string): bool {
        const actif = Hyprland.monitors.values.find(m => m.name === nom)?.activeWorkspace ?? null
        return Logique.porte(Logique.courant(special(nom), actif, Hyprland.workspaces.values))
    }

    // noter — retient le bureau spécial ouvert sur un moniteur. Entrées : nom du moniteur ; special, nom ou "".
    // Sortie : aucune. Erreurs : aucune. Dépendances : speciaux.
    function noter(nom: string, special: string): void {
        speciaux = Object.assign({}, speciaux, { [nom]: special })
    }

    // Un suivi par moniteur : l'état lu à l'amorce ne vaut qu'une fois, un événement reçu avant elle fait foi.
    Instantiator {
        model: Hyprland.monitors

        QtObject {
            id: suivi
            required property HyprlandMonitor modelData
            property bool amorce: false
            Component.onCompleted: Hyprland.refreshMonitors()

            readonly property Connections etat: Connections {
                target: suivi.modelData
                function onLastIpcObjectChanged() {
                    if (suivi.amorce) return
                    suivi.amorce = true
                    racine.noter(suivi.modelData.name, suivi.modelData.lastIpcObject?.specialWorkspace?.name ?? "")
                }
            }
            readonly property Connections evenements: Connections {
                target: Hyprland
                function onRawEvent(event) {
                    if (event.name !== "activespecial" || event.data.split(",")[1] !== suivi.modelData.name) return
                    suivi.amorce = true
                    racine.noter(suivi.modelData.name, Logique.lireSpecial(event.data))
                }
            }
        }
    }
}
