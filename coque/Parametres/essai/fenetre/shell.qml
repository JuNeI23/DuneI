//@ pragma IconTheme DuneI
//@ pragma Env QSG_DISTANCEFIELD_ANTIALIASING=gray
import QtQuick
import Quickshell
import Quickshell.Io
import QtTest
import "Parametres"

// Coque d'essai de la coquille de l'application Paramètres.
// Rôle : instancie FenetreParametres sur ses pages provisoires. La fenêtre s'ouvre et se ferme par l'IPC réelle
// (cible « parametres ») ; la cible « essai » lit son état et y joue les gestes de l'utilisateur (saisie, molette,
// touches, par un TestEvent de QtTest). tests/test_parametres.py (CoquilleTest) la pilote sous la plateforme
// offscreen ; lancée dans la session, elle sert aussi à la mesure d'ouverture et aux captures.
// Entrées : DUNEI_TOKENS_DIR, lu par Theme ; QT_QPA_PLATFORM=offscreen, posé par le test.
// Sortie : « essai : prêt » au démarrage ; voir chaque fonction de l'IpcHandler.
// Erreurs : celles de Theme et des liaisons, dans le journal. Dépendances : quickshell ≥ 0.3 (IpcHandler), QtTest,
// FenetreParametres, par les liens Theme, Composants et Parametres posés sous cette racine.
ShellRoot {
    id: essai

    // Mesure d'ouverture : instant (ms) de la demande, délai jusqu'à la deuxième image (-1 avant), pire intervalle
    // entre images (ms) et nombre d'images comptées, sur les soixante premières.
    property double t0: 0
    property int premiere: -1
    property real pire: 0
    property int images: 0

    Component.onCompleted: console.info("essai : prêt")

    FenetreParametres { id: fenetre }

    FrameAnimation {
        running: !!fenetre.fenetre?.visible && essai.t0 > 0 && essai.images < 60
        onTriggered: {
            essai.images++
            if (essai.images === 2) essai.premiere = Date.now() - essai.t0
            if (essai.images > 2) essai.pire = Math.max(essai.pire, frameTime * 1000)
        }
    }

    // frapper — frappe une touche dans la fenêtre, comme le clavier. Entrée : cle, un Qt.Key_*. Sortie : aucune.
    // Erreurs : fenêtre fermée, TypeError au journal. Dépendances : QtTest (TestEvent).
    function frapper(cle) {
        const e = Qt.createQmlObject("import QtTest; TestEvent {}", fenetre.barre)
        e.keyClick(cle, Qt.NoModifier, -1)
        e.destroy()
    }

    IpcHandler {
        target: "essai"

        // etat — état de la coquille. Entrées : aucune. Sortie : JSON { ouverte, page, chemin (EtatParametres) ;
        // fenetre (construite) ; titre ; entrees (libellés des pages), groupes (titres de groupe), ys (ordonnées
        // des entrées), gras (libellé de l'entrée en graisse moyenne), entreesVisibles ; plaque { y, cible, hauteur } ;
        // champ (texte de la recherche) ; resultats [{ libelle, origine }] ; chargees (pages construites) ;
        // defilement { y, cible, max, anime } ; niveau, retour, glisse (pile de sous-pages) ; evidence (objectName
        // de l'élément mis en évidence, vide sinon) }. Erreurs : aucune ; fenêtre fermée, seuls les quatre premiers
        // champs sont renseignés. Dépendances : fenetre, EtatParametres, Registre.
        function etat(): string {
            const e = { ouverte: EtatParametres.ouverte, page: EtatParametres.page, chemin: EtatParametres.chemin, fenetre: !!fenetre.fenetre }
            if (!e.fenetre) return JSON.stringify(e)
            const b = fenetre.barre, c = fenetre.conteneur
            const rangees = Registre.pages.map((p, i) => b.liste.itemAtIndex(i))
            return JSON.stringify(Object.assign(e, {
                titre: fenetre.fenetre.title,
                entrees: Registre.pages.map(p => p.libelle),
                groupes: Array.from(b.liste.contentItem.children).filter(o => o.section !== undefined && o.visible).map(o => o.section),
                ys: rangees.map(r => r?.y ?? -1),
                gras: Registre.pages.filter((p, i) => rangees[i]?.gras).map(p => p.libelle).join(","),
                entreesVisibles: b.liste.visible,
                plaque: { y: b.plaque?.y ?? -1, cible: b.ciblePlaque, hauteur: b.plaque?.height ?? -1 },
                champ: b.champ.text,
                resultats: b.cherche ? b.trouves.map(r => ({ libelle: r.libelle, origine: Registre.page(r.page).libelle })) : [],
                chargees: c.chargees,
                defilement: { y: c.defilement.contentY, cible: c.cible, max: c.maximum, anime: c.anime },
                niveau: c.niveau, retour: c.niveau ? "‹ " + c.retour : "", glisse: c.glisse,
                evidence: c.enEvidence?.objectName ?? ""
            }))
        }

        // saisir — écrit un terme dans le champ de recherche, qui prend le focus. Entrée : texte. Sortie : aucune.
        // Erreurs : fenêtre fermée, TypeError au journal. Dépendances : fenetre.barre.
        function saisir(texte: string): void {
            fenetre.barre.champ.forceActiveFocus()
            fenetre.barre.champ.text = texte
        }

        // activer — clique le résultat de rang donné. Entrée : rang. Sortie : aucune. Erreurs : rang absent, rien.
        // Dépendances : fenetre.barre.
        function activer(rang: int): void { fenetre.barre.resultats.itemAtIndex(rang)?.clicked() }

        // touche — frappe une touche nommée dans la fenêtre. Entrée : nom, « haut », « bas », « entree » ou « echap ».
        // Sortie : aucune. Erreurs : nom inconnu, rien. Dépendances : frapper.
        function touche(nom: string): void {
            const cle = { haut: Qt.Key_Up, bas: Qt.Key_Down, entree: Qt.Key_Return, echap: Qt.Key_Escape }[nom]
            if (cle) essai.frapper(cle)
        }

        // molette — joue un événement de molette sur la page. Entrées : angle, rotation en huitièmes de degré (120
        // pour un cran), envoyée comme un vrai événement de souris au centre de la page ; pixels, déplacement d'un
        // pavé tactile, passé à ConteneurPage.cran car QtTest ne sait pas le forger. Sortie : aucune.
        // Erreurs : fenêtre fermée, TypeError au journal. Dépendances : QtTest (TestEvent), fenetre.conteneur.
        function molette(angle: int, pixels: int): void {
            const c = fenetre.conteneur
            if (pixels !== 0) return c.cran(0, pixels)
            const e = Qt.createQmlObject("import QtTest; TestEvent {}", c)
            e.mouseWheel(c, c.width / 2, c.height / 2, Qt.NoButton, Qt.NoModifier, 0, angle, -1)
            e.destroy()
        }

        // atteindre — ouvre une page sur un de ses réglages, comme un résultat de recherche. Entrées : page ;
        // cheminJson, un objet JSON {"chemin": [...]} (un tableau nu serait déformé par la ligne de commande).
        // Sortie : aucune. Erreurs : JSON invalide, SyntaxError au journal. Dépendances : EtatParametres.
        function atteindre(page: string, cheminJson: string): void { EtatParametres.ouvrir(page, JSON.parse(cheminJson).chemin) }

        // rien — ne fait rien : sert à mesurer le coût d'un appel IPC à vide. Entrées : aucune. Sortie : aucune.
        function rien(): void {}

        // armer — remet la mesure d'ouverture à zéro et note l'instant de la demande. Entrées : aucune.
        // Sortie : aucune. Erreurs : aucune. Dépendances : Date.
        function armer(): void { essai.t0 = Date.now(); essai.premiere = -1; essai.pire = 0; essai.images = 0 }

        // ouvrirMesure — arme la mesure puis ouvre l'application, dans le même appel. Entrée : page. Sortie : aucune.
        // Erreurs : aucune. Dépendances : armer, EtatParametres.
        function ouvrirMesure(page: string): void { armer(); EtatParametres.ouvrir(page, []) }

        // mesure — rend la mesure d'ouverture. Entrées : aucune. Sortie : JSON { premiere (ms jusqu'à la deuxième
        // image, -1 avant), pire (ms, pire intervalle entre images), images }. Erreurs : aucune.
        function mesure(): string { return JSON.stringify({ premiere: essai.premiere, pire: essai.pire, images: essai.images }) }
    }
}
