import QtQuick
import Quickshell
import Quickshell.Io
import "Theme"

// Coque d'essai du module Theme, sans aucune fenêtre.
// Rôle : instancie le singleton Theme pour que tests/test_coque_theme.py éprouve dans un vrai Quickshell
// le chargement, la surveillance et le repli des fichiers générés, en lisant le journal.
// Entrées : DUNEI_TOKENS_DIR, lu par Theme. Sortie : journal de Theme, plus « essai : prêt <bool>, couleurs
// définies|indéfinies » à chaque changement de Theme.ready (les raccourcis de groupe doivent déjà être à
// jour), « essai : thème <famille>/<moment> <color.surfacePanel> teinte <hue> » à chaque nouvel objet de tokens,
// et « essai : ressort posé|en vol » deux tours de boucle après, selon que la couleur d'un ColorSpring a déjà
// rejoint sa cible ou non. Commande IPC « essai etat <interaction> »
// (rest, hover, pressed, disabled) : change l'état du ressort et journalise « essai : état <interaction>,
// ressort posé|en vol » au tour de boucle suivant ; « essai lent » donne au ressort une raideur minime, pour
// qu'il reste en vol plusieurs secondes ; « essai raideur » journalise « essai : raideur <stiffness> », la
// raideur du ressort employé. « essai : texte bureau <texteBureau> survol <texteBureauSurvol> » à chaque
// changement de l'un ou de l'autre (couleurs au format #rrggbb). Un Ressort numérique, de cible initiale 7 et
// de transition navigate : « essai cible <n> » le recible ; « essai course » journalise « essai : course
// valeur <v> pic <p> mobile <bool> » (pic : plus grande valeur vue depuis le dernier recible) ; « essai saut
// <n> » le recible et journalise valeur, vitesse et mouvement avant et après, dans le même tour de boucle ;
// « essai neuf <n> » crée un Ressort de cible n et journalise son état aussitôt puis 150 ms après.
// Erreurs : celles de Theme, dans le journal. Dépendances : quickshell ≥ 0.3 (Quickshell.Io : IpcHandler), module coque/Theme.
// Import : Quickshell ne résout pas un module situé au-dessus de la racine de la coque lancée (import "../"
// laisse Theme indéfini) ; le lien essai/Theme -> .. le place sous cette racine.
ShellRoot {
    id: essai
    property string interaction: "rest"

    // posture — état du ressort pour le journal.
    // Entrées : aucune. Sortie : « posé » si la couleur affichée a rejoint sa cible et ne bouge plus, sinon
    // « en vol ». Erreurs : aucune. Dépendances : spring.
    function posture() {
        return Qt.colorEqual(spring.value, spring.target) && !spring.moving ? "posé" : "en vol"
    }

    ColorSpring {
        id: spring
        target: Theme.stateColors("surfacePanel", "none", essai.interaction)?.fill ?? "transparent"
    }

    // texteBureau — journalise la couleur du texte sur bureau, au repos et au survol.
    // Entrées : aucune. Sortie : « essai : texte bureau <couleur> survol <couleur> ». Erreurs : aucune.
    // Dépendances : Theme.
    function texteBureau() {
        console.info("essai : texte bureau " + Theme.texteBureau + " survol " + Theme.texteBureauSurvol)
    }

    // Ressort numérique éprouvé par les commandes cible, course et saut ; pic retient sa plus grande valeur.
    Ressort {
        id: nombre
        cible: 7
        property real pic: 7
        onValueChanged: pic = Math.max(pic, value)
    }

    IpcHandler {
        target: "essai"

        // cible — recible le Ressort numérique et remet son pic à la valeur courante.
        // Entrées : n nouvelle cible. Sortie : aucune. Erreurs : aucune. Dépendances : nombre.
        function cible(n: real): void {
            nombre.pic = nombre.value
            nombre.cible = n
        }

        // course — journalise l'état du Ressort numérique.
        // Entrées : aucune. Sortie : « essai : course valeur <v> pic <p> mobile <bool> ». Erreurs : aucune.
        // Dépendances : nombre.
        function course(): void {
            console.info("essai : course valeur " + nombre.value + " pic " + nombre.pic + " mobile " + nombre.moving)
        }

        // saut — recible le Ressort numérique en lisant valeur, vitesse et mouvement juste avant et juste après,
        // sans rendre la main.
        // Entrées : n nouvelle cible.
        // Sortie : « essai : saut avant <v> <vitesse> <mobile> après <v> <vitesse> <mobile> ». Erreurs : aucune.
        // Dépendances : nombre.
        function saut(n: real): void {
            const avant = nombre.value + " " + nombre.vitesse() + " " + nombre.moving
            nombre.cible = n
            console.info("essai : saut avant " + avant + " après " + nombre.value + " " + nombre.vitesse() + " " + nombre.moving)
        }

        // neuf — crée un Ressort après que Theme est prêt, puis journalise son état à la création et plus tard.
        // Entrées : n cible initiale. Sortie : « essai : neuf <v> <mobile> » aussitôt, puis 150 ms après.
        // Erreurs : aucune. Dépendances : Ressort, Theme.
        function neuf(n: real): void {
            const r = Qt.createQmlObject('import QtQuick\nimport "Theme"\nRessort { cible: ' + n + ' }', essai, "neuf.qml")
            console.info("essai : neuf " + r.value + " " + r.moving)
            const t = Qt.createQmlObject('import QtQuick\nTimer { interval: 150; running: true }', essai, "minuteur.qml")
            t.triggered.connect(() => console.info("essai : neuf " + r.value + " " + r.moving))
        }

        // pose — crée un Ressort de cible 0, le recible, puis le pose.
        // Entrées : n cible. Sortie : « essai : pose <v> <mobile> » (valeur égale à n, mouvement faux).
        // Erreurs : aucune. Dépendances : Ressort, Theme.
        function pose(n: real): void {
            const r = Qt.createQmlObject('import QtQuick\nimport "Theme"\nRessort { cible: 0 }', essai, "pose.qml")
            r.cible = n
            r.poser()
            console.info("essai : pose " + r.value + " " + r.moving)
        }

        // etat — change l'interaction simulée du ressort, comme un survol ou une pression.
        // Entrées : interaction (rest, hover, pressed, disabled). Sortie : aucune ; journal un tour plus tard.
        // Erreurs : aucune ; une interaction inconnue donne une cible transparente. Dépendances : posture.
        function etat(interaction: string): void {
            essai.interaction = interaction
            Qt.callLater(() => console.info("essai : état " + interaction + ", ressort " + essai.posture()))
        }

        // lent — remplace le ressort d'état par un ressort très lent, pour éprouver un ressort en vol.
        // Entrées : aucune. Sortie : aucune. Erreurs : aucune. Dépendances : spring.
        function lent(): void {
            spring.params = { mass: 1, stiffness: 1, dampening: 2 }
        }

        // raideur — journalise la raideur du ressort que le ColorSpring emploie à cet instant.
        // Entrées : aucune. Sortie : aucune ; « essai : raideur <stiffness> ». Erreurs : aucune.
        // Dépendances : spring.
        function raideur(): void {
            console.info("essai : raideur " + spring.params?.stiffness)
        }
    }

    Connections {
        target: Theme
        function onReadyChanged() {
            console.info("essai : prêt " + Theme.ready + ", couleurs " + (Theme.color ? "définies" : "indéfinies"))
        }
        function onTexteBureauChanged() { essai.texteBureau() }
        function onTexteBureauSurvolChanged() { essai.texteBureau() }
        function onTokensChanged() {
            console.info("essai : thème " + Theme.famille + "/" + Theme.moment + " " + Theme.color?.surfacePanel
                + " teinte " + Theme.tokens?.hue)
            // Deux tours de boucle : le ressort prend acte du nouvel objet de tokens au premier.
            Qt.callLater(() => Qt.callLater(() => console.info("essai : ressort " + essai.posture())))
        }
    }
}
