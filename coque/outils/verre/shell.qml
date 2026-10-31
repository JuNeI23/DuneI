//@ pragma IconTheme DuneI
//@ pragma Env QSG_DISTANCEFIELD_ANTIALIASING=gray
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "Theme"
import "Composants"

// Banc d'essai du verre — une barre factice pour juger le flou de Hyprland derrière les surfaces de la coque.
// Rôle : reproduit les conditions de la future barre (L2-08), seule surface de coque posée sur le fond du
// bureau : un PanelWindow ancré en haut, de 32 px, qui réserve 32 px, au namespace « dunei-barre » que les règles
// de calque générées (generated/hyprland-layers.lua) floutent, et que peint une Surface surfacePanel (E2, verre).
// La barre du banc ne porte pas d'OmbreElevation : l'ombre E2 du jour ne s'y juge pas (L2-45, L2-08).
// Trois boutons ouvrent par Overlay un menu, un popover et une infobulle, pour juger leur verre et l'ombre de
// leur marge, ainsi que le clic qui traverse cette marge ; un quatrième, contre le bord droit, ouvre un menu plus
// large que lui, pour juger le serrage du cadre au bord de l'écran. Le banc et la barre portent le même namespace
// et ne tournent donc pas en même temps.
// Entrées : DUNEI_TOKENS_DIR, posé par verre.sh vers son dossier de brouillon (tokens et shader du matériau).
// Sortie : une seule fenêtre de calque « dunei-barre », en haut de l'écran que choisit le compositeur (pas de
//          Variants), visible dès la première lecture valide des tokens.
// Erreurs : tokens absents ou invalides au démarrage → barre transparente, erreur de Theme dans le journal ;
//           sans le shader compilé, Qt signale l'échec de chargement dans le journal de Quickshell (Materiau) ; le
//           rendu de la surface n'est alors pas garanti.
// Commande : « qs -p coque/outils/verre ipc call verre basculer <menu|droite|popover|bulle> » ouvre ou ferme un overlay
// sans geste, pour une capture.
// Dépendances : quickshell ≥ 0.3 (PanelWindow, WlrLayershell, IpcHandler), modules Theme et Composants (Surface,
// Bouton, Overlay, Liste, Rangee, Texte).
// Import : comme pour la planche, les liens verre/Theme -> ../../Theme et verre/Composants -> ../../Composants
// placent les deux modules côte à côte sous la racine ; la directive IconTheme en tête choisit DuneI.
// Rendu du texte : la directive Env en tête force l'anticrénelage du texte en niveaux de gris
// (QSG_DISTANCEFIELD_ANTIALIASING=gray), pour cette coque seule : sans elle, Qt Quick le rend en sous-pixel
// d'après l'écran, malgré le rgba=none de fontconfig, ce qui frange de couleur les lettres sur le verre.
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

            // Bouton posé contre le bord droit : son menu, plus large que lui, doit se serrer au bord de l'écran.
            Bouton {
                id: boutonDroite
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                anchors.rightMargin: Theme.space?.panelPadding ?? 0
                text: "Droite"
                onClicked: menuDroite.ouvert = true
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

        // Menu du bouton de droite, le même que le premier, pour juger le serrage au bord droit de l'écran.
        Overlay {
            id: menuDroite
            famille: "contextuel"
            ancre: boutonDroite

            Liste {
                focus: true
                selectionSuitSurvol: true
                implicitWidth: 3 * Theme.space.scale[7]
                implicitHeight: count * Theme.density.rowHeight
                model: [{ texte: "Ouvrir" }, { texte: "Copier" }]
                delegate: Rangee {
                    required property var modelData
                    text: modelData.texte
                    onActive: menuDroite.ouvert = false
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

    // Commandes du banc, pour ouvrir et fermer un overlay sans geste, le temps d'une capture.
    IpcHandler {
        target: "verre"

        // basculer — ouvre l'overlay nommé s'il est fermé, le ferme sinon.
        // Entrée : nom, "menu", "droite", "popover" ou "bulle". Sortie : aucune.
        // Erreurs : TypeError pour un nom inconnu. Dépendances : menu, menuDroite, popover, bulle.
        function basculer(nom: string): void {
            const o = ({ menu, droite: menuDroite, popover, bulle })[nom]
            o.ouvert = !o.ouvert
        }
    }
}
