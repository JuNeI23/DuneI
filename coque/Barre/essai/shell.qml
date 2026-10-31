//@ pragma IconTheme DuneI
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import Quickshell.Networking
import "Theme"
import "Barre"
import "Barre/icones.js" as Icones

// Coque d'essai du module Barre, sans aucune fenêtre.
// Rôle : expose par IPC (cible « barre ») les fonctions pures de icones.js, et porte un ElementBarre que le test
// pilote, pour que tests/test_barre.py éprouve les correspondances dans un vrai Quickshell.
// Entrées : DUNEI_TOKENS_DIR, lu par Theme. Commandes IPC : normaliserPourcent, iconeBatterie, iconeWifi,
// iconeBluetooth, iconeNotifications, iconeMoment, texteBatterie (chacune retourne son résultat), et
// regler <icone> <texte> qui règle l'élément, puis elementVisible qui retourne sa visibilité et policeTexte
// qui retourne la taille et les chiffres tabulaires de son texte.
// Sortie : le résultat de chaque appel IPC, sur la sortie de « qs ipc call ». Erreurs : celles de Theme, dans
// le journal. Dépendances : quickshell ≥ 0.3 (Quickshell.Io), modules Theme, Composants et Barre.
// Import : liens essai/Theme, essai/Composants et essai/Barre, comme dans les autres coques d'essai.
ShellRoot {
    // Le conteneur donne un parent à l'élément : sans lui, ShellRoot ne le rattache à rien et visible reste faux.
    Item {
        ElementBarre {
            id: element
        }

        // Indicateurs de la tâche 5 ; les deux processus résidents ne démarrent que sur ordre de l'essai.
        Horloge { id: horloge }
        Logo { id: logo }
        Batterie { id: batterie }
        JourNuit { id: jourNuit }
        Wifi { id: wifi }
        Bluetooth { id: bluetooth }
        Parametres { id: parametres }
        Vpn { id: vpn; actif: false }
        Notifications { id: notifications; actif: false }
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

        // policeTexte — relevé de la police du texte de l'ElementBarre d'essai : « taille;tnum ».
        // Entrées : aucune. Sortie : texte, tnum vide si la police ne demande pas de chiffres tabulaires.
        // Erreurs : aucune. Dépendances : element (le Texte est le second enfant de sa rangée).
        function policeTexte(): string {
            const f = element.contentItem.children[1].font
            return `${f.pixelSize};${f.features?.tnum ?? ""}`
        }

        // surveillerVpn — remplace la surveillance et la lecture du Vpn par « sh -c » et les démarre.
        // Entrées : commande (surveillance), lecture. Sortie : aucune. Erreurs : aucune. Dépendances : vpn.
        function surveillerVpn(commande: string, lecture: string): void {
            vpn.surveille = ["sh", "-c", commande]; vpn.lecture = ["sh", "-c", lecture]; vpn.actif = true
        }

        // relancesVpn — nombre de démarrages de la surveillance du Vpn. Sortie : entier. Dépendances : vpn.
        function relancesVpn(): int { return vpn.relances }

        // surveillerNotifications — comme surveillerVpn, pour Notifications.
        // Entrées : commande, lecture. Sortie : aucune. Dépendances : notifications.
        function surveillerNotifications(commande: string, lecture: string): void {
            notifications.surveille = ["sh", "-c", commande]; notifications.lecture = ["sh", "-c", lecture]
            notifications.actif = true
        }

        // etat — relevé des indicateurs en texte « clé=valeur » séparé par des « ; » : visibilité, texte, icône.
        // Entrée : nom de l'indicateur (horloge, logo, batterie, jourNuit, wifi, bluetooth, parametres, notifications).
        // Sortie : texte. Erreurs : nom inconnu, chaîne vide. Dépendances : les indicateurs ci-dessus.
        function etat(nom: string): string {
            const e = {horloge, logo, batterie, jourNuit, wifi, bluetooth, parametres, notifications, vpn}[nom]
            return e ? `visible=${e.visible};icone=${e.icone};texte=${e.texte};cliquable=${e.cliquable}` : ""
        }

        // releve — relevé brut des sources matérielles, pour la note du commit : percentage de UPower brut,
        // état, et nombre de cartes Wi-Fi, de réseaux sans scan et de réseaux joints. Sortie : texte.
        function releve(): string {
            const d = UPower.displayDevice
            const cartes = Array.from(Networking.devices.values).filter(c => c.type === DeviceType.Wifi)
            const reseaux = cartes.reduce((t, c) => t.concat(Array.from(c.networks.values)), [])
            return `percentage=${d.percentage};etat=${d.state};laptop=${d.isLaptopBattery};cartes=${cartes.length};`
                 + `reseaux=${reseaux.length};joints=${reseaux.filter(n => n.connected).length};`
                 + `force=${reseaux.filter(n => n.connected).map(n => n.signalStrength)}`
        }
    }
}
