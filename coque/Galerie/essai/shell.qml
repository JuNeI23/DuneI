import QtQuick
import Quickshell
import Quickshell.Io
import "Theme"
import "Galerie"
import "Presquile"
import "Galerie/galerie.js" as Galerie
import "Theme/fichiers.js" as Fichiers

// Coque d'essai du module Galerie.
// Rôle : expose par IPC (cible « galerie-essai ») les fonctions pures de galerie.js et de fichiers.js, et monte le
// module Galerie dans une fenêtre d'essai qui imite la presqu'île (fond du bureau, Encoche à la taille du module), pour
// que tests/test_galerie.py les éprouve dans un vrai Quickshell. Sous la plateforme offscreen (les tests), la fenêtre
// n'apparaît jamais à l'écran ; lancée à la main dans la session, elle s'ouvre en fenêtre flottante pour la capture.
// Entrées : DUNEI_TOKENS_DIR, lu par Theme ; QT_QPA_PLATFORM, posé à offscreen par le test. Commandes IPC : filtres,
// borner, deplacer, initial, cran, identique, url, developper, jeton, presquile, actuel, monter, etat, touche,
// molette, cliquer, capturer (les listes et objets sont rendus en JSON, le reste en texte).
// Sortie : le résultat de chaque appel IPC, sur la sortie de « qs ipc call ». Erreurs : celles de Theme, dans
// le journal ; les commandes du module sont sans effet tant qu'aucune galerie n'est montée.
// Dépendances : quickshell ≥ 0.3 (Quickshell.Io, FloatingWindow, LazyLoader), modules Theme, Galerie et Presquile.
// Import : liens essai/Theme, essai/Composants, essai/Galerie et essai/Presquile, comme dans les autres coques d'essai.
ShellRoot {
    id: racine

    // Theme est un singleton paresseux : cette lecture le charge, ce qu'attend le setUp de l'essai.
    Component.onCompleted: Theme.tokens

    // Galerie montée par monter (null avant) ; fini, chemin reçu de son signal fini (null avant) ; finiApres, délai en
    // millisecondes entre le montage et ce signal ; t0, instant du montage.
    property Item galerie: null
    property var fini: null
    property real finiApres: -1
    property real t0: 0

    Component { id: moduleGalerie; Galerie {} }

    // Fenêtre d'essai : le fond du bureau, et l'Encoche de la presqu'île étirée à la taille de la galerie, avec la
    // marge de son ombre ; cadre reçoit la galerie montée.
    LazyLoader {
        id: fenetre
        activeAsync: Theme.ready

        FloatingWindow {
            property Item cadre: support
            property Item vue: fond
            implicitWidth: fond.width
            implicitHeight: fond.height
            color: "transparent"

            Rectangle {
                id: fond
                width: forme.implicitWidth + 2 * forme.marge
                height: forme.implicitHeight + forme.marge
                color: Theme.elevation?.e0?.fill ?? "transparent"

                Encoche {
                    id: forme
                    anchors.horizontalCenter: parent.horizontalCenter
                    largeurCorps: racine.galerie?.implicitWidth ?? 0
                    hauteur: racine.galerie?.implicitHeight || (Theme.tokens?.presquile?.hauteur ?? 0)

                    Item { id: support; x: forme.evasement; width: forme.largeurCorps; height: forme.hauteur }
                }
            }
        }
    }

    IpcHandler {
        target: "galerie-essai"

        // filtres — motifs de formats. Sortie : JSON, liste de textes. Erreurs : aucune. Dépendances : Galerie.
        function filtres(): string { return JSON.stringify(Galerie.FILTRES) }
        // borner — voir galerie.js. Sortie : l'index borné. Erreurs : aucune. Dépendances : Galerie.
        function borner(index: int, nombre: int): int { return Galerie.borner(index, nombre) }
        // deplacer — voir galerie.js. Sortie : le nouvel index. Erreurs : aucune. Dépendances : Galerie.
        function deplacer(index: int, pas: int, nombre: int): int { return Galerie.deplacer(index, pas, nombre) }
        // initial — voir galerie.js. Entrées : chemins, séparés par des sauts de ligne (« qs ipc » découpe un
        // argument JSON) ; actuel. Sortie : l'index. Erreurs : aucune. Dépendances : Galerie.
        function initial(chemins: string, actuel: string): int {
            return Galerie.initial(chemins === "" ? [] : chemins.split("\n"), actuel)
        }
        // cran — voir galerie.js. Sortie : JSON {pas, reste}. Erreurs : aucune. Dépendances : Galerie.
        function cran(reste: real, delta: real, tranche: real): string {
            return JSON.stringify(Galerie.cran(reste, delta, tranche))
        }
        // identique — voir galerie.js. Sortie : true ou false. Erreurs : aucune. Dépendances : Galerie.
        function identique(choisi: string, actuel: string): bool { return Galerie.identique(choisi, actuel) }
        // url — voir fichiers.js. Sortie : l'URL. Erreurs : aucune. Dépendances : Fichiers.
        function url(chemin: string): string { return Fichiers.url(chemin) }
        // developper — voir fichiers.js. Sortie : le chemin développé. Erreurs : aucune. Dépendances : Fichiers.
        function developper(chemin: string, home: string): string { return Fichiers.developper(chemin, home) }
        // jeton — lit un jeton de Theme.galerie. Entrée : nom. Sortie : sa valeur en JSON. Erreurs : aucune.
        // Dépendances : Theme.
        function jeton(nom: string): string { return JSON.stringify(Theme.galerie?.[nom]) }
        // presquile — lit un jeton de la presqu'île. Entrée : nom. Sortie : sa valeur en JSON. Erreurs : aucune.
        // Dépendances : Theme.
        function presquile(nom: string): string { return JSON.stringify(Theme.tokens?.presquile?.[nom]) }
        // actuel — fond actuel lu dans bureau.json. Sortie : Theme.imageBureau. Erreurs : aucune. Dépendances : Theme.
        function actuel(): string { return Theme.imageBureau }

        // monter — remplace la galerie de la fenêtre d'essai par une neuve.
        // Entrée : dossier, chemin absolu lu par la galerie, ou « - » pour celui des jetons. Sortie : aucune ; fini et
        // finiApres sont remis à zéro. Erreurs : « galerie-essai : aucune fenêtre » au journal si la fenêtre n'est pas
        // encore créée. Dépendances : fenetre, moduleGalerie.
        function monter(dossier: string): void {
            if (!fenetre.item) return console.warn("galerie-essai : aucune fenêtre")
            racine.galerie?.destroy()
            racine.fini = null
            racine.finiApres = -1
            racine.t0 = Date.now()
            const g = moduleGalerie.createObject(fenetre.item.cadre, dossier === "-" ? { ecran: null } : { ecran: null, dossier: dossier })
            g.fini.connect(c => { racine.fini = c; racine.finiApres = Date.now() - racine.t0 })
            g.forceActiveFocus()
            racine.galerie = g
        }

        // etat — photographie de la galerie montée.
        // Sortie : JSON {index, nombre, chemins, lu, vide, message, largeur, hauteur, fini, finiApres, delegues} ;
        // delegues liste les délégués créés par la bande, {i, echelle, voile, statut}. "null" sans galerie.
        // Erreurs : aucune. Dépendances : galerie.
        function etat(): string {
            const g = racine.galerie
            if (!g) return "null"
            const delegues = []
            for (let i = 0; i < g.nombre; i++) {
                const d = g.liste.itemAtIndex(i)
                if (d) delegues.push({ i: i, echelle: d.vignette.echelle, voile: d.vignette.voile, statut: d.vignette.statut })
            }
            return JSON.stringify({ index: g.index, nombre: g.nombre, chemins: g.chemins, lu: g.lu, vide: g.vide,
                                    message: g.vide ? g.message.text : "", largeur: g.implicitWidth,
                                    hauteur: g.implicitHeight, fini: racine.fini, finiApres: racine.finiApres,
                                    delegues: delegues })
        }

        // touche — envoie une touche à la galerie. Entrée : nom, « Droite », « Gauche », « Entree » ou « Echap ».
        // Sortie : aucune. Erreurs : un nom inconnu est ignoré. Dépendances : galerie.touche.
        function touche(nom: string): void {
            const codes = { Droite: Qt.Key_Right, Gauche: Qt.Key_Left, Entree: Qt.Key_Return, Echap: Qt.Key_Escape }
            if (nom in codes) racine.galerie?.touche(codes[nom])
        }
        // molette — envoie un défilement à la galerie. Entrées : dx, dy ; pixel, vrai pour un pixelDelta (pavé tactile).
        // Sortie : aucune. Erreurs : aucune. Dépendances : galerie.defiler.
        function molette(dx: real, dy: real, pixel: bool): void { racine.galerie?.defiler(dx, dy, pixel) }
        // cliquer — clic sur la vignette d'index i. Sortie : aucune. Erreurs : aucune. Dépendances : galerie.cliquer.
        function cliquer(i: int): void { racine.galerie?.cliquer(i) }

        // capturer — enregistre la fenêtre d'essai en PNG, de façon asynchrone (sous offscreen, avec
        // QT_QUICK_BACKEND=rhi et QSG_RHI_BACKEND=opengl pour un rendu fidèle, comme l'essai de la presqu'île).
        // Entrée : chemin, fichier à écrire. Sortie : aucune ; le fichier paraît une fois l'image saisie.
        // Erreurs : « galerie-essai : aucune fenêtre » ou « galerie-essai : capture non écrite » au journal.
        // Dépendances : fenetre, grabToImage.
        function capturer(chemin: string): void {
            if (!fenetre.item) return console.warn("galerie-essai : aucune fenêtre")
            fenetre.item.vue.grabToImage(r => { if (!r.saveToFile(chemin)) console.warn("galerie-essai : capture non écrite") })
        }
    }
}
