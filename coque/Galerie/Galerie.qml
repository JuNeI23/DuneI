import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import "../Theme"
import "../Composants"
import "galerie.js" as Logique
import "../Theme/fichiers.js" as Fichiers

// Galerie — module de presqu'île (D98) qui montre les fonds d'écran du dossier des jetons en une bande de vignettes
// (L2-60, disposition A, relief « mélange »).
// Rôle : lit le dossier galerie.dossier (FolderListModel, sans sous-dossiers, filtres de galerie.js, tri par nom) et
// l'affiche en une bande horizontale de vignettes 16:9 : la sélection au centre, une vignette entière puis une
// vignette coupée à galerie.coupe de chaque côté, les emplacements sans image laissés vides aux bouts. La bande glisse
// par un Ressort « navigate » de nature « deplacement », seul à placer la rangée des emplacements dans une partie
// visible découpée (aucune vue ne reprend la main sur la position, rien ne se manipule au doigt) ; chaque image a un
// emplacement léger, et sa vignette n'est chargée qu'à moins d'un pas de la partie visible ; l'échelle et le voile de
// chaque vignette sont portés par la Vignette. La sélection s'ouvre sur le fond actuel (Theme.imageBureau) s'il est
// dans le dossier, sur la première image sinon. Navigation : flèches,
// molette et pavé tactile par pas (galerie.js cran : 120 par cran d'angleDelta, galerie.pas par tranche de
// pixelDelta), sans bouclage ; Entrée ou un clic sur une vignette entière valident ; un clic sur une vignette coupée la
// sélectionne ; Échap abandonne, et galerie.delai millisecondes sans action aussi, délai relancé par chaque touche,
// molette, clic ou mouvement de souris sur le module. Le module n'applique rien. Valider émet choisi aussitôt
// (l'ouvreuse appelle alors dunei-fond, et la montée du fond part), puis met le choix en valeur : la vignette choisie
// prend le relief de la sélection et les autres s'effacent en fondu (Ressort « reveal » de nature « fondu ») ; une fois
// l'effacement fini, la vignette choisie reste seule galerie.tenue millisecondes, puis le module émet fini avec son
// chemin, et l'ouvreuse rend la presqu'île aux bureaux. Dès la validation, plus aucune touche, molette ni clic n'agit.
// Un abandon émet fini("") aussitôt, sans effacement ni tenue. Chacun des deux signaux n'est émis qu'une fois.
// En mouvement réduit, le relief se pose aussitôt, seul l'effacement reste un fondu. Dossier vide, absent ou
// illisible : une ligne « Aucune image dans <galerie.dossier> » en text-secondary, à la hauteur de la presqu'île.
// Entrées : ecran, écran de la presqu'île (contrat D98, inutilisé ici) ; dossier, chemin absolu du dossier lu, par
//           défaut galerie.dossier développé depuis HOME (les essais le remplacent).
// Sorties : implicitWidth, 2 × presquile.marge + 3 vignettes + 2 coupes + 4 écarts (presquile.ecart), fixe dès la
//           création ; implicitHeight, galerie.hauteur + 2 × presquile.marge, qui laisse place au débord de la
//           sélection agrandie ; en dossier vide, la largeur du message plus les marges et presquile.hauteur ;
//           index, sélection courante (−1 sans image) ; nombre, chemins, la liste lue ; lu, vrai une fois le dossier
//           lu (ou reconnu absent) ; vide ; liste, le Repeater des emplacements, message, le texte du dossier vide,
//           glisse, vrai tant que la bande glisse, defilement, la position courante de son ressort, et
//           emplacement(i), l'emplacement d'index i s'il porte sa vignette (lus par les essais) ; choisie, index de la
//           vignette validée (−1 avant) ; effacement, opacité courante des vignettes non choisies (1 avant la validation) ; signal choisi(chemin),
//           émis à la validation ; signal fini(chemin), le chemin choisi après la tenue, ou "" pour un abandon.
// Erreurs : aucune ; une image illisible garde sa vignette vide et la navigation la traverse ; un dossier absent ou
//           illisible se traite comme un dossier vide. Avant le chargement des jetons, le module est de taille nulle.
// Dépendances : Qt.labs.folderlistmodel, Quickshell (env), Theme (galerie, dont tenue ; tokens.presquile, imageBureau,
//               color), Ressort, Composants (Texte), Vignette, galerie.js, fichiers.js.
FocusScope {
    id: galerie

    required property var ecran
    property string dossier: Fichiers.developper(Theme.galerie?.dossier ?? "", Quickshell.env("HOME"))
    property int index: -1
    readonly property int nombre: modele.count
    property var chemins: []
    readonly property bool lu: _lu
    readonly property bool vide: _lu && nombre === 0
    readonly property Repeater liste: emplacements
    readonly property Texte message: ligne
    readonly property bool glisse: glissement.moving
    readonly property real defilement: glissement.value

    readonly property int choisie: _choisie
    readonly property real effacement: efface.value

    signal choisi(string chemin)
    signal fini(string chemin)

    readonly property var jetons: Theme.galerie
    readonly property var gabarit: Theme.tokens?.presquile
    readonly property real ecart: gabarit?.ecart ?? 0
    readonly property real marge: gabarit?.marge ?? 0
    // Largeur visible de la bande : trois vignettes entières, deux coupées et les quatre écarts qui les séparent.
    // Pas de la bande : une vignette et l'écart qui la suit.
    readonly property real pasBande: (jetons?.largeur ?? 0) + ecart
    readonly property real largeurBande: 3 * (jetons?.largeur ?? 0) + 2 * (jetons?.coupe ?? 0) + 4 * ecart
    // Défilement qui vaut un pas pour angleDelta : un cran de molette chez Qt, et non une valeur de design.
    readonly property real cranMolette: 120

    property bool _lu: false
    property bool _ferme: false
    property int _choisie: -1
    property string _chemin: ""
    property bool _tenu: false
    property real _resteAngle: 0
    property real _restePixel: 0

    implicitWidth: vide ? ligne.implicitWidth + 2 * marge : largeurBande + 2 * marge
    implicitHeight: vide ? gabarit?.hauteur ?? 0 : (jetons?.hauteur ?? 0) + 2 * marge
    focus: true

    FolderListModel {
        id: modele
        folder: galerie.dossier === "" ? "" : Fichiers.url(galerie.dossier)
        showDirs: false
        nameFilters: Logique.FILTRES
        sortField: FolderListModel.Name
        onStatusChanged: galerie.synchroniser()
        onCountChanged: galerie.synchroniser()
    }

    // synchroniser — relit la liste des chemins après une lecture ou un changement du dossier.
    // Entrées : aucune (lit modele). Sortie : met à jour chemins et index ; à la première lecture complète, place la
    // sélection sur le fond actuel et pose la bande sans glissement ; ensuite, ramène la sélection dans les bornes
    // (image retirée pendant l'ouverture). Erreurs : aucune.
    // Dépendances : modele, Logique (initial, borner), glissement.
    function synchroniser() {
        if (modele.status !== FolderListModel.Ready) return
        chemins = Array.from({ length: modele.count }, (_, i) => modele.get(i, "filePath"))
        if (_lu) { index = Logique.borner(index, chemins.length); return }
        index = Logique.initial(chemins, Theme.imageBureau)
        glissement.poser()
        _lu = true
    }

    // emplacement — l'emplacement d'index i, s'il est créé et porte sa vignette chargée.
    // Entrée : i, index de l'image. Sortie : l'Item de l'emplacement (propriétés index et vignette), ou null.
    // Erreurs : aucune. Dépendances : emplacements.
    function emplacement(i) { const e = emplacements.itemAt(i); return e?.vignette ? e : null }

    // relancer — repart le délai d'abandon de zéro. Entrées : aucune. Sortie : aucune. Erreurs : aucune.
    // Dépendances : delai.
    function relancer() { if (delai.running) delai.restart() }

    // aller — déplace la sélection d'un pas signé, sans bouclage, et relance le délai.
    // Entrée : pas, entier signé. Sortie : aucune. Erreurs : sans effet une fois le module fini ou sans image.
    // Dépendances : Logique.deplacer, relancer.
    function aller(pas) {
        if (_ferme) return
        relancer()
        if (nombre > 0) index = Logique.deplacer(index, pas, nombre)
    }

    // valider — choisit une image : émet choisi avec son chemin, puis lance l'effacement des autres vignettes, que
    // suivent la tenue et fini.
    // Entrée : i, index de l'image. Sortie : aucune. Erreurs : sans effet si i est hors de la liste ou si le module
    // est déjà fini. Dépendances : chemins, choisi, efface (par sa cible), tenir.
    function valider(i) {
        if (_ferme || i < 0 || i >= chemins.length) return
        _ferme = true
        _chemin = chemins[i]
        _choisie = i
        choisi(_chemin)
        Qt.callLater(tenir)
    }

    // tenir — lance la tenue une fois l'effacement fini ; fini part à son échéance.
    // Entrées : aucune ; appelée après la validation et à chaque arrêt ou départ du ressort d'effacement, au tour de
    // boucle suivant. Sortie : aucune. Erreurs : sans effet avant la validation, pendant l'effacement ou une fois la
    // tenue lancée. Dépendances : efface, tenue.
    function tenir() {
        if (_choisie < 0 || efface.moving || efface.value !== 0 || _tenu) return
        _tenu = true
        tenue.start()
    }

    // abandonner — referme sans rien choisir : émet fini(""). Entrées : aucune. Sortie : aucune.
    // Erreurs : sans effet si le module est déjà fini. Dépendances : fini.
    function abandonner() {
        if (_ferme) return
        _ferme = true
        fini("")
    }

    // cliquer — répond au clic sur une vignette : une vignette coupée (à deux pas ou plus de la sélection) est
    // sélectionnée, toute autre est validée.
    // Entrée : i, index de la vignette cliquée. Sortie : aucune. Erreurs : aucune. Dépendances : aller, valider.
    function cliquer(i) {
        if (Math.abs(i - index) >= 2) aller(i - index)
        else { relancer(); valider(i) }
    }

    // touche — traite une touche du clavier.
    // Entrée : touche, code Qt.Key_*. Sortie : vrai si la touche est traitée. Erreurs : aucune.
    // Dépendances : aller, valider, abandonner.
    function touche(touche) {
        switch (touche) {
        case Qt.Key_Left: aller(-1); return true
        case Qt.Key_Right: aller(1); return true
        case Qt.Key_Return: case Qt.Key_Enter: relancer(); valider(index); return true
        case Qt.Key_Escape: abandonner(); return true
        }
        return false
    }

    // defiler — convertit un défilement de molette ou de pavé tactile en pas de sélection, le reste étant gardé pour
    // l'événement suivant ; l'axe dominant compte, vers le bas ou vers la droite pour avancer.
    // Entrées : dx, dy, défilement de l'événement (angleDelta, ou pixelDelta si pixel) ; pixel, vrai pour un
    // défilement en pixels (pavé tactile). Sortie : aucune. Erreurs : aucune.
    // Dépendances : Logique.cran, aller, relancer, jetons.pas.
    function defiler(dx, dy, pixel) {
        relancer()
        const delta = -(Math.abs(dx) > Math.abs(dy) ? dx : dy)
        const r = Logique.cran(pixel ? _restePixel : _resteAngle, delta, pixel ? jetons?.pas ?? 1 : cranMolette)
        if (pixel) _restePixel = r.reste
        else _resteAngle = r.reste
        if (r.pas !== 0) aller(r.pas)
    }

    Keys.onPressed: event => { event.accepted = galerie.touche(event.key) }

    // Délai d'abandon : lancé à la création, relancé par chaque action, arrêté une fois le module fini.
    Timer {
        id: delai
        interval: galerie.jetons?.delai ?? 0
        running: !galerie._ferme && interval > 0
        onTriggered: galerie.abandonner()
    }

    // Effacement des vignettes non choisies, à la validation.
    Ressort {
        id: efface
        transition: "reveal"
        nature: "fondu"
        cible: galerie._choisie < 0 ? 1 : 0
        onMovingChanged: Qt.callLater(galerie.tenir)
    }

    // Tenue de la vignette choisie, seule, avant la fermeture.
    Timer {
        id: tenue
        interval: galerie.jetons?.tenue ?? 0
        onTriggered: galerie.fini(galerie._chemin)
    }

    // Glissement de la bande : décalage de la rangée qui place la vignette sélectionnée au centre de la partie visible.
    Ressort {
        id: glissement
        transition: "navigate"
        nature: "deplacement"
        cible: galerie.index * galerie.pasBande - (galerie.largeurBande - (galerie.jetons?.largeur ?? 0)) / 2
    }

    // Bande : une fenêtre découpée sur la partie visible, dont la rangée d'emplacements est placée par le seul ressort
    // de glissement (x: −defilement). Une ListView reprenait d'elle-même son contentX au remplissage asynchrone du
    // dossier, et la première flèche faisait sauter la bande (recette de L2-60) : rien ici ne déplace la rangée.
    Item {
        id: bande
        x: galerie.marge
        width: galerie.largeurBande
        height: galerie.height
        visible: !galerie.vide
        clip: true

        Repeater {
            id: emplacements
            model: modele

            // Emplacement léger, créé pour chaque image ; la vignette n'y est chargée que près de la partie visible.
            delegate: Item {
                id: emplacement
                required property int index
                required property string filePath
                readonly property Vignette vignette: charge.item

                x: index * galerie.pasBande - glissement.value
                width: galerie.jetons?.largeur ?? 0
                height: bande.height

                Loader {
                    id: charge
                    anchors.centerIn: parent
                    // Un pas de marge de chaque côté de la partie visible : la vignette est prête avant d'entrer.
                    active: emplacement.x > -2 * galerie.pasBande && emplacement.x < bande.width + galerie.pasBande
                    sourceComponent: Vignette {
                        width: implicitWidth
                        height: implicitHeight
                        chemin: emplacement.filePath
                        // Après la validation, le relief passe à la vignette choisie, et les autres s'effacent.
                        selectionnee: emplacement.index === (galerie._choisie < 0 ? galerie.index : galerie._choisie)
                        opacity: galerie._choisie < 0 || emplacement.index === galerie._choisie ? 1 : efface.value
                    }
                }

                // Clic : une MouseArea plutôt qu'un TapHandler, pour que les vrais clics envoyés par l'essai
                // l'atteignent (comme la molette, ils n'atteignent pas les gestionnaires de pointeur).
                MouseArea {
                    anchors.fill: parent
                    enabled: charge.status === Loader.Ready
                    onClicked: galerie.cliquer(emplacement.index)
                }
            }
        }
    }

    Texte {
        id: ligne
        anchors.centerIn: parent
        visible: galerie.vide
        color: Theme.color?.textSecondary ?? "transparent"
        text: "Aucune image dans " + (galerie.jetons?.dossier ?? "")
    }

    // Molette et pavé tactile sur tout le module, sur les deux axes : une MouseArea qui n'accepte aucun bouton (les
    // clics passent aux vignettes) et lit angleDelta ou pixelDelta en x comme en y. Un WheelHandler est écarté : son
    // orientation (verticale par défaut) désigne, selon la documentation de Qt 6, la seule molette à laquelle il
    // réagit, et les vrais événements de molette envoyés par l'essai ne l'atteignent pas, alors qu'ils atteignent la
    // MouseArea. Mouvement de souris : relance le délai.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: event => {
            const pixel = event.pixelDelta.x !== 0 || event.pixelDelta.y !== 0
            const d = pixel ? event.pixelDelta : event.angleDelta
            galerie.defiler(d.x, d.y, pixel)
        }
    }
    HoverHandler { onPointChanged: galerie.relancer() }
}
