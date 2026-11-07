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
// capturer, changer, charger, changementEtat (les listes et objets sont rendus en JSON, le reste en texte). Une Scene sans
// fenêtre, montée sur les bureaux d'essai, journalise chaque image de ses changements de module (« essai : … »).
// Sortie : le résultat de chaque appel IPC, sur la sortie de « qs ipc call » ; au journal, les lignes « essai : phase
// …», « essai : contenu … », « essai : lp … » (largeur au changement de phase), « essai : l … », « essai : cl … » (cible de largeur), « essai : h … » et « essai : o … » de la scène. Erreurs : celles de Theme, dans
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

    // Modules de la scène d'essai : les bureaux, sans Hyprland, et un module factice « grand » de taille connue.
    Component { id: moduleBureaux; Bureaux { objectName: "bureaux"; idActif: 0; special: "" } }
    Component { id: moduleGrand; Item { objectName: "grand"; property var ecran; implicitWidth: 400; implicitHeight: 80 } }
    // Module « tardif » : 1000 × 80 au montage, 400 × 80 quand l'essai appelle charger, comme un contenu dont la taille
    // n'est connue qu'après coup.
    Component {
        id: moduleTardif
        Item { objectName: "tardif"; property var ecran; property bool charge: false; implicitWidth: charge ? 400 : 1000; implicitHeight: 80 }
    }

    // Scène sans fenêtre, comme celle de la surface : sa trajectoire est lue par tests/test_presquile.py.
    Scene { id: essaiScene; module: moduleBureaux }
    Connections {
        target: essaiScene
        // La largeur au moment du passage : la scène change de phase avant que la trace de l'image ne soit écrite.
        function onPhaseChanged() {
            console.info("essai : phase " + essaiScene.phase)
            console.info("essai : lp " + essaiScene.ressortLargeur.value)
        }
        function onContenuChanged() { console.info("essai : contenu " + (essaiScene.contenu?.objectName ?? "")) }
        // Hauteur réservée par la surface : elle ne doit changer qu'au départ d'un agrandissement et à l'arrêt.
        function onHauteurSurfaceChanged() { console.info("essai : hs " + essaiScene.hauteurSurface) }
    }
    Connections {
        target: essaiScene.ressortLargeur
        function onValueChanged() { console.info("essai : l " + essaiScene.ressortLargeur.value) }
        function onCibleChanged() { console.info("essai : cl " + essaiScene.ressortLargeur.cible) }
    }
    Connections {
        target: essaiScene.ressortHauteur
        function onValueChanged() { console.info("essai : h " + essaiScene.ressortHauteur.value) }
    }
    Connections {
        target: essaiScene.ressortOpacite
        function onValueChanged() { console.info("essai : o " + essaiScene.ressortOpacite.value) }
    }

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

        // montage — rejoue le montage de la surface : un Ressort « window » créé avant son module, dont la cible suit
        // la taille du module, est posé dès que le module existe. Entrées : n largeur du module.
        // Sortie : JSON {valeur, mobile} lu aussitôt. Erreurs : aucune. Dépendances : Ressort, Item.
        function montage(n: real): string {
            const r = Qt.createQmlObject('import QtQuick\nimport "Theme"\nRessort { property Item c: null; transition: "window"; cible: c?.implicitWidth ?? 0 }', essaiEncoche, "montage.qml")
            r.c = Qt.createQmlObject('import QtQuick\nItem { implicitWidth: ' + n + ' }', essaiEncoche, "module.qml")
            r.poser()
            return JSON.stringify({ valeur: r.value, mobile: r.moving })
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

        // tracerEncoche — tracé d'une Encoche éphémère aux dimensions explicites, indépendante des jetons.
        // Entrées : l, largeur du corps ; h, hauteur ; e, évasement ; r, rayon (px logiques).
        // Sortie : le tracé SVG. Erreurs : aucune. Dépendances : Encoche.
        function tracerEncoche(l: real, h: real, e: real, r: real): string {
            return essaiEncoche.tracer(l, h, e, r)
        }

        // bureauxEtat — pose idActif et special du module des bureaux d'essai (jamais Hyprland) et rend son état.
        // Entrées : idActif ; special, nom du spécial ouvert ou « - » pour aucun ; survol, index du point survolé ou −1.
        // Sortie : JSON {largeurs, couleurs, accentDiscret, textTertiary, largeur, hauteur} : largeurs et couleurs cibles de chaque point, et dimensions implicites, largeurs réelles (ressorts), zones de clic [début, fin] et centres de chaque point dans le module (déduits des largeurs réelles).
        // Erreurs : aucune. Dépendances : Bureaux.
        function bureauxEtat(idActif: int, special: string, survol: int): string {
            const b = essaiBureaux, p = Array.from({ length: b.nombre }, (_, i) => b.points.itemAt(i))
            b.idActif = idActif
            b.special = special === "-" ? "" : special
            b.survol = survol
            // Positions déduites des largeurs réelles (la rangée se replace au passage de mise en page, absent hors écran).
            let x = b.gabarit.marge
            const zones = [], centres = []
            p.forEach(pt => {
                zones.push([x + pt.zoneClic.x, x + pt.zoneClic.x + pt.zoneClic.width])
                centres.push(x + pt.width / 2)
                x += pt.width + b.gabarit.ecart
            })
            return JSON.stringify({ largeurs: p.map(x => x.largeurCible), couleurs: p.map(x => String(x.couleurCible)),
                                    accentDiscret: String(Theme.color.accentDiscret),
                                    textTertiary: String(Theme.color.textTertiary), largeur: b.implicitWidth,
                                    hauteur: b.implicitHeight,
                                    reelles: p.map(x => x.width),
                                    zones: zones, centres: centres })
        }

        // changer — change le module de la scène d'essai, ce qui déroule la séquence de changement.
        // Entrée : nom, « grand » ou « tardif » pour les modules factices, tout autre nom pour les bureaux. Sortie : aucune.
        // Erreurs : aucune. Dépendances : essaiScene, moduleGrand, moduleBureaux.
        function changer(nom: string): void {
            essaiScene.module = nom === "grand" ? moduleGrand : nom === "tardif" ? moduleTardif : moduleBureaux
        }

        // charger — donne au module « tardif » monté sa taille définitive. Entrées : aucune. Sortie : aucune.
        // Erreurs : sans effet sur un autre module. Dépendances : essaiScene.
        function charger(): void { if (essaiScene.contenu?.objectName === "tardif") essaiScene.contenu.charge = true }

        // changementEtat — photographie de la scène d'essai.
        // Entrées : aucune. Sortie : JSON {phase, opacite, largeur, hauteur, contenu (objectName du module monté),
        // mobile (vrai si l'un des trois ressorts avance)}. Erreurs : aucune. Dépendances : essaiScene.
        function changementEtat(): string {
            const s = essaiScene, l = s.ressortLargeur, h = s.ressortHauteur, o = s.ressortOpacite
            return JSON.stringify({ phase: s.phase, opacite: o.value, largeur: l.value, hauteur: h.value,
                                    contenu: s.contenu?.objectName ?? null, mobile: l.moving || h.moving || o.moving })
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
