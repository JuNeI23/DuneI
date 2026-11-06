import QtQuick
import Quickshell
import Quickshell.Io
import "Theme"
import "Fond"

// Coque d'essai du module Fond.
// Rôle : sous la plateforme offscreen seulement, ouvre une vitrine (FloatingWindow jamais montrée à l'écran) qui porte
// un
// Affichage dès le lancement, donc avant la première lecture de bureau.json, journalise chaque étape de sa machine
// d'états
// et l'expose par IPC (cible « fond ») à tests/test_fond.py.
// Entrées : DUNEI_TOKENS_DIR, lu par Theme ; QT_QPA_PLATFORM, posé à offscreen par le test ; ESSAI_FOND_SANS_TAILLE,
// non
// vide pour ouvrir la vitrine avec un Affichage de taille nulle. Commandes IPC : etat, demander, demanderDeux, taille,
// tailleEtDemande, brancher.
// Sortie : le résultat de chaque appel IPC sur la sortie de « qs ipc call » ; au journal, des lignes « essai : … ».
// Erreurs : celles de Theme et d'Affichage, dans le journal ; une commande IPC sans vitrine rend ou journalise une
// erreur.
// Dépendances : quickshell ≥ 0.3 (Quickshell.Io, FloatingWindow, LazyLoader), modules Theme et Fond.
// Import : liens essai/Theme et essai/Fond, comme dans les autres coques d'essai.
ShellRoot {
    // Theme est un singleton paresseux : cette lecture le charge, ce qu'attend le setUp de l'essai.
    Component.onCompleted: Theme.tokens

    // La vitrine ne dépend pas de Theme.ready : l'Affichage doit exister avant que bureau.json ne soit lu.
    LazyLoader {
        id: vitrine
        active: Qt.platform.pluginName === "offscreen"

        FloatingWindow {
            id: fenetre
            property alias affichage: aff
            property int largeur: Quickshell.env("ESSAI_FOND_SANS_TAILLE") ? 0 : 640
            property int hauteur: Quickshell.env("ESSAI_FOND_SANS_TAILLE") ? 0 : 400
            implicitWidth: 640
            implicitHeight: 400
            color: Theme.bureau?.fond ?? "transparent"

            Affichage { id: aff; width: fenetre.largeur; height: fenetre.hauteur }

            // Trajectoire lue par les tests : chaque passage d'état, publication et mouvement de la couche haute.
            Connections {
                target: aff
                function onEtatChanged() { console.info("essai : etat " + aff.etat) }
                function onImageAfficheeChanged() { console.info("essai : image " + aff.imageAffichee) }
            }
            Connections {
                target: Theme
                function onFondPublieChanged() { console.info("essai : publie " + Theme.fondPublie) }
                function onFondFichierChanged() { console.info("essai : fichier " + Theme.fondFichier) }
                function onMouvementReduitChanged() { console.info("essai : reduit " + Theme.mouvementReduit) }
            }
            Connections {
                target: aff.coucheHaute
                function onYChanged() { console.info("essai : y " + aff.coucheHaute.y) }
                function onOpacityChanged() { console.info("essai : opacite " + aff.coucheHaute.opacity) }
                // Le statut de la base accompagne la ligne : le journal de la base suit le gestionnaire de
                // l'Affichage, qui
                // vide la couche haute pendant la même émission.
                function onSourceChanged() {
                    console.info("essai : haut " + aff.coucheHaute.source + " base " + aff.coucheBasse.status)
                }
            }
            Connections {
                target: aff.coucheBasse
                function onStatusChanged() {
                    console.info("essai : base " + aff.coucheBasse.status + " largeur " + aff.coucheBasse.implicitWidth)
                }
            }
        }
    }

    // Second Affichage, créé à la demande : un écran branché après le démarrage, quand bureau.json est déjà lu.
    LazyLoader {
        id: second
        active: false
        Affichage { width: 320; height: 200; echelle: 2 }
    }

    IpcHandler {
        target: "fond"

        // etat — photographie de l'Affichage et de ce qu'il publie.
        // Entrées : aucune. Sortie : JSON {etat, imageAffichee, enAttente, fondPublie, y, opacite, haut, base,
        // statutBase,
        // largeurBase, hauteurBase, source (largeur de sourceSize), second (image du second Affichage, ou null),
        // sourceSecond (sa
        // largeur de sourceSize, ou null)}.
        // Erreurs : « null » tant que la vitrine n'existe pas. Dépendances : vitrine, second, Theme.
        function etat(): string {
            const a = vitrine.item?.affichage
            if (!a) return "null"
            const h = a.coucheHaute, b = a.coucheBasse
            return JSON.stringify({ etat: a.etat, imageAffichee: a.imageAffichee, enAttente: a.enAttente,
                                    fondPublie: Theme.fondPublie, y: h.y, opacite: h.opacity, haut: h.source.toString(),
                                    base: b.source.toString(), statutBase: b.status, largeurBase: b.implicitWidth,
                                    hauteurBase: b.implicitHeight, source: b.sourceSize.width,
                                    second: second.item?.imageAffichee ?? null,
                                    sourceSecond: second.item?.coucheBasse.sourceSize.width ?? null })
        }

        // demander — pose une demande dans Theme sans passer par le disque, comme la lecture de bureau.json.
        // Entrées : image, chemin ; fond, #rrggbb. Sortie : aucune. Erreurs : aucune. Dépendances : Theme.
        function demander(image: string, fond: string): void {
            Theme.fondFichier = fond
            Theme.imageBureau = image
        }

        // demanderDeux — pose deux demandes dans le même tour de boucle : la première est forcément encore en
        // chargement
        // quand la seconde arrive, ce qu'un test ne garantirait pas par deux appels ou deux écritures.
        // Entrées : image1, fond1, image2, fond2. Sortie : aucune. Erreurs : aucune. Dépendances : demander.
        function demanderDeux(image1: string, fond1: string, image2: string, fond2: string): void {
            demander(image1, fond1)
            demander(image2, fond2)
        }

        // taille — redimensionne l'Affichage de la vitrine.
        // Entrées : largeur, hauteur en pixels logiques. Sortie : aucune. Erreurs : aucune. Dépendances : vitrine.
        function taille(largeur: int, hauteur: int): void {
            vitrine.item.largeur = largeur
            vitrine.item.hauteur = hauteur
        }

        // tailleEtDemande — donne sa taille à un Affichage qui l'attendait, puis pose une demande juste après : la
        // pose du
        // démarrage, lancée au même tour différé, charge forcément encore à son arrivée.
        // Entrées : largeur, hauteur, image, fond. Sortie : aucune. Erreurs : aucune. Dépendances : taille, demander.
        function tailleEtDemande(largeur: int, hauteur: int, image: string, fond: string): void {
            taille(largeur, hauteur)
            Qt.callLater(() => demander(image, fond))
        }

        // brancher — crée le second Affichage, comme un écran branché après le démarrage.
        // Entrées : aucune. Sortie : aucune. Erreurs : aucune. Dépendances : second.
        function brancher(): void { second.active = true }
    }
}
