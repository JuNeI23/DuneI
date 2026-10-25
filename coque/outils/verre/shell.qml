//@ pragma IconTheme Adwaita
import QtQuick
import Quickshell
import Quickshell.Wayland
import "Theme"
import "Composants"

// Banc d'essai du verre — une barre factice pour juger le flou de Hyprland derrière les surfaces de la coque.
// Rôle : reproduit les conditions de la future barre (L2-08), seule surface de coque posée sur le fond du
// bureau : un PanelWindow ancré en haut, de 32 px, qui réserve 32 px, au namespace « dunei-barre » que les règles
// de calque générées (generated/hyprland-layers.lua) floutent, et que peint une Surface surfaceWindow-verre.
// Trois boutons ouvrent par Overlay un menu, un popover et une infobulle, pour juger leur verre et l'ombre de
// leur marge, ainsi que le clic qui traverse cette marge. Le banc et la barre portent le même namespace et ne
// tournent donc pas en même temps.
// Entrées : DUNEI_TOKENS_DIR, posé par verre.sh vers son dossier de brouillon (tokens et shader du matériau).
// Sortie : une fenêtre de calque « dunei-barre » en haut de chaque écran, visible dès la première lecture valide
//          des tokens.
// Erreurs : tokens absents ou invalides au démarrage → barre transparente, erreur de Theme dans le journal ;
//           sans le shader compilé, le verre retombe sur un aplat (Materiau).
// Dépendances : quickshell ≥ 0.3 (PanelWindow, WlrLayershell), modules Theme et Composants (Surface, Bouton,
// Overlay, Liste, Rangee, Texte).
// Import : comme pour la planche, les liens verre/Theme -> ../../Theme et verre/Composants -> ../../Composants
// placent les deux modules côte à côte sous la racine ; la directive IconTheme en tête choisit Adwaita.
ShellRoot {
    PanelWindow {
        id: barre

        // Hauteur et zone réservée de la barre, en pixels logiques.
        readonly property int haut: 32

        anchors { top: true; left: true; right: true }
        implicitHeight: haut
        exclusiveZone: haut
        color: "transparent"
        WlrLayershell.namespace: "dunei-barre"

        Surface {
            anchors.fill: parent
            role: "surfacePanel"
            verre: true

            Row {
                anchors.verticalCenter: parent.verticalCenter
                x: Theme.space?.panelPadding ?? 0
                spacing: Theme.space?.scale[1] ?? 0

                Bouton { id: boutonMenu; text: "Menu"; onClicked: menu.ouvert = true }
                Bouton { id: boutonPopover; text: "Popover"; onClicked: popover.ouvert = true }
                Bouton { id: boutonBulle; text: "Infobulle"; onClicked: bulle.ouvert = !bulle.ouvert }
            }
        }

        // Menu contextuel de trois rangées, ancré sous son bouton ; une rangée ou Échap le ferme.
        Overlay {
            id: menu
            famille: "contextuel"
            ancre: boutonMenu

            Liste {
                focus: true
                selectionSuitSurvol: true
                implicitWidth: 3 * Theme.space.scale[7]
                implicitHeight: count * Theme.density.rowHeight
                model: [{ texte: "Ouvrir" }, { texte: "Copier" }, { texte: "Supprimer" }]
                delegate: Rangee {
                    required property var modelData
                    text: modelData.texte
                    onActive: menu.ouvert = false
                }
            }
        }

        // Popover : un contextuel plus large et plus haut qu'un menu, à contenu libre ; Échap ou un clic au dehors le ferme.
        Overlay {
            id: popover
            famille: "contextuel"
            ancre: boutonPopover

            Column {
                spacing: Theme.space?.scale[1] ?? 0
                Texte { text: "Un popover"; moyen: true }
                Texte { text: "Le verre laisse deviner le bureau." }
                Bouton { text: "Fermer"; onClicked: popover.ouvert = false }
            }
        }

        // Infobulle ouverte au clic (le banc n'attend pas le délai de survol) ; elle ne prend pas le clavier et
        // seul son bouton la ferme : un second clic dessus la referme.
        Overlay {
            id: bulle
            famille: "infobulle"
            ancre: boutonBulle

            Texte { text: "Une infobulle" }
        }
    }
}
