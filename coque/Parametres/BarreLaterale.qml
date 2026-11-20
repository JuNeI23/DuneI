import QtQuick
import QtQuick.Layouts
import "../Theme"
import "../Composants"
import "recherche.js" as Moteur

// BarreLaterale — barre latérale de l'application Paramètres : champ de recherche, puis pages ou résultats.
// Rôle : liste les pages du registre sous le titre de leur groupe, en entrées compactes (vignette et libellé). La
// liste est une colonne de navigation (Liste.navigation) et sa plaque, la seule de la barre, marque à la fois le
// curseur de la fenêtre et la page courante (conception L2-73, arbitrage 1 : une vue, la fenêtre entière) : à
// l'accent sur l'entrée survolée, ou sur l'entrée courante quand la liste est parcourue au clavier ; au fond neutre
// controlRaised, sans ombre (D195), sur la page courante quand le curseur est ailleurs. Le libellé de la page courante
// passe en graisse moyenne. Le survol ne déplace que le curseur : un clic ou Entrée ouvre la page, et les flèches la
// changent, comme une barre latérale de macOS ; le pointeur sorti de la liste, la plaque revient à la page courante.
// Dès que le champ porte un terme, les entrées laissent place aux résultats de la recherche (libellé du réglage, page
// d'origine), dont le courant, celui qu'Entrée ouvrirait, porte le curseur, comme au lanceur : un clic, ou Entrée
// depuis le champ, ouvre la page du résultat courant et conduit à son réglage, puis vide le champ ; les flèches haut
// et bas, depuis le champ, changent de résultat courant ; Échap vide le champ et rend la liste des pages.
// La liste reçoit le focus à l'ouverture, pour les flèches, sans montrer le contour de focus, réservé au focus venu
// du clavier : tant qu'aucune touche n'a été frappée dans la barre, chaque arrivée du focus sur la liste est effacée.
// Entrées : enTete, hauteur réservée en haut pour les pastilles de la fenêtre, 0 par défaut ; pages et index, ceux du
// Registre par défaut.
// Sorties : champ, la Recherche ; liste, la Liste des pages ; resultats, la Liste des résultats ; trouves, les
// résultats ([{ page, chemin, libelle }]) ; cherche, vrai quand le champ porte un terme ; rang, rang de la page
// courante ; plaque, la Plaque de la liste des pages (y, height) ; ciblePlaque, l'ordonnée qu'elle vise. Fonctions :
// choisir, parcourir, rentrer, viser.
// Erreurs : aucune ; avant le chargement des tokens, les cotes sont nulles.
// Dépendances : EtatParametres (page, presents, ouvrir), Registre, recherche.js (chercher), Recherche, Liste, Rangee,
// Texte, Vignette, VueCurseur (par Liste), Theme (reglages, space, color).
// Cotes : retrait reglages.sidebarInset ; entrées de reglages.entryHeight, résultats plus hauts de space.scale[1] ;
// titre de groupe en échelon 0, à space.scale[2] au-dessus et space.scale[0] au-dessous ; la plaque est celle de
// Liste.
Item {
    id: barre

    property real enTete: 0
    property var pages: Registre.pages
    property var index: Registre.index
    readonly property int rang: pages.findIndex(p => p.id === EtatParametres.page)
    readonly property var trouves: Moteur.chercher(index, champ.text, EtatParametres.presents)
    readonly property bool cherche: champ.text.trim() !== ""
    readonly property real retrait: Theme.reglages?.sidebarInset ?? 0
    readonly property real ciblePlaque: liste.plaque.cible.y
    readonly property Item plaque: liste.plaque
    readonly property alias champ: champ
    readonly property alias liste: liste
    readonly property alias resultats: resultats
    // Vrai dès qu'une touche a été frappée dans la barre.
    property bool clavierUtilise: false

    // choisir — ouvre la page d'un résultat et conduit à son réglage, puis vide le champ et rend le focus à la liste
    // des pages. Entrée : resultat, { page, chemin, libelle }. Sortie : aucune. Erreurs : aucune.
    // Dépendances : EtatParametres.ouvrir, champ, liste.
    function choisir(resultat) {
        champ.clear()
        EtatParametres.ouvrir(resultat.page, resultat.chemin)
        liste.forceActiveFocus()
    }

    // parcourir — flèche du clavier dans la liste des pages : rend l'entrée voisine courante, lui donne le curseur et
    // ouvre sa page. Le survol, qui change aussi l'entrée courante, n'ouvre ainsi jamais rien.
    // Entrée : pas, -1 vers le haut, 1 vers le bas. Sortie : aucune. Erreurs : aucune ; en bout de liste, l'entrée
    // courante reste et sa page s'ouvre. Dépendances : liste (Liste, dnVue), EtatParametres.ouvrir.
    function parcourir(pas) {
        liste.focusClavier = true
        pas < 0 ? liste.decrementCurrentIndex() : liste.incrementCurrentIndex()
        liste.dnVue.prendre(liste.currentItem)
        EtatParametres.ouvrir(pages[liste.currentIndex].id, [])
    }

    // rentrer — rend la plaque à la page courante quand le curseur a quitté la liste des pages. Le retour est de place
    // seulement : le curseur reste où il est (ailleurs dans la fenêtre, ou nulle part), même si la liste, qui a le
    // focus du clavier, le reprendrait en changeant d'entrée courante. Entrées : aucune. Sortie : aucune.
    // Erreurs : aucune ; le curseur revenu dans la liste entre-temps, rien. Dépendances : liste (Liste, dnVue), rang.
    function rentrer() {
        if (liste.curseurDedans) return
        const porteur = liste.dnVue.porteur
        liste.currentIndex = rang
        // Écriture directe voulue : elle rétablit le porteur d'avant le changement de rangée courante, sans le cycle
        // prendre/lâcher, qui ferait de la rangée de la page courante la porteuse du curseur.
        liste.dnVue.porteur = porteur
    }

    // viser — donne le curseur au résultat courant, celui qu'Entrée ouvrirait, tant que le champ a le focus : la
    // frappe et les flèches sont des gestes du clavier, qui l'emportent sur le dernier survol. Entrée : libre, vrai
    // pour ne le prendre que si personne ne le porte (le pointeur vient de quitter un résultat). Sortie : aucune.
    // Erreurs : aucune ; sans recherche ou sans résultat, rien. Dépendances : resultats (Liste, dnVue), champ.
    function viser(libre) {
        if (cherche && champ.activeFocus && resultats.currentItem && !(libre && resultats.dnVue.porteur))
            resultats.dnVue.prendre(resultats.currentItem)
    }

    onRangChanged: liste.currentIndex = rang
    Component.onCompleted: { liste.currentIndex = rang; liste.forceActiveFocus() }
    Item { id: capteurTouches; Keys.onPressed: event => { barre.clavierUtilise = true; event.accepted = false } }
    Connections {
        target: liste
        function onActiveFocusChanged() { if (liste.activeFocus && !barre.clavierUtilise) liste.focusClavier = false }
    }

    Recherche {
        id: champ
        x: barre.retrait
        y: barre.enTete + (Theme.space?.scale[2] ?? 0)
        width: parent.width - 2 * x
        rayon: Theme.radius?.control ?? 0
        Keys.forwardTo: [capteurTouches]
        Keys.onDownPressed: resultats.incrementCurrentIndex()
        Keys.onUpPressed: resultats.decrementCurrentIndex()
        onAccepted: resultats.currentItem?.active()
    }

    Liste {
        id: liste
        x: barre.retrait - (Theme.space?.scale[0] ?? 0)
        y: champ.y + champ.height
        width: parent.width - 2 * x
        height: Math.min(contentHeight, parent.height - y)
        visible: !barre.cherche
        clip: true
        interactive: false
        model: barre.pages
        selectionSuitCourant: false
        navigation: true
        Keys.forwardTo: [capteurTouches]
        Keys.onUpPressed: barre.parcourir(-1)
        Keys.onDownPressed: barre.parcourir(1)
        onCurseurDedansChanged: if (!curseurDedans) Qt.callLater(barre.rentrer)

        section.property: "groupe"
        section.delegate: Item {
            required property string section
            width: ListView.view.width
            height: titre.height + (Theme.space?.scale[2] ?? 0) + (Theme.space?.scale[0] ?? 0)
            Texte {
                id: titre
                x: Theme.space?.scale[2] ?? 0
                y: x
                text: parent.section
                echelon: 0
                moyen: true
                color: Theme.color?.textTertiary ?? "transparent"
            }
        }

        delegate: Rangee {
            id: entree
            required property var modelData

            implicitHeight: Theme.reglages?.entryHeight ?? 0
            selectionnee: index === barre.rang
            onActive: EtatParametres.ouvrir(modelData.id, [])

            contentItem: RowLayout {
                spacing: Theme.space?.scale[1] ?? 0
                Vignette { glyphe: entree.modelData.glyphe; teinte: entree.modelData.teinte }
                Texte {
                    Layout.fillWidth: true
                    text: entree.modelData.libelle
                    moyen: entree.gras
                    elide: Text.ElideRight
                    color: entree.etat.texte
                }
            }
        }
    }

    Liste {
        id: resultats
        x: liste.x
        y: liste.y + (Theme.space?.scale[1] ?? 0)
        width: liste.width
        height: Math.min(contentHeight, parent.height - y)
        visible: barre.cherche
        clip: true
        interactive: false
        model: barre.trouves
        navigation: true
        onCurrentItemChanged: barre.viser(false)
        onCurseurDedansChanged: if (!curseurDedans) Qt.callLater(barre.viser, true)

        delegate: Rangee {
            id: resultat
            required property var modelData

            implicitHeight: (Theme.reglages?.entryHeight ?? 0) + (Theme.space?.scale[1] ?? 0)
            onActive: barre.choisir(modelData)

            contentItem: ColumnLayout {
                spacing: 0
                Texte { Layout.fillWidth: true; text: resultat.modelData.libelle; moyen: resultat.gras; elide: Text.ElideRight; color: resultat.etat.texte }
                Texte {
                    Layout.fillWidth: true
                    text: Registre.page(resultat.modelData.page)?.libelle ?? ""
                    echelon: 0
                    elide: Text.ElideRight
                    color: Theme.color?.textTertiary ?? "transparent"
                }
            }
        }
    }

    Texte {
        x: barre.retrait + (Theme.space?.scale[0] ?? 0)
        y: resultats.y + (Theme.space?.scale[0] ?? 0)
        visible: barre.cherche && barre.trouves.length === 0
        text: "Aucun résultat"
        color: Theme.color?.textTertiary ?? "transparent"
    }
}
