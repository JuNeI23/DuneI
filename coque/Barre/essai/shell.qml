//@ pragma IconTheme DuneI
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import Quickshell.Networking
import "Theme"
import "Barre"
import "Reseau"
import "Notifications"
import "Barre/icones.js" as Icones
import "Barre/forme.js" as Forme

// Coque d'essai du module Barre, sans aucune fenêtre.
// Rôle : expose par IPC (cible « barre ») les fonctions pures de icones.js, et porte un ElementBarre que le test
// pilote, pour que tests/test_barre.py éprouve les correspondances dans un vrai Quickshell.
// Entrées : DUNEI_TOKENS_DIR, lu par Theme. Commandes IPC : normaliserPourcent, iconeBatterie, iconeReseau,
// iconeBluetooth, iconeNotifications, iconeMoment, iconeAudio, iconeMicro, texteBatterie (chacune retourne son résultat), et
// regler <icone> <texte> qui règle l'élément, ouvrirElement, decalageElement et ressortCouleur qui en éprouvent le
// mouvement, puis elementVisible qui retourne sa visibilité et policeTexte
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
        Reseau { id: reseau }
        Bluetooth { id: bluetooth }
        Parametres { id: parametres }
        Vpn { id: vpn }
        Notifications { id: notifications; panneau: fauxPanneau; barre: fausseBarre }
    }

    // Faux panneau des notifications, à l'interface que la cloche lit (FenetrePanneau) : il compte les bascules.
    QtObject {
        id: fauxPanneau
        property bool ouvert: false
        property var ecran: null
        property int bascules: 0
        property var derniere: null
        readonly property QtObject attente: QtObject {
            property int nombre: 0
            property bool critique: false
        }
        function basculer(barre) { bascules++; derniere = barre }
    }
    // Fausse barre : la cloche n'en lit que l'écran (modelData).
    QtObject {
        id: fausseBarre
        property var modelData: null
    }

    // Réactive EtatReseau peu après son arrêt : le moniteur réel, tué par l'arrêt, ne doit pas se voir relancé
    // par sa sortie tardive sur l'état « actif » déjà rétabli.
    Timer {
        id: reprise
        interval: 300
        onTriggered: EtatReseau.actif = true
    }

    IpcHandler {
        target: "barre"

        function normaliserPourcent(p: real): int { return Icones.normaliserPourcent(p) }
        function iconeBatterie(presente: bool, pourcent: int, enCharge: bool, pleine: bool): string {
            return Icones.iconeBatterie(presente, pourcent, enCharge, pleine)
        }
        function iconeReseau(carte: bool, radio: bool, filaire: bool, connecte: bool, connectivite: string,
                             facture: bool, force: real): string {
            return Icones.iconeReseau({carte, radio, filaire, connecte, connectivite, facture, force})
        }
        function iconeBluetooth(adaptateur: bool, allume: bool): string { return Icones.iconeBluetooth(adaptateur, allume) }
        function iconeNotifications(enPause: bool): string { return Icones.iconeNotifications(enPause) }
        function iconeMoment(moment: string): string { return Icones.iconeMoment(moment) }
        function iconeAudio(presente: bool, muet: bool, pourcent: int): string { return Icones.iconeAudio(presente, muet, pourcent) }
        function iconeMicro(muet: bool): string { return Icones.iconeMicro(muet) }
        function texteBatterie(pourcent: int): string { return Icones.texteBatterie(pourcent) }

        // cibles — forme visée du cadre (forme.js), en JSON {gauche, droite, hauteur}.
        // Entrées : celles de Forme.cibles. Sortie : texte JSON. Erreurs : aucune. Dépendances : forme.js.
        function cibles(ouvert: bool, ancreX: real, ancreL: real, largeur: real, hauteur: real, ecran: real,
                        marge: real): string {
            return JSON.stringify(Forme.cibles(ouvert, ancreX, ancreL, largeur, hauteur, ecran, marge))
        }

        // trajet — distance entre deux formes JSON (forme.js). Entrées : depuis, vers (texte JSON).
        // Sortie : réel. Erreurs : JSON invalide, l'appel échoue. Dépendances : forme.js.
        function trajet(depuis: string, vers: string): real { return Forme.trajet(JSON.parse(depuis), JSON.parse(vers)) }

        // contenuPermis — règle de passage du contenu (forme.js). Entrées : celles de Forme.contenuPermis.
        // Sortie : booléen. Erreurs : aucune. Dépendances : forme.js.
        function contenuPermis(enPassage: bool, reste: real, trajetTotal: real, seuil: real): bool {
            return Forme.contenuPermis(enPassage, reste, trajetTotal, seuil)
        }

        // opaciteDisque — opacité du disque (forme.js). Entrées : celles de Forme.opaciteDisque.
        // Sortie : réel. Erreurs : aucune. Dépendances : forme.js.
        function opaciteDisque(estAffiche: bool, passageEnCours: bool, opaciteNouveau: real, fondu: real): real {
            return Forme.opaciteDisque(estAffiche, passageEnCours, opaciteNouveau, fondu)
        }

        // rayon — rayon des coins (forme.js). Entrées : rayonPanneau, largeur, hauteur. Sortie : réel.
        // Erreurs : aucune. Dépendances : forme.js.
        function rayon(rayonPanneau: real, largeur: real, hauteur: real): real {
            return Forme.rayon(rayonPanneau, largeur, hauteur)
        }

        // textePastille — texte de la pastille de la cloche (icones.js). Entrée : nombre. Sortie : texte.
        // Erreurs : aucune. Dépendances : icones.js.
        function textePastille(nombre: int): string { return Icones.textePastille(nombre) }

        // cloche — règle l'attente du faux panneau. Entrées : nombre, critique. Sortie : aucune. Erreurs : aucune.
        // Dépendances : fauxPanneau.
        function cloche(nombre: int, critique: bool): void {
            fauxPanneau.attente.nombre = nombre; fauxPanneau.attente.critique = critique
        }

        // ouvrirPanneau — ouvre ou ferme le faux panneau. Entrée : v. Sortie : aucune. Erreurs : aucune.
        // Dépendances : fauxPanneau.
        function ouvrirPanneau(v: bool): void { fauxPanneau.ouvert = v }

        // cliquerCloche — clic gauche (« gauche ») ou droit (« droit ») sur la cloche, par ses signaux.
        // Entrée : bouton. Sortie : aucune. Erreurs : aucune. Dépendances : notifications (clicked, secondaire).
        function cliquerCloche(bouton: string): void {
            bouton === "droit" ? notifications.secondaire() : notifications.clicked()
        }

        // etatCloche — JSON {icone, pleine, cliquable, ouvert, forme, texte, bascules, barre, nePasDeranger} de la
        // cloche ; barre est vrai si la dernière bascule a reçu la barre de la cloche. Entrées : aucune.
        // Sortie : texte. Erreurs : aucune. Dépendances : notifications, fauxPanneau, EtatNotifications.
        function etatCloche(): string {
            const p = notifications.pastille
            return JSON.stringify({icone: notifications.icone, pleine: notifications.pleine,
                cliquable: notifications.cliquable, ouvert: notifications.ouvert, forme: p.forme, texte: p.texte,
                bascules: fauxPanneau.bascules, barre: fauxPanneau.derniere === fausseBarre,
                nePasDeranger: EtatNotifications.nePasDeranger})
        }

        // mouvementPastille — JSON {pilule, boule, ancien} : opacité de la pilule, de la boule et de l'ancien texte.
        // Entrées : aucune. Sortie : texte. Erreurs : aucune. Dépendances : notifications.pastille.
        function mouvementPastille(): string {
            const p = notifications.pastille
            return JSON.stringify({pilule: p.pilule.opacity, boule: p.boule.opacity, ancien: p.ancien.opacity})
        }

        // centrageChiffres — JSON [dx, dy] : écart entre le centre du dessin des chiffres et celui de la pilule.
        // Entrées : aucune. Sortie : texte. Erreurs : aucune. Dépendances : notifications.pastille.
        function centrageChiffres(): string { return JSON.stringify(notifications.pastille.decalage) }

        // reglerElement — pose pleine et fondu sur l'ElementBarre d'essai. Entrées : pleine, fondu. Sortie : aucune.
        // Erreurs : aucune. Dépendances : element.
        function reglerElement(pleine: bool, fondu: bool): void { element.pleine = pleine; element.fondu = fondu }

        // mouvementElement — JSON {remplissage, sortant, couleur} de l'ElementBarre d'essai : part de la variante
        // pleine (0 à 1), opacité de la couche du glyphe sortant, couleur visée. Entrées : aucune. Sortie : texte.
        // Erreurs : aucune. Dépendances : element.
        function mouvementElement(): string {
            return JSON.stringify({remplissage: element.remplissage, sortant: element.sortant.opacity,
                                   couleur: String(element.couleurRessort.target)})
        }

        // regler — règle l'icône et le texte de l'ElementBarre d'essai. Entrées : icone, texte (vides permis).
        // Sortie : aucune. Erreurs : aucune. Dépendances : element.
        function regler(icone: string, texte: string): void { element.icone = icone; element.texte = texte }

        // ouvrirElement — ouvre ou ferme l'ElementBarre d'essai, comme le fait son popover.
        // Entrée : valeur. Sortie : aucune. Erreurs : aucune. Dépendances : element.
        function ouvrirElement(valeur: bool): void { element.ouvert = valeur }

        // decalageElement — ordonnée de la rangée de l'ElementBarre d'essai dans l'élément, transformation comprise :
        // la différence entre ouvert et fermé est la descente de l'icône.
        // Entrées : aucune. Sortie : réel. Erreurs : aucune. Dépendances : element (contentItem).
        function decalageElement(): real { return element.contentItem.mapToItem(element, 0, 0).y }

        // ressortCouleur — raideur du ressort que le ColorSpring de l'ElementBarre d'essai emploie, et si l'icône bouge.
        // Entrées : aucune. Sortie : texte « raideur ». Erreurs : aucune. Dépendances : element (couleurRessort).
        function ressortCouleur(): string { return String(element.couleurRessort.params?.stiffness) }

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

        // surveillerVpn — remplace la surveillance et la lecture de EtatReseau (que le Vpn lit) par « sh -c » et
        // les redémarre ; le compteur de démarrages repart de zéro.
        // Entrées : commande (surveillance), lecture. Sortie : aucune. Erreurs : aucune. Dépendances : EtatReseau.
        function surveillerVpn(commande: string, lecture: string): void {
            EtatReseau.actif = false; EtatReseau.relances = 0
            EtatReseau.surveille = ["sh", "-c", commande]; EtatReseau.lecture = ["sh", "-c", lecture]
            reprise.start()
        }

        // relancesVpn — nombre de démarrages de la surveillance de EtatReseau. Sortie : entier.
        // Dépendances : EtatReseau.
        function relancesVpn(): int { return EtatReseau.relances }

        // etat — relevé des indicateurs en texte « clé=valeur » séparé par des « ; » : visibilité, texte, icône.
        // Entrée : nom de l'indicateur (horloge, logo, batterie, jourNuit, reseau, bluetooth, parametres, notifications).
        // Sortie : texte. Erreurs : nom inconnu, chaîne vide. Dépendances : les indicateurs ci-dessus.
        function etat(nom: string): string {
            const e = {horloge, logo, batterie, jourNuit, reseau, bluetooth, parametres, notifications, vpn}[nom]
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
