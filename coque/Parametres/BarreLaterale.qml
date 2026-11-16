import QtQuick
import QtQuick.Layouts
import Quickshell
import "../Theme"
import "../Composants"
import "recherche.js" as Moteur

// BarreLaterale — barre latérale de l'application Paramètres : champ de recherche, puis pages ou résultats.
// Rôle : liste les pages du registre sous le titre de leur groupe, en entrées compactes (vignette et libellé). La
// page courante porte une plaque de sélection unique, qui glisse d'une entrée à l'autre par le ressort « reflow » ;
// son libellé passe en graisse moyenne. La liste est une colonne de navigation (Liste.navigation) : un clic ouvre la
// page, et au clavier la page suit les flèches, comme une barre latérale de macOS. Dès que le champ porte un terme,
// les entrées laissent place aux résultats de la recherche (libellé du réglage, page d'origine) : un clic, ou Entrée
// depuis le champ, ouvre la page du résultat courant et conduit à son réglage, puis vide le champ ; les flèches haut
// et bas, depuis le champ, changent de résultat courant ; Échap vide le champ et rend la liste des pages.
// La liste reçoit le focus à l'ouverture, pour les flèches, sans montrer le contour de focus, réservé au focus venu
// du clavier : tant qu'aucune touche n'a été frappée dans la barre, chaque arrivée du focus sur la liste est effacée.
// Entrées : enTete, hauteur réservée en haut pour les pastilles de la fenêtre, 0 par défaut ; pages et index, ceux du
// Registre par défaut.
// Sorties : champ, la Recherche ; liste, la Liste des pages ; resultats, la Liste des résultats ; trouves, les
// résultats ([{ page, chemin, libelle }]) ; cherche, vrai quand le champ porte un terme ; rang, rang de la page
// courante ; plaque, l'élément de la plaque (y, height) ; ciblePlaque, l'ordonnée qu'elle vise. Fonction : choisir.
// Erreurs : aucune ; avant le chargement des tokens, les cotes sont nulles.
// Dépendances : EtatParametres (page, presents, ouvrir), Registre, recherche.js (chercher), Recherche, Liste, Rangee,
// Texte, Vignette, OmbreControle, Ressort, Theme (reglages, space, radius, color, material.edgeLight, hairline),
// Quickshell (QsWindow, pour le filet).
// Cotes : retrait reglages.sidebarInset ; entrées de reglages.entryHeight, résultats plus hauts de space.scale[1] ;
// titre de groupe en échelon 0, à space.scale[2] au-dessus et space.scale[0] au-dessous ; plaque au rayon
// radius.control, sous un liseré clair d'un pixel physique.
Item {
    id: barre

    property real enTete: 0
    property var pages: Registre.pages
    property var index: Registre.index
    readonly property int rang: pages.findIndex(p => p.id === EtatParametres.page)
    readonly property var trouves: Moteur.chercher(index, champ.text, EtatParametres.presents)
    readonly property bool cherche: champ.text.trim() !== ""
    readonly property real retrait: Theme.reglages?.sidebarInset ?? 0
    readonly property real ciblePlaque: { liste.contentHeight; liste.count; return liste.itemAtIndex(rang)?.y ?? 0 }
    readonly property Item plaque: liste.highlightItem
    readonly property alias champ: champ
    readonly property alias liste: liste
    readonly property alias resultats: resultats
    // Vrai dès qu'une touche a été frappée dans la barre ; posee, vrai une fois la barre mise en page : avant, la
    // plaque se pose sur sa cible au lieu de glisser depuis le haut.
    property bool clavierUtilise: false
    property bool posee: false

    // choisir — ouvre la page d'un résultat et conduit à son réglage, puis vide le champ et rend le focus à la liste
    // des pages. Entrée : resultat, { page, chemin, libelle }. Sortie : aucune. Erreurs : aucune.
    // Dépendances : EtatParametres.ouvrir, champ, liste.
    function choisir(resultat) {
        champ.clear()
        EtatParametres.ouvrir(resultat.page, resultat.chemin)
        liste.forceActiveFocus()
    }

    // marquer — rend la barre « posée », au tour qui suit sa construction. Entrées : aucune. Sortie : aucune.
    // Erreurs : aucune. Dépendances : aucune.
    function marquer() { posee = true }

    onRangChanged: liste.currentIndex = rang
    Component.onCompleted: { liste.currentIndex = rang; liste.forceActiveFocus(); Qt.callLater(marquer) }
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
        onCurrentIndexChanged: if (focusClavier && currentIndex >= 0 && currentIndex !== barre.rang)
            EtatParametres.ouvrir(barre.pages[currentIndex].id, [])

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

        // Plaque de sélection : une seule pour la liste, peinte sous les entrées, que le ressort conduit à l'entrée
        // de la page courante.
        highlightFollowsCurrentItem: false
        highlight: Item {
            width: liste.width
            height: Theme.reglages?.entryHeight ?? 0
            y: glisse.value
            visible: barre.rang >= 0

            Ressort {
                id: glisse
                transition: "reflow"
                cible: barre.ciblePlaque
                onCibleChanged: if (!barre.posee) poser()
            }
            Rectangle {
                id: fond
                x: Theme.space?.scale[0] ?? 0
                width: parent.width - 2 * x
                height: parent.height
                radius: Theme.radius?.control ?? 0
                color: Theme.color?.controlRaised ?? "transparent"

                OmbreControle { cible: fond }
                Rectangle {
                    x: fond.radius
                    width: parent.width - 2 * x
                    height: Theme.hairline(QsWindow.window?.devicePixelRatio ?? 1) ?? 0
                    color: Theme.material?.edgeLight ?? "transparent"
                }
            }
        }

        delegate: Rangee {
            id: entree
            required property var modelData
            readonly property bool choisie: index === barre.rang

            implicitHeight: Theme.reglages?.entryHeight ?? 0
            gras: choisie
            // L'entrée choisie ne peint pas de survol par-dessus sa plaque.
            hoverEnabled: !choisie
            onActive: EtatParametres.ouvrir(modelData.id, [])

            contentItem: RowLayout {
                spacing: Theme.space?.scale[1] ?? 0
                Vignette { glyphe: entree.modelData.glyphe; teinte: entree.modelData.teinte }
                Texte {
                    Layout.fillWidth: true
                    text: entree.modelData.libelle
                    moyen: entree.gras
                    elide: Text.ElideRight
                    color: (entree.choisie ? Theme.color?.textEmphasis : entree.etat.texte) ?? "transparent"
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
