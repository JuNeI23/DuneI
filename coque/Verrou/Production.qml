import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "../Theme"
import "verrou.js" as Logique

// Production — fichiers de hyprlock produits d'avance par la coque (L2-22).
// Rôle : pour chaque écran, rend en images PNG, à la taille physique, le fond, la pastille et le champ de Contenu.qml,
// ainsi que deux images transparentes de même taille (pastille et champ vides, montrées par hyprlock tant que le
// marqueur d'apparition existe), puis écrit hyprlock.conf (confHyprlock). Chaque image est écrite en .tmp.png puis
// renommée ; la configuration est écrite en dernier, par écriture atomique. Une production demandée pendant une autre
// est rejouée à sa fin. Le rendu passe par grabToImage, qui exige une fenêtre : un calque d'un pixel, transparent, sans
// entrée ni clavier, posé en arrière-plan sur chaque écran, porte un Contenu caché. Une image n'est rendue qu'une fois
// le rapport de pixels de ce calque égal à l'échelle de Hyprland (Qt passe par 2 puis 1 avant l'échelle fractionnaire)
// et l'image du bureau décodée, ou après deux secondes d'attente, avec un avertissement.
// Entrées : ecrans, liste de {nom, largeur, hauteur (pixels logiques), echelle}, par défaut les écrans de Quickshell
// avec l'échelle de Hyprland ; DUNEI_ETAT_DIR, sinon $XDG_STATE_HOME/dunei, sinon ~/.local/state/dunei : le dossier
// d'état, dont verrou/ reçoit les fichiers ; XDG_RUNTIME_DIR (marqueur dunei/verrou-apparition) ; USER (nom affiché).
// Relance d'elle-même au changement des écrans ou de leur échelle, de l'image du bureau, de Theme.bureauClair, de
// Theme.mouvementReduit et des jetons (thème choisi).
// Sorties : produire() ; dans verrou/ : fond-<écran>.png, pastille-<écran>.png, champ-<écran>.png,
// pastille-<écran>-vide.png, champ-<écran>-vide.png et hyprlock.conf ; signal produit() à la fin d'une production
// réussie ; enCours.
// Erreurs : jetons non chargés, aucun écran ou échelle inconnue → rien n'est produit (relance au changement suivant) ;
// dossier impossible à créer, image non rendue ou non écrite, renommage en échec → console.warn, la configuration
// n'est pas réécrite et l'ancienne reste en place.
// Dépendances : Contenu.qml, verrou.js (confHyprlock, physique), Theme, Quickshell (Variants, PanelWindow, env),
// Quickshell.Hyprland (monitorFor, refreshMonitors, rawEvent), Quickshell.Io (Process, FileView), mkdir, sh, mv.
Scope {
    id: production

    property var ecrans: Quickshell.screens.map(s => ({ nom: s.name, largeur: s.width, hauteur: s.height,
                                                        echelle: Hyprland.monitorFor(s)?.scale ?? 0 }))
    readonly property string dossier: (Quickshell.env("DUNEI_ETAT_DIR") || (Quickshell.env("XDG_STATE_HOME")
        || Quickshell.env("HOME") + "/.local/state") + "/dunei") + "/verrou"
    readonly property string marqueur: Quickshell.env("XDG_RUNTIME_DIR") + "/dunei/verrou-apparition"
    property bool enCours: false
    // Production redemandée pendant enCours ; écrans restant à rendre ; écrans rendus, avec leurs images.
    property bool _encore: false
    property var _file: []
    property var _faits: []

    signal produit()

    // produire — lance une production complète, ou la rejoue à la fin de celle en cours.
    // Entrées : aucune (ecrans, Theme). Sortie : aucune ; crée le dossier puis enchaîne suivant().
    // Erreurs : voir l'en-tête (rien n'est produit sans jetons, sans écran ou sans échelle). Dépendances : preparer.
    function produire() {
        if (enCours) { _encore = true; return }
        if (!Theme.ready || !ecrans.length || ecrans.some(e => !(e.echelle > 0))) return
        enCours = true
        _encore = false
        _file = ecrans.slice()
        _faits = []
        preparer.running = true
    }

    // suivant — confie le premier écran restant au calque de son écran (le premier calque pour un écran inconnu de
    // Quickshell), ou renomme les images quand tous sont rendus.
    // Entrées : aucune (_file). Sortie : aucune. Erreurs : aucune. Dépendances : fenetres, renommer.
    function suivant() {
        if (!_file.length) {
            // Le moteur JavaScript de Qt n'a pas flatMap : les chemins s'aplatissent par concat.
            renommer.command = ["sh", "-c", 'for f do mv -f -- "$f" "${f%.tmp.png}.png" || exit 1; done', "sh",
                                ...[].concat(..._faits.map(e => Object.values(e.images))).map(provisoire)]
            renommer.running = true
            return
        }
        const e = _file[0]
        const fenetre = fenetres.instances.find(f => f.modelData.name === e.nom) ?? fenetres.instances[0]
        if (fenetre) fenetre.rendre(e)
        else echec("aucun calque de rendu")
    }

    // rendu — reçoit les images d'un écran et passe au suivant.
    // Entrées : e, l'écran ; images, {fond, pastille, champ, pastilleVide, champVide}, chemins définitifs. Sortie :
    // aucune. Erreurs : aucune. Dépendances : suivant.
    function rendu(e, images) {
        _faits = _faits.concat([Object.assign({}, e, { images: images })])
        _file = _file.slice(1)
        suivant()
    }

    // provisoire — chemin provisoire d'une image. Entrée : chemin, en .png. Sortie : le même en .tmp.png.
    // Erreurs : aucune. Dépendances : aucune.
    function provisoire(chemin) { return chemin.replace(/\.png$/, ".tmp.png") }

    // echec — abandonne la production en cours, l'ancienne configuration restant en place.
    // Entrée : raison, texte du journal. Sortie : aucune ; rejoue une production redemandée. Erreurs : aucune.
    // Dépendances : relance.
    function echec(raison) {
        console.warn("Production du verrou : " + raison)
        enCours = false
        if (_encore) relance.restart()
    }

    onEcransChanged: relance.restart()
    Component.onCompleted: Hyprland.refreshMonitors()

    Connections {
        target: Theme
        function onImageBureauChanged() { relance.restart() }
        function onBureauClairChanged() { relance.restart() }
        function onMouvementReduitChanged() { relance.restart() }
        function onTokensChanged() { relance.restart() }
    }
    // Un écran branché, retiré ou reconfiguré : l'échelle de Hyprland se relit, ce qui change ecrans.
    Connections {
        target: Hyprland
        function onRawEvent(ev) {
            if (["monitoraddedv2", "monitorremovedv2", "configreloaded"].includes(ev.name)) Hyprland.refreshMonitors()
        }
    }

    // Les changements arrivent en salve (jetons, puis fond publié) : une seule production après le dernier.
    Timer { id: relance; interval: 300; onTriggered: production.produire() }

    Process {
        id: preparer
        command: ["mkdir", "-p", production.dossier]
        onExited: code => code === 0 ? production.suivant() : production.echec("dossier " + production.dossier)
    }

    Process {
        id: renommer
        // onExited — les images sont en place : la configuration s'écrit en dernier.
        // Entrées : code de sortie de sh. Sortie : hyprlock.conf, signal produit. Erreurs : code non nul → echec.
        // Dépendances : Logique.confHyprlock, conf, Theme.
        onExited: code => {
            if (code !== 0) return production.echec("renommage des images")
            const j = { verrou: Theme.verrou, utilisateur: Quickshell.env("USER") ?? "",
                        couleurs: { fond: String(Theme.color.surfaceBase), heures: String(Theme.texteBureau),
                                    minutes: String(Theme.texteBureauSurvol), erreur: String(Theme.color.error) } }
            conf.setText(Logique.confHyprlock(production._faits, j, production.marqueur,
                                              production._faits[0].images.pastilleVide))
            production.enCours = false
            production.produit()
            if (production._encore) relance.restart()
        }
    }

    FileView {
        id: conf
        path: production.dossier + "/hyprlock.conf"
        printErrors: false
        blockWrites: true
        atomicWrites: true
    }

    Variants {
        id: fenetres
        model: Quickshell.screens

        PanelWindow {
            id: fenetre
            required property ShellScreen modelData
            // Écran en cours de rendu, et instant limite de l'attente du rapport de pixels et du décodage.
            property var ecran: null
            property real limite: 0

            screen: modelData
            implicitWidth: 1
            implicitHeight: 1
            color: "transparent"
            anchors { top: true; left: true }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Background
            WlrLayershell.namespace: "dunei-verrou-production"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            mask: Region {}

            // rendre — prend un écran à rendre et attend que le calque et l'image soient prêts.
            // Entrée : e, l'écran. Sortie : aucune ; l'échelle de Hyprland se relit et guet démarre. Erreurs : aucune.
            // Dépendances : guet, Hyprland.refreshMonitors.
            function rendre(e) {
                ecran = e
                Hyprland.refreshMonitors()
                limite = Date.now() + 2000
                guet.restart()
            }

            // graver — rend les cinq images de l'écran en cours, l'une après l'autre, puis les remet à production.
            // Entrées : aucune (ecran, devicePixelRatio). Sortie : aucune ; production.rendu ou production.echec.
            // Erreurs : rendu refusé ou fichier non écrit → production.echec. Dépendances : atelier, Logique.physique.
            function graver() {
                const e = ecran, d = devicePixelRatio, base = production.dossier + "/"
                const images = { fond: base + "fond-" + e.nom + ".png", pastille: base + "pastille-" + e.nom + ".png",
                                 champ: base + "champ-" + e.nom + ".png",
                                 pastilleVide: base + "pastille-" + e.nom + "-vide.png",
                                 champVide: base + "champ-" + e.nom + "-vide.png" }
                const travaux = [[atelier.fond, images.fond], [atelier.pastille, images.pastille],
                                 [atelier.champ, images.champ], [videPastille, images.pastilleVide],
                                 [videChamp, images.champVide]]
                // pas — rend le travail i puis le suivant ; la taille demandée est divisée par le rapport de pixels,
                // que grabToImage applique.
                const pas = i => {
                    if (i === travaux.length) return production.rendu(e, images)
                    const [item, chemin] = travaux[i]
                    const taille = Qt.size(Logique.physique(item.width, e.echelle) / d,
                                           Logique.physique(item.height, e.echelle) / d)
                    const lance = item.grabToImage(r => r.saveToFile(production.provisoire(chemin)) ? pas(i + 1)
                                                        : production.echec("écriture de " + chemin), taille)
                    if (!lance) production.echec("rendu de " + chemin)
                }
                pas(0)
            }

            // guet — attend le rapport de pixels de Hyprland et l'image décodée, deux secondes au plus.
            Timer {
                id: guet
                interval: 50
                repeat: true
                onTriggered: {
                    const pret = Math.abs(fenetre.devicePixelRatio - (Hyprland.monitorFor(fenetre.screen)?.scale ?? 0))
                        < 0.001 && atelier.pret
                    if (!pret && Date.now() < fenetre.limite) return
                    stop()
                    if (!pret) console.warn("Production du verrou : rendu de " + fenetre.ecran.nom + " sans attendre"
                        + " (rapport de pixels " + fenetre.devicePixelRatio + ", image prête " + atelier.pret + ")")
                    fenetre.graver()
                }
            }

            Contenu {
                id: atelier
                visible: false
                width: fenetre.ecran?.largeur ?? 0
                height: fenetre.ecran?.hauteur ?? 0
                echelle: fenetre.ecran?.echelle ?? 1
            }
            Item { id: videPastille; visible: false; width: atelier.pastille.width; height: atelier.pastille.height }
            Item { id: videChamp; visible: false; width: atelier.champ.width; height: atelier.champ.height }
        }
    }
}
