import QtQuick
import Quickshell
import Quickshell.Io
import "Theme"
import "Verrou"

// Coque d'essai du contenu du verrou (L2-22), sans fenêtre : un Contenu de 1536 × 960 sur une fausse saisie et de faux
// lecteurs de médias, jamais le bus MPRIS réel.
// Rôle : pilote Contenu par l'IPC « essai » pour tests/test_verrou.py (ContenuTest).
// Entrées : DUNEI_TOKENS_DIR ; IPC « essai » : vu(bool), ouvrir(points), fermer(), message(texte), secouer(),
// lecteurs(json), reduit(bool), mesure() (JSON {champLargeur, champOpacite, points, message, mediaVisible, titre,
// artiste, ligneLargeur, decalageChamp}).
// Sorties : « essai : prêt » au démarrage. Erreurs : celles de Theme et de Contenu, dans le journal.
// Dépendances : quickshell ≥ 0.3 (IpcHandler), Contenu, Media, Theme ; liens essai/contenu/ vers les modules de la coque.
ShellRoot {
    id: essai

    // Fausse saisie : mêmes propriétés et même signal que Saisie.
    QtObject {
        id: saisie
        property int points: 0
        property bool ouvert: false
        property bool verifie: false
        property string message: ""
        signal secoue()
    }

    Media { id: media; lecteurs: [] }

    Item {
        width: 1536
        height: 960
        Contenu {
            id: contenu
            anchors.fill: parent
            vu: false
            saisie: saisie
            media: media
        }
    }

    // Component.onCompleted — la coque d'essai n'ouvre aucune fenêtre de verrou et signale qu'elle est prête.
    // Entrées, sortie : la ligne « essai : prêt ». Erreurs : aucune.
    Component.onCompleted: { Verrou.fenetree = false; console.log("essai : prêt") }

    IpcHandler {
        target: "essai"

        // vu — montre ou retire le contenu. Entrée : oui. Sortie : aucune.
        function vu(oui: bool): void { contenu.vu = oui }
        // ouvrir — ouvre le champ avec ce nombre de points. Entrée : points. Sortie : aucune.
        function ouvrir(points: int): void { saisie.points = points; saisie.ouvert = true }
        // fermer — referme le champ. Entrées, sortie : aucune.
        function fermer(): void { saisie.points = 0; saisie.ouvert = false }
        // message — pose le message de la saisie. Entrée : texte. Sortie : aucune.
        function message(texte: string): void { saisie.message = texte }
        // secouer — émet la secousse d'un échec. Entrées, sortie : aucune.
        function secouer(): void { saisie.secoue() }
        // lecteurs — remplace les faux lecteurs. Entrée : json, un objet {isPlaying, trackTitle, trackArtist,
        // trackArtUrl}, un tableau de tels objets ou rien : le client de l'IPC peut rendre un tableau sans ses crochets,
        // d'où la normalisation en tableau. Sortie : aucune. Erreurs : JSON invalide, aucun lecteur.
        function lecteurs(json: string): void {
            let lues = []
            try { lues = [].concat(JSON.parse(json)) } catch (e) { lues = [] }
            media.lecteurs = lues
        }
        // reduit — préférence de mouvement réduit. Entrée : oui. Sortie : aucune.
        function reduit(oui: bool): void { Theme.mouvementReduit = oui }
        // mesure — dimensions et textes du contenu, en JSON. Entrées : aucune. Sortie : le JSON de l'en-tête.
        function mesure(): string {
            return JSON.stringify(Object.assign({ points: contenu.saisie.points, decalageChamp: contenu.decalage },
                                                contenu.mesures))
        }
    }
}
