import QtQuick
import Quickshell
import Quickshell.Io
import "Theme"
import "Presquile"
import "Presquile/bureaux.js" as Bureaux
import "Presquile/encoche.js" as Forme
import "Audio"

// Coque d'essai du module Presquile.
// Rôle : expose par IPC (cible « presquile ») les fonctions pures de bureaux.js et la géométrie d'une Encoche sans
// fenêtre, pour que tests/test_presquile.py les éprouve dans un vrai Quickshell ; sous la plateforme offscreen
// seulement, ouvre une vitrine (FloatingWindow jamais montrée à l'écran) qui porte une Encoche au corps de la
// planche forme.html (106), sur le fond du bureau, avec la marge de son ombre, et l'enregistre en PNG à la demande.
// Les commandes arbitreDemander, arbitreLiberer et arbitreEtat éprouvent l'Arbitre ; annonceurRafale,
// annonceurPleinEcran et annonceurEtat, l'Annonceur, piloté par une source et une presqu'île factices ; alerteAnnoncer,
// alerteEffacer, alertePleinEcran, alerteEcran, alerteDemander, alerteLiberer, alertePhase et alerteEtat, l'AnnonceurAlerte, piloté
// par une source et deux presqu'îles factices ; alerteModule, le rendu du module Alerte réel ;
// volumeAnnoncer, volumeMicro, volumeSourdine, volumeNiveau et volumeEtat, le module Volume réel dans une scène sans fenêtre (débord
// du remplissage hors de l'encoche, jointures, disposition du son coupé) ; audioTenir et audioPopover, le compte des
// popovers audio ouverts d'EtatAudio. Les tâches suivantes y ajoutent leurs composants et leurs fonctions IPC.
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
// Presquile (dont encoche.js).
// Import : liens essai/Theme, essai/Composants et essai/Presquile, comme dans les autres coques d'essai ; essai/Audio et
// essai/Barre, que résolvent les imports relatifs de l'Annonceur et du module Volume ; essai/Energie, celui de
// l'AnnonceurAlerte.
ShellRoot {
    // Theme est un singleton paresseux : cette lecture le charge, ce qu'attend le setUp de l'essai.
    Component.onCompleted: Theme.tokens

    // Encoche sans fenêtre, de corps 96 : sa géométrie seule est éprouvée.
    Encoche { id: essaiEncoche; largeurCorps: 96 }

    // Module des bureaux sans fenêtre et sans Hyprland : idActif et special, écrits par l'IPC, remplacent leurs
    // liaisons par défaut dès la création, et rien ici n'appelle Hyprland.dispatch.
    Bureaux { id: essaiBureaux; ecran: null; idActif: 0; special: "" }

    // Modules de la scène d'essai : les bureaux, sans Hyprland, et un module factice « grand » de taille connue.
    // Chaque module d'essai journalise sa destruction (« detruit <nom> ») : aucun contenu ne doit rester orphelin.
    Component {
        id: moduleBureaux
        Bureaux {
            objectName: "bureaux"; idActif: 0; special: ""
            Component.onDestruction: console.info("essai : detruit bureaux")
        }
    }
    Component {
        id: moduleGrand
        Item {
            objectName: "grand"; property var ecran; implicitWidth: 400; implicitHeight: 80
            Component.onDestruction: console.info("essai : detruit grand")
        }
    }
    // Module « tardif » : 1000 × 80 au montage, 400 × 80 quand l'essai appelle charger, comme un contenu dont la taille
    // n'est connue qu'après coup.
    Component {
        id: moduleTardif
        Item { objectName: "tardif"; property var ecran; property bool charge: false; implicitWidth: charge ? 400 : 1000; implicitHeight: 80 }
    }

    // Arbitre sans fenêtre, au module par défaut des bureaux, et deux modules factices « volume » et « galerie » ;
    // changements compte les fois où le module arbitré change, c'est-à-dire les remontages que subirait la scène.
    Component {
        id: moduleVolume
        Item { objectName: "volume"; property var ecran; implicitWidth: 60; implicitHeight: 28 }
    }
    Component {
        id: moduleGalerie
        Item { objectName: "galerie"; property var ecran; implicitWidth: 400; implicitHeight: 28 }
    }
    Arbitre {
        id: essaiArbitre
        property int changements: 0
        onModuleChanged: changements++
    }

    // Annonceur d'essai, sans Hyprland ni PipeWire : une source factice émet les annonces, et une presqu'île factice
    // (sans écran, comme ecranActif) relaie ses demandes à un arbitre qui compte les changements de module (les
    // montages que subirait la scène) et les libérations.
    QtObject { id: essaiSource; signal annoncer(var annonce) }
    Arbitre {
        id: arbitreAnnonce
        property int changements: 0
        onModuleChanged: changements++
    }
    QtObject {
        id: essaiIle
        property var modelData: null
        property int liberations: 0

        // demander — relaie une demande à l'arbitre de l'annonceur d'essai. Entrées : cle, composant, priorite.
        // Sortie : aucune. Erreurs : aucune. Dépendances : arbitreAnnonce.
        function demander(cle, composant, priorite) { arbitreAnnonce.demander(cle, composant, priorite) }

        // liberer — compte la libération et la relaie à l'arbitre. Entrée : cle. Sortie : aucune. Erreurs : aucune.
        // Dépendances : arbitreAnnonce.
        function liberer(cle) { liberations++; arbitreAnnonce.liberer(cle) }
    }
    Annonceur {
        id: essaiAnnonceur
        etat: essaiSource
        ecranActif: null
        pleinEcran: false
        volume: moduleVolume
        Component.onCompleted: inscrire(essaiIle)
    }
    // Annonceur de l'alerte d'énergie, sans Hyprland ni UPower : une source factice émet annoncer et effacer, et deux
    // presqu'îles factices, aux écrans « A » et « B » (des noms, comme ecranActif), portent chacune un arbitre réel.
    // montees compte les fois où le module Alerte devient le module arbitré d'une presqu'île.
    QtObject { id: sourceAlerte; signal annoncer(int palier); signal effacer() }
    component IleAlerte: QtObject {
        property var modelData
        // Phase de la séquence de changement, posée par l'IPC (alertePhase) : « repos » tient le module pour posé.
        property string phase: "repos"
        readonly property Arbitre arbitre: Arbitre {}
        readonly property Component module: arbitre.module

        // demander — relaie une demande à l'arbitre de la presqu'île factice. Entrées : cle, composant, priorite.
        // Sortie : aucune. Erreurs : aucune. Dépendances : arbitre.
        function demander(cle, composant, priorite) { arbitre.demander(cle, composant, priorite) }

        // liberer — relaie une libération à l'arbitre. Entrée : cle. Sortie : aucune. Erreurs : aucune.
        // Dépendances : arbitre.
        function liberer(cle) { arbitre.liberer(cle) }
    }
    IleAlerte { id: ileA; modelData: "A"; onModuleChanged: if (module === essaiAlerte.alerte) essaiAlerte.montees++ }
    IleAlerte { id: ileB; modelData: "B"; onModuleChanged: if (module === essaiAlerte.alerte) essaiAlerte.montees++ }
    AnnonceurAlerte {
        id: essaiAlerte
        property int montees: 0
        etat: sourceAlerte
        ecranActif: "A"
        pleinEcran: false
        galerie: moduleGalerie
        Component.onCompleted: { inscrire(ileA); inscrire(ileB) }
    }
    // Scène d'essai du module Volume réel (EtatAudio lu en lecture seule ; l'essai n'écrit que annonceCourante, dans
    // ce processus) : depassement retient, image par image, le plus grand débord du remplissage hors du corps.
    // Le niveau et la sourdine du module viennent de la scène d'essai, que l'IPC écrit, et non de PipeWire.
    Component { id: moduleAlerteReel; Alerte {} }
    Component { id: moduleVolumeReel; Volume { objectName: "volume"; muet: sceneVolume.muetEssai; niveauSon: sceneVolume.niveauEssai } }
    Scene {
        id: sceneVolume
        property real depassement: 0
        property bool muetEssai: false
        property int niveauEssai: 50
        readonly property real evasement: Theme.tokens?.presquile?.evasement ?? 0

        // bords — bords gauche et droit de toute la partie remplie (corps et évasements), dans le repère de la scène.
        // Entrées : aucune. Sortie : {gauche, droite}, droite égal à gauche quand rien n'est rempli ; null sans module.
        // Erreurs : aucune. Dépendances : Volume (remplie, flanc).
        function bords() {
            const v = contenu, r = v?.remplie, f = v?.flanc
            if (!r) return null
            const g = v.x + r.x
            return { gauche: g, droite: Math.max(g + r.width, f.visible ? v.x + f.x + f.width : -Infinity) }
        }

        // mesurer — retient le débord courant du remplissage hors de l'encoche (corps et évasements), en px logiques.
        // Entrées : aucune. Sortie : met à jour depassement. Erreurs : aucune, sans module monté. Dépendances : bords.
        function mesurer() {
            const b = bords()
            if (b) depassement = Math.max(depassement, -evasement - b.gauche, b.droite - width - evasement)
        }
    }
    Connections {
        target: sceneVolume.ressortLargeur
        function onValueChanged() { sceneVolume.mesurer() }
    }
    Connections {
        target: sceneVolume.contenu?.remplissage ?? null
        ignoreUnknownSignals: true
        function onValueChanged() { sceneVolume.mesurer() }
    }

    // Rafale : count annonces de volume, une toutes les interval millisecondes.
    Timer {
        id: rafale
        property int reste: 0
        repeat: true
        onTriggered: {
            essaiSource.annoncer({ genre: "volume", appareil: "", texte: "", coupe: false })
            if (--reste <= 0) stop()
        }
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
        function onSortantChanged() { console.info("essai : sortant " + (essaiScene.sortant?.objectName ?? "")) }
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
        target: essaiScene.ressortSortant
        // Valeur puis vitesse, pour vérifier que le fondu continue sans rupture de vitesse à la cession.
        function onValueChanged() {
            const r = essaiScene.ressortSortant
            console.info("essai : so " + r.value + " " + r.vitesse())
        }
    }
    Connections {
        target: essaiScene.ressortOpacite
        function onValueChanged() {
            const r = essaiScene.ressortOpacite
            console.info("essai : o " + r.value + " " + r.vitesse())
        }
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

        // tracerEncoche — tracé de l'encoche aux dimensions explicites, indépendant des jetons.
        // Entrées : l, largeur du corps ; h, hauteur ; e, évasement ; r, rayon (px logiques).
        // Sortie : le tracé SVG. Erreurs : aucune. Dépendances : encoche.js.
        function tracerEncoche(l: real, h: real, e: real, r: real): string {
            return Forme.tracer(l, h, e, r)
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

        // arbitreDemander — relaie une demande à l'arbitre d'essai. Entrées : cle ; nom, « volume » ou « galerie » ;
        // priorite. Sortie : aucune. Erreurs : aucune. Dépendances : essaiArbitre.
        function arbitreDemander(cle: string, nom: string, priorite: int): void {
            essaiArbitre.demander(cle, nom === "volume" ? moduleVolume : moduleGalerie, priorite)
        }

        // arbitreLiberer — retire une demande de l'arbitre d'essai. Entrée : cle. Sortie : aucune. Erreurs : aucune.
        // Dépendances : essaiArbitre.
        function arbitreLiberer(cle: string): void { essaiArbitre.liberer(cle) }

        // arbitreEtat — module arbitré. Entrées : aucune. Sortie : JSON {module (« volume », « galerie » ou
        // « bureaux »), changements (nombre de changements de module depuis le démarrage)}. Erreurs : aucune.
        // Dépendances : essaiArbitre.
        function arbitreEtat(): string {
            const m = essaiArbitre.module
            return JSON.stringify({ module: m === moduleVolume ? "volume" : m === moduleGalerie ? "galerie" : "bureaux",
                                    changements: essaiArbitre.changements })
        }

        // annonceurRafale — émet n annonces de volume, la première aussitôt, puis une toutes les ms millisecondes.
        // Entrées : n, nombre d'annonces (au moins 1) ; ms, intervalle. Sortie : aucune. Erreurs : aucune.
        // Dépendances : essaiSource, rafale.
        function annonceurRafale(n: int, ms: int): void {
            essaiSource.annoncer({ genre: "volume", appareil: "", texte: "", coupe: false })
            rafale.reste = n - 1
            rafale.interval = ms
            if (rafale.reste > 0) rafale.start()
        }

        // annonceurPleinEcran — pose le plein écran vu par l'annonceur d'essai. Entrée : b. Sortie : aucune.
        // Erreurs : aucune. Dépendances : essaiAnnonceur.
        function annonceurPleinEcran(b: bool): void { essaiAnnonceur.pleinEcran = b }

        // annonceurEtat — état de l'annonceur d'essai. Entrées : aucune. Sortie : JSON {module (« volume » ou
        // « bureaux »), changements, liberations, cible (vrai si une presqu'île porte la jauge)}. Erreurs : aucune.
        // Dépendances : arbitreAnnonce, essaiIle, essaiAnnonceur.
        function annonceurEtat(): string {
            return JSON.stringify({ module: arbitreAnnonce.module === moduleVolume ? "volume" : "bureaux",
                                    changements: arbitreAnnonce.changements, liberations: essaiIle.liberations,
                                    cible: essaiAnnonceur.cible !== null })
        }

        // alerteAnnoncer — émet une annonce de la source factice de l'alerte. Entrée : palier (1 ou 2). Sortie : aucune.
        // Erreurs : aucune. Dépendances : sourceAlerte.
        function alerteAnnoncer(palier: int): void { sourceAlerte.annoncer(palier) }

        // alerteEffacer — émet l'effacement de la source factice (branchement). Entrées : aucune. Sortie : aucune.
        // Erreurs : aucune. Dépendances : sourceAlerte.
        function alerteEffacer(): void { sourceAlerte.effacer() }

        // alertePleinEcran — pose le plein écran vu par l'annonceur de l'alerte. Entrée : b. Sortie : aucune.
        // Erreurs : aucune. Dépendances : essaiAlerte.
        function alertePleinEcran(b: bool): void { essaiAlerte.pleinEcran = b }

        // alerteEcran — pose l'écran actif vu par l'annonceur de l'alerte. Entrée : nom (« A » ou « B »).
        // Sortie : aucune. Erreurs : aucune. Dépendances : essaiAlerte.
        function alerteEcran(nom: string): void { essaiAlerte.ecranActif = nom }

        // alerteDemander — demande un module factice à une presqu'île de l'alerte, à sa priorité de la coque (galerie 3,
        // volume 1). Entrées : ile (« A » ou « B ») ; cle (« galerie » ou « volume »). Sortie : aucune.
        // Erreurs : aucune. Dépendances : ileA, ileB, moduleGalerie, moduleVolume.
        function alerteDemander(ile: string, cle: string): void {
            (ile === "A" ? ileA : ileB).demander(cle, cle === "galerie" ? moduleGalerie : moduleVolume, cle === "galerie" ? 3 : 1)
        }

        // alertePhase — pose la phase de la séquence de changement d'une presqu'île de l'alerte. Entrées : ile (« A »
        // ou « B ») ; phase (« repos », « sortie », « forme » ou « entree »). Sortie : aucune. Erreurs : aucune.
        // Dépendances : ileA, ileB.
        function alertePhase(ile: string, phase: string): void { (ile === "A" ? ileA : ileB).phase = phase }

        // alerteLiberer — libère la demande d'une clé sur une presqu'île de l'alerte. Entrées : ile, cle.
        // Sortie : aucune. Erreurs : aucune. Dépendances : ileA, ileB.
        function alerteLiberer(ile: string, cle: string): void { (ile === "A" ? ileA : ileB).liberer(cle) }

        // alerteEtat — état de l'annonceur de l'alerte. Entrées : aucune. Sortie : JSON {A, B (module arbitré de chaque
        // presqu'île : « alerte », « galerie », « volume » ou « bureaux »), enAttente, affiche, cible (« A », « B » ou
        // vide), montees}. Erreurs : aucune. Dépendances : essaiAlerte, ileA, ileB.
        function alerteEtat(): string {
            const nom = m => m === essaiAlerte.alerte ? "alerte" : m === moduleGalerie ? "galerie"
                : m === moduleVolume ? "volume" : "bureaux"
            return JSON.stringify({ A: nom(ileA.module), B: nom(ileB.module), enAttente: essaiAlerte.enAttente,
                                    affiche: essaiAlerte.affiche, cible: essaiAlerte.cible?.modelData ?? "",
                                    montees: essaiAlerte.montees })
        }

        // alerteModule — crée un module Alerte réel hors fenêtre, en relève le rendu et le détruit.
        // Entrée : palier (1 ou 2). Sortie : JSON {icone, texte, couleurIcone, couleurTexte, warning, error (couleurs
        // des rôles du thème), hauteur, gabarit (hauteur de la presqu'île), largeur, contenu (symbole, écart et texte)}.
        // Erreurs : aucune. Dépendances : moduleAlerteReel, Theme.
        function alerteModule(palier: int): string {
            const a = moduleAlerteReel.createObject(null, { ecran: null, palier })
            const r = { icone: a.symbole.nom, texte: a.message.text, couleurIcone: String(a.symbole.couleur),
                        couleurTexte: String(a.message.color), warning: String(Theme.color.warning),
                        error: String(Theme.color.error), hauteur: a.implicitHeight,
                        gabarit: Theme.tokens.presquile.hauteur, largeur: a.implicitWidth,
                        contenu: a.symbole.width + 6 + a.message.implicitWidth }
            a.destroy()
            return JSON.stringify(r)
        }

        // volumeAnnoncer — pose l'annonce courante d'EtatAudio dans ce processus et monte le module Volume réel dans sa
        // scène d'essai. Entrées : genre (« volume », « micro », « sortie » ou « entree ») ; texte, le libellé.
        // Sortie : aucune. Erreurs : aucune. Dépendances : EtatAudio, sceneVolume, moduleVolumeReel.
        function volumeAnnoncer(genre: string, texte: string): void {
            EtatAudio.annonceCourante = { genre, appareil: genre === "micro" ? "" : "audio-speakers", texte, coupe: false }
            sceneVolume.module = moduleVolumeReel
        }

        // volumeMicro — rebascule l'annonce de micro courante, module monté. Entrée : coupe, vrai pour « Micro coupé ».
        // Sortie : aucune. Erreurs : aucune. Dépendances : EtatAudio.
        function volumeMicro(coupe: bool): void {
            EtatAudio.annonceCourante = { genre: "micro", appareil: "", texte: coupe ? "Micro coupé" : "Micro actif", coupe }
        }

        // volumeEtat — photographie de la scène du Volume. Entrées : aucune. Sortie : JSON {depassement (débord
        // maximal du remplissage hors du corps depuis le départ), largeurScene, largeurModule, phase, mobile}.
        // Erreurs : aucune. Dépendances : sceneVolume.
        function volumeEtat(): string {
            const s = sceneVolume, v = s.contenu
            s.mesurer()
            const b = s.bords()
            return JSON.stringify({ depassement: s.depassement, largeurScene: s.width, evasement: s.evasement,
                                    largeurModule: v?.implicitWidth ?? 0, phase: s.phase, genre: v?.annonce?.genre ?? null,
                                    gauche: b?.gauche ?? null, droite: b?.droite ?? null,
                                    cible: v?.remplissage?.cible ?? null, fond: String(v?.couleurFond ?? ""),
                                    encre: String(v?.couleurEncre ?? ""), opaciteCote: v?.cote?.opacity ?? null,
                                    opaciteCentre: v?.centre?.opacity ?? null, symbole: v?.symbole?.nom ?? null,
                                    texte: v?.etiquette?.text ?? null, opaciteActif: v?.actif?.opacity ?? null, yCentre: v?.centre?.y ?? null,
                                    yActif: v?.actif?.y ?? null, hauteur: v?.height ?? null,
                                    symboleActif: v?.symboleActif?.nom ?? null, texteActif: v?.etiquetteActif?.text ?? null,
                                    mobile: s.ressortLargeur.moving || (v?.remplissage?.moving ?? false) || (v?.jointure?.moving ?? false)
                                        || (v?.disposition?.moving ?? false) || (v?.bascule?.moving ?? false) })
        }

        // volumeSourdine, volumeNiveau — sourdine et niveau du son vus par le module Volume d'essai, à la place de
        // PipeWire. Entrées : b, vrai pour couper ; n, le niveau de 0 à 100. Sortie : aucune. Erreurs : aucune.
        // Dépendances : sceneVolume.
        function volumeSourdine(b: bool): void { sceneVolume.muetEssai = b }
        function volumeNiveau(n: int): void { sceneVolume.niveauEssai = n }

        // audioTenir — un popover audio s'ouvre ou se ferme, sous la clé d'un propriétaire, comme le fait chaque
        // indicateur de barre. Entrées : cle, le propriétaire ; ouvert, son état. Sortie : aucune. Erreurs : aucune.
        // Dépendances : EtatAudio (tenirPopover).
        function audioTenir(cle: string, ouvert: bool): void { EtatAudio.tenirPopover(cle, ouvert) }

        // audioPopover — dit si un popover audio est ouvert, d'après EtatAudio. Entrées : aucune. Sortie : « true » ou
        // « false ». Erreurs : aucune. Dépendances : EtatAudio (popoverOuvert).
        function audioPopover(): string { return String(EtatAudio.popoverOuvert) }

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
        // sortant (objectName de l'ancien contenu qui s'efface, ou null), mobile (vrai si l'un des quatre ressorts
        // avance)}. Erreurs : aucune. Dépendances : essaiScene.
        function changementEtat(): string {
            const s = essaiScene, l = s.ressortLargeur, h = s.ressortHauteur, o = s.ressortOpacite
            return JSON.stringify({ phase: s.phase, opacite: o.value, largeur: l.value, hauteur: h.value,
                                    contenu: s.contenu?.objectName ?? null, sortant: s.sortant?.objectName ?? null,
                                    mobile: l.moving || h.moving || o.moving || s.ressortSortant.moving })
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
