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
// par un Ressort « navigate » de nature « deplacement » sur contentX (la ListView n'anime rien d'elle-même et ne se
// manipule pas au doigt) ; l'échelle et le voile de chaque vignette sont portés par la Vignette. La sélection s'ouvre
// sur le fond actuel (Theme.imageBureau) s'il est dans le dossier, sur la première image sinon. Navigation : flèches,
// molette et pavé tactile par pas (galerie.js cran : 120 par cran d'angleDelta, galerie.pas par tranche de
// pixelDelta), sans bouclage ; Entrée ou un clic sur une vignette entière valident ; un clic sur une vignette coupée la
// sélectionne ; Échap abandonne, et galerie.delai millisecondes sans action aussi, délai relancé par chaque touche,
// molette, clic ou mouvement de souris sur le module. Le module n'applique rien : il émet fini, une seule fois, et
// l'ouvreuse (Tâche 4) appelle dunei-fond et rend la presqu'île aux bureaux. Dossier vide, absent ou illisible : une
// ligne « Aucune image dans <galerie.dossier> » en text-secondary, à la hauteur de la presqu'île.
// Entrées : ecran, écran de la presqu'île (contrat D98, inutilisé ici) ; dossier, chemin absolu du dossier lu, par
//           défaut galerie.dossier développé depuis HOME (les essais le remplacent).
// Sorties : implicitWidth, 2 × presquile.marge + 3 vignettes + 2 coupes + 4 écarts (presquile.ecart), fixe dès la
//           création ; implicitHeight, galerie.hauteur + 2 × presquile.marge, qui laisse place au débord de la
//           sélection agrandie ; en dossier vide, la largeur du message plus les marges et presquile.hauteur ;
//           index, sélection courante (−1 sans image) ; nombre, chemins, la liste lue ; lu, vrai une fois le dossier
//           lu (ou reconnu absent) ; vide ; liste, la ListView, et message, le texte du dossier vide (lus par les
//           essais) ; signal fini(chemin), le chemin choisi, ou "" pour un abandon.
// Erreurs : aucune ; une image illisible garde sa vignette vide et la navigation la traverse ; un dossier absent ou
//           illisible se traite comme un dossier vide. Avant le chargement des jetons, le module est de taille nulle.
// Dépendances : Qt.labs.folderlistmodel, Quickshell (env), Theme (galerie, tokens.presquile, imageBureau, color),
//               Ressort, Composants (Texte), Vignette, galerie.js, fichiers.js.
FocusScope {
    id: galerie

    required property var ecran
    property string dossier: Fichiers.developper(Theme.galerie?.dossier ?? "", Quickshell.env("HOME"))
    property int index: -1
    readonly property int nombre: modele.count
    property var chemins: []
    readonly property bool lu: _lu
    readonly property bool vide: _lu && nombre === 0
    readonly property ListView liste: bande
    readonly property Texte message: ligne

    signal fini(string chemin)

    readonly property var jetons: Theme.galerie
    readonly property var gabarit: Theme.tokens?.presquile
    readonly property real ecart: gabarit?.ecart ?? 0
    readonly property real marge: gabarit?.marge ?? 0
    // Largeur visible de la bande : trois vignettes entières, deux coupées et les quatre écarts qui les séparent.
    readonly property real largeurBande: 3 * (jetons?.largeur ?? 0) + 2 * (jetons?.coupe ?? 0) + 4 * ecart
    // Défilement qui vaut un pas pour angleDelta : un cran de molette chez Qt, et non une valeur de design.
    readonly property real cranMolette: 120

    property bool _lu: false
    property bool _ferme: false
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
    // (image retirée pendant l'ouverture). Erreurs : aucune. Dépendances : modele, Logique (initial, borner), glisse.
    function synchroniser() {
        if (modele.status !== FolderListModel.Ready) return
        chemins = Array.from({ length: modele.count }, (_, i) => modele.get(i, "filePath"))
        if (_lu) { index = Logique.borner(index, chemins.length); return }
        index = Logique.initial(chemins, Theme.imageBureau)
        glisse.poser()
        _lu = true
    }

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

    // valider — choisit une image : émet fini avec son chemin.
    // Entrée : i, index de l'image. Sortie : aucune. Erreurs : sans effet si i est hors de la liste ou si le module
    // est déjà fini. Dépendances : chemins, fini.
    function valider(i) {
        if (_ferme || i < 0 || i >= chemins.length) return
        _ferme = true
        fini(chemins[i])
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

    // Glissement de la bande : contentX qui place la vignette sélectionnée au centre de la partie visible.
    Ressort {
        id: glisse
        transition: "navigate"
        nature: "deplacement"
        cible: galerie.index * ((galerie.jetons?.largeur ?? 0) + galerie.ecart) - (galerie.largeurBande - (galerie.jetons?.largeur ?? 0)) / 2
    }

    ListView {
        id: bande
        x: galerie.marge
        width: galerie.largeurBande
        height: galerie.height
        visible: !galerie.vide
        orientation: ListView.Horizontal
        spacing: galerie.ecart
        interactive: false
        clip: true
        contentX: glisse.value
        model: modele

        delegate: Item {
            id: emplacement
            required property int index
            required property string filePath
            readonly property Vignette vignette: image

            width: image.implicitWidth
            height: bande.height

            Vignette {
                id: image
                anchors.centerIn: parent
                width: implicitWidth
                height: implicitHeight
                chemin: emplacement.filePath
                selectionnee: emplacement.index === galerie.index
            }

            // Clic : une MouseArea plutôt qu'un TapHandler, pour que les vrais clics envoyés par l'essai l'atteignent
            // (comme la molette, ils n'atteignent pas les gestionnaires de pointeur).
            MouseArea { anchors.fill: parent; onClicked: galerie.cliquer(emplacement.index) }
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
