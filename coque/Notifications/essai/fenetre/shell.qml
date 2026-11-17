//@ pragma IconTheme DuneI
//@ pragma Env QSG_DISTANCEFIELD_ANTIALIASING=gray
import QtQuick
import Quickshell
import Quickshell.Io
import "Theme"
import "Composants"
import "Notifications"
import "Notifications/essai"

// Coque d'essai de la fenêtre du panneau des notifications, sous la plateforme offscreen.
// Rôle : porte la logique de FenetrePanneau (ouverture, écran, exclusivité) sans sa fenêtre de calque, que la
// plateforme offscreen ne sait pas construire (fenetree faux), et une FormePanneau dans une fenêtre jamais montrée,
// liée à cette logique : la forme, ses ressorts, son contenu et ses phases s'y éprouvent tels qu'en session.
// tests/test_notifications.py (FenetrePanneauTest) la pilote.
// Entrées : DUNEI_TOKENS_DIR, lu par Theme ; DUNEI_ETAT_DIR ; mouvement.json pour le mouvement réduit.
// Sortie : « essai : prêt » au démarrage ; voir l'IpcHandler. Erreurs : celles de Theme, dans le journal.
// Dépendances : quickshell ≥ 0.3 (IpcHandler, FloatingWindow), FenetrePanneau, FormePanneau, Attente, Overlays,
// FausseNotification, FauxVerrou, liens Theme, Composants, Presquile et Notifications.
ShellRoot {
    id: essai

    property int suivant: 1
    // Phases traversées depuis le dernier appel à marquer, sans répétition consécutive.
    property var phases: []
    // Tailles (largeur × hauteur) prises par la forme depuis le dernier appel à marquer.
    property var hauteurs: []

    Component.onCompleted: console.info("essai : prêt")

    Attente {
        id: attente
        verrou: Component { FauxVerrou {} }
    }
    QtObject { id: fauxCentre; readonly property QtObject attente: attente }
    QtObject { id: ecranA; property string name: "A" }
    QtObject { id: ecranB; property string name: "B" }
    QtObject { id: barreA; property var modelData: ecranA }
    QtObject { id: barreB; property var modelData: ecranB }
    // Autre contextuel exclusif, au contrat du registre Overlays.
    QtObject {
        id: autre
        readonly property string famille: "contextuel"
        readonly property bool exclusif: true
        property bool ouvert: false
    }
    Component { id: fabrique; FausseNotification {} }

    FenetrePanneau {
        id: panneau
        centre: fauxCentre
        fenetree: false
        ecrans: [ecranA, ecranB]
        pleinEcran: false
    }

    FloatingWindow {
        implicitWidth: 500
        implicitHeight: 900
        color: "transparent"

        FormePanneau {
            id: forme
            anchors.fill: parent
            attente: attente
            ouvert: panneau.ouvert
            onPhaseChanged: if (essai.phases[essai.phases.length - 1] !== phase) essai.phases = essai.phases.concat([phase])
            onHauteurFormeChanged: essai.hauteurs = essai.hauteurs.concat([hauteurForme])
            onFermer: panneau.ouvert = false
        }
    }

    IpcHandler {
        target: "essai"

        // pret — vrai une fois les jetons chargés. Sortie : « true » ou « false ».
        function pret(): string { return String(Theme.panneau !== undefined) }

        // basculer — clic sur la cloche de la barre « A » ou « B ». Entrée : nom. Sortie : aucune.
        function basculer(nom: string): void { panneau.basculer(nom === "B" ? barreB : barreA) }

        // marquer — vide les relevés de phases et de hauteurs. Sortie : aucune.
        function marquer(): void { essai.phases = []; essai.hauteurs = [] }

        // etat — JSON {ouvert, ecran, phase, phases, largeur, hauteur, hauteurs, charge, masque: [x, y, l, h],
        // opacite, contenuHauteur}. Sortie : texte. Dépendances : panneau, forme.
        function etat(): string {
            const c = forme.corps
            const p = c.mapToItem(forme, 0, 0)
            return JSON.stringify({ouvert: panneau.ouvert, ecran: panneau.ecran?.name ?? "", phase: forme.phase,
                phases: essai.phases, largeur: forme.largeurForme, hauteur: forme.hauteurForme,
                hauteurs: essai.hauteurs, charge: forme.charge, opacite: forme.opaciteContenu,
                masque: forme.charge ? [p.x, p.y, c.width, c.height] : [0, 0, 0, 0],
                formeHauteur: forme.height, formeLargeur: forme.width})
        }

        // creer — ajoute une notification factice à l'attente. Entrée : app. Sortie : son identifiant.
        function creer(app: string): string {
            const n = fabrique.createObject(essai, {id: essai.suivant++, appName: app, summary: "Titre", body: "Corps",
                                                    tracked: true})
            attente.ajouter(n, "", new Date())
            return String(n.id)
        }

        // ouvrirAutre — ouvre l'autre contextuel exclusif par le registre. Sortie : aucune.
        function ouvrirAutre(): void { autre.ouvert = true; Overlays.ouvrir(autre) }
        function autreOuvert(): string { return String(autre.ouvert) }

        // debrancher — retire un écran de la liste. Entrée : nom. Sortie : aucune.
        function debrancher(nom: string): void { panneau.ecrans = panneau.ecrans.filter(e => e.name !== nom) }

        // detruireEcran — l'écran du panneau disparaît (ecran devient null) avant que la liste des écrans ne
        // change. Entrée : nom. Sortie : aucune.
        function detruireEcran(nom: string): void {
            if (panneau.ecran?.name === nom) panneau.ecran = null
            panneau.ecrans = panneau.ecrans.filter(e => e.name !== nom)
        }

        // pleinEcran — pose le plein écran simulé. Entrée : v. Sortie : aucune.
        function pleinEcran(v: bool): void { panneau.pleinEcran = v }

        // echap — touche Échap reçue par la forme. Sortie : aucune.
        function echap(): void { forme.fermer() }

        // reglages — clic sur « Réglages des notifications… » du panneau chargé dans la forme. Sortie : aucune.
        // Erreurs : TypeError au journal sans panneau chargé. Dépendances : forme (panneau).
        function reglages(): void { forme.panneau.lienReglages.active() }
    }
}
