//@ pragma IconTheme Adwaita
import QtQuick
import Quickshell
import Quickshell.Io
import "Theme"
import "Barre"
import "Barre/icones.js" as Icones

// Coque d'essai du module Barre, sans aucune fenêtre.
// Rôle : expose par IPC (cible « barre ») les fonctions pures de icones.js, et porte un ElementBarre que le test
// pilote, pour que tests/test_barre.py éprouve les correspondances dans un vrai Quickshell.
// Entrées : DUNEI_TOKENS_DIR, lu par Theme. Commandes IPC : normaliserPourcent, iconeBatterie, iconeWifi,
// iconeBluetooth, iconeNotifications, iconeMoment, texteBatterie (chacune retourne son résultat), et
// regler <icone> <texte> qui règle l'élément, puis elementVisible qui retourne sa visibilité.
// Sortie : le résultat de chaque appel IPC, sur la sortie de « qs ipc call ». Erreurs : celles de Theme, dans
// le journal. Dépendances : quickshell ≥ 0.3 (Quickshell.Io), modules Theme, Composants et Barre.
// Import : liens essai/Theme, essai/Composants et essai/Barre, comme dans les autres coques d'essai.
ShellRoot {
    // Le conteneur donne un parent à l'élément : sans lui, ShellRoot ne le rattache à rien et visible reste faux.
    Item {
        ElementBarre {
            id: element
        }
    }

    IpcHandler {
        target: "barre"

        function normaliserPourcent(p: real): int { return Icones.normaliserPourcent(p) }
        function iconeBatterie(presente: bool, pourcent: int, enCharge: bool, pleine: bool): string {
            return Icones.iconeBatterie(presente, pourcent, enCharge, pleine)
        }
        function iconeWifi(carte: bool, actif: bool, connecte: bool, force: real): string {
            return Icones.iconeWifi(carte, actif, connecte, force)
        }
        function iconeBluetooth(adaptateur: bool, allume: bool): string { return Icones.iconeBluetooth(adaptateur, allume) }
        function iconeNotifications(enPause: bool): string { return Icones.iconeNotifications(enPause) }
        function iconeMoment(moment: string): string { return Icones.iconeMoment(moment) }
        function texteBatterie(pourcent: int): string { return Icones.texteBatterie(pourcent) }

        // regler — règle l'icône et le texte de l'ElementBarre d'essai. Entrées : icone, texte (vides permis).
        // Sortie : aucune. Erreurs : aucune. Dépendances : element.
        function regler(icone: string, texte: string): void { element.icone = icone; element.texte = texte }

        // elementVisible — lit la visibilité de l'ElementBarre d'essai.
        // Entrées : aucune. Sortie : vrai s'il est visible. Erreurs : aucune. Dépendances : element.
        function elementVisible(): bool { return element.visible }
    }
}
