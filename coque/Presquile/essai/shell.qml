import QtQuick
import Quickshell
import Quickshell.Io
import "Theme"
import "Presquile"
import "Presquile/bureaux.js" as Bureaux

// Coque d'essai du module Presquile.
// Rôle : expose par IPC (cible « presquile ») les fonctions pures de bureaux.js et la géométrie d'une Encoche sans
// fenêtre, pour que tests/test_presquile.py les éprouve dans un vrai Quickshell ; sous la plateforme offscreen
// seulement, ouvre une vitrine (FloatingWindow jamais montrée à l'écran) qui porte une Encoche au corps de la
// planche forme.html (106), sur le fond du bureau, avec la marge de son ombre, et l'enregistre en PNG à la demande.
// Les tâches suivantes y ajoutent leurs composants et leurs fonctions IPC.
// Entrées : DUNEI_TOKENS_DIR, lu par Theme ; QT_QPA_PLATFORM, posé à offscreen par le test ; QT_SCALE_FACTOR, pour
// une capture agrandie ; QT_QUICK_BACKEND=rhi et QSG_RHI_BACKEND=opengl pour une capture fidèle (la plateforme
// offscreen choisit sinon le rendu logiciel, qui ne peint ni shader ni remplissage par texture). Commandes IPC :
// indexPilule, pasMolette, cibleMolette, lireSpecial, commandesClic, commandeBureau, bureauxEtat, encoche, etirerEncoche,
// capturer (les listes et objets sont rendus en JSON, le reste en texte).
// Sortie : le résultat de chaque appel IPC, sur la sortie de « qs ipc call ». Erreurs : celles de Theme, dans
// le journal ; capturer sans vitrine (hors offscreen) journalise « presquile : aucune vitrine ».
// Dépendances : quickshell ≥ 0.3 (Quickshell.Io, FloatingWindow, LazyLoader), modules Theme, Composants et
// Presquile.
// Import : liens essai/Theme, essai/Composants et essai/Presquile, comme dans les autres coques d'essai.
ShellRoot {
    // Theme est un singleton paresseux : cette lecture le charge, ce qu'attend le setUp de l'essai.
    Component.onCompleted: Theme.tokens

    // Encoche sans fenêtre, de corps 96 : sa géométrie seule est éprouvée.
    Encoche { id: essaiEncoche; largeurCorps: 96 }

    // Module des bureaux sans fenêtre et sans Hyprland : idActif et special, écrits par l'IPC, remplacent leurs
    // liaisons par défaut dès la création, et rien ici n'appelle Hyprland.dispatch.
    Bureaux { id: essaiBureaux; ecran: null; idActif: 0; special: "" }

    LazyLoader {
        id: vitrine
        activeAsync: Theme.ready && Qt.platform.pluginName === "offscreen"

        FloatingWindow {
            property Item cadre: fond
            implicitWidth: fond.width
            implicitHeight: fond.height
            color: "transparent"

            // Fond du bureau, sous l'encoche collée à son bord haut, avec la marge de l'ombre autour.
            Rectangle {
                id: fond
                width: forme.implicitWidth + 2 * forme.marge
                height: forme.implicitHeight + forme.marge
                color: Theme.elevation?.e0?.fill ?? "transparent"

                Encoche { id: forme; largeurCorps: 106; anchors.horizontalCenter: parent.horizontalCenter }
            }
        }
    }

    IpcHandler {
        target: "presquile"

        function indexPilule(idActif: int, nombre: int): int { return Bureaux.indexPilule(idActif, nombre) }
        function pasMolette(cumul: real, delta: real): string { return JSON.stringify(Bureaux.pasMolette(cumul, delta)) }
        function cibleMolette(idActif: int, pas: int, nombre: int): int { return Bureaux.cibleMolette(idActif, pas, nombre) }
        function lireSpecial(donnees: string): string { return Bureaux.lireSpecial(donnees) }
        function commandeBureau(id: int): string { return Bureaux.commandeBureau(id) }
        function commandesClic(id: int, idActif: int, special: string): string {
            return JSON.stringify(Bureaux.commandesClic(id, idActif, special))
        }

        // encoche — géométrie de l'Encoche sans fenêtre. Sortie : JSON {largeur, hauteur, corpsX, corpsLargeur,
        // corpsHauteur, trace}. Erreurs : aucune. Dépendances : Encoche.
        function encoche(): string {
            const e = essaiEncoche
            return JSON.stringify({ largeur: e.implicitWidth, hauteur: e.implicitHeight, corpsX: e.corps.x,
                                    corpsLargeur: e.corps.width, corpsHauteur: e.corps.height, trace: e.trace })
        }

        // etirerEncoche — porte le corps de l'Encoche sans fenêtre à une largeur. Entrée : l, px logiques.
        // Sortie : la géométrie, comme encoche. Erreurs : aucune. Dépendances : encoche, Encoche.
        function etirerEncoche(l: real): string { essaiEncoche.largeurCorps = l; return encoche() }

        // bureauxEtat — pose idActif et special du module des bureaux d'essai (jamais Hyprland) et rend son état.
        // Entrées : idActif ; special, nom du spécial ouvert ou « - » pour aucun. Sortie : JSON {largeurs, couleurs,
        // accentDiscret, largeur, hauteur} : largeurs et couleurs cibles de chaque point, et dimensions implicites.
        // Erreurs : aucune. Dépendances : Bureaux.
        function bureauxEtat(idActif: int, special: string): string {
            const b = essaiBureaux, p = Array.from({ length: b.nombre }, (_, i) => b.points.itemAt(i))
            b.idActif = idActif
            b.special = special === "-" ? "" : special
            return JSON.stringify({ largeurs: p.map(x => x.largeurCible), couleurs: p.map(x => String(x.couleurCible)),
                                    accentDiscret: String(Theme.color.accentDiscret), largeur: b.implicitWidth,
                                    hauteur: b.implicitHeight })
        }

        // capturer — enregistre la vitrine en PNG, de façon asynchrone. Entrée : chemin, fichier à écrire.
        // Sortie : aucune ; le fichier paraît une fois l'image saisie. Erreurs : « presquile : aucune vitrine » au
        // journal hors offscreen ; un échec d'écriture se lit au journal. Dépendances : vitrine, grabToImage.
        function capturer(chemin: string): void {
            if (!vitrine.item) return console.warn("presquile : aucune vitrine")
            vitrine.item.cadre.grabToImage(r => {
                if (!r.saveToFile(chemin)) console.warn("presquile : capture non écrite")
            })
        }
    }
}
